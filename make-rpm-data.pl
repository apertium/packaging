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

print `mkdir -pv /opt/autopkg/tmp/autorpm.$$ 2>&1`;
chdir "/opt/autopkg/tmp/autorpm.$$";

my $autopath = $ENV{AUTOPKG_AUTOPATH};
my @rbs = split /;/, $ENV{AUTOPKG_REBUILT};
foreach my $pk (@rbs) {
   print `ar x $autopath/amd64/sid/${pk}_*sid*_all.deb data.tar.xz 2>&1`;
   print `ar x $autopath/amd64/sid/${pk}_*sid*_all.deb data.tar.gz 2>&1`;
   print `tar --overwrite -Jxvf data.tar.xz 2>&1`;
   print `tar --overwrite -zxvf data.tar.gz 2>&1`;
   print `rm -fv data.tar.* 2>&1`;
}
my $files = '';
if (-e 'usr/bin') {
   $files .= "\%{_bindir}/*\n";
}
if (-e 'usr/lib/x86_64-linux-gnu/voikko') {
   print `mv -v 'usr/lib/x86_64-linux-gnu/voikko' 'usr/share/' 2>&1`;
}
if (-e 'usr/lib/x86_64-linux-gnu/pkgconfig') {
   print `mv -v 'usr/lib/x86_64-linux-gnu/pkgconfig' 'usr/share/' 2>&1`;
}
if (-e 'usr/share/apertium') {
   $files .= "\%{_datadir}/apertium\n";
}
if (-e 'usr/share/doc') {
   $files .= "\%{_datadir}/doc/*\n";
}
if (-e 'usr/share/giella') {
   $files .= "\%{_datadir}/giella\n";
}
if (-e 'usr/share/giella-core') {
   $files .= "\%{_datadir}/giella-core\n";
}
if (-e 'usr/share/giella-common') {
   $files .= "\%{_datadir}/giella-common\n";
}
if (-e 'usr/share/pkgconfig') {
   $files .= "\%{_datadir}/pkgconfig\n";
}
if (-e 'usr/share/voikko') {
   $files .= "\%{_datadir}/voikko\n";
}
mkdir($pkname.'-'.$opts{'v'});
print `cp -av --reflink=auto 'usr' '$pkname-$opts{'v'}/' 2>&1`;
print `tar -jcvf '$pkname\_$opts{'v'}.tar.bz2' '$pkname-$opts{'v'}' 2>&1`;

chdir "/root/osc/$opts{'oscp'}/";
print `osc up 2>&1`;
if (!(-d "/root/osc/$opts{'oscp'}/$pkname")) {
   print `osc mkpac $pkname 2>&1`;
   print `osc ci -m "Create package $pkname" $pkname 2>&1`;
}

chdir "/root/osc/$opts{'oscp'}/$pkname/";
print `osc up 2>&1`;
print `osc rm * 2>&1`;
print `osc rm --force * 2>&1`;
print `osc rm *.bz2 2>&1`;
print `osc rm --force *.bz2 2>&1`;
print `cp -av --reflink=auto /opt/autopkg/tmp/autorpm.$$/$pkname\_$opts{'v'}.tar.bz2 /root/osc/$opts{'oscp'}/$pkname/`;

my $btype = "\u$ENV{AUTOPKG_BUILDTYPE}";

my $spec = <<SPEC;
Name: $pkname
Version: $opts{'v'}
Release: $opts{'dv'}\%{?dist}
Summary: Autopkg of $pkname
Group: Development/Tools
License: GPL-3.0+
URL: https://apertium.org/
Source0: \%{name}_\%{version}.tar.bz2
BuildArch: noarch

Requires: lttoolbox >= 3.6.0
Requires: apertium >= 3.8.0
Requires: apertium-lex-tools >= 0.3.0
Requires: apertium-separable >= 0.4.0
Requires: apertium-recursive >= 1.1.0
Requires: apertium-anaphora >= 1.1.0
Requires: cg3 >= 1.3.2
Requires: hfst >= 3.15.3
Requires: hfst-ospell >= 0.5.2

\%description
$btype autopkg of $pkname

\%prep
\%setup -q -n \%{name}-\%{version}

\%build

\%install
cp -av * \%{buildroot}/

\%files
\%defattr(-,root,root)
$files

SPEC

if ($opts{auto}) {
   $spec =~ s/\%changelog.*//sg;
   $spec .= <<CHLOG;
\%changelog
* $date $opts{'m'} $opts{'v'}-$opts{'dv'}
- Automatic build - see changelog at $opts{u}/

CHLOG
}
file_put_contents("/root/osc/$opts{'oscp'}/$pkname/$pkname.spec", $spec);

my $meta = <<META;
<package name="$pkname" project="home:TinoDidriksen:$ENV{AUTOPKG_BUILDTYPE}">
  <title></title>
  <description></description>
  <build>
    <disable/>
    <enable arch="x86_64"/>
  </build>
</package>
META
file_put_contents("/opt/autopkg/tmp/autorpm.$$/$pkname.xml", $meta);
print `osc meta pkg -F /opt/autopkg/tmp/autorpm.$$/$pkname.xml`;

print `osc add * 2>&1`;
print `osc ci -m "Automatic update to version $opts{'v'}" 2>&1`;
print `osc ci -m "Automatic update to version $opts{'v'}" 2>&1`;
print `rm -rf /opt/autopkg/tmp/autorpm.$$ 2>&1`;
