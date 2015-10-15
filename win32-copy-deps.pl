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

my @locs = (
   "/opt/mxe/usr/i686-w64-mingw32.shared/bin",
   "/opt/mxe/usr/i686-w64-mingw32.shared/qt5/bin",
   "/opt/icudata",
   );

my $did = 1;
for (my $i=1 ; $i<1000 && $did ; $i++) {
   $did = 0;

   print "Round $i\n";

   my @deps = split("\n", `strings *.exe *.dll | grep '\\.dll\$' | sort | uniq`);
   foreach my $d (@deps) {
      if (-s $d) {
         next;
      }

      my $s = 0;
      foreach my $loc (@locs) {
         if (-s "$loc/$d") {
            `rsync -avu -L '$loc/$d' './$d'`;
            $did = 1;
            $s = 1;
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
