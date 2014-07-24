#!/usr/bin/env perl
# -*- mode: cperl; indent-tabs-mode: nil; tab-width: 3; cperl-indent-level: 3; -*-
# Copyright (C) 2014, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 2 or later; see http://www.gnu.org/licenses/
use utf8;
use strict;
use warnings;
BEGIN {
	$| = 1;
	binmode(STDIN, ':encoding(UTF-8)');
	binmode(STDOUT, ':encoding(UTF-8)');
}
use open qw( :encoding(UTF-8) :std );

use File::Basename;
my $dir = dirname(__FILE__);
chdir($dir) or die $!;
if (!(-x 'get-version.pl')) {
   die "get-version.pl not found in $dir!\n";
}
if (!(-s 'packages.json')) {
   die "packages.json not found in $dir!\n";
}

use JSON;
my $pkgs = ();
{
	local $/ = undef;
	open FILE, 'packages.json' or die "Could not open packages.json: $!\n";
	my $data = <FILE>;
   $pkgs = JSON->new->utf8->relaxed->decode($data);
   close FILE;
}

my %rebuilt = ();
my %blames = ();

use IO::Tee;
open my $log, '>rebuild.log' or die "Failed to open rebuilt.log: $!\n";
my $out = IO::Tee->new($log, \*STDOUT);

foreach my $pkg (@$pkgs) {
   # If a package path is given, only rebuild that package, but force a rebuild of it
   if ($ARGV[0] && $ARGV[0] ne @$pkg[0]) {
      next;
   }

   if (!@$pkg[2]) {
      @$pkg[2] = 'configure.ac';
   }

   print {$out} "Package: @$pkg[0]\n";
   my $gv = `./get-version.pl --url '@$pkg[1]' --file '@$pkg[2]' 2>/dev/null`;
   chomp($gv);
   my ($version,$srcdate) = split(/\t/, $gv);
   print {$out} "\tlatest: $version\n";
   my ($pkname) = (@$pkg[0] =~ m@([-\w]+)$@);
   my $first = substr($pkname, 0, 1);
   my $oldversion = '0.0.0.0';
   if (-e "/home/apertium/public_html/apt/nightly/pool/main/$first/$pkname") {
      $oldversion = `dpkg -I ~apertium/public_html/apt/nightly/pool/main/$first/$pkname/$pkname\_*~sid*_a*.deb | grep 'Version:' | egrep -o '[-.0-9]+' | head -n 1`;
      chomp($oldversion);
   }
   print {$out} "\texisting: $oldversion\n";
   my $gt = `dpkg --compare-versions '$version' gt '$oldversion' && echo 1 || echo 0` + 0;

   my $rebuild = 0;
   if (!$gt) {
      # Current version is not newer, so check if any dependencies were rebuilt
      # ToDo: This should really check the actual .deb dependencies and files
      my $deps = (@$pkg[3]) || ('http://svn.code.sf.net/p/apertium/svn/branches/packaging/'.@$pkg[0]);
      $deps = `svn cat $deps/debian/control | egrep '^Build-Depends:' | sort | uniq`;
      $deps =~ s@(Build-)?Depends:\s*@@g;
      foreach my $dep (split(/[,|\n]/, $deps)) {
         $dep =~ s@\([^)]+\)@@g;
         $dep =~ s@\s$@@g;
         $dep =~ s@^\s@@g;
         if (defined $rebuilt{$dep}) {
            $rebuild = 1;
            print {$out} "\tdependency $dep was rebuilt\n";
            last;
         }
      }
   }

   if ($gt || $rebuild || $ARGV[0]) {
      my $distv = 1;
      if (!$gt) {
         # If the current version is the same as the old version, bump the distro version since this means we're rebuilding due to a newer dependency
         ($distv) = ($oldversion =~ m@(\d+)$@);
         ++$distv;
      }
      print {$out} "\tdistv: $distv\n";

      my $cli = "./make-deb-source.pl -p '@$pkg[0]' -u '@$pkg[1]' -v '$version' --distv '$distv' -d '$srcdate' -m 'Apertium Automaton <apertium-packaging\@lists.sourceforge.net>' -e 'Apertium Automaton <apertium-packaging\@lists.sourceforge.net>'";
      if (@$pkg[3]) {
         $cli .= " -r '@$pkg[3]'";
      }
      print {$out} "\tlaunching rebuild\n";
      `$cli >&2`;
      my $is_data = '';
      if (@$pkg[0] =~ m@^languages/@ || @$pkg[0] =~ m@/apertium-\w{2,3}-\w{2,3}@) {
         print {$out} "\tdata only\n";
         $is_data = 'data';
      }
      `./build-debian-ubuntu.sh '$pkname' '$is_data' >&2`;

      my $failed = `grep -L 'dpkg-genchanges' \$(grep -l 'Copying COW directory' \$(find /home/apertium/public_html/apt/logs/$pkname -newermt \$(date '+\%Y-\%m-\%d' -d '1 day ago') -type f))`;
      chomp($failed);
      if ($failed) {
         print {$out} "\tFAILED:\n";
         foreach my $fail (split(/\n/, $failed)) {
            chomp($fail);
            $fail =~ s@^/home/apertium/public_html@http://apertium.projectjj.com@;
            print {$out} "\t\t$fail\n";
         }
         my ($oldrev) = $oldversion =~ m@\.(\d+)$@;
         ++$oldrev;
         my ($newrev) = $version =~ m@\.(\d+)$@;
         my $blames = `svn log -q -r$oldrev:$newrev '@$pkg[1]' | egrep '^r' | awk '{ print \$3 }' | sort | uniq`;
         chomp($blames);
         print {$out} "\tblames in revisions $oldrev:$newrev :\n";
         foreach my $blame (split(/\n/, $blames)) {
            chomp($blame);
            $blames{$blame} = 1;
            print {$out} "\t\t$blame\n";
         }
         next;
      }

      `./reprepro.sh '$pkname' >&2`;

      my $ls = `ls -1 ~apertium/public_html/apt/nightly/pool/main/$first/$pkname/ | egrep -o '^[^_]+' | sort | uniq`;
      foreach my $pk (split(/\s+/, $ls)) {
         chomp($pk);
         $rebuilt{$pk} = 1;
         print {$out} "\trebuilt: $pk\n";
      }
   }
}

close $log;

if (!$ARGV[0] && (%rebuilt || %blames)) {
   my $subject = '[TEST] Nightly';
   my $cc = '';
   if (%blames) {
      $subject .= ': Failures (att:';
      foreach my $blame (sort(keys(%blames))) {
         $subject .= " $blame";
         $cc .= " '$blame\@users.sourceforge.net'";
      }
      $subject .= ')';
   }
   else {
      $subject .= ': Success';
   }
   `cat rebuild.log | mail -s '$subject' -r 'apertium-packaging\@projectjj.com' 'apertium-packaging\@lists.sourceforge.net' $cc`;
}
