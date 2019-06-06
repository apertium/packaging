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

use FindBin qw($Bin);
use lib "$Bin/";
use Helpers;

use Getopt::Long;
my %opts = (
   'u' => 'https://github.com/apertium/apertium',
   'p' => 'trunk/apertium',
   'v' => '0.0.0.0',
   'd' => '0001-01-01 00:00:00 +0000',
	'm' => 'Tino Didriksen <tino@didriksen.cc>',
	'e' => 'Tino Didriksen <tino@didriksen.cc>',
	'dv' => 1,
	'fv' => 1,
	'rev' => 'HEAD',
	'auto' => 1,
	'nobuild' => '',
);
GetOptions(
	'u=s' => \$opts{'u'},
	'p=s' => \$opts{'p'},
	'v=s' => \$opts{'v'},
	'd=s' => \$opts{'d'},
	'm=s' => \$opts{'m'},
	'e=s' => \$opts{'e'},
	'distv=i' => \$opts{'dv'},
	'flavv=i' => \$opts{'fv'},
	'rev=s' => \$opts{'rev'},
	'auto=i' => \$opts{'auto'},
	'nobuild=s' => \$opts{'nobuild'},
);

chdir($Bin);

use JSON;
my %pkgs = load_packages();
my $targets = JSON->new->relaxed->decode(file_get_contents("$Bin/targets.json"));
my $distros = $targets->{'distros'};
my $archs = $targets->{'archs'};

my @includes = ();
my @excludes = ();
if (-s $opts{p}.'/exclude.txt') {
   open FILE, $opts{p}.'/exclude.txt';
   while (<FILE>) {
      chomp;
      if (/^\s*$/) {
         next;
      }
      if (m@^\+ (.+)$@) {
         push(@includes, $1);
      }
      elsif (m@^\- (.+)$@) {
         push(@excludes, $1);
      }
      else {
         s@\*@.*@g;
         s@\?@.@g;
         push(@excludes, "$_.*");
      }
   }
   close FILE;
}

my ($pkname) = ($opts{p} =~ m@([-\w]+)$@);
my $date = `date -u -R`; # Not chomped, but that's ok since it's used last on a line

my $autopath = $ENV{AUTOPATH};
print `rm -rf '$autopath' 2>&1`;
print `mkdir -pv '$autopath' 2>&1`;
chdir $autopath;

if ($opts{'u'} =~ m@^https://github.com/[^/]+/([^/]+)$@) {
   my $pkg = $1;
   chdir("/misc/git/${pkg}.git");
   print `git submodule update --init --depth 1 --recursive || git submodule update --init --depth 100 --recursive`;
   print `find . -name '.git*' -print0 | xargs -0rn1 rm -rfv 2>&1`;
   chdir('..');
   print `cp -av --reflink=auto '${pkg}.git' '$autopath/$pkname-$opts{v}'`;
   chdir $autopath;
}
else {
   print `cp -av --reflink=auto /opt/autopkg/repos/$pkname.svn-$ENV{BUILDTYPE} '$pkname-$opts{v}'`;
   print `find . -name '.svn*' -print0 | xargs -0rn1 rm -rfv 2>&1`;
   print `find . -name '.git*' -print0 | xargs -0rn1 rm -rfv 2>&1`;
}
if (@excludes) {
   chdir "$pkname-$opts{v}";
   my @files = split(/\n/, `find . ! -type d`);
   foreach my $f (@files) {
      $f =~ s@^\./@@;
      my $keep = 0;
      foreach my $p (@includes) {
         if ($f =~ m@^$p$@) {
            print "keeping '$f'\n";
            $keep = 1;
            last;
         }
      }
      if ($keep) {
         next;
      }
      foreach my $p (@excludes) {
         if ($f =~ m@^$p$@) {
            print `rm -rfv '$f'`;
         }
      }
   }
   while (my $o = `find . -type d -empty -print0 | LC_ALL=C sort -zr | xargs -0rn1 rm -rfv 2>&1`) {
      print $o;
   }
   chdir "..";
}

# OS tools should only try to use OS binaries
`grep -rl '^\#!/usr/bin/env perl' | xargs -rn1 perl -pe 's\@^\#!/usr/bin/env perl\@\#!/usr/bin/perl\@g;' -i`;
`grep -rl '^\#!/usr/bin/env python' | xargs -rn1 perl -pe 's\@^\#!/usr/bin/env python\@\#!/usr/bin/python\@g;' -i`;
`grep -rl '^\#!/usr/bin/env bash' | xargs -rn1 perl -pe 's\@^\#!/usr/bin/env bash\@\#!/bin/bash\@g;' -i`;

# If this is a release, bundle language resources to avoid drift
my %cnfs = ( 'control' => '', 'rules' => '' );
if ($ENV{'BUILDTYPE'} eq 'release' && -s "$pkname-$opts{v}/configure.ac") {
   $cnfs{'rules'} = file_get_contents("$ENV{PKPATH}/debian/rules");
   if ($cnfs{'rules'} =~ m@dh_auto_configure|dh_auto_build@) {
      die "Has dh_auto_configure/dh_auto_build - can't bundle!\n";
   }

   $cnfs{'rules'} =~ s@(\n\%:)@\nNUMJOBS = 1\nifneq (,\$(filter parallel=\%,\$(DEB_BUILD_OPTIONS)))\n\tNUMJOBS = \$(patsubst parallel=\%,\%,\$(filter parallel=\%,\$(DEB_BUILD_OPTIONS)))\nendif\n$1@gs;
   $cnfs{'control'} = read_control("$ENV{PKPATH}/debian/control");
   my ($bdeps) = ($cnfs{'control'} =~ m@(Build-Depends:\s*[^\n]+)@);
   my $config = file_get_contents("$pkname-$opts{v}/configure.ac");
   my @ss = ('override_dh_auto_configure:', 'override_dh_auto_build:');
   my $withlang = '';

   for my $dep ($config =~ m@AP_CHECK_LING\((.+?)\)@g) {
      my ($n,$p,$v) = ($dep =~ m@\[(.+?)\], \[(.+?)\](?:, \[(.+?)\])@);
      if ($p !~ m@^apertium@) {
         # Skip bundling giella languages for now, as they need recursive bundling of giella-core and -common
         next;
      }
      if ($bdeps =~ m@\Q$p\E \(.*?([\d.]+)\)@) {
         `dpkg --compare-versions '$v' gt '$1'`;
         if ($?) {
            $v = $1;
         }
      }
      $bdeps =~ s@\s+\Q$p\E[^,\n]+,?@ @g;

      my $pkg = $pkgs{'packages'}->{$p};
      if (!$pkg->[1]) {
         my ($path) = ($pkg->[0] =~ m@/([^/]+)$@);
         $pkg->[1] = 'https://github.com/apertium/'.$path;
      }
      if (!$pkg->[2]) {
         $pkg->[2] = 'configure.ac';
      }
      my $gv = `$Bin/get-version.pl --url '$pkg->[1]' --file '$pkg->[2]' --pkname '$p' --rev v$v`;
      chomp($gv);
      my ($newrev,$version,$srcdate) = split(/\t/, $gv);
      if (!$newrev) {
         die "Missing revision: $newrev\n";
      }
      print "Bundling $n $p $v $newrev $version $srcdate\n";

      my $cli = "--nobuild '$opts{nobuild}' -p '$pkg->[0]' -u '$pkg->[1]' -v '$version' --distv '0' -d '$srcdate' --rev $newrev -m 'Apertium Automaton <apertium-packaging\@lists.sourceforge.net>' -e 'Apertium Automaton <apertium-packaging\@lists.sourceforge.net>'";
      `export 'PKPATH=$Bin/$pkg->[0]' 'AUTOPATH=/opt/autopkg/$ENV{BUILDTYPE}/$p' && $Bin/make-deb-source.pl $cli >&2`;

      $ss[0] .= "\n\tcd \$(CURDIR)/$p-$version && autoreconf -fi && ./configure";
      if ($p =~ m@^giella-@) {
         $ss[0] .= " --with-hfst --without-xfst --enable-alignment --enable-reversed-intersect --enable-apertium --with-backend-format=foma --disable-analysers --disable-generators";
      }
      $ss[1] .= "\n\tcd \$(CURDIR)/$p-$version && \$(MAKE) -j\$(NUMJOBS)";
      $withlang .= " --with-lang$n=\$(CURDIR)/$p-$version";

      print `cp -av --reflink=auto /opt/autopkg/$ENV{BUILDTYPE}/$p/$p-$version '$pkname-$opts{v}/'`;
      my ($bds) = (read_control("$pkname-$opts{v}/$p-$version/debian/control") =~ m@Build-Depends:\s*([^\n]+)@);
      $bdeps .= ", $bds";
      `rm -rfv '$pkname-$opts{v}/$p-$version/debian'`;
   }

   $cnfs{'control'} =~ s@Build-Depends:\s*[^\n]+@$bdeps@;
   $ss[0] .= "\n\tdh_auto_configure --$withlang";
   $ss[1] .= "\n\tdh_auto_build";

   $cnfs{'rules'} .= "\n".join("\n\n", @ss)."\n";
}

# RPM tar.bz2
my $rv = $opts{v};
$rv =~ s@[+~]@.@g;
if ($rv ne $opts{v}) {
   `cp -a --reflink=auto '$pkname-$opts{v}' '$pkname-$rv'`;
}
`find '$pkname-$rv' ! -type d | LC_ALL=C sort > orig.lst`;
`find '$pkname-$rv' -type d -empty | LC_ALL=C sort >> orig.lst`;
print `tar --no-acls --no-xattrs '--mtime=$opts{d}' -cf '${pkname}_$rv.orig.tar' -T orig.lst`;
`bzip2 -9c '${pkname}_$rv.orig.tar' > '${pkname}_$rv.orig.tar.bz2'`;
if ($rv ne $opts{v}) {
   `rm -rf '$pkname-$rv'`;
}

# Debian tar.bz2
`find '$pkname-$opts{v}' ! -type d | LC_ALL=C sort > orig.lst`;
`find '$pkname-$opts{v}' -type d -empty | LC_ALL=C sort >> orig.lst`;
print `tar --no-acls --no-xattrs '--mtime=$opts{d}' -cf '${pkname}_$opts{v}.orig.tar' -T orig.lst`;
`bzip2 -9c '${pkname}_$opts{v}.orig.tar' > '${pkname}_$opts{v}.orig.tar.bz2'`;
print `cp -av --reflink=auto '$ENV{PKPATH}/debian' '$pkname-$opts{v}/'`;
if ($cnfs{'control'}) {
   file_put_contents("$pkname-$opts{v}/debian/control", $cnfs{'control'});
}
if ($cnfs{'rules'}) {
   file_put_contents("$pkname-$opts{v}/debian/rules", $cnfs{'rules'});
}

if (!$opts{auto}) {
   print `grep -l ldconfig '$pkname-$opts{v}'/debian/*.post* -print0 | xargs -0rn1 rm -fv`;
}

# dpkg tools are not happy if PERL_UNICODE is on
$ENV{'PERL_UNICODE'} = '';

foreach my $distro (keys(%$distros)) {
   if (!$opts{auto}) {
      $distro = 'sid';
   }
   if ($opts{'nobuild'} =~ m@,$distro,@) {
      next;
   }

	my $chver = $opts{v}.'-';
   if ($opts{auto}) {
      $chver .= $opts{'dv'}."~".$distro.$opts{'fv'};
      my $chlog = <<CHLOG;
$pkname ($chver) $distro; urgency=low

  * Automatic build - see changelog via: svn log $opts{u}/

 -- $opts{e}  $date
CHLOG

      `cp -a --reflink=auto '$pkname-$opts{v}' '$pkname-$chver'`;
      file_put_contents("$pkname-$chver/debian/changelog", $chlog);
   }
   else {
      $chver .= $opts{'dv'};
      `cp -a --reflink=auto '$pkname-$opts{v}' '$pkname-$chver'`;
   }

   if ($distros->{$distro}{'dh'} >= 10) {
      file_put_contents("$pkname-$chver/debian/compat", $distros->{$distro}{'dh'});

      my $control = file_get_contents("$pkname-$chver/debian/control");
      $control =~ s@debhelper \([^)]+\)@debhelper (>= $distros->{$distro}{'dh'})@g;
      $control =~ s@[ \t]*dh-autoreconf,?\n@@g;
      $control =~ s@[ \t]*autotools-dev,?\n@@g;
      file_put_contents("$pkname-$chver/debian/control", $control);

      my $rules = file_get_contents("$pkname-$chver/debian/rules");
      $rules =~ s@(\tdh.*) --parallel@$1@g;
      if ($distros->{$distro}{'dh'} >= 12) {
         $rules =~ s@(\tdh.*) --fail-missing@$1@g;
         $rules .= "\noverride_dh_missing:\n\tdh_missing --fail-missing\n";
      }
      file_put_contents("$pkname-$chver/debian/rules", $rules);
   }

	chdir "$pkname-$chver";
	run_fail('wrap-and-sort');
	chdir '..';
	print run_fail("dpkg-source '-DMaintainer=$opts{m}' '-DUploaders=$opts{e}' -b '$pkname-$chver'");
	chdir "$pkname-$chver";
	print run_fail("dpkg-genchanges -S -sa '-m$opts{m}' '-e$opts{e}' > '../${pkname}_${chver}_source.changes'");
	chdir '..';
	print run_fail("debsign '${pkname}_${chver}_source.changes'");

   if (!$opts{auto}) {
      last;
   }

   foreach my $arch (@{$distros->{$distro}{'archs'}}) {
      `mkdir -pv $arch/$distro`;
      `cp -a --reflink=auto '${pkname}_$opts{v}.orig.tar.bz2' *$chver* $arch/$distro/`;
   }
}

`chown -R 1234:1234 '$autopath'`;
