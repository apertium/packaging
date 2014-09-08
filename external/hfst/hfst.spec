Name: hfst
Version: 3.7.1
Release: 1%{?dist}
Summary: Helsinki Finite-State Transducer Technology
Group: Development/Tools
License: GPL-3.0+
URL: http://www.ling.helsinki.fi/kieliteknologia/tutkimus/hfst/
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: pkgconfig
BuildRequires: autoconf
BuildRequires: automake
BuildRequires: gcc-c++
BuildRequires: libicu-devel
BuildRequires: zlib-devel
BuildRequires: flex
BuildRequires: bison
BuildRequires: libtool
BuildRequires: readline-devel

%description
The Helsinki Finite-State Transducer software is intended for the
implementation of morphological analysers and other tools which are
based on weighted and unweighted finite-state transducer technology.

%package -n libhfst36
Summary: Helsinki Finite-State Transducer Technology Libraries
Group: Development/Libraries

%description -n libhfst36
Runtime libraries for HFST

%package -n libhfst36-devel
Summary: Helsinki Finite-State Transducer Technology Development files
Group: Development/Libraries
Requires: libhfst36 = %{version}-%{release}

%description -n libhfst36-devel
Development headers and libraries for HFST

%prep
%setup -q -n %{name}-%{version}

%build
autoreconf -fi
%configure --with-unicode-handler=ICU --enable-all-tools
./scripts/generate-cc-files.sh
make %{?_smp_mflags} || /bin/true
make %{?_smp_mflags} || /bin/true
make

%install
make DESTDIR=%{buildroot} install
rm -f %{buildroot}/%{_libdir}/*.la

%files
%doc AUTHORS NEWS README THANKS
%{_bindir}/*
%{_datadir}/man/man1/*

%files -n libhfst36
%{_libdir}/*.so.*

%files -n libhfst36-devel
%{_includedir}/*
%{_libdir}/pkgconfig/*
%{_libdir}/*.a*
%{_libdir}/*.so
%{_datadir}/aclocal/*

%post -n libhfst36 -p /sbin/ldconfig

%postun -n libhfst36 -p /sbin/ldconfig

%changelog
* Fri Sep 05 2014 Tino Didriksen <mail@tinodidriksen.com> 3.7.1
- Initial version of the package
