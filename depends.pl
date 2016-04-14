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

my %build = ();
my %deps = ();

while (<>) {
   if (/^\s*#/) {
      next;
   }
   if (/\bPKG_CHECK_MODULES.*?hfst\b/) {
      $build{'libhfst45-dev'} = 1;
      $build{'hfst'} = 1;
      $deps{'hfst'} = 1;
   }
   elsif (/\bhfst\b/) {
      $build{'hfst'} = 1;
      $deps{'hfst'} = 1;
   }
   elsif (/\bPKG_CHECK_MODULES.*?libxml-2.0\b/) {
      $build{'libxml2-dev'} = 1;
      $build{'libxml2-utils'} = 1;
   }
   elsif (/\bLIBS\b.*?\blz\b/) {
      $build{'zlib1g-dev'} = 1;
   }
   elsif (/\bAC_PROG_AWK\b/) {
      $build{'gawk'} = 1;
   }
   elsif (/\bcg-comp\b/ || /\bcg-proc\b/ || /\bcg-conv\b/ || /\bvislc3g\b/ || /\bcg3-autobin\b/) {
      $build{'cg3'} = 1;
      $deps{'cg3'} = 1;
   }
   elsif (/\blrx-comp\b/ || /\blrx-proc\b/) {
      $build{'apertium-lex-tools'} = 1;
      $deps{'apertium-lex-tools'} = 1;
   }
   elsif (/\bAP_CHECK_LING.*?(apertium-\w+)/ || /\bAP_CHECK_LING.*?(giella-\w+)/) {
      $build{$1} = 1;
   }
}

print "Build-Depends: debhelper (>= 9), dh-autoreconf, autotools-dev, apertium-dev (>= 3.4), pkg-config (>= 0.21)";
foreach my $k (sort(keys(%build))) {
   print ", $k";
}
print "\n";

print "Depends: apertium (>= 3.4)";
foreach my $k (sort(keys(%deps))) {
   print ", $k";
}
print ", \${shlibs:Depends}, \${misc:Depends}\n";
