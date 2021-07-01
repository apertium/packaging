Name: apertium-separable
Version: 0.3.0
Release: 1%{?dist}
Summary: Reordering separable/discontiguous multiwords
Group: Development/Tools
License: GPL-3.0+
URL: https://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: gcc-c++
BuildRequires: lttoolbox-devel
BuildRequires: libicu-devel
BuildRequires: libtool
BuildRequires: libxml2-devel
BuildRequires: pkgconfig

%description
Apertium module for reordering separable/discontiguous multiwords

%prep
%setup -q -n %{name}-%{version}

%build
export LC_ALL=%(locale -a | grep -i utf | head -n1)
autoreconf -fi
%configure
make %{?_smp_mflags} || make %{?_smp_mflags} || make

%install
make DESTDIR=%{buildroot} install

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README
%{_bindir}/*
%{_libdir}/pkgconfig/*

%changelog
* Sun Mar 04 2018 Tino Didriksen <tino@didriksen.cc> 0.2.0
- Initial version of the package
