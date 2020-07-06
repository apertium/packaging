Name: apertium-anaphora
Version: 1.0.0
Release: 1%{?dist}
Summary: Anaphora resolution module
Group: Development/Tools
License: GPL-3.0
URL: https://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: gcc-c++
BuildRequires: lttoolbox-devel
BuildRequires: libtool
BuildRequires: libxml2-devel
BuildRequires: pkgconfig

# Require xmllint from:
Requires: libxml2

%description
Anaphora resolution module used by Apertium

%prep
%setup -q -n %{name}-%{version}

%build
export LC_ALL=%(locale -a | grep -i utf | head -n1)
autoreconf -fi
%configure
make %{?_smp_mflags}

%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT
rm -f %{buildroot}/%{_libdir}/*.la

%check
export LC_ALL=%(locale -a | grep -i utf | head -n1)
make test

%files
%defattr(-,root,root)
%{_bindir}/*
%{_datadir}/apertium-anaphora
%{_libdir}/pkgconfig/*

%changelog
* Mon Jul 06 2020 Tino Didriksen <tino@didriksen.cc> 1.0.0
- Initial version of the package
