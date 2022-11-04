Name: libdivvun
Version: 0.2.0
Release: 1%{?dist}
Summary: Grammar checker tools for Divvun languages
Group: Development/Tools
License: GPL-3.0+
URL: https://github.com/divvun/libdivvun
Source0: %{name}_%{version}.orig.tar.bz2

%if 0%{?el7}
BuildRequires: devtoolset-11-gcc-c++
%endif
BuildRequires: autoconf
BuildRequires: automake
BuildRequires: gawk
BuildRequires: gcc-c++
BuildRequires: hfst-ospell-devel
BuildRequires: libarchive-devel
BuildRequires: libcg3-devel
BuildRequires: libhfst-devel
BuildRequires: libtool
BuildRequires: libxml2
BuildRequires: swig
BuildRequires: pkgconfig
BuildRequires: pugixml-devel
BuildRequires: python3
BuildRequires: python3-devel
BuildRequires: zip
Requires: libdivvun0 = %{version}-%{release}
Provides: divvun-gramcheck = %{version}-%{release}
Provides: libdivvun-bin = %{version}-%{release}
Provides: libdivvun-tools = %{version}-%{release}

%description
Helper tools for grammar checking for Divvun languages

%package -n libdivvun0
Summary: Runtime for Divvun grammar checker

%description -n libdivvun0
Runtime library for applications using the Divvun grammar checker API

%package -n libdivvun-devel
Summary: Headers and shared files to develop using the Divvun grammar checker library
Group: Development/Libraries
Requires: divvun-gramcheck = %{version}-%{release}

%description -n libdivvun-devel
Development files to use the Divvun grammar checker API

%package -n python3-libdivvun
Summary: Runtime for Divvun grammar checker (Python 3 module)
Requires: libdivvun0 = %{version}-%{release}

%description -n python3-libdivvun
Python 3 module for applications using the Divvun grammar checker API

%prep
%setup -q -n %{name}-%{version}

%build
%if 0%{?el7}
	source /opt/rh/devtoolset-11/enable
%endif
autoreconf -fvi
%configure --enable-checker --enable-cgspell --enable-python-bindings
make %{?_smp_mflags}

%install
%if 0%{?el7}
	source /opt/rh/devtoolset-11/enable
%endif
make DESTDIR=%{buildroot} install
find %{buildroot}/%{_libdir}/ -type f -name '*.pyc' -exec rm -f '{}' \;
find %{buildroot}/%{_libdir}/ -type f -name '*.pyo' -exec rm -f '{}' \;
find %{buildroot}/%{_libdir}/ -type f -name '*.la' -exec rm -f '{}' \;
find %{buildroot}/%{_libdir}/ -type f -name '*.a' -exec rm -f '{}' \;

%check
%if 0%{?el7}
	source /opt/rh/devtoolset-11/enable
%endif
export LC_ALL=%(locale -a | grep -i utf | head -n1)
make check

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README README.org
%{_bindir}/*
%{_datadir}/man/man1/*
%{_datadir}/divvun-gramcheck

%files -n libdivvun0
%defattr(-,root,root)
%{_libdir}/*.so.*

%files -n libdivvun-devel
%defattr(-,root,root)
%{_includedir}/*
%{_libdir}/*.so

%files -n python3-libdivvun
%defattr(-,root,root)
%{python3_sitearch}/*

%post -n libdivvun0 -p /sbin/ldconfig

%postun -n libdivvun0 -p /sbin/ldconfig

%changelog
* Fri Dec 19 2014 Tino Didriksen <tino@didriksen.cc> 0.2.0
- Initial release
