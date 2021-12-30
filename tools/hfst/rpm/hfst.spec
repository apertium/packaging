Name: hfst
Version: 3.15.1
Release: 1%{?dist}
Summary: Helsinki Finite-State Transducer Technology
Group: Development/Tools
License: GPL-3.0+
URL: http://www.ling.helsinki.fi/kieliteknologia/tutkimus/hfst/
Source0: %{name}_%{version}.orig.tar.bz2
Patch0: hfst_01_configure.ac.diff
Patch1: hfst_02_notimestamp.diff

%if 0%{?el7}
BuildRequires: devtoolset-7-gcc-c++
%endif
BuildRequires: autoconf
BuildRequires: automake
BuildRequires: bison
BuildRequires: flex
BuildRequires: gcc-c++
BuildRequires: libicu-devel
BuildRequires: libtool
BuildRequires: swig
BuildRequires: pkgconfig
BuildRequires: readline-devel
BuildRequires: zlib-devel
BuildRequires: python3
BuildRequires: python3-devel

Requires: libhfst54 = %{version}-%{release}
Requires: grep
Requires: python3
Requires: sed

%description
The Helsinki Finite-State Transducer software is intended for the
implementation of morphological analysers and other tools which are
based on weighted and unweighted finite-state transducer technology.

%package -n libhfst54
Summary: Helsinki Finite-State Transducer Technology Libraries
Group: Development/Libraries
Provides: libhfst = %{version}-%{release}
Obsoletes: libhfst < %{version}-%{release}
Obsoletes: libhfst3 < %{version}-%{release}

%description -n libhfst54
Runtime libraries for HFST

%package -n libhfst-devel
Summary: Helsinki Finite-State Transducer Technology Development files
Group: Development/Libraries
Requires: hfst = %{version}-%{release}
Requires: libicu-devel
Obsoletes: libhfst3-devel < %{version}-%{release}

%description -n libhfst-devel
Development headers and libraries for HFST

%package -n python3-hfst
Summary: Python 3 modules for Helsinki Finite-State Transducer Technology
Requires: libhfst54 = %{version}-%{release}
Provides: python3-libhfst = %{version}-%{release}
Obsoletes: python3-libhfst < %{version}-%{release}

%description -n python3-hfst
Python 3 modules for libhfst

%prep
%setup -q -n %{name}-%{version}
%patch0 -p1
%patch1 -p1

%build
%if 0%{?el7}
	source /opt/rh/devtoolset-7/enable
%endif
autoreconf -fi
%configure --disable-static --enable-all-tools --with-readline --with-unicode-handler=icu --enable-python-bindings
make %{?_smp_mflags}

%install
%if 0%{?el7}
	source /opt/rh/devtoolset-7/enable
%endif
make DESTDIR=%{buildroot} install
sed -i 's/@GLIB_CFLAGS@//' %{buildroot}/%{_libdir}/pkgconfig/hfst.pc
rm -f %{buildroot}/%{_libdir}/*.la

%check
%if 0%{?el7}
	source /opt/rh/devtoolset-7/enable
%endif
make check || /bin/true

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README THANKS
%{_bindir}/*
%{_datadir}/man/man1/*

%files -n libhfst54
%defattr(-,root,root)
%{_libdir}/*.so.*

%files -n libhfst-devel
%defattr(-,root,root)
%{_includedir}/*
%{_libdir}/pkgconfig/*
%{_libdir}/*.so
%{_datadir}/aclocal/*

%files -n python3-hfst
%defattr(-,root,root)
%{python3_sitearch}/*

%post -n libhfst54 -p /sbin/ldconfig

%postun -n libhfst54 -p /sbin/ldconfig

%changelog
* Fri Dec 19 2014 Tino Didriksen <tino@didriksen.cc> 3.8.2
- New upstream release

* Tue Nov 04 2014 Tino Didriksen <tino@didriksen.cc> 3.8.1
- New upstream release

* Fri Sep 05 2014 Tino Didriksen <tino@didriksen.cc> 3.8.0
- Initial version of the package
