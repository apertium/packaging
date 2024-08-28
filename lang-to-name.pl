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

use FindBin qw($Bin);
use lib "$Bin/";
use Helpers;

my %ns = ();
my $names = file_get_contents('scraped-sil.tsv');
for my $l (split(/\n/, $names)) {
   my @ls = split(/\t/, $l);
   $ns{$ls[0]} = $ls[1];
}

my $isob = file_get_contents('isobork');
for my $l (split(/\n/, $isob)) {
   my @ls = split(/\s+/, $l);
   if (exists $ns{$ls[1]}) {
      $ns{$ls[0]} = $ns{$ls[1]};
   }
}

while (<STDIN>) {
   chomp;
   if (m@(?:apertium|giella)-(\w+)-(\w+)@) {
      my ($iso1,$iso2) = ($1,$2);
      if (!exists $ns{$iso1}) {
         print "NOT FOUND: 1 $_ $iso1\n";
         next;
      }
      if (!exists $ns{$iso2}) {
         print "NOT FOUND: 2 $_ $iso2\n";
         next;
      }
      print `perl -Mutf8 -pe 's/LANG1/$ns{$iso1}/g' -i $_`;
      print `perl -Mutf8 -pe 's/LANG2/$ns{$iso2}/g' -i $_`;
   }
   elsif (m@(?:apertium|giella)-(\w+)@) {
      my ($iso1) = ($1);
      if (!exists $ns{$iso1}) {
         print "NOT FOUND: 1 $_ $iso1\n";
         next;
      }
      print `perl -Mutf8 -pe 's/LANG1/$ns{$iso1}/g' -i $_`;
   }
}
