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
	'm' => 'Tino Didriksen <tino@didriksen.cc>',
	'e' => 'Tino Didriksen <tino@didriksen.cc>',
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
	'sid' => 'debian',
	'jessie' => 'debian',
	'stretch' => 'debian',
	'buster' => 'debian',
	'trusty' => 'ubuntu',
	'xenial' => 'ubuntu',
	'artful' => 'ubuntu',
	'bionic' => 'ubuntu',
);

my @includes = ();
my @excludes = ();
if (-s $opts{p}.'/exclude.txt') {
   open FILE, $opts{p}.'/exclude.txt' or die "Could not open exclude.txt: $!\n";
   while (<FILE>) {
      chomp;
      if (m@^\+ (.+)$@) {
         push(@includes, $1);
      }
      elsif (m@^\- (.+)$@) {
         push(@excludes, $1);
      }
      else {
         s@\*@.*@g;
         s@\?@.@g;
         push(@excludes, "$_.*");
      }
   }
   close FILE;
}

print `rm -rf /tmp/autopkg.* 2>&1`;
print `mkdir -pv /tmp/autopkg.$$ 2>&1`;
chdir "/tmp/autopkg.$$" or die "Could not change folder: $!\n";

my ($pkname) = ($opts{p} =~ m@([-\w]+)$@);
my $date = `date -u -R`; # Not chomped, but that's ok since it's used last on a line

if ($opts{u} =~ m@^(https://github.com/[^/]+/[^/]+/)@i) {
   my $ref = `svn pg git-commit --revprop $opts{rev} $opts{u}/`;
   chomp($ref);
   print `git clone '$1' '$pkname-$opts{v}' 2>&1`;
   chdir "$pkname-$opts{v}" or die "Could not change folder: $!\n";
   print `git reset --hard '$ref' 2>&1`;
   print `git submodule update --init --recursive 2>&1`;
   `find . -name '.git*' -print0 | xargs -0rn1 rm -rfv 2>&1`;
   chdir '..' or die "Could not change folder: $!\n";
}
else {
   print `svn export $opts{rev} $opts{u}/ '$pkname-$opts{v}'`;
}
if (@excludes) {
   chdir "$pkname-$opts{v}" or die "Could not change folder: $!\n";
   my @files = split(/\n/, `find . ! -type d`);
   foreach my $f (@files) {
      $f =~ s@^\./@@;
      my $keep = 0;
      foreach my $p (@includes) {
         if ($f =~ m@^$p$@) {
            print "keeping '$f'\n";
            $keep = 1;
            last;
         }
      }
      if ($keep) {
         next;
      }
      foreach my $p (@excludes) {
         if ($f =~ m@^$p$@) {
            print `rm -rfv '$f'`;
         }
      }
   }
   while (my $o = `find . -type d -empty -print0 | LC_ALL=C sort -zr | xargs -0rn1 rm -rfv 2>&1`) {
      print $o;
   }
   chdir ".." or die "Could not change folder: $!\n";
}

# RPM tar.bz2
my $rv = $opts{v};
$rv =~ s@~@.@g;
`cp -al '$pkname-$opts{v}' '$pkname-$rv'`;
`find '$pkname-$rv' ! -type d | LC_ALL=C sort > orig.lst`;
`find '$pkname-$rv' -type d -empty | LC_ALL=C sort >> orig.lst`;
print `tar --no-acls --no-xattrs '--mtime=$opts{d}' -cf '$pkname\_$rv.orig.tar' -T orig.lst`;
`bzip2 -9c '$pkname\_$rv.orig.tar' > '$pkname\_$rv.orig.tar.bz2'`;
`rm -rf '$pkname-$rv'`;

# Debian tar.bz2
`find '$pkname-$opts{v}' ! -type d | LC_ALL=C sort > orig.lst`;
`find '$pkname-$opts{v}' -type d -empty | LC_ALL=C sort >> orig.lst`;
print `tar --no-acls --no-xattrs '--mtime=$opts{d}' -cf '$pkname\_$opts{v}.orig.tar' -T orig.lst`;
`bzip2 -9c '$pkname\_$opts{v}.orig.tar' > '$pkname\_$opts{v}.orig.tar.bz2'`;
my $path = `find /misc/branches/packaging/ -type d -name '$pkname'`;
chomp($path);
print `cp -av '$path/debian' '$pkname-$opts{v}/'`;
#print `svn export $opts{r}/debian/ '$pkname-$opts{v}/debian/'`;

if (!$opts{auto}) {
   print `grep -l ldconfig '$pkname-$opts{v}'/debian/*.post* -print0 | xargs -0rn1 rm -fv`;
}

# dpkg tools are not happy if PERL_UNICODE is on
$ENV{'PERL_UNICODE'} = '';

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
