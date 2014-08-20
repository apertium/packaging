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

use Getopt::Long;
my %opts = (
	'url' => 'http://svn.code.sf.net/p/apertium/svn/trunk/apertium',
	'file' => 'configure.ac',
	'rev' => '',
);
GetOptions(
	'u|url=s' => \$opts{'url'},
	'f|file=s' => \$opts{'file'},
	'rev=i' => \$opts{'rev'},
);

if ($opts{rev} > 0) {
   $opts{rev} = '-r'.$opts{rev};
}
else {
   $opts{rev} = '';
}

print STDERR "Getting version quad from $opts{url}/$opts{file}\n";

chdir('/tmp');
`svn export $opts{rev} $opts{url}/$opts{file} version.$$.tmp >&2`;
if (!(-s "version.$$.tmp")) {
   die "Failed to svn export $opts{file} from $opts{url}!\n";
}

my $major = 0;
my $minor = 0;
my $patch = 0;
my $logline = `svn log $opts{rev} -q -l 1 $opts{url} | grep '^r'`;
my ($revision,$srcdate) = ($logline =~ m@^r(\d+) \| [^|]+\| ([^(]+)@);
{
	local $/ = undef;
	open FILE, "version.$$.tmp" or die "Could not open version.$$.tmp: $!\n";
	my $data = <FILE>;
	my $version = '';
	if ($data =~ m@_VERSION_MAJOR = (\d+);.*?_VERSION_MINOR = (\d+);.*?_VERSION_PATCH = (\d+);@s) {
	   print STDERR "Found _VERSION_MAJOR/MINOR/PATCH version\n";
	   $version = "$1.$2.$3";
	}
	elsif ($data =~ m@AC_INIT.*?\[([\d.]+)\]@s) {
	   print STDERR "Found AC_INIT version\n";
	   $version = $1;
	}
	elsif ($data =~ m@VERSION.*?([\d.]+)@s) {
	   print STDERR "Found VERSION version\n";
	   $version = $1;
	}
	else {
	   die "No version found!\n";
	}
	if ($version =~ m@^(\d+)\.(\d+)$@) {
		$major = $1;
		$minor = $2;
	}
	elsif ($version =~ m@^(\d+)\.(\d+)\.(\d+)$@) {
		$major = $1;
		$minor = $2;
		$patch = $3;
	}
	close FILE;
}

unlink("version.$$.tmp");

print "$major.$minor.$patch.$revision\t$srcdate\n";
