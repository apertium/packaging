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

use File::Copy;
use Getopt::Long;
my %opts = (
	'url' => 'https://github.com/apertium/apertium',
	'file' => 'configure.ac',
	'rev' => 'HEAD',
	'pkname' => 'apertium',
);
GetOptions(
	'u|url=s' => \$opts{'url'},
	'f|file=s' => \$opts{'file'},
	'rev=s' => \$opts{'rev'},
	'pkname|p=s' => \$opts{'pkname'},
);

print STDERR "Getting version quad from $opts{url}/$opts{file}\n";

my $rawrev = '';
my $revision = '';
my $srcdate = '';

my $pkg = $opts{'pkname'};
chdir('/opt/autopkg/repos');
if ($opts{'url'} =~ m@^https://github.com/[^/]+/([^/]+)$@) {
   if (! -s "${pkg}.git") {
      print STDERR `git clone --mirror '$opts{url}' 2>&1`;
   }

   chdir("${pkg}.git");
   print STDERR `git fetch --all -f`;
   print STDERR `git remote update -p`;
   print STDERR `git reflog expire --expire=now --all`;
   print STDERR `git repack -ad`;
   print STDERR `git prune`;

   chdir('/misc/git');
   `rm -rf '${pkg}.git'`;
   print STDERR `git clone --shallow-submodules /opt/autopkg/repos/${pkg}.git ${pkg}.git`;

   chdir("${pkg}.git");
   print STDERR `git reset --hard '$opts{rev}'`;
   my $logline = `git log --first-parent '--format=format:\%H\%x09\%ai' '$opts{rev}~..$opts{rev}'`;
   ($rawrev,$srcdate) = ($logline =~ m@^([^\t]+)\t([^\t]+)$@);
   $revision = '+g'.(`git log '--format=format:\%H' '$opts{rev}' | sort | uniq | wc -l` + 0).'~'.substr($rawrev, 0, 8);
}
else {
   my $retried = 0;
   my $sdir = "${pkg}.svn-$ENV{BUILDTYPE}";
   RETRY_SVN:
   if (! -d $sdir) {
      print STDERR `svn co -r$opts{rev} $opts{url}/ $sdir/ 2>&1`;
   }
   chdir($sdir);
   my $e = 0;
   print STDERR `svn switch --ignore-ancestry --force --accept tf -r$opts{rev} $opts{url}/ 2>&1`;
   $e += $?;
   print STDERR `svn cleanup --remove-unversioned 2>&1`;
   $e += $?;
   print STDERR `svn revert -R . 2>&1`;
   $e += $?;
   print STDERR `svn up --force --accept tf -r$opts{rev} 2>&1`;
   $e += $?;

   my $logline = `svn info -r$opts{rev}`;
   ($rawrev) = ($logline =~ m@Last Changed Rev: (\d+)@);
   ($srcdate) = ($logline =~ m@Last Changed Date: ([^)]+) \(@);
   $revision = '+s'.$rawrev;
   $e += $?;

   if ($e && !$retried) {
      print STDERR "Subversion repo failed somewhere - wiping and retrying...\n";
      chdir('/opt/autopkg/repos');
      `rm -rf $sdir`;
      $retried = 1;
      goto RETRY_SVN;
   }
   if ($e) {
      die "Subversion repo failed somewhere.\n";
   }
}
copy($opts{file}, "/tmp/version.$$.tmp");

my $major = 0;
my $minor = 0;
my $patch = 0;

my $data = file_get_contents("/tmp/version.$$.tmp");
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

unlink("/tmp/version.$$.tmp");

if ($opts{'rev'} ne 'HEAD') {
   $revision = '';
}

print "$rawrev\t$major.$minor.$patch$revision\t$srcdate\n";
