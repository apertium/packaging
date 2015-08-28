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
	'oscp' => 'nightly',
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
	'oscp=s' => \$opts{'oscp'},
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

$opts{'v'} =~ s@~@.@g;

my ($pkname) = ($opts{p} =~ m@([-\w]+)$@);
my $date = `date -u '+\%a \%b \%d \%Y'`;
chomp($date);

print `rm -rf '/tmp/autorpm.$$' 2>&1`;
mkdir("/tmp/autorpm.$$");
chdir(glob('/tmp/autorpm.*')) or die "Could not change folder: $!\n";
print `ar x /var/cache/pbuilder/result/$pkname*stretch*_all.deb data.tar.xz 2>&1`;
print `tar -Jxf data.tar.xz 2>&1`;
rename('usr', $pkname.'-'.$opts{'v'});
print `tar -jcf '$pkname\_$opts{'v'}.orig.tar.bz2' '$pkname-$opts{'v'}' 2>&1`;

chdir "/root/osc/$opts{'oscp'}/" or die "Could not change folder: $!\n";
if (!(-d "/root/osc/$opts{'oscp'}/$pkname")) {
   print `osc mkpac $pkname 2>&1`;
   print `osc ci -m "Create package $pkname" 2>&1`;
}

chdir "/root/osc/$opts{'oscp'}/$pkname/" or die "Could not change folder: $!\n";
print `osc up 2>&1`;
print `osc rm * 2>&1`;
print `cp -av /tmp/autorpm.*/$pkname\_$opts{'v'}.orig.tar.bz2 /root/osc/$opts{'oscp'}/$pkname/`;

my $spec = <<SPEC;
Name: $pkname
Version: $opts{'v'}
Release: $opts{'dv'}\%{?dist}
Summary: Autopkg of $pkname
Group: Development/Tools
License: GPL-3.0+
URL: http://apertium.org/
Source0: \%{name}_\%{version}.orig.tar.bz2
BuildArch: noarch

BuildRequires: binutils
BuildRequires: xz
Requires: apertium
Requires: apertium-lex-tools
Requires: cg3
Requires: hfst

\%description
Nightly autopkg of $pkname

\%prep
\%setup -q -n \%{name}-\%{version}

\%build

\%install
install -d \%{buildroot}\%{_datadir}
cp -a share/* \%{buildroot}\%{_datadir}/

\%files
\%defattr(-,root,root)
\%{_datadir}/apertium
\%{_datadir}/[b-z]*/*

SPEC

if ($opts{auto}) {
   $spec =~ s/\%changelog.*//sg;
   $spec .= <<CHLOG;
\%changelog
* $date $opts{'m'} $opts{'v'}-$opts{'dv'}
- Automatic build - see changelog via: svn log $opts{u}/

CHLOG
}
open FILE, ">/root/osc/$opts{'oscp'}/$pkname/$pkname.spec" or die "Could not write /root/osc/$opts{'oscp'}/$pkname/$pkname.spec: $!\n";;
print FILE $spec;
close FILE;

print `osc add * 2>&1`;
print `osc ci -m "Automatic update to version $opts{'v'}" 2>&1`;
print `rm -rf '/tmp/autorpm.$$' 2>&1`;
