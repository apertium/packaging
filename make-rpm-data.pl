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
	'm' => 'Tino Didriksen <tino@didriksen.cc>',
	'dv' => 1,
	'rev' => '',
	'auto' => 1,
	'oscp' => $ENV{'BUILDTYPE'} || 'nightly',
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

print `rm -rf /tmp/autorpm.* 2>&1`;
print `mkdir -pv /tmp/autorpm.$$ 2>&1`;
chdir "/tmp/autorpm.$$" or die "Could not change folder: $!\n";

print `ar x /var/cache/pbuilder/result/$pkname*sid*_all.deb data.tar.xz 2>&1`;
print `ar x /var/cache/pbuilder/result/$pkname*sid*_all.deb data.tar.gz 2>&1`;
print `tar -Jxvf data.tar.xz 2>&1`;
print `tar -zxvf data.tar.gz 2>&1`;
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
print `cp -av 'usr' '$pkname-$opts{'v'}/' 2>&1`;
print `tar -jcvf '$pkname\_$opts{'v'}.tar.bz2' '$pkname-$opts{'v'}' 2>&1`;

chdir "/root/osc/$opts{'oscp'}/" or die "Could not change folder: $!\n";
if (!(-d "/root/osc/$opts{'oscp'}/$pkname")) {
   print `osc up 2>&1`;
   print `osc mkpac $pkname 2>&1`;
   print `osc ci -m "Create package $pkname" 2>&1`;
}

chdir "/root/osc/$opts{'oscp'}/$pkname/" or die "Could not change folder: $!\n";
print `osc up 2>&1`;
print `osc rm --force * 2>&1`;
print `cp -av /tmp/autorpm.*/$pkname\_$opts{'v'}.tar.bz2 /root/osc/$opts{'oscp'}/$pkname/`;

my $btype = "\u$ENV{BUILDTYPE}";

my $spec = <<SPEC;
Name: $pkname
Version: $opts{'v'}
Release: $opts{'dv'}\%{?dist}
Summary: Autopkg of $pkname
Group: Development/Tools
License: GPL-3.0+
URL: http://apertium.org/
Source0: \%{name}_\%{version}.tar.bz2
BuildArch: noarch

Requires: apertium
Requires: apertium-lex-tools
Requires: cg3
Requires: hfst
Requires: hfst-ospell

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
- Automatic build - see changelog via: svn log $opts{u}/

CHLOG
}
open FILE, ">/root/osc/$opts{'oscp'}/$pkname/$pkname.spec" or die "Could not write /root/osc/$opts{'oscp'}/$pkname/$pkname.spec: $!\n";;
print FILE $spec;
close FILE;

my $meta = <<META;
<package name="$pkname" project="home:TinoDidriksen:$ENV{BUILDTYPE}">
  <title></title>
  <description></description>
  <build>
    <disable/>
    <enable arch="x86_64"/>
  </build>
</package>
META
open FILE, ">/tmp/$pkname.xml" or die "Could not write /tmp/$pkname.xml: $!\n";;
print FILE $meta;
close FILE;
print `osc meta pkg -F /tmp/$pkname.xml`;

print `osc add * 2>&1`;
print `osc ci -m "Automatic update to version $opts{'v'}" 2>&1`;
print `osc ci -m "Automatic update to version $opts{'v'}" 2>&1`;
print `rm -rf /tmp/autorpm.* 2>&1`;
