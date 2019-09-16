Name: apertium-recursive
Version: 0.2.0
Release: 1%{?dist}
Summary: Recursive structural transfer module
Group: Development/Tools
License: GPL-3.0+
URL: https://apertium.org/
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
BuildRequires: python3
BuildRequires: zlib-devel

%description
Apertium module for recursive structural transfer

%prep
%setup -q -n %{name}-%{version}

%build
export LC_ALL=%(locale -a | grep -i utf | head -n1)
autoreconf -fi
%configure
make %{?_smp_mflags}

%install
make DESTDIR=%{buildroot} install

%check
export LC_ALL=%(locale -a | grep -i utf | head -n1)
make test

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README
%{_bindir}/*
%{_libdir}/pkgconfig/*

%changelog
* Sun Mar 04 2018 Tino Didriksen <tino@didriksen.cc> 0.2.0
- Initial version of the package
