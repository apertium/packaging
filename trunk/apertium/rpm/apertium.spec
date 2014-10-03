Name: apertium
Version: 3.3.0
Release: 1%{?dist}
Summary: Shallow-transfer machine translation engine
Group: Development/Tools
License: GPL-2.0+
URL: http://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2

Requires: lttoolbox >= 3.3
# Require xmllint from:
Requires: libxml2
# Require xsltproc from:
Requires: libxslt

BuildRequires: autoconf
BuildRequires: automake
BuildRequires: flex
BuildRequires: gcc-c++
BuildRequires: liblttoolbox3-3_3-devel
BuildRequires: libtool
BuildRequires: libxml2
BuildRequires: libxml2-devel
BuildRequires: libxslt
BuildRequires: pcre-devel
BuildRequires: pkgconfig

%description
An open-source shallow-transfer machine translation
engine, Apertium is initially aimed at related-language pairs.

It uses finite-state transducers for lexical processing,
hidden Markov models for part-of-speech tagging, and
finite-state based chunking for structural transfer.

The system is largely based upon systems already developed by
the Transducens  group at the Universitat d'Alacant, such as
interNOSTRUM (Spanish-Catalan, http://www.internostrum.com/welcome.php)
and Traductor Universia (Spanish-Portuguese,
http://traductor.universia.net).

It will be possible to use Apertium to build machine translation
systems for a variety of related-language pairs simply providing
the linguistic data needed in the right format.

%package -n libapertium3-3_3-0
Summary: Shared library for apertium
Group: Development/Libraries
Provides: libapertium3 = %{version}-%{release}

%description -n libapertium3-3_3-0
Contains shared library for the Apertium shallow-transfer
machine translation engine.

%package -n libapertium3-3_3-devel
Summary: Development library for apertium
Group: Development/Libraries
Requires: libapertium3-3_3-0 = %{version}-%{release}
Provides: libapertium3-devel = %{version}-%{release}

%description -n libapertium3-3_3-devel
Contains development files for the Apertium shallow-transfer
machine translation engine.

%prep
%setup -q -n %{name}-%{version}

%build
autoreconf -fi
%configure
make %{?_smp_mflags} || make %{?_smp_mflags} || make

%install
make DESTDIR=%{buildroot} install
rm -f %{buildroot}/%{_libdir}/*.la
ln -s libapertium3-3.3.so.0.0.0 %{buildroot}/%{_libdir}/libapertium3-3.3.so

%files
%defattr(-,root,root)
%doc AUTHORS NEWS README README-MODES
%{_bindir}/*
%{_datadir}/%{name}
%{_datadir}/man/man1/*

%files -n libapertium3-3_3-0
%defattr(-,root,root)
%{_libdir}/*.so.*

%files -n libapertium3-3_3-devel
%defattr(-,root,root)
%{_includedir}/*
%{_libdir}/pkgconfig/*
%{_libdir}/*.a*
%{_libdir}/*.so
%{_datadir}/aclocal/*

%post -n libapertium3-3_3-0 -p /sbin/ldconfig

%postun -n libapertium3-3_3-0 -p /sbin/ldconfig

%changelog
* Fri Sep 05 2014 Tino Didriksen <mail@tinodidriksen.com> 3.3.0
- Initial version of the package
