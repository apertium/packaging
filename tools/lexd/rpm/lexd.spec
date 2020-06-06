Name: lexd
Version: 0.0.1
Release: 1%{?dist}
Summary: Lexicon compiler for non-suffixational morphologies
Group: Development/Tools
License: GPL-3.0+
URL: https://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: gcc-c++
BuildRequires: hfst
BuildRequires: libicu-devel
BuildRequires: lttoolbox-devel
BuildRequires: libtool
BuildRequires: pkgconfig
BuildRequires: time

%description
A lexicon compiler for non-suffixational morphologies.

%prep
%setup -q -n %{name}-%{version}

%build
export LC_ALL=%(locale -a | grep -i utf | head -n1)
autoreconf -fi
%configure
make %{?_smp_mflags}

%check
export LC_ALL=%(locale -a | grep -i utf | head -n1)
make check

%install
make DESTDIR=%{buildroot} install

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README
%{_bindir}/*

%changelog
* Sat Jun 06 2020 Tino Didriksen <tino@didriksen.cc> 0.0.1
- Initial version of the package
