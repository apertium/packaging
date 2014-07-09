#!/usr/bin/env perl
# -*- mode: cperl; indent-tabs-mode: nil; tab-width: 3; cperl-indent-level: 3; -*-
use utf8;
use strict;
use warnings;
BEGIN {
	$| = 1;
	binmode(STDIN, ':encoding(UTF-8)');
	binmode(STDOUT, ':encoding(UTF-8)');
}
use open qw( :encoding(UTF-8) :std );

use File::Basename;
my $dir = dirname(__FILE__);
chdir($dir) or die $!;
if (!(-x 'get-version.pl')) {
   die "get-version.pl not found in $dir!\n";
}

my @pkgs = (
   # Dependencies first
   ['external/cg3',             'http://visl.sdu.dk/svn/visl/tools/vislcg3/trunk',                'src/version.hpp'],
   ['external/cg3ide',          'http://visl.sdu.dk/svn/visl/tools/cg3ide',                       'src/version.hpp'],
   ['external/foma',            'http://foma.googlecode.com/svn/trunk/foma',                      'Makefile'],
   ['external/hfst',            'http://svn.code.sf.net/p/hfst/code/trunk/hfst3',                 'configure.ac'],
   ['external/trie-tools',      'http://visl.sdu.dk/svn/visl/tools/trie-tools',                   'include/tdc_trie.hpp'],
   ['trunk/lttoolbox',          'http://svn.code.sf.net/p/apertium/svn/trunk/lttoolbox',          'configure.ac'],
   ['trunk/apertium',           'http://svn.code.sf.net/p/apertium/svn/trunk/apertium',           'configure.ac'],
   ['trunk/apertium-lex-tools', 'http://svn.code.sf.net/p/apertium/svn/trunk/apertium-lex-tools', 'configure.ac'],
   # Then languages
   ['languages/apertium-kaz',   'http://svn.code.sf.net/p/apertium/svn/languages/apertium-kaz',   'configure.ac'],
   ['languages/apertium-tat',   'http://svn.code.sf.net/p/apertium/svn/languages/apertium-tat',   'configure.ac'],
   # Finally, language pairs
   ['trunk/apertium-br-fr',     'http://svn.code.sf.net/p/apertium/svn/trunk/apertium-br-fr',     'configure.ac'],
   ['trunk/apertium-eo-en',     'http://svn.code.sf.net/p/apertium/svn/trunk/apertium-eo-en',     'configure.ac'],
   ['trunk/apertium-kaz-tat',   'http://svn.code.sf.net/p/apertium/svn/trunk/apertium-kaz-tat',   'configure.ac'],
   );

foreach my $pkg (@pkgs) {
   chdir($dir) or die $!;

   # If a package path is given, only rebuild that package, but force a rebuild of it
   if ($ARGV[0] && $ARGV[0] ne @$pkg[0]) {
      next;
   }

   print "@$pkg[0]: ";
   my $gv = `./get-version.pl --url @$pkg[1] --file @$pkg[2] 2>/dev/null`;
   chomp($gv);
   my ($version,$srcdate) = split(/\t/, $gv);
   print "latest $version is ";
   my ($pkname) = (@$pkg[0] =~ m@([-\w]+)$@);
   my $first = substr($pkname, 0, 1);
   my $oldversion = `dpkg -I ~apertium/public_html/apt/nightly/pool/main/$first/$pkname/$pkname\_*-0ubuntu*~precise*_a*.deb | grep 'Version:' | head -n 1 | egrep -o '[0-9].*\$'`;
   chomp($oldversion);
   my $gt = `dpkg --compare-versions '$version' gt '$oldversion' && echo 1 || echo 0` + 0;
   if ($gt || $ARGV[0]) {
      print "newer than $oldversion - triggering rebuild\n";
      my $cli = "./make-deb-source.pl -p '@$pkg[0]' -u '@$pkg[1]' -v '$version' -d '$srcdate' -m 'Apertium Automaton <apertium-packaging\@lists.sourceforge.net>' -e 'Apertium Automaton <apertium-packaging\@lists.sourceforge.net>'";
      print "$cli\n";
      `$cli >&2`;
      `./build-debian-ubuntu.sh '$pkname' >&2`;
   }
   else {
      print "same or older than $oldversion\n";
   }
}
