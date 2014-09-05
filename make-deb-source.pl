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
   'u' => 'http://svn.code.sf.net/p/apertium/svn/trunk/apertium',
   'r' => '',
   'p' => 'trunk/apertium',
   'v' => '0.0.0.0',
   'd' => '0001-01-01 00:00:00 +0000',
	'm' => 'Tino Didriksen <mail@tinodidriksen.com>',
	'e' => 'Tino Didriksen <mail@tinodidriksen.com>',
	'dv' => 1,
	'fv' => 1,
	'rev' => '',
	'auto' => 1,
);
GetOptions(
	'u=s' => \$opts{'u'},
	'r=s' => \$opts{'r'},
	'p=s' => \$opts{'p'},
	'v=s' => \$opts{'v'},
	'd=s' => \$opts{'d'},
	'm=s' => \$opts{'m'},
	'e=s' => \$opts{'e'},
	'distv=i' => \$opts{'dv'},
	'flavv=i' => \$opts{'fv'},
	'rev=i' => \$opts{'rev'},
	'auto=i' => \$opts{'auto'},
);

if ($opts{r} eq '') {
   $opts{r} = 'http://svn.code.sf.net/p/apertium/svn/branches/packaging/'.$opts{p};
}
if ($opts{rev} && $opts{rev} > 0) {
   $opts{rev} = '-r'.$opts{rev};
}
else {
   $opts{rev} = '';
}

my %distros = (
	'wheezy' => 'debian',
	'jessie' => 'debian',
	'sid' => 'debian',
	'precise' => 'ubuntu',
	'saucy' => 'ubuntu',
	'trusty' => 'ubuntu',
	'utopic' => 'ubuntu',
);

print `rm -rf /tmp/autopkg.*`;
print `mkdir -pv /tmp/autopkg.$$`;
chdir "/tmp/autopkg.$$" or die "Could not change folder: $!\n";

my ($pkname) = ($opts{p} =~ m@([-\w]+)$@);
my $date = `date -u -R`; # Not chomped, but that's ok since it's used last on a line

print `svn export $opts{rev} $opts{u}/ '$pkname-$opts{v}'`;
`find '$pkname-$opts{v}' ! -type d | LC_ALL=C sort > orig.lst`;
`find '$pkname-$opts{v}' -type d -empty | LC_ALL=C sort >> orig.lst`;
print `tar --no-acls --no-xattrs '--mtime=$opts{d}' -cf '$pkname\_$opts{v}.orig.tar' -T orig.lst`;
`bzip2 -9c '$pkname\_$opts{v}.orig.tar' > '$pkname\_$opts{v}.orig.tar.bz2'`;
print `svn export $opts{r}/debian/ '$pkname-$opts{v}/debian/'`;

foreach my $distro (keys %distros) {
	my $chver = $opts{v}.'-';
   if ($opts{auto}) {
      if ($distros{$distro} eq 'ubuntu') {
         $chver .= "0ubuntu";
      }
      $chver .= $opts{'dv'}."~".$distro.$opts{'fv'};
      my $chlog = <<CHLOG;
$pkname ($chver) $distro; urgency=low

  * Automatic build - see changelog via: svn log $opts{u}/

 -- $opts{e}  $date
CHLOG

      `cp -al '$pkname-$opts{v}' '$pkname-$chver'`;
      unlink "$pkname-$chver/debian/changelog";
      open FILE, ">$pkname-$chver/debian/changelog" or die "Could not write to debian/changelog: $!\n";
      print FILE $chlog;
      close FILE;
   }
   else {
      $chver .= $opts{'dv'};
      `cp -al '$pkname-$opts{v}' '$pkname-$chver'`;
   }
	print `dpkg-source '-DMaintainer=$opts{m}' '-DUploaders=$opts{e}' -b '$pkname-$chver'`;
	chdir "$pkname-$chver";
	print `dpkg-genchanges -S -sa '-m$opts{m}' '-e$opts{e}' > '../$pkname\_$chver\_source.changes'`;
	chdir '..';
	print `debsign '$pkname\_$chver\_source.changes'`;

   if (!$opts{auto}) {
      last;
   }
}
