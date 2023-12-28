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

my $bitwidth = $ENV{'AUTOPKG_BITWIDTH'} || 'i686';

my @locs = (
   "/opt/win-$bitwidth/bin",
   "/opt/mxe/usr/$bitwidth-w64-mingw32.shared/bin",
   "/opt/mxe/usr/$bitwidth-w64-mingw32.shared/qt5/bin",
   );

my $did = 1;
for (my $i=1 ; $i<1000 && $did ; $i++) {
   $did = 0;

   print STDERR "Round $i\n";

   my @deps = split("\n", `strings *.exe *.dll | tr ' ' '\\n' | grep '\\.dll\$' | sort | uniq`);
   foreach my $d (@deps) {
      $d =~ s@^.*?([-_+.\w\d]+\.dll)$@$1@i;
      my @ds = ($d, lc($d), uc($d));
      if (-s $ds[0] || -s $ds[1] || -s $ds[2]) {
         next;
      }

      my $s = 0;
      foreach my $loc (@locs) {
         foreach my $d (@ds) {
            if (-s "$loc/$d") {
               `rsync -avu -L '$loc/$d' './$d'`;
               $did = 1;
               $s = 1;
            }
         }
      }

      if ($s) {
         print STDERR "\tcopied dependency '$d'\n";
      }
      else {
         print STDERR "\tskipped $d\n";
      }
   }
}
