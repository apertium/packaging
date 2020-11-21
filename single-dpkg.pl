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

if (-s '/opt/autopkg/rebuild.lock') {
   die "Another instance of builder is running - bailing out!\n";
}
if (!$ARGV[0]) {
   die "Must provide a package path!\n";
}

use Getopt::Long;
my %opts = (
	'm' => 'Tino Didriksen <tino@didriksen.cc>',
	'e' => 'Tino Didriksen <tino@didriksen.cc>',
	'dv' => 1,
	'fv' => 1,
	'rev' => 'HEAD',
	'auto' => 1,
	'rpm' => 0,
);
GetOptions(
	'm=s' => \$opts{'m'},
	'e=s' => \$opts{'e'},
	'distv=i' => \$opts{'dv'},
	'flavv=i' => \$opts{'fv'},
	'rev=s' => \$opts{'rev'},
	'auto=i' => \$opts{'auto'},
	'rpm' => \$opts{'rpm'},
);

chdir($Bin);

my %pkgs = load_packages();

if ($ARGV[0]) {
   $ARGV[0] =~ s@/$@@g;
}

$ENV{'AUTOPKG_BUILDTYPE'} = ($opts{'auto'} == 0) ? 'release' : 'nightly';
$ENV{'AUTOPKG_MAINTAINER'} = $opts{'m'};

foreach my $k (@{$pkgs{'order'}}) {
   my $pkg = $pkgs{'packages'}->{$k};
   if ($ARGV[0] ne $pkg->[0]) {
      next;
   }

   if (!$pkg->[1]) {
      my ($path) = ($pkg->[0] =~ m@/([^/]+)$@);
      $pkg->[1] = 'https://github.com/apertium/'.$path;
   }
   if (!$pkg->[2]) {
      $pkg->[2] = 'configure.ac';
   }
   my ($pkname) = ($pkg->[0] =~ m@([^/]+)$@);

   $ENV{'AUTOPKG_PKPATH'} = "$Bin/".$pkg->[0];
   $ENV{'AUTOPKG_AUTOPATH'} = "/opt/autopkg/$ENV{AUTOPKG_BUILDTYPE}/$pkname";
   $ENV{'AUTOPKG_LOGPATH'} = $ENV{'AUTOPKG_AUTOPATH'};

   print "Making deb source for $pkname $pkg->[0]\n";
   my $gv = `$Bin/get-version.pl --rev=$opts{rev} --url '$pkg->[1]' --file '$pkg->[2]' --pkname '$pkname'`;
   chomp($gv);
   print "$gv\n";
   my ($rawrev,$version,$srcdate) = split(/\t/, $gv);
   my $cli = "--rev=$opts{rev} --auto $opts{auto} -p '$pkg->[0]' -u '$pkg->[1]' -v '$version' -d '$srcdate' -m '$opts{m}' -e '$opts{e}'";
   print "$cli\n";
   print `$Bin/make-deb-source.pl $cli 2>&1`;
   if ($opts{'rpm'}) {
      print `$Bin/make-rpm-source.pl $cli 2>&1`;
   }
}
