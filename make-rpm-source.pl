#!/usr/bin/env perl
# -*- mode: cperl; indent-tabs-mode: nil; tab-width: 3; cperl-indent-level: 3; -*-
# Copyright (C) 2014, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 2 or later; see https://www.gnu.org/licenses/
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

use Getopt::Long;
my %opts = (
   'u' => 'https://github.com/apertium/apertium',
   'p' => 'trunk/apertium',
   'v' => '0.0.0.0',
	'm' => 'Tino Didriksen <tino@didriksen.cc>',
	'dv' => 1,
	'rev' => 'HEAD',
	'auto' => 1,
	'oscp' => $ENV{'AUTOPKG_BUILDTYPE'} || 'nightly',
);
GetOptions(
	'u=s' => \$opts{'u'},
	'p=s' => \$opts{'p'},
	'v=s' => \$opts{'v'},
	'm=s' => \$opts{'m'},
	'distv=i' => \$opts{'dv'},
	'rev=s' => \$opts{'rev'},
	'auto=i' => \$opts{'auto'},
	'oscp=s' => \$opts{'oscp'},
);

$opts{'v'} =~ s@[+~]@.@g;

my ($pkname) = ($opts{p} =~ m@([-\w]+)$@);
my $date = `date -u '+\%a \%b \%d \%Y'`;
chomp($date);

my $autopath = $ENV{AUTOPKG_AUTOPATH};
chdir $autopath;

#`svn export $opts{r}/rpm >/dev/null 2>&1`;
if (!(-s "$ENV{AUTOPKG_PKPATH}/rpm/$pkname.spec")) {
   die "No such file $ENV{AUTOPKG_PKPATH}/rpm/$pkname.spec !\n";
}
print `cp -av --reflink=auto '$ENV{AUTOPKG_PKPATH}/rpm' ./`;
my $spec = `cat rpm/$pkname.spec`;

chdir "/root/osc/$opts{'oscp'}/";
print `osc up 2>&1`;
if (!(-d "/root/osc/$opts{'oscp'}/$pkname")) {
   print `osc mkpac $pkname 2>&1`;
   print `osc ci -m "Create package $pkname" $pkname 2>&1`;
}

chdir "/root/osc/$opts{'oscp'}/$pkname/";
print `osc up 2>&1`;
print `osc rm --force * 2>&1`;
print `cp -av --reflink=auto $autopath/$pkname\_$opts{'v'}.orig.tar.bz2 /root/osc/$opts{'oscp'}/$pkname/`;
print `cp -av --reflink=auto $autopath/rpm/* /root/osc/$opts{'oscp'}/$pkname/`;

$spec =~ s/^Version:(\s+)[^\n]+$/Version:$1$opts{'v'}/m;
$spec =~ s/^Release:(\s+)\d+/Release:$1$opts{'dv'}/m;
if ($opts{auto}) {
   $spec =~ s/\%changelog.*//sg;
   $spec .= <<CHLOG;
\%changelog
* $date $opts{'m'} $opts{'v'}-$opts{'dv'}
- Automatic build - see changelog at $opts{u}/

CHLOG
}
file_put_contents("/root/osc/$opts{'oscp'}/$pkname/$pkname.spec", $spec);

print `osc add * 2>&1`;
print `osc ci -m "Automatic update to version $opts{'v'}" 2>&1`;
print `osc ci -m "Automatic update to version $opts{'v'}" 2>&1`;
