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

$ENV{'PATH'} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:'.$ENV{'PATH'};

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
my @failed = ();

use IO::Tee;
open my $log, ">/tmp/rebuild.$$.log" or die "Failed to open rebuild.log: $!\n";
my $out2 = IO::Tee->new($log, \*STDOUT);
print {$out2} "Build started ".`date -u`;
`rm -f /var/cache/pbuilder/aptcache/*.deb`;

foreach my $pkg (@$pkgs) {
   # If a package path is given, only rebuild that package, but force a rebuild of it
   if ($ARGV[0] && $ARGV[0] ne @$pkg[0]) {
      next;
   }

   my ($pkname) = (@$pkg[0] =~ m@([-\w]+)$@);
   my $logpath = "/home/apertium/public_html/apt/logs/$pkname";
   `mkdir -p $logpath/`;
   open my $pkglog, ">$logpath/rebuild.log" or die "Failed to open $logpath/rebuild.log: $!\n";
   my $out = IO::Tee->new($out2, $pkglog);

   if (!@$pkg[1]) {
      @$pkg[1] = 'http://svn.code.sf.net/p/apertium/svn/'.@$pkg[0];
   }
   if (!@$pkg[2]) {
      @$pkg[2] = 'configure.ac';
   }

   print {$out} "\n";
   print {$out} "Package: @$pkg[0]\n";
   print {$out} "\tstarted: ".`date -u`;

   # Determine latest version and date stamp from the repository
   my $gv = `./get-version.pl --url '@$pkg[1]' --file '@$pkg[2]' 2>$logpath/stderr.log`;
   chomp($gv);
   my ($version,$srcdate) = split(/\t/, $gv);
   print {$out} "\tlatest: $version\n";

   # Determine existing package version, if any
   my $first = substr($pkname, 0, 1);
   my $oldversion = '0.0.0.0';
   if (-e "/home/apertium/public_html/apt/nightly/pool/main/$first/$pkname") {
      $oldversion = `dpkg -I ~apertium/public_html/apt/nightly/pool/main/$first/$pkname/$pkname\_*~sid*_a*.deb | grep 'Version:' | egrep -o '[-.0-9]+' | head -n 1`;
      chomp($oldversion);
   }
   print {$out} "\texisting: $oldversion\n";

   # Figure out if the latest is newer than existing, which is complicated enough that we just ask dpkg
   my $gt = `dpkg --compare-versions '$version' gt '$oldversion' && echo 1 || echo 0` + 0;

   my $rebuild = 0;
   if (!$gt) {
      # Current version is not newer, so check if any dependencies were rebuilt
      # ToDo: This should really check the actual .deb dependencies and files
      # Counter-ToDo: Since .deb packages have no clue about Build-Depends, we'd need to check both anyway, so this is fine for now
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

   if (!($gt || $rebuild || $ARGV[0])) {
      # Package doesn't need rebuilding, so skip to cleanup
      goto CLEANUP;
   }

   my $distv = 1;
   if (!$gt) {
      # If the current version is the same as the old version, bump the distro version since this means we're rebuilding due to a newer dependency
      ($distv) = ($oldversion =~ m@(\d+)$@);
      ++$distv;
   }
   print {$out} "\tdistv: $distv\n";

   # Create the source packages
   my $cli = "-p '@$pkg[0]' -u '@$pkg[1]' -v '$version' --distv '$distv' -d '$srcdate' -m 'Apertium Automaton <apertium-packaging\@lists.sourceforge.net>' -e 'Apertium Automaton <apertium-packaging\@lists.sourceforge.net>'";
   if (@$pkg[3]) {
      $cli .= " -r '@$pkg[3]'";
   }
   print {$out} "\tlaunching rebuild\n";
   `./make-deb-source.pl $cli 2>>$logpath/stderr.log >&2`;
   my $is_data = '';
   if (@$pkg[0] =~ m@^languages/@ || @$pkg[0] =~ m@/apertium-\w{2,3}-\w{2,3}$@) {
      # If this is a data-only package, only build it for one arch per distro
      print {$out} "\tdata only\n";
      $is_data = 'data';
   }

   # Build the packages for Debian/Ubuntu
   `./build-debian-ubuntu.sh '$pkname' '$is_data' 2>>$logpath/stderr.log >&2`;
   my $failed = '';
   $failed = `grep -L 'dpkg-genchanges' \$(grep -l 'Copying COW directory' \$(find /home/apertium/public_html/apt/logs/$pkname -newermt \$(date '+\%Y-\%m-\%d' -d '1 day ago') -type f))`;
   chomp($failed);

   # If debs did not fail building, try RPMs
   if (!$failed) {
      `./make-rpm-source.pl $cli 2>>$logpath/stderr.log >&2`;
   }
   print {$out} "\tstopped: ".`date -u`;

   if ($failed) {
      push(@failed, $pkname);
      # Gather up URLs for the logs of the failed builds
      print {$out} "\tFAILED:\n";
      foreach my $fail (split(/\n/, $failed)) {
         chomp($fail);
         $fail =~ s@^/home/apertium/public_html@http://apertium.projectjj.com@;
         print {$out} "\t\t$fail\n";
      }

      # Determine who was most likely responsible for breaking the build
      my ($oldrev) = ($oldversion =~ m@^\d+\.\d+\.\d+\.(\d+)@);
      ++$oldrev;
      my ($newrev) = ($version =~ m@\.(\d+)$@);
      # Check that $oldrev is less than newrev, but greater than 1
      if (!$oldrev || $oldrev <= 1 || $oldrev >= $newrev) {
         goto CLEANUP;
      }
      my $blames = `svn log -q -r$oldrev:$newrev '@$pkg[1]' | egrep '^r' | awk '{ print \$3 }' | sort | uniq`;
      chomp($blames);
      print {$out} "\tblames in revisions $oldrev:$newrev :\n";
      my $cc = '';
      foreach my $blame (split(/\n/, $blames)) {
         chomp($blame);
         $blames{$blame} = 1;
         print {$out} "\t\t$blame\n";
         # Add the suspect to CC so they are directly notified
         $cc .= " '$blame\@users.sourceforge.net'";
      }

      my $subject = "@$pkg[0] failed nightly build";
      # Don't send individual emails if this is a single package build, or if the package isn't from SourceForge.
      if (!$ARGV[0] && @$pkg[1] =~ m@^http://svn.code.sf.net/@) {
         `cat $logpath/rebuild.log | mail -s '$subject' -r 'apertium-packaging\@projectjj.com' 'apertium-packaging\@lists.sourceforge.net' $cc`;
      }
      goto CLEANUP;
   }

   # Add the resulting .deb to the Apt repository
   # Note that this does not happen if ANY failure was detected, to ensure we don't get partially-updated trees
   `./reprepro.sh '$pkname' 2>>$logpath/stderr.log >&2`;

   # Add the resulting .rpms to the Yum repositories
   if (-s "/home/apertium/rpmbuild/SRPMS/$pkname-$version-$distv.src.rpm") {
      open my $yumlog, ">$logpath/createrepo.log" or die "Failed to open $logpath/createrepo.log: $!\n";
      my %distros;
      `rm -rf /home/apertium/public_html/yum/nightly/*/$first/$pkname`;
      my $rpms = `find /home/apertium/mock/ -type f -name '*.rpm'`;
      chomp($rpms);
      foreach my $rpm (split(/\n/, $rpms)) {
         chomp($rpm);
         my $nc = $rpm;
         $nc =~ s@\.centos@@g;
         my ($distro,$arch) = $nc =~ m@\.([^.]+)\.([^.]+)\.rpm$@;
         $distros{$distro} = 1;
         `mkdir -p /home/apertium/public_html/yum/nightly/$distro/$first/$pkname`;
         `su apertium -c "/home/apertium/bin/rpmsign.exp '$rpm'"`;
         print {$yumlog} `mv -fv '$rpm' /home/apertium/public_html/yum/nightly/$distro/$first/$pkname/`;
      }
      `chown -R apertium:apertium /home/apertium/public_html/yum`;
      foreach my $distro (keys(%distros)) {
         print {$yumlog} "Recreating $distro yum repo\n";
         print {$yumlog} `su apertium -c "createrepo --database '/home/apertium/public_html/yum/nightly/$distro/'"`;
         unlink("/home/apertium/public_html/yum/nightly/$distro/repodata/repomd.xml.asc");
         `su apertium -c "gpg --detach-sign --armor '/home/apertium/public_html/yum/nightly/$distro/repodata/repomd.xml'"`;
      }
      close $yumlog;
   }

   # Get a list of resulting packages and mark them all as rebuilt
   my $ls = `ls -1 ~apertium/public_html/apt/nightly/pool/main/$first/$pkname/ | egrep -o '^[^_]+' | sort | uniq`;
   foreach my $pk (split(/\s+/, $ls)) {
      chomp($pk);
      $rebuilt{$pk} = 1;
      print {$out} "\trebuilt: $pk\n";
   }

   CLEANUP:
   close $pkglog;
}

print {$out2} "\n";
print {$out2} "Build stopped at ".`date -u`;
close $log;

# If any package was (attempted) rebuilt, send a status email
if (!$ARGV[0] && (%rebuilt || %blames)) {
   my $subject = 'Nightly: ';
   if (%blames) {
      $subject .= 'Failures (att:';
      foreach my $blame (sort(keys(%blames))) {
         $subject .= " $blame";
      }
      $subject .= ')';
   }
   elsif (@failed) {
      $subject .= 'Failures';
   }
   else {
      $subject .= 'Success';
   }
   `cat /tmp/rebuild.$$.log | mail -s '$subject' -r 'apertium-packaging\@projectjj.com' 'apertium-packaging\@lists.sourceforge.net'`;
}

unlink("/tmp/rebuild.$$.log");
