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

use JSON;
my $targets = JSON->new->relaxed->decode(file_get_contents('targets.json'));
my $distros = $targets->{'distros'};
my $archs = $targets->{'archs'};

my @includes = ();
my @excludes = ();
if (-s $opts{p}.'/exclude.txt') {
   open FILE, $opts{p}.'/exclude.txt' or die "Could not open exclude.txt: $!\n";
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
chdir $autopath or die "Could not change folder: $!\n";

if ($opts{'u'} =~ m@^https://github.com/[^/]+/([^/]+)$@) {
   my $pkg = $1;
   chdir("/misc/git/${pkg}.git") or die $!;
   print `git submodule update --init --depth 1 --recursive || git submodule update --init --depth 100 --recursive`;
   print `find . -name '.git*' -print0 | xargs -0rn1 rm -rfv 2>&1`;
   chdir('..');
   print `cp -av --reflink=auto '${pkg}.git' '$autopath/$pkname-$opts{v}'`;
   chdir $autopath or die "Could not change folder: $!\n";
}
else {
   print `cp -av --reflink=auto /opt/autopkg/repos/$pkname.svn-$ENV{BUILDTYPE} '$pkname-$opts{v}'`;
   print `find . -name '.svn*' -print0 | xargs -0rn1 rm -rfv 2>&1`;
   print `find . -name '.git*' -print0 | xargs -0rn1 rm -rfv 2>&1`;
}
if (@excludes) {
   chdir "$pkname-$opts{v}" or die "Could not change folder: $!\n";
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
   chdir ".." or die "Could not change folder: $!\n";
}

# OS tools should only try to use OS binaries
`grep -rl '^\#!/usr/bin/env perl' | xargs -rn1 perl -pe 's\@^\#!/usr/bin/env perl\@\#!/usr/bin/perl\@g;' -i`;
`grep -rl '^\#!/usr/bin/env python' | xargs -rn1 perl -pe 's\@^\#!/usr/bin/env python\@\#!/usr/bin/python\@g;' -i`;
`grep -rl '^\#!/usr/bin/env bash' | xargs -rn1 perl -pe 's\@^\#!/usr/bin/env bash\@\#!/bin/bash\@g;' -i`;

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
#print `svn export $opts{r}/debian/ '$pkname-$opts{v}/debian/'`;

if (!$opts{auto}) {
   print `grep -l ldconfig '$pkname-$opts{v}'/debian/*.post* -print0 | xargs -0rn1 rm -fv`;
}

# dpkg tools are not happy if PERL_UNICODE is on
$ENV{'PERL_UNICODE'} = '';

foreach my $distro (keys %$distros) {
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
      open FILE, ">$pkname-$chver/debian/changelog" or die "Could not write to debian/changelog: $!\n";
      print FILE $chlog;
      close FILE;
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
      file_put_contents("$pkname-$chver/debian/rules", $rules);
   }

	print `dpkg-source '-DMaintainer=$opts{m}' '-DUploaders=$opts{e}' -b '$pkname-$chver'`;
	chdir "$pkname-$chver";
	`wrap-and-sort`;
	print `dpkg-genchanges -S -sa '-m$opts{m}' '-e$opts{e}' > '../${pkname}_${chver}_source.changes'`;
	chdir '..';
	print `debsign '${pkname}_${chver}_source.changes'`;

   if (!$opts{auto}) {
      last;
   }

   foreach my $arch (@$archs) {
      `mkdir -pv $arch/$distro`;
      `cp -a --reflink=auto '${pkname}_$opts{v}.orig.tar.bz2' *$chver* $arch/$distro/`;
   }
}

`chown -R 1234:1234 '$autopath'`;
