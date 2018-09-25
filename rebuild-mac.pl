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

use FindBin qw($Bin);
chdir($Bin) or die "Could not chdir($Bin): $!\n";

sub file_get_contents {
   my ($fname) = @_;
   local $/ = undef;
   open FILE, $fname or die "Could not open ${fname}: $!\n";
   my $data = <FILE>;
   close FILE;
   return $data;
}

if (-s '/tmp/rebuild.lock') {
   die "Another instance of builder is running - bailing out!\n";
}
`date -u > /tmp/rebuild.lock`;

$ENV{'LANG'} = 'en_US.UTF-8';
$ENV{'LC_ALL'} = 'en_US.UTF-8';
$ENV{'PATH'} = '/opt/local/bin:/opt/local/sbin:'.$ENV{'PATH'};
$ENV{'TERM'} = 'putty';
$ENV{'TERMCAP'} = '';

$ENV{'CC'} = 'clang';
$ENV{'CXX'} = 'clang++';
$ENV{'CFLAGS'} = '-Wall -Wextra -O2';
$ENV{'CXXFLAGS'} = '-stdlib=libc++ -Wall -Wextra -O2 -DSIZET_NOT_CSTDINT=1 -DU_USING_ICU_NAMESPACE=1';
$ENV{'LDFLAGS'} = '-stdlib=libc++ -Wl,-headerpad_max_install_names';
$ENV{'ACLOCAL_PATH'} = '/usr/local/share/aclocal';
$ENV{'PKG_CONFIG_PATH'} = '/usr/local/lib/pkgconfig';

use JSON;
my $pkgs = JSON->new->relaxed->decode(file_get_contents('packages.json'));

`mkdir -p '${Bin}/nightly/source' '${Bin}/nightly/build/apertium-all-dev'`;
`mkdir -p '${Bin}/release/source' '${Bin}/release/build/apertium-all-dev'`;

for my $pkg (@$pkgs) {
   my ($pkname) = (@$pkg[0] =~ m@([-\w]+)$@);
   if (! -s "${Bin}/@$pkg[0]/osx/setup.sh") {
      next;
   }
   print "Syncing ${pkname}\n";

   print `rsync -az 'apertium\@oqaa.projectjj.com:~/public_html/apt/nightly/source/${pkname}/*+*.tar.bz2' 'nightly/source/${pkname}.tar.bz2'`;
   print `rsync -az 'apertium\@oqaa.projectjj.com:~/public_html/apt/release/source/${pkname}/*.tar.bz2' 'release/source/${pkname}.tar.bz2'`;
}

# Ordered so that nightly is left installed after the build
for my $cadence (qw( release nightly )) {
   print "Building ${cadence}...\n";
   my @combo = ();
   my %rebuilt = ();
   my $did = 0;

   for my $pkg (@$pkgs) {
      my ($pkname) = (@$pkg[0] =~ m@([-\w]+)$@);
      if (! -s "${Bin}/@$pkg[0]/osx/setup.sh") {
         next;
      }
      push(@combo, $pkname);

      print "${pkname}\n";
      my $pkpath = "${Bin}/${cadence}/build/${pkname}";
      chdir("${Bin}/${cadence}") or die "Could not chdir(${Bin}/${cadence}): $!\n";

      if (! -s "source/${pkname}.tar.bz2") {
         print "\tno such tarball\n";
         next;
      }

      my $rebuild = (!-s "${pkpath}/${pkname}-latest.tar.bz2");

      if (!$rebuild) {
         my $deps = file_get_contents("${Bin}/@$pkg[0]/debian/control");
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
         if (-M "${pkpath}/${pkname}-latest.tar.bz2" > -M "source/${pkname}.tar.bz2") {
            print "\ttarball newer\n";
            $rebuild = 1;
         }
      }

      if (!$rebuild) {
         print "\tno reason to build\n";
         chdir('/usr/local') or die "Could not chdir(/usr/local): $!\n";
         `tar -jxvf '${pkpath}/${pkname}-latest.tar.bz2' >/dev/null 2>&1`;
         next;
      }

      my $logfile = "/tmp/build/${cadence}/${pkname}.log";
      unlink($logfile);

      print "\tunpacking source...\n";
      `echo '======== SOURCE ========' >>'${logfile}'`;
      `date -u >>'${logfile}'`;
      `rm -rf /tmp/build/${cadence}/${pkname}`;
      `mkdir -p /tmp/build/${cadence}/${pkname}`;
      chdir("/tmp/build/${cadence}/${pkname}") or die "Could not chdir(/tmp/build/${cadence}/${pkname}): $!\n";
      `tar -jxvf '${Bin}/${cadence}/source/${pkname}.tar.bz2' >>'${logfile}' 2>&1`;

      my @vers = glob("${pkname}*");
      my $ver = $vers[0];
      chdir($ver) or die "Could not chdir(${ver}): $!\n";

      # Use binaries in $PATH
      `grep -rl '^#!/usr/bin/perl' * | xargs -n1 perl -pe 's\@^#!/usr/bin/perl\@#!/usr/bin/env perl\@g;' -i`;
      `grep -rl '^#!/usr/bin/python' * | xargs -n1 perl -pe 's\@^#!/usr/bin/python\@#!/usr/bin/env python\@g;' -i`;
      `grep -rl '^#!/bin/bash' * | xargs -n1 perl -pe 's\@^#!/usr/bin/bash\@#!/usr/bin/env bash\@g;' -i`;

      print "\tsetting up build...\n";
      `echo '======== SETUP ========' >>'${logfile}'`;
      `date -u >>'${logfile}'`;
      my $log = `bash '${Bin}/@$pkg[0]/osx/setup.sh' >>'${logfile}' 2>&1 || echo 'SETUP FAILED'`;
      if ($log =~ /^SETUP FAILED/) {
         print "\tfailed setup\n";
         next;
      }

      print "\tbuilding...\n";
      `echo '======== BUILD ========' >>'${logfile}'`;
      `date -u >>'${logfile}'`;
      $log = `make -j4 V=1 VERBOSE=1 >>'${logfile}' 2>&1 >>'${logfile}' 2>&1 || echo 'BUILD FAILED'`;
      if ($log =~ /^BUILD FAILED/) {
         print "\tfailed build\n";
         next;
      }

      my $test = '';
      my $mkfile = file_get_contents('Makefile');
      if ($mkfile =~ /^test:/m) {
         $test = 'test';
      }
      elsif ($mkfile =~ /^check:/m) {
         $test = 'check';
      }
      if ($test) {
         print "\ttesting...\n";
         `echo '======== TEST ========' >>'${logfile}'`;
         `date -u >>'${logfile}'`;
         $log = `make '${test}' V=1 VERBOSE=1 >>'${logfile}' 2>&1 || echo 'TEST FAILED'`;
         if ($log =~ /^TEST FAILED/) {
            print "\tfailed test\n";
            next;
         }
      }

      print "\tinstalling...\n";
      `echo '======== INSTALL ========' >>'${logfile}'`;
      `date -u >>'${logfile}'`;
      `rm -rf /tmp/install`;
      $log = `make -j4 install DESTDIR=/tmp/install V=1 VERBOSE=1 >>'${logfile}' 2>&1 || echo 'INSTALL FAILED'`;
      if ($log =~ /^INSTALL FAILED/) {
         print "\tfailed install\n";
         next;
      }
      `make -j4 install >/dev/null 2>&1`;

      print "\tpackaging...\n";
      `echo '======== PACKAGE ========' >>'${logfile}'`;
      `date -u >>'${logfile}'`;
      unlink("/tmp/${pkname}.tar.bz2");
      chdir('/tmp/install/usr/local') or die "Could not chdir(/tmp/install/usr/local): $!\n";
      `echo '======== PACKAGE: DEPS ========' >>'${logfile}'`;
      `${Bin}/macos-copy-deps.pl >>'${logfile}' 2>&1`;
      `echo '======== PACKAGE: TAR ========' >>'${logfile}'`;
      chdir('/tmp/install/usr') or die "Could not chdir(/tmp/install/usr): $!\n";
      rename('local', $pkname);
      $log = `tar -jcvf '/tmp/${pkname}.tar.bz2' * >>'${logfile}' 2>&1 || echo 'PACKAGE FAILED'`;
      if ($log =~ /PACKAGE FAILED/) {
         print "\tfailed packaging\n";
         next;
      }

      my $deps = file_get_contents("${Bin}/@$pkg[0]/debian/control");
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
      `mv -v '/tmp/${pkname}.tar.bz2' '${pkpath}/${pkname}-latest.tar.bz2' >>'${logfile}' 2>&1`;
      `ln -sv '${pkname}-latest.tar.bz2' '${pkpath}/${ver}.tar.bz2' >>'${logfile}' 2>&1`;
      `cp -a '${logfile}' '${pkpath}/${pkname}.log'`;

      $did = 1;
   }

   if (!$did) {
      next;
   }

   print "Combining ${cadence}...\n";
   `rm -rf /tmp/combo`;
   `mkdir -p /tmp/combo/apertium-all-dev`;
   chdir('/tmp/combo') or die "Could not chdir(/tmp/combo): $!\n";
   for my $pkname (@combo) {
      if (! -s "${Bin}/${cadence}/build/${pkname}/${pkname}-latest.tar.bz2") {
         next;
      }
      print "\t${pkname}\n";
      `tar -jxvf '${Bin}/${cadence}/build/${pkname}/${pkname}-latest.tar.bz2' >>apertium-all-dev.log 2>&1`;
      `cp -a '${pkname}/'* ./apertium-all-dev/`;
      `rm -rf '${pkname}'`;
   }
   `tar -jcvf apertium-all-dev.tar.bz2 apertium-all-dev >>apertium-all-dev.log 2>&1`;
   `7za a apertium-all-dev.7z apertium-all-dev >>apertium-all-dev.log 2>&1`;
   `mv apertium-all-dev.tar.bz2 apertium-all-dev.7z apertium-all-dev.log '${Bin}/${cadence}/build/apertium-all-dev/'`;

   print "Uploading ${cadence}...\n";
   chdir("${Bin}/${cadence}/build") or die "Could not chdir(${Bin}/${cadence}/build): $!\n";
   unlink('upload.log');
   for (my $i=0 ; $i<3 ; ++$i) {
      `rsync -avz */*.tar.bz2 */*.7z apertium\@oqaa.projectjj.com:public_html/osx/${cadence}/ >>upload.log 2>&1`;
   }
   `ssh -l apertium oqaa.projectjj.com "find '/home/apertium/public_html/osx/${cadence}' -name '*-[0-9]*' | xargs -rn1 rm -fv" >>upload.log 2>&1`;
   `rsync -avzc */*.tar.bz2 */*.7z apertium\@oqaa.projectjj.com:public_html/osx/${cadence}/ >>upload.log 2>&1`;

   print "\n";
}

unlink('/tmp/rebuild.lock');
