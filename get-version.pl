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

use File::Copy;
use Getopt::Long;
my %opts = (
	'url' => 'https://github.com/apertium/apertium',
	'file' => 'configure.ac',
	'rev' => 'HEAD',
);
GetOptions(
	'u|url=s' => \$opts{'url'},
	'f|file=s' => \$opts{'file'},
	'rev=s' => \$opts{'rev'},
);

print STDERR "Getting version quad from $opts{url}/$opts{file}\n";

my $rawrev = '';
my $revision = '';
my $srcdate = '';

if ($opts{'url'} =~ m@^https://github.com/[^/]+/([^/]+)$@) {
   my $pkg = $1;
   chdir('/home/apertium/public_html/git');
   if (! -s "${pkg}.git") {
      print STDERR `git clone --mirror '$opts{url}' 2>&1`;
      print STDERR `chown -R apertium:apertium '${pkg}.git'`;
   }

   chdir("${pkg}.git") or die $!;
   print STDERR `git remote update -p`;

   chdir('/misc/git') or die $!;
   `rm -rf '${pkg}.git'`;
   print STDERR `git clone --shallow-submodules /home/apertium/public_html/git/${pkg}.git ${pkg}.git`;

   chdir("${pkg}.git") or die $!;
   print STDERR `git reset --hard '$opts{rev}'`;
   my $logline = `git log '--format=format:\%H\%x09\%ai' '$opts{rev}~..$opts{rev}'`;
   ($rawrev,$srcdate) = ($logline =~ m@^([^\t]+)\t([^\t]+)$@);
   $revision = '+g'.(`git rev-list --count --first-parent '$opts{rev}'` + 0).'~'.substr($rawrev, 0, 8);

   copy($opts{'file'}, "/tmp/version.$$.tmp");
   chdir('/tmp') or die $!;
}
else {
   chdir('/tmp') or die $!;
   `svn export -r$opts{rev} $opts{url}/$opts{file} version.$$.tmp >&2`;
   my $logline = `svn info -r$opts{rev} $opts{url}`;
   ($rawrev) = ($logline =~ m@Last Changed Rev: (\d+)@);
   ($srcdate) = ($logline =~ m@Last Changed Date: ([^)]+) \(@);
   $revision = '+s'.$rawrev;
}

if (!(-s "version.$$.tmp")) {
   die "Failed to git/svn export $opts{file} from $opts{url}!\n";
}

my $major = 0;
my $minor = 0;
my $patch = 0;
{
	local $/ = undef;
	open FILE, "version.$$.tmp" or die "Could not open version.$$.tmp: $!\n";
	my $data = <FILE>;
	my $version = '';
	if ($data =~ m@_VERSION_MAJOR = (\d+);.*?_VERSION_MINOR = (\d+);.*?_VERSION_PATCH = (\d+);@s) {
	   print STDERR "Found _VERSION_MAJOR/MINOR/PATCH version\n";
	   $version = "$1.$2.$3";
	}
	elsif ($data =~ m@__version__ = "([\d.]+)"@s || $data =~ m@__version__ = '([\d.]+)'@s) {
	   print STDERR "Found __version__ version\n";
	   $version = $1;
	}
	elsif ($data =~ m@AC_INIT.*?\[([\d.]+)[^\]]*\]@s) {
	   print STDERR "Found AC_INIT version\n";
	   $version = $1;
	}
	elsif ($data =~ m@\n\s*VERSION.*?([\d.]+)@s || $data =~ m@VERSION.*?([\d.]+)@s) {
	   print STDERR "Found VERSION version\n";
	   $version = $1;
	}
	elsif ($data =~ m@PACKAGE_VERSION\s*=\s*"([\d.]+)@s) {
	   print STDERR "Found PACKAGE_VERSION version\n";
	   $version = $1;
	}
	else {
	   die "No version found!\n";
	}
	if ($version =~ m@^(\d+)$@) {
		$patch = $1;
	}
	elsif ($version =~ m@^(\d+)\.(\d+)$@) {
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

if ($opts{'rev'} ne 'HEAD') {
   $revision = '';
}

print "$rawrev\t$major.$minor.$patch$revision\t$srcdate\n";
