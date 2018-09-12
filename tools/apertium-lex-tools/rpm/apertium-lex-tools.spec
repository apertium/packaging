Name: apertium-lex-tools
Version: 0.1.0
Release: 1%{?dist}
Summary: Constraint-based lexical selection module
Group: Development/Tools
License: GPL-3.0
URL: https://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: gcc-c++
BuildRequires: apertium-devel
BuildRequires: libtool
BuildRequires: libxml2
BuildRequires: libxml2-devel
BuildRequires: pkgconfig
BuildRequires: pcre-devel
BuildRequires: zlib-devel

%description
Constraint-based lexical selection module used by Apertium

%prep
%setup -q -n %{name}-%{version}

%build
export LC_ALL=%(locale -a | grep -i utf | head -n1)
autoreconf -fi
%configure
make %{?_smp_mflags} || make %{?_smp_mflags} || make

%install
make DESTDIR=%{buildroot} install
rm -f %{buildroot}/%{_libdir}/*.la

%check
export LC_ALL=%(locale -a | grep -i utf | head -n1)
make check

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README
%{_bindir}/*

%changelog
* Sun Jan 18 2015 Tino Didriksen <tino@didriksen.cc> 0.1.0
- Initial version of the package
