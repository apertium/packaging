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
if (!$ARGV[0]) {
   die "Must provide a package path!\n";
}

use Getopt::Long;
my %opts = (
	'm' => 'Tino Didriksen <tino@didriksen.cc>',
	'e' => 'Tino Didriksen <tino@didriksen.cc>',
	'dv' => 1,
	'fv' => 1,
	'rev' => '',
	'auto' => 1,
	'rpm' => 0,
);
GetOptions(
	'm=s' => \$opts{'m'},
	'e=s' => \$opts{'e'},
	'distv=i' => \$opts{'dv'},
	'flavv=i' => \$opts{'fv'},
	'rev=i' => \$opts{'rev'},
	'auto=i' => \$opts{'auto'},
	'rpm' => \$opts{'rpm'},
);

if ($opts{rev} && $opts{rev} > 0) {
   $opts{rev} = '--rev '.$opts{rev};
}
else {
   $opts{rev} = '';
}

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

if ($ARGV[0]) {
   $ARGV[0] =~ s@/$@@g;
}

foreach my $pkg (@$pkgs) {
   if ($ARGV[0] ne @$pkg[0]) {
      next;
   }

   if (!@$pkg[1]) {
      @$pkg[1] = 'http://svn.code.sf.net/p/apertium/svn/'.@$pkg[0];
   }
   if (!@$pkg[2]) {
      @$pkg[2] = 'configure.ac';
   }

   print "Making deb source for @$pkg[0]\n";
   my $gv = `./get-version.pl $opts{rev} --url '@$pkg[1]' --file '@$pkg[2]' 2>/dev/null`;
   chomp($gv);
   print "$gv\n";
   my ($version,$srcdate) = split(/\t/, $gv);
   my $cli = "$opts{rev} --auto $opts{auto} -p '@$pkg[0]' -u '@$pkg[1]' -v '$version' -d '$srcdate' -m '$opts{m}' -e '$opts{e}'";
   if (@$pkg[3]) {
      $cli .= " -r '@$pkg[3]'";
   }
   print "$cli\n";
   print `./make-deb-source.pl $cli 2>&1`;
   if ($opts{'rpm'}) {
      print `./make-rpm-source.pl $cli 2>&1`;
   }
}
