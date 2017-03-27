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

if (-s '/tmp/rebuild.lock') {
   die "Another instance of builder is running - bailing out!\n";
}
`date -u > /tmp/rebuild.lock`;

use Getopt::Long;
my $release = 0;
my $dry = 0;
my $rop = GetOptions(
   "release|r!" => \$release,
   "dry|n!" => \$dry,
   );

$ENV{'PATH'} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:'.$ENV{'PATH'};
$ENV{'DEBIAN_FRONTEND'} = 'noninteractive';
$ENV{'DEBCONF_NONINTERACTIVE_SEEN'} = 'true';
$ENV{'BUILDTYPE'} = ($release == 1) ? 'release' : 'nightly';

use File::Basename;
my $dir = dirname(__FILE__);
chdir($dir) or die $!;
use Cwd;
$dir = getcwd();
if (!(-x 'get-version.pl')) {
   die "get-version.pl not found in $dir!\n";
}
if (!(-s 'packages.json')) {
   die "packages.json not found in $dir!\n";
}
if (!(-s 'authors.json')) {
   die "authors.json not found in $dir!\n";
}

use JSON;
my $pkgs = ();
{
   local $/ = undef;
   open FILE, 'packages.json' or die "Could not open packages.json: $!\n";
   my $data = <FILE>;
   $pkgs = JSON->new->relaxed->decode($data);
   close FILE;
}

my $authors = ();
{
   local $/ = undef;
   open FILE, 'authors.json' or die "Could not open authors.json: $!\n";
   my $data = <FILE>;
   $authors = JSON->new->relaxed->decode($data);
   close FILE;
}

my %rebuilt = ();
my %blames = ();
my @failed = ();
my $win32 = 0;
my $osx = 0;
my $aptget = 0;

use IO::Tee;
open my $log, ">/tmp/rebuild.$$.log" or die "Failed to open rebuild.log: $!\n";
my $out2 = IO::Tee->new($log, \*STDOUT);
print {$out2} "Build $ENV{BUILDTYPE} started ".`date -u`;
`rm -f /var/cache/pbuilder/aptcache/*.deb`;
`rm -f /tmp/update-*.log`;

if ($ARGV[0]) {
   $ARGV[0] =~ s@/$@@g;
}

foreach my $pkg (@$pkgs) {
   # If a package path is given, only rebuild that package, but force a rebuild of it
   if ($ARGV[0] && @$pkg[0] !~ m@/\Q$ARGV[0]\E$@) {
      next;
   }

   my ($pkname) = (@$pkg[0] =~ m@([-\w]+)$@);
   my $logpath = "/home/apertium/public_html/apt/logs/$pkname";
   `mkdir -p $logpath/ && rm -f $logpath/*-*`;
   open my $pkglog, ">$logpath/rebuild.log" or die "Failed to open $logpath/rebuild.log: $!\n";
   my $out = IO::Tee->new($out2, $pkglog);

   if (!@$pkg[1]) {
      @$pkg[1] = 'http://svn.code.sf.net/p/apertium/svn/'.@$pkg[0];
   }
   if (!@$pkg[2]) {
      @$pkg[2] = 'configure.ac';
   }
   if (!@$pkg[4]) {
      @$pkg[4] = '';
   }

   print {$out} "\n";
   print {$out} "Package: @$pkg[0]\n";
   print {$out} "\tstarted: ".`date -u`;

   my $rev = '';
   if ($release) {
      $rev = `head -n1 @$pkg[0]/debian/changelog | egrep -o '~r[0-9]+' | egrep -o '[0-9]+'`;
      chomp($rev);
      if (!$rev || $rev eq '' || $rev+0 < 1) {
         print {$out} "\tmissing release revision: $rev\n";
         next;
      }
      print {$out} "\trelease rev: $rev\n";
      $rev = "--rev '$rev'";
   }
   # Determine latest version and date stamp from the repository
   my $gv = `./get-version.pl --url '@$pkg[1]' --file '@$pkg[2]' $rev 2>$logpath/stderr.log`;
   chomp($gv);
   my ($version,$srcdate) = split(/\t/, $gv);
   my ($newrev) = ($version =~ m@~r(\d+)$@);
   if (!$newrev) {
      print {$out} "\tmissing revision: $newrev\n";
      next;
   }
   print {$out} "\tlatest: $version\n";

   # Determine existing package version, if any
   my $first = substr($pkname, 0, 1);
   if ($pkname =~ m@^lib@) {
      $first = substr($pkname, 0, 4);
   }
   my $oldversion = '0.0.0~r0';
   if (-e "/home/apertium/public_html/apt/$ENV{BUILDTYPE}/pool/main/$first/$pkname") {
      $dir = getcwd();
      chdir("/home/apertium/public_html/apt/$ENV{BUILDTYPE}/pool/main/$first/$pkname/");
      $oldversion = `dpkg -I \$(ls -1 *~sid*.deb | head -n1) | grep 'Version:' | egrep -o '[-.0-9]+~r[-.0-9]+' | head -n 1`;
      chomp($oldversion);
      chdir($dir);
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
      $deps = `svn cat $deps/debian/control`;
      $deps = join("\n", ($deps =~ m@Build-Depends:(\s*.*?)\n\S@gs));
      foreach my $dep (split(/[,|\n]/, $deps)) {
         $dep =~ s@\([^)]+\)@@g;
         $dep =~ s@\s+$@@gs;
         $dep =~ s@^\s+@@gs;
         if ($dep && defined $rebuilt{$dep}) {
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
   my $cli = "-p '@$pkg[0]' -u '@$pkg[1]' -v '$version' --distv '$distv' -d '$srcdate' $rev -m 'Apertium Automaton <apertium-packaging\@lists.sourceforge.net>' -e 'Apertium Automaton <apertium-packaging\@lists.sourceforge.net>'";
   if (@$pkg[3]) {
      $cli .= " -r '@$pkg[3]'";
   }
   print {$out} "\tlaunching rebuild\n";
   `./make-deb-source.pl $cli 2>>$logpath/stderr.log >&2`;

   my $is_data = '';
   if (@$pkg[0] =~ m@^languages/@ || @$pkg[0] =~ m@/apertium-\w{2,3}-\w{2,3}$@ || @$pkg[0] =~ m@/giella-@ || @$pkg[0] =~ m@-java$@) {
      # If this is a data-only package, only build it once for latest Debian Sid
      print {$out} "\tdata only\n";
      $is_data = 'data';
   }
   if (@$pkg[0] =~ m@/apertium-apy$@ || @$pkg[0] =~ m@/streamparser$@) {
      print {$out} "\tarch-all\n";
      $is_data = 'arch-all';
   }
   if ($dry || $is_data eq 'data') {
      @$pkg[4] = "wheezy,jessie,stretch,trusty,xenial,yakkety";
   }

   # Build the packages for Debian/Ubuntu
   `./build-debian-ubuntu.sh '$pkname' '$is_data' ',@$pkg[4],' 2>>$logpath/stderr.log >&2`;
   my $failed = '';
   $failed = `grep -L 'dpkg-genchanges' \$(grep -l 'Copying COW directory' \$(find /home/apertium/public_html/apt/logs/$pkname -type f))`;
   chomp($failed);

   my $hashfail = '';
   $hashfail = `grep -l 'Hash Sum mismatch' \$(grep -l 'Copying COW directory' \$(find /home/apertium/public_html/apt/logs/$pkname -type f))`;
   chomp($hashfail);
   if ($hashfail) {
      print {$out} "\tsoft fail: hash sum mismatch\n";
   }

   my $depfail = '';
   $depfail = `grep -l 'packages have unmet dependencies' \$(grep -l 'Copying COW directory' \$(find /home/apertium/public_html/apt/logs/$pkname -type f))`;
   chomp($depfail);
   if ($depfail) {
      print {$out} "\tsoft fail: unmet dependencies\n";
   }

   if ($dry) {
      print {$out} "\tparched\n";
      last;
   }

   print {$out} "\trunning lintian\n";
   `find /var/cache/pbuilder/result/ -type f -name '*.deb' -print0 | xargs -0rn1 '-I{}' sh -c "echo '{}'; lintian -IEv --pedantic --color auto '{}'; echo '';" >$logpath/lintian.log 2>&1`;

   # If debs did not fail building, try RPMs and win32
   if (!$failed) {
      if (-s "@$pkg[0]/rpm/$pkname.spec") {
         print {$out} "\tupdating rpm sources\n";
         `./make-rpm-source.pl $cli 2>>$logpath/stderr.log >&2`;
      }
      elsif ($is_data eq 'data') {
         print {$out} "\tupdating rpm from data\n";
         `./make-rpm-data.pl $cli 2>>$logpath/stderr.log >&2`;
      }

      if (-s "@$pkg[0]/win32/$pkname.sh") {
         print {$out} "\tbuilding win32\n";
         $ENV{'BITWIDTH'} = 'i686';
         $ENV{'WINX'} = 'win32';
         `bash -c '. $dir/win32-pre.sh; . $dir/@$pkg[0]/win32/$pkname.sh; . $dir/win32-post.sh;' -- '$pkname' '$newrev' '$version-$distv' '$dir/@$pkg[0]' 2>$logpath/win32.log >&2`;

         print {$out} "\tbuilding win64\n";
         $ENV{'BITWIDTH'} = 'x86_64';
         $ENV{'WINX'} = 'win64';
         `bash -c '. $dir/win32-pre.sh; . $dir/@$pkg[0]/win32/$pkname.sh; . $dir/win32-post.sh;' -- '$pkname' '$newrev' '$version-$distv' '$dir/@$pkg[0]' 2>$logpath/win64.log >&2`;

         $win32 = 1;
      }

      if (-s "@$pkg[0]/osx/$pkname.sh") {
         print {$out} "\tbuilding osx\n";
         `bash -c '. $dir/osx-pre.sh; . $dir/@$pkg[0]/osx/$pkname.sh; . $dir/osx-post.sh;' -- '$pkname' '$newrev' '$version-$distv' '$dir/@$pkg[0]' 2>$logpath/osx.log >&2`;
         $osx = 1;
      }

      if ($is_data) {
         $aptget = 1;
      }
   }
   print {$out} "\tstopped: ".`date -u`;

   if ($failed) {
      push(@failed, $pkname);
      # Gather up URLs for the logs of the failed builds
      print {$out} "\tFAILED:\n";
      foreach my $fail (split(/\n/, $failed)) {
         chomp($fail);
         $fail =~ s@^/home/apertium/public_html@https://apertium.projectjj.com@;
         print {$out} "\t\t$fail\n";
      }

      # Determine who was most likely responsible for breaking the build
      my ($oldrev) = ($oldversion =~ m@^\d+\.\d+\.\d+~r(\d+)@);
      ++$oldrev;
      # Check that $oldrev is less than newrev, but greater than 1
      if (!$oldrev || $oldrev <= 1 || $oldrev >= $newrev || $hashfail || $depfail) {
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
         if (defined $authors->{$blame}) {
            my $who = $authors->{$blame};
            $cc .= " '$who'";
         }
      }

      my $subject = "@$pkg[0] failed $ENV{BUILDTYPE} build";
      # Don't send individual emails if this is a single package build
      if (!$ARGV[0] && $cc ne '') {
         `cat $logpath/rebuild.log | mail -s '$subject' -r 'apertium-packaging\@projectjj.com' 'apertium-packaging\@lists.sourceforge.net' $cc`;
      }
      goto CLEANUP;
   }

   # Add the resulting .deb to the Apt repository
   # Note that this does not happen if ANY failure was detected, to ensure we don't get partially-updated trees
   `./reprepro.sh '$pkname' '$is_data' ',@$pkg[4],' 2>>$logpath/stderr.log >&2`;

   if (-s "@$pkg[0]/hook.post" && -x "@$pkg[0]/hook.post") {
      `./@$pkg[0]/hook.post >$logpath/hook.post.log 2>&1`;
   }

=pod
   # Add the resulting .rpms to the Yum repositories
   if (-s "/home/apertium/rpmbuild/SRPMS/$pkname-$version-$distv.src.rpm") {
      open my $yumlog, ">$logpath/createrepo.log" or die "Failed to open $logpath/createrepo.log: $!\n";
      my %distros;
      `rm -rf /home/apertium/public_html/yum/$ENV{BUILDTYPE}/*/$first/$pkname`;
      my $rpms = `find /home/apertium/mock/ -type f -name '*.rpm'`;
      chomp($rpms);
      foreach my $rpm (split(/\n/, $rpms)) {
         chomp($rpm);
         my $nc = $rpm;
         $nc =~ s@\.centos@@g;
         my ($distro,$arch) = $nc =~ m@\.([^.]+)\.([^.]+)\.rpm$@;
         $distros{$distro} = 1;
         `mkdir -p /home/apertium/public_html/yum/$ENV{BUILDTYPE}/$distro/$first/$pkname`;
         `su apertium -c "/home/apertium/bin/rpmsign.exp '$rpm'"`;
         print {$yumlog} `mv -fv '$rpm' /home/apertium/public_html/yum/$ENV{BUILDTYPE}/$distro/$first/$pkname/`;
      }
      `chown -R apertium:apertium /home/apertium/public_html/yum`;
      foreach my $distro (keys(%distros)) {
         print {$yumlog} "Recreating $distro yum repo\n";
         print {$yumlog} `su apertium -c "createrepo --database '/home/apertium/public_html/yum/$ENV{BUILDTYPE}/$distro/'"`;
         unlink("/home/apertium/public_html/yum/$ENV{BUILDTYPE}/$distro/repodata/repomd.xml.asc");
         `su apertium -c "gpg --detach-sign --armor '/home/apertium/public_html/yum/$ENV{BUILDTYPE}/$distro/repodata/repomd.xml'"`;
      }
      close $yumlog;
   }
=cut

   # Get a list of resulting packages and mark them all as rebuilt
   my $ls = `ls -1 ~apertium/public_html/apt/$ENV{BUILDTYPE}/pool/main/$first/$pkname/ | egrep -o '^[^_]+' | sort | uniq`;
   foreach my $pk (split(/\s+/, $ls)) {
      chomp($pk);
      $rebuilt{$pk} = 1;
      print {$out} "\trebuilt: $pk\n";
   }

   CLEANUP:
   close $pkglog;
}

print {$out2} "\n";

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

if ($win32) {
   print {$out2} "Combining Win32 builds\n";
   $ENV{'BITWIDTH'} = 'i686';
   $ENV{'WINX'} = 'win32';
   `./win32-combine.sh`;

   print {$out2} "Combining Win64 builds\n";
   $ENV{'BITWIDTH'} = 'x86_64';
   $ENV{'WINX'} = 'win64';
   `./win32-combine.sh`;
}
if ($osx) {
   print {$out2} "Combining OS X builds\n";
   `./osx-combine.sh`;
}
if ($aptget && !$release) {
   print {$out2} "Installing new data packages\n";
   `./apt-get-upgrade.sh`;
}

print {$out2} "Build $ENV{BUILDTYPE} stopped at ".`date -u`;
close $log;
unlink("/tmp/rebuild.$$.log");
unlink('/tmp/rebuild.lock');
