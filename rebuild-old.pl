#!/usr/bin/env perl
# -*- mode: cperl; indent-tabs-mode: nil; tab-width: 3; cperl-indent-level: 3; -*-
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

foreach my $pkg (@$pkgs) {
   # If a package path is given, only rebuild that package, but force a rebuild of it
   if ($ARGV[0] && $ARGV[0] ne @$pkg[0]) {
      next;
   }

   print "Package: @$pkg[0]\n";
   my $gv = `./get-version.pl --url '@$pkg[1]' --file '@$pkg[2]' 2>/dev/null`;
   chomp($gv);
   my ($version,$srcdate) = split(/\t/, $gv);
   print "\tlatest: $version\n";
   my ($pkname) = (@$pkg[0] =~ m@([-\w]+)$@);
   my $first = substr($pkname, 0, 1);
   my $oldversion = `dpkg -I ~apertium/public_html/apt/nightly/pool/main/$first/$pkname/$pkname\_*-0ubuntu*~precise*_a*.deb | grep 'Version:' | head -n 1 | egrep -o '[0-9].*\$'`;
   chomp($oldversion);
   print "\texisting: $oldversion\n";
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
            print "\tdependency $dep was rebuilt\n";
            last;
         }
      }
   }

   if ($gt || $rebuild || $ARGV[0]) {
      my $distv = 1;
      if (!$gt) {
         # If the current version is the same as the old version, bump the distro version since this means we're rebuilding due to a newer dependency
         ($distv) = ($oldversion =~ m@(\d+)~\w+$@);
         ++$distv;
      }
      print "\tdistv: $distv\n";

      my $cli = "./make-deb-source.pl -p '@$pkg[0]' -u '@$pkg[1]' -v '$version' --distv '$distv' -d '$srcdate' -m 'Apertium Automaton <apertium-packaging\@lists.sourceforge.net>' -e 'Apertium Automaton <apertium-packaging\@lists.sourceforge.net>'";
      if (@$pkg[3]) {
         $cli .= " -r '@$pkg[3]'";
      }
      print "\tlaunching: $cli\n";
      `$cli >&2`;
      `./build-debian-ubuntu.sh '$pkname' >&2`;

      my $ls = `ls -1 ~apertium/public_html/apt/nightly/pool/main/$first/$pkname/ | egrep -o '^[^_]+' | sort | uniq`;
      foreach my $pk (split(/\s+/, $ls)) {
         chomp($pk);
         $rebuilt{$pk} = 1;
         print "\trebuilt: $pk\n";
      }
   }
}
