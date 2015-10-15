Name: hfst-ospell
Version: 0.3.1
Release: 1%{?dist}
Summary: Spell checker library and tool based on HFST
Group: Development/Tools
License: Apache-2.0
URL: http://www.ling.helsinki.fi/kieliteknologia/tutkimus/hfst/
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: gcc-c++
BuildRequires: libtool
BuildRequires: pkgconfig
BuildRequires: hfst
BuildRequires: libarchive-devel
BuildRequires: libicu-devel
BuildRequires: libxml++-devel

%description
Minimal HFST optimized lookup format based spell checker library and
a demonstrational implementation of command line based spell checker.

%package -n hfst-ospell-devel
Summary: HFST spell checker Development files
Group: Development/Libraries
Requires: hfst-ospell = %{version}-%{release}

%description -n hfst-ospell-devel
Development headers and libraries for hfst-ospell

%prep
%setup -q -n %{name}-%{version}

%build
autoreconf -fi
%configure --disable-static --enable-zhfst
make %{?_smp_mflags} || make %{?_smp_mflags} || make

%install
make DESTDIR=%{buildroot} install
rm -f %{buildroot}/%{_libdir}/*.la

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README
%{_bindir}/*
%{_datadir}/man/man1/*
%{_libdir}/*.so.*

%files -n hfst-ospell-devel
%defattr(-,root,root)
%{_includedir}/*
%{_libdir}/pkgconfig/*
%{_libdir}/*.so

%post -p /sbin/ldconfig

%postun -p /sbin/ldconfig

%changelog
* Fri Sep 05 2014 Tino Didriksen <mail@tinodidriksen.com> 0.3.1
- Initial version of the package
