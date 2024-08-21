#!/usr/bin/env perl
# -*- mode: cperl; indent-tabs-mode: nil; tab-width: 3; cperl-indent-level: 3; -*-
# Copyright (C) 2014, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 2 or later; see https://www.gnu.org/licenses/
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

if (-s '/opt/autopkg/rebuild.lock') {
   die "Another instance of builder is running - bailing out!\n";
}
`date -u > /opt/autopkg/rebuild.lock`;

`rm -rf /opt/autopkg/tmp /opt/autopkg/rules.*`;
`mkdir -p /opt/autopkg /opt/autopkg/repos /opt/autopkg/tmp/git`;

use Getopt::Long;
Getopt::Long::Configure('no_ignore_case');
my %opts = (
   'distro' => '',
   'dry' => 0,
   'force' => 0,
   'only' => '',
   'release' => 0,
   'staccato' => 0,
   );
my $rop = GetOptions(\%opts,
   'distro=s',
   'dry|n!',
   'force|f!',
   'only=s',
   'release|r!',
   'staccato!',
   );

$ENV{'PATH'} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:'.$ENV{'PATH'};
$ENV{'AUTOPKG_BUILDTYPE'} = ($opts{'release'} == 1) ? 'release' : 'nightly';
$ENV{'DOCKER_BUILDKIT'} = 1;
$ENV{'BUILDKIT_PROGRESS'} = 'plain';
$ENV{'PROGRESS_NO_TRUNC'} = 1;
$ENV{'TZ'} = 'UTC';
$ENV{'GIT_TERMINAL_PROMPT'} = '0';

use File::Copy;
use Cwd;
$ENV{'AUTOPKG_HOME'} = $Bin;
my $dir = $Bin;
chdir($dir);

use JSON;
my %pkgs = load_packages();
my $authors = JSON->new->relaxed->decode(file_get_contents("$Bin/authors.json"));
my $targets = JSON->new->relaxed->decode(file_get_contents("$Bin/targets.json"));

use Sys::MemInfo qw(totalmem);
my $maxmem = int((totalmem() * 0.85)/(1024 * 1024));
my $maxswap = $maxmem + 10240;
$ENV{'AUTOPKG_MAX_MEM'} = "${maxmem}m";
$ENV{'AUTOPKG_MAX_SWAP'} = "${maxswap}m";

my %rebuilt = ();
my %blames = ();
my @failed = ();
my $win32 = 0;
my $osx = 0;

my $exitcode = 0;

use IO::Tee;
open my $log, ">/opt/autopkg/tmp/rebuild.$$.log";
my $out2 = IO::Tee->new($log, \*STDOUT);
print {$out2} "Build $ENV{AUTOPKG_BUILDTYPE} started ".`date -u`;

if ($ARGV[0]) {
   $ARGV[0] =~ s@/$@@g;

   foreach my $k (@{$pkgs{'order'}}) {
      my $pkg = $pkgs{'packages'}->{$k};
      if ($pkg->[0] !~ m@$ARGV[0]@) {
         delete $pkgs{'packages'}->{$k};
      }
   }
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
      $dep_our{$p} = int($n);
   }
   $dep_order{$p} = int($n);
}

sub order_deps {
   if (defined $dep_order{$a} && defined $dep_order{$b}) {
      return $dep_order{$b} <=> $dep_order{$a};
   }
   return 0;
}

foreach my $k (@{$pkgs{'order'}}) {
   if (!exists($pkgs{'packages'}->{$k})) {
      next;
   }

   my $pkg = $pkgs{'packages'}->{$k};
   if (-s '/opt/autopkg/halt-build') {
      last;
   }

   my ($pkname) = ($pkg->[0] =~ m@([-\w]+)$@);
   my $logpath = "/home/apertium/public_html/apt/logs/$pkname";
   `mkdir -p $logpath/`;
   `cp -a $logpath/sid-amd64.log $logpath/build.log >/dev/null 2>&1`;
   `rm -f $logpath/*-*.log >/dev/null 2>&1`;
   open my $pkglog, ">$logpath/rebuild.log";
   my $out = IO::Tee->new($out2, $pkglog);

   my $is_tool = 'data';
   if ($pkg->[0] =~ m@^tools/@) {
      $is_tool = 'tool';
   }

   $ENV{'AUTOPKG_PKPATH'} = "$Bin/".$pkg->[0];
   $ENV{'AUTOPKG_AUTOPATH'} = "/opt/autopkg/$ENV{AUTOPKG_BUILDTYPE}/$pkname";
   $ENV{'AUTOPKG_LOGPATH'} = $logpath;

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

   $ENV{'AUTOPKG_VCS'} = 'svn';
   my $pkpath = '';
   if ($pkg->[1] =~ m@^https://github.com/[^/]+/([^/]+)$@) {
      $ENV{'AUTOPKG_VCS'} = 'git';
      $pkpath = $1;
   }

   print {$out} "\n";
   print {$out} "Package: $pkg->[0]\n";
   print {$out} "\tstarted: ".`date -u`;

   my $rev = '';
   if ($opts{'release'}) {
      $rev = `head -n1 $pkg->[0]/debian/changelog`;
      chomp($rev);
      if ($rev =~ m@\((?:\d+:)?[\d.]+\+[gs]([^-)]+)@) {
         $rev = $1;
      }
      elsif ($rev =~ m@\((?:\d+:)?(\d+\.\d+\.\d+)-\d+@) {
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
   if (-e "/home/apertium/public_html/apt/$ENV{AUTOPKG_BUILDTYPE}/pool/main/$first/$pkname") {
      $oldversion = `dpkg -I \$(ls -1 /home/apertium/public_html/apt/$ENV{AUTOPKG_BUILDTYPE}/pool/main/$first/$pkname/*~sid*.deb | grep -v i386 | head -n1) | grep 'Version:' | egrep -o '[-.0-9]+([~+][gsr][-.0-9a-f]+)?(~[-0-9a-f]+)?' | head -n 1`;
      chomp($oldversion);
   }
   print {$out} "\texisting: $oldversion\n";

   # Figure out if the latest is newer than existing, which is complicated enough that we just ask dpkg
   my $gt = `dpkg --compare-versions '$version' gt '$oldversion' && echo 1 || echo 0` + 0;
   my $rebuild = 0;

   my $control = read_control($pkg->[0].'/debian/control');

   if (!$opts{'staccato'}) {
      my ($bdeps) = ($control =~ m@Build-Depends:\s*([^\n]+)@);
      $bdeps =~ s@\([^)]+\)@@g;
      $bdeps =~ s@\s+@@gs;

      foreach my $dep (split(/,/, $bdeps)) {
         if (defined $rebuilt{$is_tool}{$dep}) {
            $rebuild = 1;
            print {$out} "\tdependency $dep was rebuilt\n";
         }
      }
   }

   if (!($gt || $rebuild || $opts{'force'})) {
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
   if ($opts{'dry'}) {
      $is_data = 'dry';
   }

   if ($pkg->[0] =~ m@/apertium-all-dev$@) {
      print {$out} "\tarch-all\n";
      $is_data = 'arch-all';
      $ENV{'AUTOPKG_DATA_ONLY'} = $is_data;
   }
   elsif ($pkg->[0] =~ m@^(data|languages|pairs)/@ || $pkg->[0] =~ m@/apertium-(get|regtest|shared)$@ || $pkg->[0] =~ m@/giella-@ || $pkg->[0] =~ m@-java$@) {
      # If this is a data-only package, only build it once for latest Debian Sid
      print {$out} "\tdata only\n";
      $is_data = 'data';
      $ENV{'AUTOPKG_DATA_ONLY'} = $is_data;
   }
   elsif ($control =~ m@Architecture: all@ && $control !~ m@Architecture: any@) {
      print {$out} "\tarch-all\n";
      $is_data = 'arch-all';
      $ENV{'AUTOPKG_DATA_ONLY'} = $is_data;
   }
   if ($opts{'dry'} || $is_data eq 'data') {
      # For data-only packages, skip all distros except Debian Sid
      $pkg->[3] = join(',', keys(%{$targets->{'distros'}}));
      $pkg->[3] =~ s@(^|,)sid(,|$)@,@g;
   }
   if ($opts{'distro'}) {
      $pkg->[3] = $opts{'distro'};
   }

   $pkg->[3] = ",$pkg->[3],";

   # Build the packages for Debian/Ubuntu
   `$Bin/make-deb-source.pl $cli --nobuild '$pkg->[3]' 2>>$logpath/stderr.log >&2`;

   my $oldhash = '';
   my $newhash = `ls -1 --color=no /opt/autopkg/$ENV{AUTOPKG_BUILDTYPE}/$pkname/*.tar.bz2 2>/dev/null | head -n1 | xargs -rn1 tar -jxOf | sha256sum`;
   if (-d "/home/apertium/public_html/apt/$ENV{AUTOPKG_BUILDTYPE}/source/$pkname") {
      $oldhash = `ls -1 --color=no /home/apertium/public_html/apt/$ENV{AUTOPKG_BUILDTYPE}/source/$pkname/*.tar.bz2 2>/dev/null | head -n1 | xargs -rn1 tar -jxOf | sha256sum`;
   }
   if (-d "/home/apertium/public_html/apt/$ENV{AUTOPKG_BUILDTYPE}/source/$pkname/failed") {
      $oldhash = `ls -1 --color=no /home/apertium/public_html/apt/$ENV{AUTOPKG_BUILDTYPE}/source/$pkname/failed/*.tar.bz2 2>/dev/null | head -n1 | xargs -rn1 tar -jxOf | sha256sum`;
   }
   if (!$ARGV[0] && !$rebuild && $oldhash && ($oldhash eq $newhash)) {
      print {$out} "\tno change in tarball - skipping\n";
      goto CLEANUP;
   }

   # Track whether this build resulted in actual data changes, because it's pointless to trigger downstream rebuilds if not
   my $changed = 0;
   my $failed = '';

   my $config = '';
   if (-s "$pkg->[0]/config.json") {
      $config = JSON->new->relaxed->decode(file_get_contents("$pkg->[0]/config.json"));
   }

   print {$out} "\tlaunching build\n";
   if ($opts{'only'} eq 'win') {
      goto WINDOWS;
   }
   foreach my $distro (keys %{$targets->{'distros'}}) {
      if ($pkg->[3] =~ m@,$distro,@) {
         next;
      }

      my $variant = $targets->{'distros'}->{$distro}{'variant'};
      foreach my $arch (@{$targets->{'distros'}->{$distro}{'archs'}}) {
         if ($is_data && $arch ne 'amd64') {
            next;
         }

         my $dpath = $ENV{'AUTOPKG_AUTOPATH'}."/$arch/$distro";

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

         if ($pkg->[0] =~ m@^(languages|pairs)/apertium@) {
            push(@our_deps, 'apertium-regtest');
         }

         push(@deps, 'apt-utils', 'build-essential', 'fakeroot', 'time', 'eatmydata');
         @os_deps = sort @os_deps;
         @our_deps = sort @our_deps;

         my $docker = '';
         #$docker .= "#syntax=docker/dockerfile:1.2-labs\n";
         $docker .= "FROM $arch/$variant:$distro\n";
         $docker .= "\n";
         $docker .= "ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LD_PRELOAD=libeatmydata.so\n";
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
         $docker .= "RUN apt-get -qy update && apt-get -qfy -o DPkg::Options::=--force-overwrite --no-install-recommends install eatmydata\n";
         $docker .= "RUN apt-get -qy update && apt-get -qfy -o DPkg::Options::=--force-overwrite --no-install-recommends install apt-utils\n";
         $docker .= "RUN apt-get -qy update && if [ -s /etc/dpkg/dpkg.cfg.d/excludes ]; then mv -v /etc/dpkg/dpkg.cfg.d/excludes /tmp/dpkg-excludes; echo 'y' | /usr/local/sbin/unminimize; mv -v /tmp/dpkg-excludes /etc/dpkg/dpkg.cfg.d/excludes; fi\n";
         $docker .= "RUN apt-get -qy update && apt-get -qfy -o DPkg::Options::=--force-overwrite --no-install-recommends install man-db\n";
         $docker .= "RUN apt-get -qy update && apt-get -qfy -o DPkg::Options::=--force-overwrite --no-install-recommends dist-upgrade\n";
         $docker .= "RUN apt-get -qy update && apt-get -qfy -o DPkg::Options::=--force-overwrite --no-install-recommends install build-essential fakeroot time\n";
         if ($is_data eq 'data') {
            $docker .= "RUN apt-get -qy update && apt-get -qfy -o DPkg::Options::=--force-overwrite --no-install-recommends install libgoogle-perftools-dev\n";
            push(@deps, 'libgoogle-perftools-dev');
         }
         if (scalar(@os_deps)) {
            $docker .= "\n";
            $docker .= "# OS dependencies\n";
            $docker .= "RUN apt-get -qy update && apt-get -qfy -o DPkg::Options::=--force-overwrite --no-install-recommends install ".join(' ', @os_deps)."\n";
         }
         if (scalar(@our_deps)) {
            $docker .= "\n";
            $docker .= "# Our dependencies\n";
            $docker .= "COPY apertium-packaging.public.gpg /etc/apt/trusted.gpg.d/apertium.gpg\n";
            $docker .= "RUN chmod 0666 /etc/apt/trusted.gpg.d/apertium.gpg\n";
            $docker .= "RUN echo 'Package: *' > /etc/apt/preferences.d/apertium.pref && \\\n";
            $docker .= "\techo 'Pin: origin apertium.projectjj.com' >> /etc/apt/preferences.d/apertium.pref && \\\n";
            $docker .= "\techo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/apertium.pref && \\\n";
            $docker .= "\techo 'deb http://apertium.projectjj.com/apt/$ENV{AUTOPKG_BUILDTYPE} $distro main' > /etc/apt/sources.list.d/apertium.list\n";
            $docker .= "\n";
            $docker .= "RUN apt-get -qy update && apt-get -qfy -o DPkg::Options::=--force-overwrite --no-install-recommends install ".join(' ', @our_deps)."\n";
         }
         file_put_contents("$dpath/Dockerfile", $docker);
         my $hash = substr(`sha256sum $dpath/Dockerfile`, 0, 16);
         my $img = "autopkg-${distro}-${arch}/${hash}";

         my $exists = int(`docker images -q $img-build 2>/dev/null | wc -l`);
         if ($exists) {
            `echo 'Checking available updates for $distro $arch' >>$logpath/stderr.log 2>&1`;
            my $avail = int(`docker run --privileged --rm -i $img-build /bin/bash -c "apt-get -qqy update && apt-get -qfy --allow-downgrades dist-upgrade --simulate" | egrep '^(Conf|Remv|Inst) ' | wc -l`);
            if ($avail) {
               $exists = 0;
            }
         }
         if (!$exists) {
            my $deps = join(' ', sort @deps);
            $docker .= "\n";
            $docker .= "# Un-cacheable upgrade\n";
            $docker .= "ARG CACHE_NONCE=1\n";
            $docker .= "RUN echo \"\$CACHE_NONCE\" && apt-get -qy update && apt-get -qfy -o DPkg::Options::=--force-overwrite --no-install-recommends --allow-downgrades dist-upgrade && apt-get -qfy -o DPkg::Options::=--force-overwrite install --no-install-recommends --allow-downgrades ${deps} && apt-get -qfy autoremove --purge\n";
            file_put_contents("$dpath/Dockerfile", $docker);

            my $nonce = time();
            `echo 'Creating $distro $arch' >>$logpath/stderr.log 2>&1`;
            `docker build --build-arg "CACHE_NONCE=$nonce" -f $dpath/Dockerfile -t $img-build $Bin/docker/ >>$logpath/$distro-$arch.log 2>&1`;
            if ($?) {
               print {$out} "\tdocker $distro:$arch create fail\n";
               goto CLEANUP;
            }
         }

         my $script = "#!/bin/bash\n";
         $script .= "set -e\n";
         $script .= "export 'VERBOSE=1' 'V=1'\n";
         $script .= "export 'CTEST_OUTPUT_ON_FAILURE=1'\n";
         if ($config && $config->{'max-threads'}) {
            $script .= "export 'DEB_BUILD_OPTIONS=parallel=".$config->{'max-threads'}."'\n";
         }
         else {
            $script .= "export 'DEB_BUILD_OPTIONS=parallel=10'\n";
         }
         $script .= "export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH:+\"\$LD_LIBRARY_PATH:\"}/usr/lib/libeatmydata\n";
         #$script .= "export LD_PRELOAD=\${LD_PRELOAD:+\"\$LD_PRELOAD \"}libeatmydata.so\n";
         if ($is_data eq 'data') {
            $script .= "export LD_PRELOAD=\${LD_PRELOAD:+\"\$LD_PRELOAD \"}libtcmalloc_minimal.so\n";
            $script .= "export 'LT_JOBS=1'\n";
         }
         if ($ENV{'AUTOPKG_BUILDTYPE'} eq 'nightly') {
            $script .= "export 'AP_REGTEST_MIN=80'\n";
            $script .= "export 'AP_REGTEST_QUIET=yes'\n";
         }
         $script .= "cd /build/${pkname}-*/\n";
         $script .= "timeout 180m time nice -n20 dpkg-buildpackage --no-sign\n";
         file_put_contents("$dpath/build.sh", $script);
         `chmod +x '$dpath/build.sh'`;
         `chown -R 1234:1234 '$dpath'`;

         `echo 'Building $distro $arch' >>$logpath/stderr.log 2>&1`;
         `$Bin/build-debian-ubuntu.sh '$img' '$dpath' >>$logpath/$distro-$arch.log 2>&1`;
         if ($?) {
            print {$out} "\tdocker $distro:$arch build fail\n";
            $failed .= "$logpath/$distro-$arch.log\n";
            $exitcode = 1;
            goto FAILED;
         }

         `debsign --no-re-sign $dpath/${pkname}_*.changes >>$logpath/$distro-$arch.log 2>&1`;
         `docker run --rm --network none -v "$dpath/:/build/" lintian-$variant >$logpath/$distro-$arch-lintian.log 2>&1`;

         `find $dpath -type f -name '*.deb' | LC_ALL=C sort | xargs -rn1 '-I{}' ar p '{}' data.tar.gz data.tar.xz 2>/dev/null | sha256sum -b | awk '{print \$1}' >$logpath/$distro-$arch.sha256-new`;
         if (! -s "$logpath/$distro-$arch.sha256" || int(`diff '$logpath/$distro-$arch.sha256' '$logpath/$distro-$arch.sha256-new' | wc -l`)) {
            $changed = 1;
         }
         rename("$logpath/$distro-$arch.sha256-new", "$logpath/$distro-$arch.sha256");
      }
   }

   FAILED:
   $failed .= `grep -L 'dpkg-genchanges' \$(grep -l 'dpkg-buildpackage: info: source package' \$(find /home/apertium/public_html/apt/logs/$pkname -type f | pcregrep "[-][^/]*log\$"))`;
   chomp($failed);

   my $depfail = '';
   $depfail = `grep -l 'packages have unmet dependencies' \$(grep -l 'dpkg-buildpackage: info: source package' \$(find /home/apertium/public_html/apt/logs/$pkname -type f | pcregrep "[-][^/]*log\$"))`;
   chomp($depfail);
   if ($depfail) {
      print {$out} "\tsoft fail: unmet dependencies\n";
   }

   if ($opts{'dry'}) {
      print {$out} "\tparched\n";
      last;
   }
   # If debs did not fail building, try RPMs and win32
   if (!$failed && $opts{'only'} ne 'deb') {
=pod
      if (-s "$pkg->[0]/rpm/$pkname.spec") {
         print {$out} "\tupdating rpm sources\n";
         `$Bin/make-rpm-source.pl $cli 2>>$logpath/stderr.log >&2`;
      }
      elsif ($is_data eq 'data') {
         $ENV{AUTOPKG_REBUILT} = '';
         foreach my $pk ($control =~ m@Package:\s*(\S+)@g) {
            chomp($pk);
            $ENV{AUTOPKG_REBUILT} .= "$pk;";
         }
         print {$out} "\tupdating rpm from data\n";
         `$Bin/make-rpm-data.pl $cli 2>>$logpath/stderr.log >&2`;
      }
=cut

=pod
      WINDOWS:
      while (-s "$pkg->[0]/win32/$pkname.sh") {
         print {$out} "\tbuilding win32\n";
         $ENV{'AUTOPKG_BITWIDTH'} = 'i686';
         $ENV{'AUTOPKG_WINX'} = 'win32';
         `bash -c '. $dir/win32-pre.sh; . $dir/$pkg->[0]/win32/$pkname.sh; . $dir/win32-post.sh;' -- '$pkname' '$newrev' '$version-$distv' '$dir/$pkg->[0]' 2>$logpath/win32.log >&2`;
         if ($?) {
            print {$out} "\tFAILED: win32\n";
            last;
         }
=cut

=pod
         print {$out} "\tbuilding win64\n";
         $ENV{'AUTOPKG_BITWIDTH'} = 'x86_64';
         $ENV{'AUTOPKG_WINX'} = 'win64';
         `bash -c '. $dir/win32-pre.sh; . $dir/$pkg->[0]/win32/$pkname.sh; . $dir/win32-post.sh;' -- '$pkname' '$newrev' '$version-$distv' '$dir/$pkg->[0]' 2>$logpath/win64.log >&2`;
         if ($?) {
            print {$out} "\tFAILED: win64\n";
            last;
         }
=cut
=pod

         $win32 = 1;
         if ($opts{'only'} eq 'win') {
            goto CLEANUP;
         }
         last;
      }
=cut
=pod
      if (-s "$pkg->[0]/osx/$pkname.sh") {
         print {$out} "\tbuilding osx\n";
         `bash -c '. $dir/osx-pre.sh; . $dir/$pkg->[0]/osx/$pkname.sh; . $dir/osx-post.sh;' -- '$pkname' '$newrev' '$version-$distv' '$dir/$pkg->[0]' 2>$logpath/osx.log >&2`;
         $osx = 1;
      }
=cut
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
      if ($ENV{'AUTOPKG_VCS'} eq 'git') {
         my ($oldrev) = ($oldversion =~ m@^\d+\.\d+\.\d+\+g\d+~([0-9a-f]+)@);
         if (!$oldrev) {
            goto CLEANUP;
         }
         $dir = getcwd();
         chdir("/opt/autopkg/repos/$pkname.git");
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
         elsif ($blame !~ m/\.local$/ && $blame !~ m/github\.com$/ && $blame =~ m/^.+@.+?\..+$/) {
            $cc .= " '$blame'";
         }
      }

=pod
      my $subject = "$pkg->[0] failed $ENV{AUTOPKG_BUILDTYPE} build";
      # Don't send individual emails if this is a manual build
      if (!$ARGV[0] && $cc ne '') {
         `cat $logpath/rebuild.log | mailx -s '$subject' -b 'mail\@tinodidriksen.com' -r 'apertium-packaging\@projectjj.com' 'apertium-packaging\@lists.sourceforge.net' $cc`;
      }
=cut
      goto CLEANUP;
   }

   # Add the resulting .deb to the Apt repository
   # Note that this does not happen if ANY failure was detected, to ensure we don't get partially-updated trees
   `$Bin/reprepro.sh '$pkname' '$is_data' '$pkg->[3]' 2>>$logpath/stderr.log >&2`;

   if (-s "$Bin/$pkg->[0]/hooks/post-publish" && -x "$Bin/$pkg->[0]/hooks/post-publish") {
      `$Bin/$pkg->[0]/hooks/post-publish >$logpath/hook-post-publish.log 2>&1`;
   }

   if ($pkg->[0] =~ m@^(languages|pairs)/apertium-@ && $ENV{'AUTOPKG_BUILDTYPE'} eq 'nightly') {
      my $y = substr($srcdate, 0, 4);
      $srcdate =~ s/-//g;
      $srcdate =~ s/://g;
      $srcdate =~ s/ /-/g;
      `mkdir -pv '/home/apertium/public_html/pkg-stats/$pkname/$y/' 2>>$logpath/stderr.log >&2`;
      `cd '/opt/autopkg/tmp/git/$pkname.git' && /opt/apertium-stats/tally-source.pl >/home/apertium/public_html/pkg-stats/$pkname/$y/$srcdate-$newrev.json`;
      `cd '/home/apertium/public_html/pkg-stats/$pkname/' && ln -sf '$y/$srcdate-$newrev.json' ./latest.json && /opt/apertium-stats/fetch-badges.pl latest.json`;
   }

=pod
   # Add the resulting .rpms to the Yum repositories
   if (-s "/home/apertium/rpmbuild/SRPMS/$pkname-$version-$distv.src.rpm") {
      open my $yumlog, ">$logpath/createrepo.log";
      my %distros;
      `rm -rf /home/apertium/public_html/yum/$ENV{AUTOPKG_BUILDTYPE}/*/$first/$pkname`;
      my $rpms = `find /home/apertium/mock/ -type f -name '*.rpm'`;
      chomp($rpms);
      foreach my $rpm (split(/\n/, $rpms)) {
         chomp($rpm);
         my $nc = $rpm;
         $nc =~ s@\.centos@@g;
         my ($distro,$arch) = $nc =~ m@\.([^.]+)\.([^.]+)\.rpm$@;
         $distros{$distro} = 1;
         `mkdir -p /home/apertium/public_html/yum/$ENV{AUTOPKG_BUILDTYPE}/$distro/$first/$pkname`;
         `su apertium -c "/home/apertium/bin/rpmsign.exp '$rpm'"`;
         print {$yumlog} `mv -fv '$rpm' /home/apertium/public_html/yum/$ENV{AUTOPKG_BUILDTYPE}/$distro/$first/$pkname/`;
      }
      `chown -R apertium:apertium /home/apertium/public_html/yum`;
      foreach my $distro (keys(%distros)) {
         print {$yumlog} "Recreating $distro yum repo\n";
         print {$yumlog} `su apertium -c "createrepo --database '/home/apertium/public_html/yum/$ENV{AUTOPKG_BUILDTYPE}/$distro/'"`;
         unlink("/home/apertium/public_html/yum/$ENV{AUTOPKG_BUILDTYPE}/$distro/repodata/repomd.xml.asc");
         `su apertium -c "gpg --detach-sign --armor '/home/apertium/public_html/yum/$ENV{AUTOPKG_BUILDTYPE}/$distro/repodata/repomd.xml'"`;
      }
      close $yumlog;
   }
=cut

   # Get a list of resulting packages and mark them all as rebuilt
   foreach my $pk ($control =~ m@Package:\s*(\S+)@g) {
      chomp($pk);
      $rebuilt{$is_tool}{$pk} = 1;
      print {$out} "\trebuilt: $pk\n";
   }

   CLEANUP:
   close $pkglog;

   # Wipe temporary clone
   `rm -rf /opt/autopkg/tmp/git/$pkname.git`;
}

print {$out2} "\n";

# If any package was (attempted) rebuilt, send a status email
if (!$ARGV[0] && (%rebuilt || %blames)) {
   print {$out2} `docker images | egrep '^autopkg' | egrep 'weeks|months' | cut '-d ' -f 1 | xargs -r docker rmi 2>&1`;
   print {$out2} `docker system prune -f 2>&1`;

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
   `echo 'See log at https://apertium.projectjj.com/apt/logs/nightly/' | mailx -s '$subject' -b 'mail\@tinodidriksen.com' -r 'apertium-packaging\@projectjj.com' 'apertium-packaging\@lists.sourceforge.net'`;
}

if ($win32) {
   print {$out2} "Combining Win32 builds\n";
   $ENV{'AUTOPKG_BITWIDTH'} = 'i686';
   $ENV{'AUTOPKG_WINX'} = 'win32';
   `$Bin/win32-combine.sh`;

=pod
   print {$out2} "Combining Win64 builds\n";
   $ENV{'AUTOPKG_BITWIDTH'} = 'x86_64';
   $ENV{'AUTOPKG_WINX'} = 'win64';
   `$Bin/win32-combine.sh`;
=cut
}
if ($osx) {
   print {$out2} "Combining OS X builds\n";
   `$Bin/osx-combine.sh`;
}

print {$out2} "Build $ENV{AUTOPKG_BUILDTYPE} stopped at ".`date -u`;
close $log;
unlink("/opt/autopkg/tmp/rebuild.$$.log");
unlink('/opt/autopkg/rebuild.lock');

exit($exitcode);
