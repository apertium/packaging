Name: hfst
Version: 3.12.1
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
BuildRequires: swig
BuildRequires: pkgconfig
BuildRequires: python
BuildRequires: python-devel
BuildRequires: readline-devel
BuildRequires: zlib-devel
%if ! ( 0%{?el6} || 0%{?el7} )
BuildRequires: python3
BuildRequires: python3-devel
%endif
Requires: grep
Requires: python
Requires: sed

%description
The Helsinki Finite-State Transducer software is intended for the
implementation of morphological analysers and other tools which are
based on weighted and unweighted finite-state transducer technology.

%package -n libhfst48
Summary: Helsinki Finite-State Transducer Technology Libraries
Group: Development/Libraries
Provides: libhfst = %{version}-%{release}
Obsoletes: libhfst < %{version}-%{release}
Obsoletes: libhfst3 < %{version}-%{release}

%description -n libhfst48
Runtime libraries for HFST

%package -n libhfst48-devel
Summary: Helsinki Finite-State Transducer Technology Development files
Group: Development/Libraries
Requires: libhfst48 = %{version}-%{release}
Provides: libhfst-devel = %{version}-%{release}
Obsoletes: libhfst-devel < %{version}-%{release}
Obsoletes: libhfst3-devel < %{version}-%{release}

%description -n libhfst48-devel
Development headers and libraries for HFST

%package -n python-libhfst
Summary: Python modules for Helsinki Finite-State Transducer Technology
Requires: libhfst48 = %{version}-%{release}

%description -n python-libhfst
Python modules for libhfst

%if ! ( 0%{?el6} || 0%{?el7} )
%package -n python3-libhfst
Summary: Python3 modules for Helsinki Finite-State Transducer Technology
Requires: libhfst48 = %{version}-%{release}

%description -n python3-libhfst
Python3 modules for libhfst
%endif

%prep
%setup -q -n %{name}-%{version}
%patch0 -p1
%patch1 -p1

%build
autoreconf -fi
%configure --disable-static --with-unicode-handler=ICU --enable-all-tools --with-readline
make %{?_smp_mflags} || make %{?_smp_mflags} || make
%if ! ( 0%{?el6} || 0%{?el7} )
cd python
python3 setup.py build_ext
strip --strip-unneeded build/*/*.so
cd ..
%endif

%install
make DESTDIR=%{buildroot} install
rm -f %{buildroot}/%{_libdir}/*.la
rm -f %{buildroot}/%{python_sitelib}/*.py[co]
%if ! ( 0%{?el6} || 0%{?el7} )
cd python
python3 setup.py install --no-compile --prefix /usr --root %{buildroot}
cd ..
%endif

%check
make check

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README THANKS
%{_bindir}/*
%{_datadir}/man/man1/*

%files -n libhfst48
%defattr(-,root,root)
%{_libdir}/*.so.*

%files -n libhfst48-devel
%defattr(-,root,root)
%{_includedir}/*
%{_libdir}/pkgconfig/*
%{_libdir}/*.so
%{_datadir}/aclocal/*

%files -n python-libhfst
%defattr(-,root,root)
%{python_sitelib}/*

%if ! ( 0%{?el6} || 0%{?el7} )
%files -n python3-libhfst
%defattr(-,root,root)
%{python3_sitearch}/*
%endif

%post -n libhfst48 -p /sbin/ldconfig

%postun -n libhfst48 -p /sbin/ldconfig

%changelog
* Fri Dec 19 2014 Tino Didriksen <tino@didriksen.cc> 3.8.2
- New upstream release

* Tue Nov 04 2014 Tino Didriksen <tino@didriksen.cc> 3.8.1
- New upstream release

* Fri Sep 05 2014 Tino Didriksen <tino@didriksen.cc> 3.8.0
- Initial version of the package
