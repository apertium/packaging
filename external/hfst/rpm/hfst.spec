Name: hfst
Version: 3.8.1
Release: 1%{?dist}
Summary: Helsinki Finite-State Transducer Technology
Group: Development/Tools
License: GPL-3.0+
URL: http://www.ling.helsinki.fi/kieliteknologia/tutkimus/hfst/
Source0: %{name}_%{version}.orig.tar.bz2
Patch0: hfst_01_configure.ac.diff
Patch1: hfst_02_notimestamp.diff

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: bison
BuildRequires: flex
BuildRequires: gcc-c++
BuildRequires: libicu-devel
BuildRequires: libtool
BuildRequires: libxml2
BuildRequires: libxml2-devel
BuildRequires: pkgconfig
BuildRequires: python
BuildRequires: python-devel
BuildRequires: readline-devel
BuildRequires: zlib-devel
Requires: grep
Requires: python
Requires: sed

%description
The Helsinki Finite-State Transducer software is intended for the
implementation of morphological analysers and other tools which are
based on weighted and unweighted finite-state transducer technology.

%package -n libhfst38
Summary: Helsinki Finite-State Transducer Technology Libraries
Group: Development/Libraries
Provides: libhfst3 = %{version}-%{release}

%description -n libhfst38
Runtime libraries for HFST

%package -n libhfst38-devel
Summary: Helsinki Finite-State Transducer Technology Development files
Group: Development/Libraries
Requires: libhfst38 = %{version}-%{release}
Provides: libhfst3-devel = %{version}-%{release}

%description -n libhfst38-devel
Development headers and libraries for HFST

%prep
%setup -q -n %{name}-%{version}
%patch0 -p1
%patch1 -p1

%build
autoreconf -fi
%configure --without-foma --with-unicode-handler=ICU --enable-all-tools
./scripts/generate-cc-files.sh
make %{?_smp_mflags} || make %{?_smp_mflags} || make

%install
make DESTDIR=%{buildroot} install
rm -f %{buildroot}/%{_libdir}/*.la
rm -f %{buildroot}/%{python_sitelib}/*.py[co]

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README THANKS
%{_bindir}/*
%{_datadir}/man/man1/*

%files -n libhfst38
%defattr(-,root,root)
%{python_sitelib}/*
%{_libdir}/*.so.*

%files -n libhfst38-devel
%defattr(-,root,root)
%{_includedir}/*
%{_libdir}/pkgconfig/*
%{_libdir}/*.a*
%{_libdir}/*.so
%{_datadir}/aclocal/*

%post -n libhfst38 -p /sbin/ldconfig

%postun -n libhfst38 -p /sbin/ldconfig

%changelog
* Tue Nov 04 2014 Tino Didriksen <mail@tinodidriksen.com> 3.8.1
- New upstream release

* Fri Sep 05 2014 Tino Didriksen <mail@tinodidriksen.com> 3.8.0
- Initial version of the package
