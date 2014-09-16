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
	'm' => 'Tino Didriksen <mail@tinodidriksen.com>',
	'dv' => 1,
	'rev' => '',
	'auto' => 1,
);
GetOptions(
	'u=s' => \$opts{'u'},
	'r=s' => \$opts{'r'},
	'p=s' => \$opts{'p'},
	'v=s' => \$opts{'v'},
	'm=s' => \$opts{'m'},
	'distv=i' => \$opts{'dv'},
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

my ($pkname) = ($opts{p} =~ m@([-\w]+)$@);
my $date = `date -u '+\%a \%b \%d \%Y'`;
chomp($date);

chdir(glob('/tmp/autopkg.*')) or die "Could not change folder: $!\n";
`svn export $opts{r}/rpm >/dev/null 2>&1`;
if (!(-s "rpm/$pkname.spec")) {
   die "No such file $opts{r}/rpm/$pkname.spec !\n";
}
my $spec = `cat rpm/$pkname.spec`;

chdir "/root/osc/$pkname/" or die "Could not change folder: $!\n";
`osc up`;
`osc rm *`;
print `cp -av /tmp/autopkg.*/*.orig.tar.bz2 /root/osc/$pkname/`;
print `cp -av /tmp/autopkg.*/rpm/* /root/osc/$pkname/`;

$spec =~ s/^Version:[^\n]+$/Version: $opts{'v'}/m;
$spec =~ s/^Release: \d+/Release: $opts{'dv'}/m;
if ($opts{auto}) {
   $spec =~ s/\%changelog.*//sg;
   $spec .= <<CHLOG;
\%changelog
* $date $opts{'m'} $opts{'v'}-$opts{'dv'}
- Automatic build - see changelog via: svn log $opts{u}/

CHLOG
}
open FILE, ">/root/osc/$pkname/$pkname.spec" or die "Could not write /root/osc/$pkname/$pkname.spec: $!\n";;
print FILE $spec;
close FILE;

`osc add *`;
`osc ci -m "Automatic update to version $opts{'v'}"`;
