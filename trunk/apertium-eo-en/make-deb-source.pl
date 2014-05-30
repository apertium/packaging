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

use Getopt::Long;
my %opts = (
	'm' => 'Tino Didriksen <mail@tinodidriksen.com>',
	'e' => 'Tino Didriksen <mail@tinodidriksen.com>',
	'dv' => 1,
);
GetOptions(
	'm=s' => \$opts{'m'},
	'e=s' => \$opts{'e'},
	'distv=i' => \$opts{'dv'},
);

print `rm -rf /tmp/autopkg.*`;
print `mkdir -pv /tmp/autopkg.$$`;
chdir "/tmp/autopkg.$$" or die "Could not change folder: $!\n";

print `svn export https://svn.code.sf.net/p/apertium/svn/trunk/apertium-eo-en/configure.ac`;
my $major = 0;
my $minor = 0;
my $patch = 0;
my $revision = `svn log -q -l 1 https://svn.code.sf.net/p/apertium/svn/trunk/apertium-eo-en/ | egrep -o '^r[0-9]+' | egrep -o '[0-9]+'` + 0;
{
	local $/ = undef;
	open FILE, 'configure.ac' or die "Could not open configure.ac: $!\n";
	my $data = <FILE>;
	my ($version) = ($data =~ m@AC_INIT.*?\[([\d.]+)\]@s);
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

my $version = "$major.$minor.$patch.$revision";
my $date = `date -u -R`;

print `svn export https://svn.code.sf.net/p/apertium/svn/trunk/apertium-eo-en/ 'apertium-eo-en-$version'`;
`find 'apertium-eo-en-$version' | LC_ALL=C sort -r > orig.lst`;
print `tar -jcvf 'apertium-eo-en_$version.orig.tar.bz2' -T orig.lst`;
print `svn export https://svn.code.sf.net/p/apertium/svn/branches/packaging/trunk/apertium-eo-en/debian/ 'apertium-eo-en-$version/debian/'`;

my $chver = $version.'-'.$opts{'dv'};
my $chlog = <<CHLOG;
apertium-eo-en ($chver) all; urgency=low

  * Automatic build - see changelog via: svn log https://svn.code.sf.net/p/apertium/svn/trunk/apertium-eo-en/

 -- $opts{e}  $date
CHLOG

`cp -al 'apertium-eo-en-$version' 'apertium-eo-en-$chver'`;
unlink "apertium-eo-en-$chver/debian/changelog";
open FILE, ">apertium-eo-en-$chver/debian/changelog" or die "Could not write to debian/changelog: $!\n";
print FILE $chlog;
close FILE;
print `dpkg-source '-DMaintainer=$opts{m}' '-DUploaders=$opts{e}' -b 'apertium-eo-en-$chver'`;
chdir "apertium-eo-en-$chver";
print `dpkg-genchanges -S -sa '-m$opts{m}' '-e$opts{e}' > '../apertium-eo-en_$chver\_source.changes'`;
chdir '..';
print `debsign 'apertium-eo-en_$chver\_source.changes'`;

chdir "/tmp";
