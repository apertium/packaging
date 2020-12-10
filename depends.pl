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

my %build = ();
my %deps = ();

while (<>) {
   if (/^\s*#/) {
      next;
   }
   if (/\bPKG_CHECK_MODULES.*?hfst\b/) {
      $build{'libhfst-dev'} = 1;
      $build{'hfst'} = 1;
      $deps{'hfst'} = 1;
   }
   elsif (/\bhfstospell\b/ || /\bhfst-ospell\b/) {
      $build{'hfst-ospell-dev'} = 1;
   }
   elsif (/\bhfst\b/) {
      $build{'hfst'} = 1;
      $deps{'hfst'} = 1;
   }
   elsif (/\blibxml-2.0\b/) {
      $build{'libxml2-dev'} = 1;
      $build{'libxml2-utils'} = 1;
   }
   elsif (/\bLIBS\b.*?\blz\b/) {
      $build{'zlib1g-dev'} = 1;
   }
   elsif (/\bcg-comp\b/ || /\bcg-proc\b/ || /\bcg-conv\b/ || /\bvislcg3\b/ || /\bcg3\b/ || /\bcg3-autobin\b/) {
      $build{'cg3-dev'} = 1;
      $deps{'cg3'} = 1;
   }
   elsif (/\blrx-comp\b/ || /\blrx-proc\b/ || /\bapertium-lex-tools\b/) {
      $build{'apertium-lex-tools'} = 1;
      $deps{'apertium-lex-tools'} = 1;
   }
   elsif (/\blsx-comp\b/ || /\blsx-proc\b/ || /\bapertium-separable\b/) {
      $build{'apertium-separable'} = 1;
      $deps{'apertium-separable'} = 1;
   }
   elsif (/\bapertium-anaphora\b/) {
      $build{'apertium-anaphora'} = 1;
      $deps{'apertium-anaphora'} = 1;
   }
   elsif (/\bapertium-recursive\b/) {
      $build{'apertium-recursive'} = 1;
      $deps{'apertium-recursive'} = 1;
   }
   elsif (/\bAP_CHECK_LING.*?(apertium-\w+)/ || /\bAP_CHECK_LING.*?(giella-\w+)/) {
      $build{$1} = 1;
   }
}

print "Build-Depends: debhelper (>= 12), apertium-dev (>= 3.7.0), gawk, pkg-config";
foreach my $k (sort(keys(%build))) {
   print ", $k";
}
print "\n";

print "Depends: apertium (>= 3.6.0)";
foreach my $k (sort(keys(%deps))) {
   print ", $k";
}
print ", \${shlibs:Depends}, \${misc:Depends}\n";
