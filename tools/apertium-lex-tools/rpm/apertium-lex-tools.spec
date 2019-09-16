Name: apertium-lex-tools
Version: 0.2.1
Release: 1%{?dist}
Summary: Constraint-based lexical selection module
Group: Development/Tools
License: GPL-3.0
URL: https://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: apertium-devel
BuildRequires: autoconf
BuildRequires: automake
BuildRequires: gcc-c++
BuildRequires: libtool
BuildRequires: libxml2
BuildRequires: libxml2-devel
BuildRequires: pcre-devel
BuildRequires: pkgconfig
BuildRequires: python3
BuildRequires: python3-devel
BuildRequires: swig
BuildRequires: zlib-devel

%description
Constraint-based lexical selection module used by Apertium

%package -n python3-apertium-lex-tools
Summary: Python 3 module for Apertium lexical selection module
Requires: apertium-lex-tools = %{version}-%{release}

%description -n python3-apertium-lex-tools
Python 3 module for Apertium lexical selection module

%prep
%setup -q -n %{name}-%{version}

%build
export LC_ALL=%(locale -a | grep -i utf | head -n1)
autoreconf -fi
%configure --enable-python-bindings
make %{?_smp_mflags}

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
%{_libdir}/pkgconfig/*

%files -n python3-apertium-lex-tools
%defattr(-,root,root)
%{python3_sitearch}/*

%changelog
* Sun Jan 18 2015 Tino Didriksen <tino@didriksen.cc> 0.2.1
- Initial version of the package
