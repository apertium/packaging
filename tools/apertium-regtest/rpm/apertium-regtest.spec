Name: apertium-regtest
Version: 0.0.1
Release: 1%{?dist}
Summary: Suite to run regression tests for Apertium languages and pairs
Group: Development/Tools
License: GPL-3.0+
URL: https://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2
BuildArch: noarch

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: python3

Requires: python3

%description
Suite to run regression tests for Apertium languages and pairs.

%prep
%setup -q -n %{name}-%{version}

%build
autoreconf -fi
%configure
make %{?_smp_mflags}

%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT PREFIX=/usr

%files
%defattr(-,root,root)
%doc README
%{_bindir}/*
%{_datadir}/apertium-regtest
%{_datadir}/pkgconfig/*

%changelog
* Thu Aug 12 2021 Tino Didriksen <tino@didriksen.cc> 0.0.1
- Initial version of the package
