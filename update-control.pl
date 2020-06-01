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

if (!$ARGV[0]) {
   die "Must provide a package path!\n";
}
$ARGV[0] =~ s@/$@@g;

chdir($Bin);
if (!(-x 'get-version.pl')) {
   die "get-version.pl not found in $Bin!\n";
}

my ($pkg) = ($ARGV[0] =~ m@^(.+?)/?$@); # Trim final /, if any
if (!(-e $pkg)) {
   die "$pkg doesn't exist!\n";
}
my ($pkname) = ($pkg =~ m@([-\w]+)$@);

if ($pkname =~ m@^apertium-([a-z]{2,3})$@ || $pkname =~ m@^apertium-([a-z]{2,3})-([a-z]{2,3})$@) {
   `find $pkg -type f -exec sed -r -i 's/apertium-[a-z]{2,3}(-[a-z]{2,3})?/$pkname/g' '{}' \\;`;
   `find $pkg -type f -exec sed -i 's/$pkname\@dlsi.ua.es/apertium-pmc\@dlsi.ua.es/g' '{}' \\;`;
   if ($ARGV[1]) {
      `find $pkg -type f -exec replace 'LANG1' '$ARGV[1]' -- '{}' \\;`;
   }
   if ($ARGV[2]) {
      `find $pkg -type f -exec replace 'LANG2' '$ARGV[2]' -- '{}' \\;`;
   }
}

my $url = 'https://github.com/apertium/'.$pkname;
my $deps = `svn cat $url/trunk/configure.ac | $Bin/depends.pl`;
chomp($deps);
my @deps = split(/\n/, $deps);

my $control = file_get_contents("$pkg/debian/control");

my @depends = ($control =~ m@D?epends:(\s*.*?)\n\S@gs);
@depends = sort { length($b) <=> length($a) } @depends;
foreach my $depend (@depends) {
   my $copy = $depend;
   $copy =~ s@^\s+@@sg;
   $copy =~ s@\s+$@@sg;
   $copy =~ s@,\s+@,@sg;
   $control =~ s@\Q$depend\E(\n\S)@ $copy$1@g;
   #print "$depend -> $copy\n";
}

$control =~ s@^Build-Depends:[^\n]+@$deps[0]@mg;
$control =~ s@^Depends:[^\n]+@$deps[1]@mg;
if ($pkname =~ m@-([a-z]{2,3})-([a-z]{2,3})$@) {
   my ($a,$b) = ($1,$2);
   if ($control =~ m@(\nDepends:[^\n]+\n)Provides:[^\n]+\nConflicts:[^\n]+\n@) {
      $control =~ s@(\nDepends:[^\n]+\n)Provides:[^\n]+\nConflicts:[^\n]+\n@$1Provides: apertium-$b-$a\nConflicts: apertium-$b-$a\n@g;
   }
   else {
      $control =~ s@(\nDepends:[^\n]+\n)@$1Provides: apertium-$b-$a\nConflicts: apertium-$b-$a\n@g;
   }
}

file_put_contents("$pkg/debian/control", $control);

my $gv = `$Bin/get-version.pl --url '$url' --pkname '$pkname'`;
($gv) = ($gv =~ m@^[^\t]+\t([^\t]+)@);
$gv .= '-1';
replace_in_file("$pkg/debian/changelog", "^$pkname.*urgency=low", "$pkname ($gv) experimental; urgency=low");

chdir $pkg;
`wrap-and-sort`;
