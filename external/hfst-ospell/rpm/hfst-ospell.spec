Name: hfst-ospell
Version: 0.4.0
Release: 1%{?dist}
Summary: Spell checker library and tool based on HFST
Group: Development/Tools
License: Apache-2.0
URL: http://www.ling.helsinki.fi/kieliteknologia/tutkimus/hfst/
Source0: %{name}_%{version}.orig.tar.bz2
Patch0: hfst-ospell_01_notimestamp.diff

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: gcc-c++
BuildRequires: libtool
BuildRequires: pkgconfig
BuildRequires: hfst
BuildRequires: libarchive-devel
BuildRequires: libicu-devel
BuildRequires: libxml++-devel
BuildRequires: zip

%description
Minimal HFST optimized lookup format based spell checker library and
a demonstrational implementation of command line based spell checker.

%package -n libhfstospell8
Summary: HFST spell checker runtime libraries
Group: Development/Libraries
Provides: libhfstospell = %{version}-%{release}
Obsoletes: libhfstospell < %{version}-%{release}

%description -n libhfstospell8
Runtime libraries for hfst-ospell

%package -n hfst-ospell-devel
Summary: HFST spell checker development files
Group: Development/Libraries
Requires: hfst-ospell = %{version}-%{release}

%description -n hfst-ospell-devel
Development headers and libraries for hfst-ospell

%prep
%setup -q -n %{name}-%{version}
%patch0 -p1

%build
autoreconf -fi
%configure --disable-static --enable-zhfst
make %{?_smp_mflags} || make %{?_smp_mflags} || make

%install
make DESTDIR=%{buildroot} install
rm -f %{buildroot}/%{_libdir}/*.la

%check
make check

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README
%{_bindir}/*
%{_datadir}/man/man1/*

%files -n libhfstospell8
%defattr(-,root,root)
%{_libdir}/*.so.*

%files -n hfst-ospell-devel
%defattr(-,root,root)
%{_includedir}/*
%{_libdir}/pkgconfig/*
%{_libdir}/*.so

%post -n libhfstospell8 -p /sbin/ldconfig

%postun -n libhfstospell8 -p /sbin/ldconfig

%changelog
* Fri Sep 05 2014 Tino Didriksen <tino@didriksen.cc> 0.4.0
- Initial version of the package
