Name: apertium-lex-tools
Version: 0.1.0
Release: 1%{?dist}
Summary: Constraint-based lexical selection module
Group: Development/Tools
License: GPL-3.0
URL: http://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: gcc-c++
BuildRequires: apertium-devel
BuildRequires: libtool
BuildRequires: libxml2
BuildRequires: libxml2-devel
BuildRequires: pkgconfig
BuildRequires: zlib-devel

%description
Constraint-based lexical selection module used by Apertium

%prep
%setup -q -n %{name}-%{version}

%build
autoreconf -fi
%configure
make %{?_smp_mflags} || make %{?_smp_mflags} || make

%install
make DESTDIR=%{buildroot} install
rm -f %{buildroot}/%{_libdir}/*.la

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README
%{_bindir}/*

%changelog
* Sun Jan 18 2015 Tino Didriksen <mail@tinodidriksen.com> 0.1.0
- Initial version of the package
