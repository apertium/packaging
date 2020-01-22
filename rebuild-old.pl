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
use autodie qw(:all);
use List::MoreUtils qw(uniq);

use FindBin qw($Bin);
use lib "$Bin/";
use Helpers;

`mkdir -p /opt/autopkg`;
if (-s '/opt/autopkg/rebuild.lock') {
   die "Another instance of builder is running - bailing out!\n";
}
`date -u > /opt/autopkg/rebuild.lock`;

use Getopt::Long;
Getopt::Long::Configure('no_ignore_case');
my $release = 0;
my $refresh = 0;
my $dry = 0;
my $staccato = 0;
my $distro = '';
my $rop = GetOptions(
   'release|r!' => \$release,
   'refresh!' => \$refresh,
   'dry|n!' => \$dry,
   'staccato!' => \$staccato,
   'distro=s' => \$distro,
   );

$ENV{'PATH'} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:'.$ENV{'PATH'};
$ENV{'BUILDTYPE'} = ($release == 1) ? 'release' : 'nightly';

use File::Copy;
use Cwd;
$ENV{'AUTOPKG_HOME'} = $Bin;
my $dir = $Bin;
chdir($dir);

use JSON;
my %pkgs = load_packages();
my $authors = JSON->new->relaxed->decode(file_get_contents("$Bin/authors.json"));
my $targets = JSON->new->relaxed->decode(file_get_contents("$Bin/targets.json"));

my %rebuilt = ();
my %blames = ();
my @failed = ();
my $win32 = 0;
my $osx = 0;
my $aptget = 0;

use IO::Tee;
open my $log, ">/tmp/rebuild.$$.log";
my $out2 = IO::Tee->new($log, \*STDOUT);
print {$out2} "Build $ENV{BUILDTYPE} started ".`date -u`;

if ($ARGV[0]) {
   $ARGV[0] =~ s@/$@@g;
}

my %our_pkgs = ();
foreach (split(/\n+/, `$Bin/enum-our-packages.sh`)) {
   $our_pkgs{$_} = 1;
}

my %dep_order = ();
my %dep_our = ();
foreach (split(/\n+/, `$Bin/enum-build-deps.sh`)) {
   s/^\s+//g;
   s/\s+$//g;
   my ($n,$p) = split(/\s+/);
   if (defined $our_pkgs{$p}) {
      $dep_our{$p} = 0+$n;
   }
   $dep_order{$p} = 0+$n;
}

sub order_deps {
   if (defined $dep_order{$a} && defined $dep_order{$b}) {
      return $dep_order{$b} <=> $dep_order{$a};
   }
   return 0;
}

foreach my $k (@{$pkgs{'order'}}) {
   my $pkg = $pkgs{'packages'}->{$k};
   # If a package path is given, only rebuild that package, but force a rebuild of it
   if ($ARGV[0] && $pkg->[0] !~ m@/\Q$ARGV[0]\E$@) {
      next;
   }

   my ($pkname) = ($pkg->[0] =~ m@([-\w]+)$@);
   my $logpath = "/home/apertium/public_html/apt/logs/$pkname";
   `mkdir -p $logpath/ && rm -f $logpath/*-*.log`;
   open my $pkglog, ">$logpath/rebuild.log";
   my $out = IO::Tee->new($out2, $pkglog);

   $ENV{'PKPATH'} = "$Bin/".$pkg->[0];
   $ENV{'AUTOPATH'} = "/opt/autopkg/$ENV{BUILDTYPE}/$pkname";

   if (!$pkg->[1]) {
      my ($path) = ($pkg->[0] =~ m@/([^/]+)$@);
      $pkg->[1] = 'https://github.com/apertium/'.$path;
   }
   if (!$pkg->[2]) {
      $pkg->[2] = 'configure.ac';
   }
   if (!$pkg->[3]) {
      $pkg->[3] = '';
   }

   $ENV{'BUILD_VCS'} = 'svn';
   my $pkpath = '';
   if ($pkg->[1] =~ m@^https://github.com/[^/]+/([^/]+)$@) {
      $ENV{'BUILD_VCS'} = 'git';
      $pkpath = $1;
   }

   print {$out} "\n";
   print {$out} "Package: $pkg->[0]\n";
   print {$out} "\tstarted: ".`date -u`;

   my $rev = '';
   if ($release) {
      $rev = `head -n1 $pkg->[0]/debian/changelog`;
      chomp($rev);
      if ($rev =~ m@\([\d.]+\+[gs]([^-)]+)@) {
         $rev = $1;
      }
      elsif ($rev =~ m@\((\d+\.\d+\.\d+)-\d+@) {
            $rev = "v$1";
      }
      else {
         print {$out} "\tmissing release revision: $rev\n";
         next;
      }
      print {$out} "\trelease rev: $rev\n";
      $rev = "--rev '$rev'";
   }
   # Determine latest version and date stamp from the repository
   my $gv = `$Bin/get-version.pl --url '$pkg->[1]' --file '$pkg->[2]' --pkname '$pkname' $rev 2>$logpath/stderr.log`;
   chomp($gv);
   my ($newrev,$version,$srcdate) = split(/\t/, $gv);
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
   my $oldversion = '0.0.0';
   if (-e "/home/apertium/public_html/apt/$ENV{BUILDTYPE}/pool/main/$first/$pkname") {
      $oldversion = `dpkg -I \$(ls -1 /home/apertium/public_html/apt/$ENV{BUILDTYPE}/pool/main/$first/$pkname/*~sid*.deb | head -n1) | grep 'Version:' | egrep -o '[-.0-9]+([~+][gsr][-.0-9a-f]+)?(~[-0-9a-f]+)?' | head -n 1`;
      chomp($oldversion);
   }
   print {$out} "\texisting: $oldversion\n";

   # Figure out if the latest is newer than existing, which is complicated enough that we just ask dpkg
   my $gt = `dpkg --compare-versions '$version' gt '$oldversion' && echo 1 || echo 0` + 0;
   my $rebuild = 0;

   my $control = read_control($pkg->[0].'/debian/control');

   if (!$staccato) {
      my ($bdeps) = ($control =~ m@Build-Depends:\s*([^\n]+)@);
      $bdeps =~ s@\([^)]+\)@@g;
      $bdeps =~ s@\s+@@gs;

      foreach my $dep (split(/,/, $bdeps)) {
         if (defined $rebuilt{$dep}) {
            $rebuild = 1;
            print {$out} "\tdependency $dep was rebuilt\n";
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
   my $cli = "-p '$pkg->[0]' -u '$pkg->[1]' -v '$version' --distv '$distv' -d '$srcdate' --rev $newrev -m 'Apertium Automaton <apertium-packaging\@lists.sourceforge.net>' -e 'Apertium Automaton <apertium-packaging\@lists.sourceforge.net>'";
   print {$out} "\tmaking source package\n";

   $ENV{'AUTOPKG_DATA_ONLY'} = '';
   my $is_data = '';
   copy("$pkg->[0]/debian/rules", "/opt/autopkg/rules.$$");
   if ($pkg->[0] =~ m@^languages/@ || $pkg->[0] =~ m@/apertium-\w{2,3}-\w{2,3}$@ || $pkg->[0] =~ m@/giella-@ || $pkg->[0] =~ m@-java$@) {
      # If this is a data-only package, only build it once for latest Debian Sid
      print {$out} "\tdata only\n";
      $is_data = 'data';
      $ENV{'AUTOPKG_DATA_ONLY'} = $is_data;
      `cat data-gzip.Makefile >> "$pkg->[0]/debian/rules"`;
   }
   elsif ($control =~ m@Architecture: all@ && $control !~ m@Architecture: any@) {
      print {$out} "\tarch-all\n";
      $is_data = 'arch-all';
      $ENV{'AUTOPKG_DATA_ONLY'} = $is_data;
   }
   if ($dry || $is_data eq 'data') {
      $is_data = 'data';
      # For data-only packages, skip all distros except Debian Sid
      $pkg->[3] = join(',', keys(%{$targets->{'distros'}}));
      $pkg->[3] =~ s@(^|,)sid(,|$)@,@g;
   }
   if ($distro) {
      $pkg->[3] = $distro;
   }

   $pkg->[3] = ",$pkg->[3],";

   # Build the packages for Debian/Ubuntu
   `$Bin/make-deb-source.pl $cli --nobuild '$pkg->[3]' 2>>$logpath/stderr.log >&2`;
   copy("/opt/autopkg/rules.$$", "$pkg->[0]/debian/rules");
   unlink("/opt/autopkg/rules.$$");

   my $oldhash = '';
   my $newhash = `ls -1 --color=no /opt/autopkg/$ENV{BUILDTYPE}/$pkname/*.tar.bz2 | head -n1 | xargs -rn1 tar -jxOf | sha256sum`;
   if (-d "/home/apertium/public_html/apt/$ENV{BUILDTYPE}/source/$pkname") {
      $oldhash = `ls -1 --color=no /home/apertium/public_html/apt/$ENV{BUILDTYPE}/source/$pkname/*.tar.bz2 | head -n1 | xargs -rn1 tar -jxOf | sha256sum`;
   }
   if (-d "/home/apertium/public_html/apt/$ENV{BUILDTYPE}/source/$pkname/failed") {
      $oldhash = `ls -1 --color=no /home/apertium/public_html/apt/$ENV{BUILDTYPE}/source/$pkname/failed/*.tar.bz2 | head -n1 | xargs -rn1 tar -jxOf | sha256sum`;
   }
   if (!$ARGV[0] && !$rebuild && ($oldhash eq $newhash)) {
      print {$out} "\tno change in tarball - skipping\n";
      goto CLEANUP;
   }

   # Track whether this build resulted in actual data changes, because it's pointless to trigger downstream rebuilds if not
   my $changed = 0;
   my $failed = '';

   print {$out} "\tlaunching build\n";
   foreach my $distro (keys %{$targets->{'distros'}}) {
      if ($pkg->[3] =~ m@,$distro,@) {
         next;
      }

      my $variant = $targets->{'distros'}->{$distro}{'variant'};
      foreach my $arch (@{$targets->{'distros'}->{$distro}{'archs'}}) {
         if ($is_data && $arch ne 'amd64') {
            next;
         }

         my $dpath = $ENV{'AUTOPATH'}."/$arch/$distro";

         my $control = read_control((glob("$dpath/*/debian/control"))[0]);
         my ($bdeps) = ($control =~ m@Build-Depends:\s*([^\n]+)@);
         $bdeps =~ s@\([^)]+\)@@g;
         $bdeps =~ s@\s+@@gs;

         my @os_deps = ();
         my @our_deps = ();
         my @deps = split(/,/, $bdeps);
         foreach my $dep (@deps) {
            if (defined $dep_our{$dep}) {
               push(@our_deps, $dep);
            }
            else {
               push(@os_deps, $dep);
            }
         }

         push(@deps, 'apt-utils', 'build-essential', 'fakeroot');
         @os_deps = sort order_deps @os_deps;
         @our_deps = sort order_deps @our_deps;

         my $docker = "FROM $arch/$variant:$distro\n";
         $docker .= "\n";
         $docker .= "ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true\n";
         $docker .= "\n";
         if ($arch ne 'i386' && $arch ne 'amd64') {
            `cp -av --reflink=auto /usr/bin/qemu-$arch-static $Bin/docker/`;
            if ($arch eq 'ppc64le') {
               $docker .= "ENV QEMU_CPU=POWER8\n";
            }
            $docker .= "COPY qemu-$arch-static /usr/bin/\n";
            $docker .= "\n";
         }
         $docker .= "RUN mkdir /build\n";
         $docker .= "RUN groupadd -g 1234 builder && useradd -d /build -M -u 1234 -g 1234 builder\n";
         $docker .= "RUN chown 1234:1234 /build\n";
         $docker .= "\n";
         $docker .= "# Use caching proxy\n";
         $docker .= 'RUN export HOST_IP=$(cat /proc/net/route | awk \'/^[a-z]+[0-9]+\t00000000/ { printf("%d.%d.%d.%d\n", "0x" substr($3, 7, 2), "0x" substr($3, 5, 2), "0x" substr($3, 3, 2), "0x" substr($3, 1, 2)) }\') && \\'."\n";
         $docker .= "\techo 'Acquire::http::Proxy \"http://'\$HOST_IP':3124\";' > /etc/apt/apt.conf.d/30autoproxy\n";
         $docker .= "\n";
         $docker .= "# Upgrade everything and install base builder dependencies\n";
         $docker .= "RUN apt-get -qy update && apt-get -qfy --no-install-recommends install apt-utils\n";
         $docker .= "RUN apt-get -qy update && apt-get -qfy --no-install-recommends dist-upgrade\n";
         $docker .= "RUN apt-get -qy update && apt-get -qfy --no-install-recommends install build-essential\n";
         $docker .= "RUN apt-get -qy update && apt-get -qfy --no-install-recommends install fakeroot\n";
         if (scalar(@os_deps)) {
            $docker .= "\n";
            $docker .= "# OS dependencies\n";
            foreach my $dep (@os_deps) {
               $docker .= "RUN apt-get -qy update && apt-get -qfy --no-install-recommends install $dep\n";
            }
         }
         if (scalar(@our_deps)) {
            $docker .= "\n";
            $docker .= "# Our dependencies\n";
            $docker .= "COPY apertium-packaging.public.gpg /etc/apt/trusted.gpg.d/apertium.gpg\n";
            $docker .= "RUN chmod 0666 /etc/apt/trusted.gpg.d/apertium.gpg\n";
            $docker .= "RUN echo 'Package: *' > /etc/apt/preferences.d/apertium.pref && \\\n";
            $docker .= "\techo 'Pin: origin apertium.projectjj.com' >> /etc/apt/preferences.d/apertium.pref && \\\n";
            $docker .= "\techo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/apertium.pref && \\\n";
            $docker .= "\techo 'deb http://apertium.projectjj.com/apt/$ENV{BUILDTYPE} $distro main' > /etc/apt/sources.list.d/apertium.list\n";
            $docker .= "\n";
            foreach my $dep (@our_deps) {
               $docker .= "RUN apt-get -qy update && apt-get -qfy --no-install-recommends install $dep\n";
            }
         }
         file_put_contents("$dpath/Dockerfile", $docker);

         my $hash = substr(`sha256sum $dpath/Dockerfile`, 0, 16);
         my $img = "autopkg-${distro}-${arch}/${hash}";
         my $exists = 0+`docker images -q $img 2>/dev/null | wc -l`;
         if (0+`docker history -q $img 2>/dev/null | wc -l` > 75) {
            print {$out} "\tdocker $distro:$arch refreshing (depth > 75)\n";
            $exists = 0;
         }
         my $force_refresh = 0;
         FORCE_REFRESH:
         if (!$exists || $refresh || $force_refresh) {
            `echo 'Creating $distro $arch' >>$logpath/stderr.log 2>&1`;
            `docker build --pull -f $dpath/Dockerfile -t $img $Bin/docker/ >>$logpath/$distro-$arch.log 2>&1`;
            if ($?) {
               print {$out} "\tdocker $distro:$arch create fail\n";
               goto CLEANUP;
            }
         }

         `echo 'Checking available updates for $distro $arch' >>$logpath/stderr.log 2>&1`;
         my $avail = 0+`docker run --rm -it $img /bin/bash -c "apt-get -qqy update && apt-get -qfy dist-upgrade --simulate" | egrep '^(Conf|Remv|Inst) ' | wc -l`;
         if ($avail || $?) {
            `echo 'Updating $distro $arch ($avail packages)' >>$logpath/stderr.log 2>&1`;
            `docker tag $img $img-old >>$logpath/$distro-$arch.log 2>&1`;
            my $deps = join(' ', @deps);
            `echo -e 'FROM $img-old\nRUN apt-get -qy update && apt-get -qfy --no-install-recommends dist-upgrade && apt-get -qfy install --no-install-recommends $deps && apt-get -qfy autoremove --purge' | docker build --no-cache -t $img - >>$logpath/$distro-$arch.log 2>&1`;
            if ($?) {
               if (!$force_refresh && 0+`grep -c 'max depth exceeded' $logpath/$distro-$arch.log` > 0) {
                  $force_refresh = 1;
                  print {$out} "\tdocker $distro:$arch refreshing (max depth exceeded)\n";
                  goto FORCE_REFRESH;
               }
               if (!$force_refresh && 0+`egrep -c 'changed its '.+' value from' $logpath/$distro-$arch.log` > 0) {
                  $force_refresh = 1;
                  print {$out} "\tdocker $distro:$arch refreshing (repo fields changed)\n";
                  goto FORCE_REFRESH;
               }
               print {$out} "\tdocker $distro:$arch update fail\n";
               goto CLEANUP;
            }
            `docker rmi $img-old >>$logpath/$distro-$arch.log 2>&1`;
         }

         my $script = "#!/bin/bash\n";
         $script .= "set -e\n";
         $script .= "export 'VERBOSE=1' 'V=1'\n";
         $script .= "export 'DEB_BUILD_OPTIONS=parallel=3'\n";
         $script .= "cd /build/${pkname}-*/\n";
         $script .= "nice -n20 dpkg-buildpackage -us -uc -rfakeroot\n";
         file_put_contents("$dpath/build.sh", $script);
         `chmod +x '$dpath/build.sh'`;
         `chown -R 1234:1234 '$dpath'`;

         `echo 'Building $distro $arch' >>$logpath/stderr.log 2>&1`;
         `$Bin/build-debian-ubuntu.sh '$img' '$dpath' >>$logpath/$distro-$arch.log 2>&1`;
         if ($?) {
            print {$out} "\tdocker $distro:$arch build fail\n";
            $failed .= "$logpath/$distro-$arch.log\n";
            next;
         }

         `debsign --no-re-sign $dpath/${pkname}_*.changes >>$logpath/$distro-$arch.log 2>&1`;
         `docker run --rm --network none -v "$dpath/:/build/" lintian-$variant >$logpath/$distro-$arch-lintian.log 2>&1`;

         `find $dpath -type f -name '*.deb' | LC_ALL=C sort | xargs -rn1 '-I{}' ar p '{}' data.tar.gz data.tar.xz 2>/dev/null | sha256sum -b | awk '{print \$1}' >$logpath/$distro-$arch.sha256-new`;
         if (! -s "$logpath/$distro-$arch.sha256" || 0+`diff '$logpath/$distro-$arch.sha256' '$logpath/$distro-$arch.sha256-new' | wc -l`) {
            $changed = 1;
         }
         rename("$logpath/$distro-$arch.sha256-new", "$logpath/$distro-$arch.sha256");
      }
   }

   $failed .= `grep -L 'dpkg-genchanges' \$(grep -l 'dpkg-buildpackage: info: source package' \$(find /home/apertium/public_html/apt/logs/$pkname -type f))`;
   chomp($failed);

   my $depfail = '';
   $depfail = `grep -l 'packages have unmet dependencies' \$(grep -l 'dpkg-buildpackage: info: source package' \$(find /home/apertium/public_html/apt/logs/$pkname -type f))`;
   chomp($depfail);
   if ($depfail) {
      print {$out} "\tsoft fail: unmet dependencies\n";
   }

   if ($dry) {
      print {$out} "\tparched\n";
      last;
   }

   # If debs did not fail building, try RPMs and win32
   if (!$failed) {
      if (-s "$pkg->[0]/rpm/$pkname.spec") {
         print {$out} "\tupdating rpm sources\n";
         `$Bin/make-rpm-source.pl $cli 2>>$logpath/stderr.log >&2`;
      }
      elsif ($is_data eq 'data') {
         print {$out} "\tupdating rpm from data\n";
         `$Bin/make-rpm-data.pl $cli 2>>$logpath/stderr.log >&2`;
      }

      if (-s "$pkg->[0]/win32/$pkname.sh") {
         print {$out} "\tbuilding win32\n";
         $ENV{'BITWIDTH'} = 'i686';
         $ENV{'WINX'} = 'win32';
         `bash -c '. $dir/win32-pre.sh; . $dir/$pkg->[0]/win32/$pkname.sh; . $dir/win32-post.sh;' -- '$pkname' '$newrev' '$version-$distv' '$dir/$pkg->[0]' 2>$logpath/win32.log >&2`;

         print {$out} "\tbuilding win64\n";
         $ENV{'BITWIDTH'} = 'x86_64';
         $ENV{'WINX'} = 'win64';
         `bash -c '. $dir/win32-pre.sh; . $dir/$pkg->[0]/win32/$pkname.sh; . $dir/win32-post.sh;' -- '$pkname' '$newrev' '$version-$distv' '$dir/$pkg->[0]' 2>$logpath/win64.log >&2`;

         $win32 = 1;
      }

=pod
      if (-s "$pkg->[0]/osx/$pkname.sh") {
         print {$out} "\tbuilding osx\n";
         `bash -c '. $dir/osx-pre.sh; . $dir/$pkg->[0]/osx/$pkname.sh; . $dir/osx-post.sh;' -- '$pkname' '$newrev' '$version-$distv' '$dir/$pkg->[0]' 2>$logpath/osx.log >&2`;
         $osx = 1;
      }
=cut

      if ($is_data) {
         $aptget = 1;
      }
   }
   print {$out} "\tstopped: ".`date -u`;

   if ($failed) {
      `$Bin/failed.sh '$pkname' 2>>$logpath/stderr.log >&2`;

      push(@failed, $pkname);
      # Gather up URLs for the logs of the failed builds
      print {$out} "\tFAILED:\n";
      foreach my $fail (uniq(sort(split(/\n/, $failed)))) {
         chomp($fail);
         $fail =~ s@^/home/apertium/public_html@https://apertium.projectjj.com@;
         print {$out} "\t\t$fail\n";
      }

      if ($depfail) {
         goto CLEANUP;
      }

      # Determine who was most likely responsible for breaking the build
      my $blames = '';
      if ($ENV{'BUILD_VCS'} eq 'git') {
         my ($oldrev) = ($oldversion =~ m@^\d+\.\d+\.\d+\+g\d+~([0-9a-f]+)@);
         if (!$oldrev) {
            goto CLEANUP;
         }
         $dir = getcwd();
         chdir("/opt/autopkg/repos/$pkpath.git");
         $blames = `git log '--format=format:\%aE\%x0a\%cE' $oldrev..$newrev | sort | uniq`;
         chomp($blames);
         print {$out} "\tblames in revisions $oldrev..$newrev :\n";
         chdir($dir);
      }
      else {
         my ($oldrev) = ($oldversion =~ m@^\d+\.\d+\.\d+\+s(\d+)@);
         ++$oldrev;
         # Check that $oldrev is less than newrev, but greater than 1
         if (!$oldrev || $oldrev <= 1 || $oldrev >= $newrev) {
            goto CLEANUP;
         }
         $blames = `svn log -q -r$oldrev:$newrev '$pkg->[1]' | egrep '^r' | awk '{ print \$3 }' | sort | uniq`;
         chomp($blames);
         print {$out} "\tblames in revisions $oldrev:$newrev :\n";
      }
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
         elsif ($blame !~ m/github\.com$/ && $blame =~ m/^.+@.+?\..+$/) {
            $cc .= " '$blame'";
         }
      }

      my $subject = "$pkg->[0] failed $ENV{BUILDTYPE} build";
      # Don't send individual emails if this is a single package build
      if (!$ARGV[0] && $cc ne '') {
         `cat $logpath/rebuild.log | mailx -s '$subject' -b 'mail\@tinodidriksen.com' -r 'apertium-packaging\@projectjj.com' 'apertium-packaging\@lists.sourceforge.net' $cc`;
      }
      goto CLEANUP;
   }

   # Add the resulting .deb to the Apt repository
   # Note that this does not happen if ANY failure was detected, to ensure we don't get partially-updated trees
   `$Bin/reprepro.sh '$pkname' '$is_data' '$pkg->[3]' 2>>$logpath/stderr.log >&2`;

   if (-s "$Bin/$pkg->[0]/hook.post" && -x "$Bin/$pkg->[0]/hook.post") {
      `$Bin/$pkg->[0]/hook.post >$logpath/hook.post.log 2>&1`;
   }

=pod
   # Add the resulting .rpms to the Yum repositories
   if (-s "/home/apertium/rpmbuild/SRPMS/$pkname-$version-$distv.src.rpm") {
      open my $yumlog, ">$logpath/createrepo.log";
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
   foreach my $pk ($control =~ m@Package:\s*(\S+)@g) {
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
   `cat /tmp/rebuild.$$.log | mailx -s '$subject' -b 'mail\@tinodidriksen.com' -r 'apertium-packaging\@projectjj.com' 'apertium-packaging\@lists.sourceforge.net'`;
}

if ($win32) {
   print {$out2} "Combining Win32 builds\n";
   $ENV{'BITWIDTH'} = 'i686';
   $ENV{'WINX'} = 'win32';
   `$Bin/win32-combine.sh`;

   print {$out2} "Combining Win64 builds\n";
   $ENV{'BITWIDTH'} = 'x86_64';
   $ENV{'WINX'} = 'win64';
   `$Bin/win32-combine.sh`;
}
if ($osx) {
   print {$out2} "Combining OS X builds\n";
   `$Bin/osx-combine.sh`;
}
if ($aptget && !$release) {
   print {$out2} "Installing new data packages\n";
   `$Bin/apt-get-upgrade.sh`;
}

print {$out2} "Build $ENV{BUILDTYPE} stopped at ".`date -u`;
close $log;
unlink("/tmp/rebuild.$$.log");
unlink('/opt/autopkg/rebuild.lock');
