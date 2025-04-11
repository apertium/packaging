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

use FindBin qw($Bin);
use lib "$Bin/";
use Helpers;
chdir($Bin);

if (-s '/tmp/rebuild.lock') {
   my $pid = int(file_get_contents('/tmp/rebuild.lock'));
   if (int(`ps ax | grep [r]ebuild | grep '$pid' | wc -l`) >= 1) {
      die "Another instance of builder is running as PID $pid - bailing out!\n";
   }
   print "Clobbering stale builder lock from PID $pid\n";
}
file_put_contents('/tmp/rebuild.lock', $$);

$ENV{'LANG'} = 'en_US.UTF-8';
$ENV{'LC_ALL'} = 'en_US.UTF-8';
$ENV{'PATH'} = '/opt/local/bin:/opt/local/sbin:/usr/bin:/bin:'.$ENV{'PATH'};
$ENV{'TERM'} = 'putty';
$ENV{'TERMCAP'} = '';

$ENV{'MACOSX_DEPLOYMENT_TARGET'} = '11.0';
$ENV{'CC'} = 'clang';
$ENV{'CXX'} = 'clang++';
$ENV{'CPATH'} = '/opt/local/include/';
$ENV{'CFLAGS'} = '-Wall -Wextra -O2';
$ENV{'CXXFLAGS'} = '-stdlib=libc++ -Wall -Wextra -O2 -DSIZET_NOT_CSTDINT=1 -DU_USING_ICU_NAMESPACE=1';
$ENV{'LDFLAGS'} = '-L/opt/local/lib/ -stdlib=libc++ -Wl,-headerpad_max_install_names';
$ENV{'ACLOCAL_PATH'} = '/usr/local/share/aclocal';
$ENV{'PKG_CONFIG_PATH'} = '/usr/local/lib/pkgconfig';

my $py3v = `python3 --version | egrep -o '[0-9]+[.][0-9]+'`;
chomp($py3v);
$ENV{'PYTHONPATH'} = "/usr/local/lib/python${py3v}/site-packages";
my $python3 = "python${py3v}";

my %pkgs = load_packages();

my $ncpu = int(`sysctl -n hw.ncpu`);
chomp(my $arch = `uname -m`);

`mkdir -p '${Bin}/nightly/source' '${Bin}/nightly/build/apertium-all-dev'`;
`mkdir -p '${Bin}/release/source' '${Bin}/release/build/apertium-all-dev'`;

for my $k (@{$pkgs{'order'}}) {
   my $pkg = $pkgs{'packages'}->{$k};
   if ($ARGV[0] && $pkg->[0] !~ m@/\Q$ARGV[0]\E$@) {
      next;
   }
   my ($pkname) = ($pkg->[0] =~ m@([-\w]+)$@);
   if (! -e "${Bin}/$pkg->[0]/osx/setup.sh") {
      next;
   }
   print "Syncing ${pkname}\n";

   print `rsync -az 'root\@192.168.1.19:/home/apertium/public_html/apt/nightly/source/${pkname}/*+*.tar.bz2' 'nightly/source/${pkname}.tar.bz2'`;
   print `rsync -az 'root\@192.168.1.19:/home/apertium/public_html/apt/release/source/${pkname}/*.tar.bz2' 'release/source/${pkname}.tar.bz2'`;
}

# Ordered so that nightly is left installed after the build
for my $cadence (qw( nightly )) {#release
   print "Building ${cadence} for ${arch}...\n";
   `rm -rf /tmp/build/${cadence}`;
   `mkdir -p /tmp/build/${cadence}`;

   my @combo = ();
   my %rebuilt = ();
   my $did = 0;
   my $done = 0;

   for my $k (@{$pkgs{'order'}}) {
      my $pkg = $pkgs{'packages'}->{$k};
      if ($ARGV[0] && $pkg->[0] !~ m@/\Q$ARGV[0]\E$@) {
         next;
      }
      my ($pkname) = ($pkg->[0] =~ m@([-\w]+)$@);
      if (! -e "${Bin}/$pkg->[0]/osx/setup.sh") {
         next;
      }
      push(@combo, $pkname);

      $ENV{'AUTOPKG_PKPATH'} = "${Bin}/$pkg->[0]";

      print "${pkname}\n";
      my $pkpath = "${Bin}/${cadence}/build/${pkname}";
      chdir("${Bin}/${cadence}");

      if (! -s "source/${pkname}.tar.bz2") {
         print "\tno such tarball\n";
         next;
      }

      my $rebuild = (!-s "${pkpath}/${pkname}-latest.${arch}.tar.bz2") || $ARGV[0];

      if (!$rebuild) {
         my $deps = file_get_contents("${Bin}/$pkg->[0]/debian/control");
         $deps = join("\n", ($deps =~ m@Build-Depends:(\s*.*?)\n\S@gs));
         foreach my $dep (split(/[,|\n]/, $deps)) {
            $dep =~ s@\([^)]+\)@@g;
            $dep =~ s@\s+$@@gs;
            $dep =~ s@^\s+@@gs;
            if ($dep && defined $rebuilt{$dep}) {
               $rebuild = 1;
               print "\tdependency $dep rebuilt\n";
               last;
            }
         }
      }

      if (!$rebuild) {
         if (-M "${pkpath}/${pkname}-latest.${arch}.tar.bz2" > -M "source/${pkname}.tar.bz2") {
            print "\ttarball newer\n";
            $rebuild = 1;
         }
      }

      if (!$rebuild) {
         print "\tno reason to build - extracting latest\n";
         `mkdir -p /tmp/$$`;
         chdir("/tmp/$$");
         `tar -jxf '${pkpath}/${pkname}-latest.${arch}.tar.bz2'`;
         `cp -ac '${pkname}/'* /usr/local/`;
         chdir("/tmp");
         `rm -rf /tmp/$$`;
         ++$done;
         next;
      }

      # Dirty hack for @rpath issue https://developer.apple.com/forums/thread/737920
      `install_name_tool -id /usr/local/lib/libcg3.1.dylib /usr/local/lib/libcg3.1.dylib`;
      `install_name_tool -id /usr/local/lib/libfoma.0.10.0.dylib /usr/local/lib/libfoma.0.10.0.dylib`;

      my $logfile = "/tmp/build/${cadence}/${pkname}";
      `rm -fv '${logfile}'-*.log`;

      $ENV{'AUTOPKG_BUILDPATH'} = "/tmp/build/${cadence}/${pkname}";

      print "\tunpacking source...\n";
      `echo '======== SOURCE ========' >>'${logfile}-source.log'`;
      `date -u >>'${logfile}-source.log'`;
      `rm -rf /tmp/build/${cadence}/${pkname}`;
      `mkdir -p /tmp/build/${cadence}/${pkname}`;
      chdir("/tmp/build/${cadence}/${pkname}");
      `tar -jxvf '${Bin}/${cadence}/source/${pkname}.tar.bz2' >>'${logfile}-source.log' 2>&1`;
      `cat '${logfile}-source.log' >>'${logfile}.log'`;

      my @vers = glob("${pkname}*");
      my $ver = $vers[0];
      chdir($ver);

      # Use binaries in $PATH
      `grep -rl '^\#!/usr/bin/perl' * | xargs -n1 perl -pe 's\@^\#!/usr/bin/perl\@\#!/usr/bin/env perl\@g;' -i`;
      `grep -rl '^\#!/usr/bin/python' * | xargs -n1 perl -pe 's\@^\#!/usr/bin/python\@\#!/usr/bin/env python\@g;' -i`;
      `grep -rl '^\#!/bin/bash' * | xargs -n1 perl -pe 's\@^\#!/usr/bin/bash\@\#!/usr/bin/env bash\@g;' -i`;

      print "\tsetting up build...\n";
      `echo '======== SETUP ========' >>'${logfile}-setup.log'`;
      `date -u >>'${logfile}-setup.log'`;
      my $log = `bash '${Bin}/$pkg->[0]/osx/setup.sh' >>'${logfile}-setup.log' 2>&1 || echo 'SETUP FAILED'`;
      `cat '${logfile}-setup.log' >>'${logfile}.log'`;
      if ($log =~ /^SETUP FAILED/) {
         print "\tfailed setup\n";
         next;
      }

      print "\tbuilding...\n";
      `echo '======== BUILD ========' >>'${logfile}-build.log'`;
      `date -u >>'${logfile}-build.log'`;
      if (-s 'Makefile') {
         $log = `make -j${ncpu} V=1 VERBOSE=1 >>'${logfile}-build.log' 2>&1 || echo 'BUILD FAILED'`;
      }
      elsif (-s 'setup.py') {
         $log = `$python3 setup.py build >>'${logfile}-build.log' 2>&1 || echo 'BUILD FAILED'`;
      }
      elsif (-s 'pyproject.toml') {
         # Skip build
      }
      `cat '${logfile}-build.log' >>'${logfile}.log'`;
      if ($log =~ /^BUILD FAILED/) {
         print "\tfailed build\n";
         next;
      }

      $log = '';
      if (-e "${Bin}/$pkg->[0]/osx/post-build.sh") {
         print "\tpost-build...\n";
         `echo '======== POST-BUILD ========' >>'${logfile}-post-build.log'`;
         `date -u >>'${logfile}-post-build.log'`;
         $log = `${Bin}/$pkg->[0]/osx/post-build.sh >>'${logfile}-post-build.log' 2>&1 || echo 'POST-BUILD FAILED'`;
         `cat '${logfile}-post-build.log' >>'${logfile}.log'`;
      }
      if ($log =~ /^POST-BUILD FAILED/) {
         print "\tpost-build test\n";
         next;
      }

      $log = '';
      my $test = '';
      if (-e "${Bin}/$pkg->[0]/osx/test.sh") {
        $test = "${Bin}/$pkg->[0]/osx/test.sh";
      }
      elsif (-s 'Makefile') {
         my $mkfile = file_get_contents('Makefile');
         if ($mkfile =~ /^test:/m) {
            $test = 'test';
         }
         elsif ($mkfile =~ /^check:/m) {
            $test = 'check';
         }
         if ($test) {
            $test = "make '${test}' V=1 VERBOSE=1";
         }
      }
      if ($test) {
         print "\ttesting...\n";
         `echo '======== TEST ========' >>'${logfile}-test.log'`;
         `date -u >>'${logfile}-test.log'`;
         $log = `${test} >>'${logfile}-test.log' 2>&1 || echo 'TEST FAILED'`;
         `cat '${logfile}-test.log' >>'${logfile}.log'`;
      }
      if ($log =~ /^TEST FAILED/) {
         print "\tfailed test\n";
         next;
      }

      print "\tinstalling...\n";
      `echo '======== INSTALL ========' >>'${logfile}-install.log'`;
      `date -u >>'${logfile}-install.log'`;
      `rm -rf /tmp/install`;
      if (-s 'Makefile') {
         $log = `make -j${ncpu} install DESTDIR=/tmp/install V=1 VERBOSE=1 >>'${logfile}-install.log' 2>&1 || echo 'INSTALL FAILED'`;
      }
      elsif (-s 'setup.py') {
         $log = `$python3 setup.py install --prefix=/usr/local --install-scripts=/usr/local/bin --root=/tmp/install >>'${logfile}-install.log' 2>&1 || echo 'INSTALL FAILED'`;
         `grep -rl '^\#!/opt/local/bin/python' /tmp/install | xargs -n1 perl -pe 's\@^\#!/opt/local/bin/python3[^\\n]*\@\#!/usr/bin/env python3\@g; s\@^\#!/opt/local/bin/python[^\\n]*\@\#!/usr/bin/env python\@g;' -i`;
      }
      elsif (-s 'pyproject.toml') {
         $log = `$python3 -m pip install --prefix=/usr/local --root=/tmp/install -I --no-deps . >>'${logfile}-install.log' 2>&1 || echo 'INSTALL FAILED'`;
         `grep -rl '^\#!/opt/local/bin/python' /tmp/install | xargs -n1 perl -pe 's\@^\#!/opt/local/bin/python3[^\\n]*\@\#!/usr/bin/env python3\@g; s\@^\#!/opt/local/bin/python[^\\n]*\@\#!/usr/bin/env python\@g;' -i`;
      }
      `cat '${logfile}-install.log' >>'${logfile}.log'`;
      if ($log =~ /^INSTALL FAILED/) {
         print "\tfailed install\n";
         next;
      }
      if (-s 'Makefile') {
         `make -j4 install >/dev/null 2>&1`;
      }
      elsif (-s 'setup.py') {
         `$python3 setup.py install --prefix=/usr/local --install-scripts=/usr/local/bin --root=/ >/dev/null 2>&1`;
         `grep -rl '^\#!/opt/local/bin/python' /usr/local | xargs -n1 perl -pe 's\@^\#!/opt/local/bin/python3[^\\n]*\@\#!/usr/bin/env python3\@g; s\@^\#!/opt/local/bin/python[^\\n]*\@\#!/usr/bin/env python\@g;' -i`;
      }
      elsif (-s 'pyproject.toml') {
         $log = `$python3 -m pip install --prefix=/usr/local --root=/ -I --no-deps . >>'${logfile}-install.log' 2>&1 || echo 'INSTALL FAILED'`;
         `grep -rl '^\#!/opt/local/bin/python' /usr/local | xargs -n1 perl -pe 's\@^\#!/opt/local/bin/python3[^\\n]*\@\#!/usr/bin/env python3\@g; s\@^\#!/opt/local/bin/python[^\\n]*\@\#!/usr/bin/env python\@g;' -i`;
      }

      print "\tpackaging...\n";
      `echo '======== PACKAGE ========' >>'${logfile}-package.log'`;
      `date -u >>'${logfile}-package.log'`;
      if (-s "/tmp/${pkname}.tar.bz2") {
         unlink("/tmp/${pkname}.tar.bz2");
      }
      chdir('/tmp/install/usr/local');
      `mkdir -p lib`;
      `echo '======== PACKAGE: DEPS ========' >>'${logfile}-package.log'`;
      `${Bin}/macos-copy-deps.pl >>'${logfile}-package.log' 2>&1`;
      `echo '======== PACKAGE: TAR ========' >>'${logfile}-package.log'`;
      chdir('/tmp/install/usr');
      rename('local', $pkname);
      $log = `tar -jcvf '/tmp/${pkname}.${arch}.tar.bz2' * >>'${logfile}-package.log' 2>&1 || echo 'PACKAGE FAILED'`;
      `cat '${logfile}-package.log' >>'${logfile}.log'`;
      if ($log =~ /PACKAGE FAILED/) {
         print "\tfailed packaging\n";
         next;
      }

      my $deps = file_get_contents("${Bin}/$pkg->[0]/debian/control");
      $deps = join("\n", ($deps =~ m@Package:(\s*.*?)\n\S@gs));
      foreach my $dep (split(/\n+/, $deps)) {
         $dep =~ s@\([^)]+\)@@g;
         $dep =~ s@\s+$@@gs;
         $dep =~ s@^\s+@@gs;
         if ($dep) {
            print "\trebuilt: $dep\n";
            $rebuilt{$dep} = 1;
         }
      }

      `rm -rf '${pkpath}'`;
      `mkdir -p '${pkpath}'`;
      `mv -v '/tmp/${pkname}.${arch}.tar.bz2' '${pkpath}/${pkname}-latest.${arch}.tar.bz2' >>'${logfile}.log' 2>&1`;
      `ln -sv '${pkname}-latest.${arch}.tar.bz2' '${pkpath}/${ver}.${arch}.tar.bz2' >>'${logfile}.log' 2>&1`;
      `cp -acf '${logfile}.log' '${pkpath}/${pkname}.log'`;

      $did = 1;
      ++$done;
   }

   if (!$did) {
      next;
   }

   if ($ARGV[0]) {
      print "Specific package $ARGV[0] build - won't combine.\n";
      next;
   }

   my $expect = scalar(@combo);
   if ($done < $expect) {
      print "${done} of ${expect} builds succeeded - won't combine!\n";
      next;
   }

   print "Combining ${cadence}...\n";
   `rm -rf /tmp/combo`;
   `mkdir -p /tmp/combo/apertium-all-dev`;
   chdir('/tmp/combo');
   for my $pkname (@combo) {
      if (! -s "${Bin}/${cadence}/build/${pkname}/${pkname}-latest.${arch}.tar.bz2") {
         next;
      }
      print "\t${pkname}\n";
      `tar -jxvf '${Bin}/${cadence}/build/${pkname}/${pkname}-latest.${arch}.tar.bz2' >>apertium-all-dev.log 2>&1`;
      `cp -ac '${pkname}/'* ./apertium-all-dev/`;
      `rm -rf '${pkname}'`;
   }
   `tar -jcvf apertium-all-dev.${arch}.tar.bz2 apertium-all-dev >>apertium-all-dev.log 2>&1`;
   `7za a apertium-all-dev.${arch}.7z apertium-all-dev >>apertium-all-dev.log 2>&1`;
   `mv apertium-all-dev.${arch}.tar.bz2 apertium-all-dev.${arch}.7z apertium-all-dev.log '${Bin}/${cadence}/build/apertium-all-dev/'`;

   print "Uploading ${cadence}...\n";
   chdir("${Bin}/${cadence}/build");
   file_put_contents('upload.log', '');
   for (my $i=0 ; $i<3 ; ++$i) {
      `rsync -avz */*.tar.bz2 */*.7z apertium\@oqaa.projectjj.com:public_html/osx/${cadence}/${arch}/ >>upload.log 2>&1`;
   }
   `ssh -l apertium oqaa.projectjj.com "find '/home/apertium/public_html/osx/${cadence}/${arch}' -name '*-[0-9]*.${arch}*' | xargs -rn1 rm -fv" >>upload.log 2>&1`;
   `rsync -avzc */*.tar.bz2 */*.7z apertium\@oqaa.projectjj.com:public_html/osx/${cadence}/${arch}/ >>upload.log 2>&1`;

   print "\n";
}

unlink('/tmp/rebuild.lock');
