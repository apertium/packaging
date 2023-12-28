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
   die "Another instance of builder is running - bailing out!\n";
}
`date -u > /tmp/rebuild.lock`;

$ENV{'LANG'} = 'C.UTF-8';
$ENV{'LC_ALL'} = 'C.UTF-8';
$ENV{'PATH'} = '/opt/mxe/usr/bin:'.$ENV{'PATH'};
$ENV{'TERM'} = 'putty';
$ENV{'TERMCAP'} = '';

my $arch = $ENV{'AUTOPKG_BITWIDTH'} = 'x86_64';
$ENV{'LDFLAGS'} = '-fno-use-linker-plugin';
$ENV{'PKG_CONFIG'} = "/opt/mxe/usr/bin/${arch}-w64-mingw32.shared-pkg-config";
$ENV{"PKG_CONFIG_PATH_${arch}_w64_mingw32_shared"} = "/opt/win-${arch}/lib/pkgconfig";

my $py3v = `python3 --version | egrep -o '[0-9]+[.][0-9]+'`;
chomp($py3v);
$ENV{'PYTHONPATH'} = "/opt/win-${arch}/lib/python${py3v}/site-packages";
my $python3 = "python${py3v}";

my %pkgs = load_packages();

my $ncpu = int(`nproc`);

`mkdir -p '${Bin}/nightly/source' '${Bin}/nightly/build/apertium-all-dev'`;
`mkdir -p '${Bin}/release/source' '${Bin}/release/build/apertium-all-dev'`;

for my $k (@{$pkgs{'order'}}) {
   my $pkg = $pkgs{'packages'}->{$k};
   if ($ARGV[0] && $pkg->[0] !~ m@/\Q$ARGV[0]\E$@) {
      next;
   }
   my ($pkname) = ($pkg->[0] =~ m@([-\w]+)$@);
   if (! -e "${Bin}/$pkg->[0]/windows/setup.sh") {
      next;
   }
   print "Syncing ${pkname}\n";

   for (my $i=0 ; $i<2 ; ++$i) {
      print `rsync -az --partial --inplace 'apertium\@oqaa.projectjj.com:~/public_html/apt/nightly/source/${pkname}/*+*.tar.bz2' 'nightly/source/${pkname}.tar.bz2'`;
      print `rsync -az --partial --inplace 'apertium\@oqaa.projectjj.com:~/public_html/apt/release/source/${pkname}/*.tar.bz2' 'release/source/${pkname}.tar.bz2'`;
   }
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
      if (! -e "${Bin}/$pkg->[0]/windows/setup.sh") {
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

      my $rebuild = (!-s "${pkpath}/${pkname}-latest.${arch}.7z") || $ARGV[0];

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
         if (-M "${pkpath}/${pkname}-latest.${arch}.7z" > -M "source/${pkname}.tar.bz2") {
            print "\ttarball newer\n";
            $rebuild = 1;
         }
      }

      if (!$rebuild) {
         print "\tno reason to build - extracting latest\n";
         `mkdir -p /tmp/$$`;
         chdir("/tmp/$$");
         `unzip '${pkpath}/${pkname}-latest.${arch}.zip'`;
         `cp -a --reflink=auto '${pkname}/'* /opt/win-${arch}/`;
         chdir("/tmp");
         `rm -rf /tmp/$$`;
         ++$done;
         next;
      }

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
      `grep -rl '^\#!/usr/bin/perl' * | xargs -rn1 perl -pe 's\@^\#!/usr/bin/perl\@\#!/usr/bin/env perl\@g;' -i`;
      `grep -rl '^\#!/usr/bin/python' * | xargs -rn1 perl -pe 's\@^\#!/usr/bin/python\@\#!/usr/bin/env python\@g;' -i`;
      `grep -rl '^\#!/bin/bash' * | xargs -rn1 perl -pe 's\@^\#!/usr/bin/bash\@\#!/usr/bin/env bash\@g;' -i`;

      print "\tsetting up build...\n";
      `echo '======== SETUP ========' >>'${logfile}-setup.log'`;
      `date -u >>'${logfile}-setup.log'`;
      my $log = `bash '${Bin}/$pkg->[0]/windows/setup.sh' >>'${logfile}-setup.log' 2>&1 || echo 'SETUP FAILED'`;
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
      else {
         $log = `$python3 setup.py build >>'${logfile}-build.log' 2>&1 || echo 'BUILD FAILED'`;
      }
      `cat '${logfile}-build.log' >>'${logfile}.log'`;
      if ($log =~ /^BUILD FAILED/) {
         print "\tfailed build\n";
         next;
      }

      $log = '';
      if (-e "${Bin}/$pkg->[0]/windows/post-build.sh") {
         print "\tpost-build...\n";
         `echo '======== POST-BUILD ========' >>'${logfile}-post-build.log'`;
         `date -u >>'${logfile}-post-build.log'`;
         $log = `${Bin}/$pkg->[0]/windows/post-build.sh >>'${logfile}-post-build.log' 2>&1 || echo 'POST-BUILD FAILED'`;
         `cat '${logfile}-post-build.log' >>'${logfile}.log'`;
      }
      if ($log =~ /^POST-BUILD FAILED/) {
         print "\tpost-build test\n";
         next;
      }

      print "\tinstalling...\n";
      `echo '======== INSTALL ========' >>'${logfile}-install.log'`;
      `date -u >>'${logfile}-install.log'`;
      `rm -rf /tmp/install`;
      if (-s 'Makefile') {
         $log = `make -j${ncpu} install DESTDIR=/tmp/install V=1 VERBOSE=1 >>'${logfile}-install.log' 2>&1 || echo 'INSTALL FAILED'`;
      }
      else {
         $log = `$python3 setup.py install --prefix=/opt/win-${arch} --install-scripts=/opt/win-${arch}/bin --root=/tmp/install >>'${logfile}-install.log' 2>&1 || echo 'INSTALL FAILED'`;
         `grep -rl '^\#!/opt/local/bin/python' /tmp/install | xargs -rn1 perl -pe 's\@^\#!/opt/local/bin/python3[^\\n]*\@\#!/usr/bin/env python3\@g; s\@^\#!/opt/local/bin/python[^\\n]*\@\#!/usr/bin/env python\@g;' -i`;
      }
      `cat '${logfile}-install.log' >>'${logfile}.log'`;
      if ($log =~ /^INSTALL FAILED/) {
         print "\tfailed install\n";
         next;
      }
      if (-s 'Makefile') {
         `make -j4 install >/dev/null 2>&1`;
      }
      else {
         `$python3 setup.py install --prefix=/opt/win-${arch} --install-scripts=/opt/win-${arch}/bin --root=/ >/dev/null 2>&1`;
         `grep -rl '^\#!/opt/local/bin/python' /opt/win-${arch} | xargs -rn1 perl -pe 's\@^\#!/opt/local/bin/python3[^\\n]*\@\#!/usr/bin/env python3\@g; s\@^\#!/opt/local/bin/python[^\\n]*\@\#!/usr/bin/env python\@g;' -i`;
      }

      print "\tpackaging...\n";
      `echo '======== PACKAGE ========' >>'${logfile}-package.log'`;
      `date -u >>'${logfile}-package.log'`;
      if (-s "/tmp/${pkname}.${arch}.zip") {
         unlink("/tmp/${pkname}.${arch}.zip");
      }
      if (-s "/tmp/${pkname}.${arch}.7z") {
         unlink("/tmp/${pkname}.${arch}.7z");
      }
      chdir("/tmp/install/opt/win-${arch}/bin");
      `echo '======== PACKAGE: DEPS ========' >>'${logfile}-package.log'`;
      `${Bin}/mxe-copy-deps.pl >>'${logfile}-package.log' 2>&1`;
      chdir("/tmp/install/opt/win-${arch}");
      `${Bin}/mxe-strip.sh >>'${logfile}-package.log' 2>&1`;
      `echo '======== PACKAGE: ZIP + 7Z ========' >>'${logfile}-package.log'`;
      chdir('/tmp/install/opt');
      rename("win-${arch}", $pkname);
      $log = '';
      $log .= `zip -9r '/tmp/${pkname}.${arch}.zip' * >>'${logfile}-package.log' 2>&1 || echo 'PACKAGE FAILED'`;
      $log .= `7za a '/tmp/${pkname}.${arch}.7z' * >>'${logfile}-package.log' 2>&1 || echo 'PACKAGE FAILED'`;
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
      `mv -v '/tmp/${pkname}.${arch}.zip' '${pkpath}/${pkname}-latest.${arch}.zip' >>'${logfile}.log' 2>&1`;
      `mv -v '/tmp/${pkname}.${arch}.7z' '${pkpath}/${pkname}-latest.${arch}.7z' >>'${logfile}.log' 2>&1`;
      `ln -sv '${pkname}-latest.${arch}.zip' '${pkpath}/${ver}.${arch}.zip' >>'${logfile}.log' 2>&1`;
      `ln -sv '${pkname}-latest.${arch}.7z' '${pkpath}/${ver}.${arch}.7z' >>'${logfile}.log' 2>&1`;
      `cp -avf --reflink=auto '${logfile}.log' '${pkpath}/${pkname}.log'`;

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
      if (! -s "${Bin}/${cadence}/build/${pkname}/${pkname}-latest.${arch}.zip") {
         next;
      }
      print "\t${pkname}\n";
      `unzip -o '${Bin}/${cadence}/build/${pkname}/${pkname}-latest.${arch}.zip' >>apertium-all-dev.log 2>&1`;
      `cp -af --reflink=auto '${pkname}/'* ./apertium-all-dev/`;
      `rm -rf '${pkname}'`;
   }
   `${Bin}/mxe-strip.sh >>apertium-all-dev.log 2>&1`;
   `zip -9r apertium-all-dev.${arch}.zip apertium-all-dev >>apertium-all-dev.log 2>&1`;
   `7za a apertium-all-dev.${arch}.7z apertium-all-dev >>apertium-all-dev.log 2>&1`;
   `mv apertium-all-dev.${arch}.zip apertium-all-dev.${arch}.7z apertium-all-dev.log '${Bin}/${cadence}/build/apertium-all-dev/'`;

   print "Uploading ${cadence}...\n";
   chdir("${Bin}/${cadence}/build");
   file_put_contents('upload.log', '');
   for (my $i=0 ; $i<3 ; ++$i) {
      `rsync -avz */*.zip */*.7z apertium\@oqaa.projectjj.com:public_html/windows/${cadence}/${arch}/ >>upload.log 2>&1`;
   }
   `ssh -l apertium oqaa.projectjj.com "find '/home/apertium/public_html/windows/${cadence}/${arch}' -name '*-[0-9]*.${arch}*' | xargs -rn1 rm -fv" >>upload.log 2>&1`;
   `rsync -avzc */*.zip */*.7z apertium\@oqaa.projectjj.com:public_html/windows/${cadence}/${arch}/ >>upload.log 2>&1`;

   print "\n";
}

unlink('/tmp/rebuild.lock');
