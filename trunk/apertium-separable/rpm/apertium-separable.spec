Name: apertium-separable
Version: 0.2.0
Release: 1%{?dist}
Summary: Reordering separable/discontiguous multiwords
Group: Development/Tools
License: GPL-3.0+
URL: http://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: apertium-devel
BuildRequires: gcc-c++
BuildRequires: lttoolbox-devel
BuildRequires: libtool
BuildRequires: libxml2-devel
BuildRequires: pcre-devel
BuildRequires: pkgconfig
BuildRequires: zlib-devel

%description
Apertium module for reordering separable/discontiguous multiwords

%prep
%setup -q -n %{name}-%{version}

%build
autoreconf -fi
%configure
make %{?_smp_mflags} || make %{?_smp_mflags} || make

%install
make DESTDIR=%{buildroot} install

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README
%{_bindir}/*
%{_datadir}/%{name}

%changelog
* Sun Mar 04 2018 Tino Didriksen <tino@didriksen.cc> 0.2.0
- Initial version of the package
