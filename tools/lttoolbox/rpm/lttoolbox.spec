Name: lttoolbox
Version: 3.6.0
Release: 1%{?dist}
Summary: Apertium lexical processing modules and tools
Group: Development/Tools
License: GPL-2.0+
URL: https://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: autoconf
BuildRequires: automake
%if 0%{?el7}
BuildRequires: devtoolset-11-gcc-c++
%endif
BuildRequires: flex
BuildRequires: gawk
BuildRequires: gcc-c++
BuildRequires: libicu-devel
BuildRequires: libtool
BuildRequires: libxml2
BuildRequires: libxml2-devel
BuildRequires: libxslt
BuildRequires: pkgconfig
BuildRequires: python3
BuildRequires: python3-devel
BuildRequires: swig
%if 0%{?suse_version}
BuildRequires: utfcpp-devel
%else
BuildRequires: utf8cpp-devel
%endif
BuildRequires: zlib-devel
Requires: liblttoolbox3 = %{version}-%{release}

%description
The lttoolbox contains the augmented letter transducer tools for natural
language processing used by Apertium, a platform for building rule-based
and hybrid machine translation systems. The software is also useful
for making morphological analysers and generators for natural language
processing applications.

%package -n liblttoolbox3
Summary: Shared library for lttoolbox
Group: Development/Libraries
Provides: liblttoolbox = %{version}-%{release}
Obsoletes: liblttoolbox < %{version}-%{release}

%description -n liblttoolbox3
Contains shared library for lttoolbox

%package -n lttoolbox-devel
Summary: Development tools and library for lttoolbox
Group: Development/Tools
Requires: lttoolbox = %{version}-%{release}
Requires: libicu-devel
%if 0%{?suse_version}
Requires: utfcpp-devel
%else
Requires: utf8cpp-devel
%endif
Obsoletes: liblttoolbox3-devel < %{version}-%{release}

%description -n lttoolbox-devel
Contains development tools and library for lttoolbox.

%package -n python3-lttoolbox
Summary: Python 3 module for the Apertium lexical processing modules and tools
Requires: liblttoolbox3 = %{version}-%{release}

%description -n python3-lttoolbox
Python 3 module for the Apertium lexical processing modules and tools

%prep
%setup -q -n %{name}-%{version}

%build
%if 0%{?el7}
	source /opt/rh/devtoolset-11/enable
%endif
export LC_ALL=%(locale -a | grep -i utf | head -n1)
autoreconf -fi
%configure --disable-static --enable-python-bindings
make %{?_smp_mflags}

%install
%if 0%{?el7}
	source /opt/rh/devtoolset-11/enable
%endif
make DESTDIR=%{buildroot} install
rm -f %{buildroot}/%{_libdir}/*.la

%check
%if 0%{?el7}
	source /opt/rh/devtoolset-11/enable
%endif
export LC_ALL=%(locale -a | grep -i utf | head -n1)
make test

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README
%{_bindir}/lt-merge
%{_bindir}/lt-proc
%{_bindir}/lt-tmxcomp
%{_bindir}/lt-tmxproc
%{_datadir}/man/man1/lt-merge.*
%{_datadir}/man/man1/lt-proc.*
%{_datadir}/man/man1/lt-tmxcomp.*
%{_datadir}/man/man1/lt-tmxproc.*

%files -n liblttoolbox3
%defattr(-,root,root)
%{_libdir}/*.so.*

%files -n lttoolbox-devel
%defattr(-,root,root)
%{_bindir}/lsx-comp
%{_bindir}/lt-append
%{_bindir}/lt-apply-acx
%{_bindir}/lt-comp
%{_bindir}/lt-compose
%{_bindir}/lt-expand
%{_bindir}/lt-invert
%{_bindir}/lt-restrict
%{_bindir}/lt-paradigm
%{_bindir}/lt-print
%{_bindir}/lt-trim
%{_includedir}/*
%{_libdir}/pkgconfig/*
%{_libdir}/*.so
%{_datadir}/%{name}
%{_datadir}/man/man1/lsx-comp.*
%{_datadir}/man/man1/lt-append.*
%{_datadir}/man/man1/lt-comp.*
%{_datadir}/man/man1/lt-compose.*
%{_datadir}/man/man1/lt-expand.*
%{_datadir}/man/man1/lt-paradigm.*
%{_datadir}/man/man1/lt-print.*
%{_datadir}/man/man1/lt-trim.*

%files -n python3-lttoolbox
%defattr(-,root,root)
%{python3_sitearch}/*

%post -n liblttoolbox3 -p /sbin/ldconfig

%postun -n liblttoolbox3 -p /sbin/ldconfig

%changelog
* Fri Sep 05 2014 Tino Didriksen <tino@didriksen.cc> 3.3.0
- Initial version of the package
