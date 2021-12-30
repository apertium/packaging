Name: apertium-lex-tools
Version: 0.3.0
Release: 1%{?dist}
Summary: Constraint-based lexical selection module
Group: Development/Tools
License: GPL-3.0
URL: https://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: gcc-c++
BuildRequires: libicu-devel
BuildRequires: libtool
BuildRequires: libxml2-devel
BuildRequires: lttoolbox-devel
BuildRequires: pkgconfig
%if 0%{?el7}
BuildRequires: devtoolset-7-gcc-c++
%else
BuildRequires: python3
BuildRequires: python3-devel
BuildRequires: swig
%endif

%description
Constraint-based lexical selection module used by Apertium

%if ! ( 0%{?el7} )
%package -n python3-apertium-lex-tools
Summary: Python 3 module for Apertium lexical selection module
Requires: apertium-lex-tools = %{version}-%{release}

%description -n python3-apertium-lex-tools
Python 3 module for Apertium lexical selection module
%endif

%prep
%setup -q -n %{name}-%{version}

%build
export LC_ALL=%(locale -a | grep -i utf | head -n1)
%if 0%{?el7}
	source /opt/rh/devtoolset-7/enable
	autoreconf -fi
	%configure --enable-yasmet
%else
	autoreconf -fi
	%configure --enable-yasmet --enable-python-bindings
%endif
make %{?_smp_mflags}

%install
%if 0%{?el7}
	source /opt/rh/devtoolset-7/enable
%endif
make DESTDIR=%{buildroot} install
rm -f %{buildroot}/%{_libdir}/*.la

%check
export LC_ALL=%(locale -a | grep -i utf | head -n1)
make check

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README
%{_bindir}/*
%{_datadir}/%{name}
%{_libdir}/pkgconfig/*

%if ! ( 0%{?el7} )
%files -n python3-apertium-lex-tools
%defattr(-,root,root)
%{python3_sitearch}/*
%endif

%changelog
* Fri Dec 25 2020 Tino Didriksen <tino@didriksen.cc> 0.2.7
- Latest upstream release
