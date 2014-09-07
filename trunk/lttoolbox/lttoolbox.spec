Name: lttoolbox
Version: 3.3.0
Release: 1%{?dist}
Summary: Apertium lexical processing modules and tools
Group: Development/Tools
License: GPL-2.0+
URL: http://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: pkgconfig
BuildRequires: autoconf
BuildRequires: automake
BuildRequires: gcc-c++
BuildRequires: libxml2
BuildRequires: libxml2-devel
BuildRequires: zlib-devel
BuildRequires: gawk
BuildRequires: libxslt
BuildRequires: flex
BuildRequires: pcre-devel
BuildRequires: libtool

%description
The lttoolbox contains the augmented letter transducer tools for natural
language processing used by Apertium, a platform for building rule-based
and hybrid machine translation systems. The software is also useful
for making morphological analysers and generators for natural language
processing applications.

%package -n liblttoolbox3-3_3-0
Summary: Shared library for lttoolbox
Group: Development/Libraries
Provides: liblttoolbox3 = %{version}-%{release}

%description -n liblttoolbox3-3_3-0
Contains shared library for lttoolbox

%package -n liblttoolbox3-3_3-devel
Summary: Development library for lttoolbox
Group: Development/Libraries
Requires: liblttoolbox3-3_3-0 = %{version}-%{release}
Provides: liblttoolbox3-devel = %{version}-%{release}

%description -n liblttoolbox3-3_3-devel
Contains development library for lttoolbox.

%prep
%setup -q -n %{name}-%{version}

%build
autoreconf -fi
%configure
make %{?_smp_mflags}
make %{?_smp_mflags}
make

%install
make DESTDIR=%{buildroot} install
rm -f %{buildroot}/%{_libdir}/*.la
ln -s liblttoolbox3-3.3.so.0.0.0 %{buildroot}/%{_libdir}/liblttoolbox3-3.3.so

%files
%doc AUTHORS NEWS README
%{_bindir}/*
%{_datadir}/%{name}
%{_datadir}/man/man1/*

%files -n liblttoolbox3-3_3-0
%{_libdir}/*.so.*

%files -n liblttoolbox3-3_3-devel
%{_includedir}/*
%{_libdir}/pkgconfig/*
%{_libdir}/*.a*
%{_libdir}/*.so

%post -n liblttoolbox3-3_3-0 -p /sbin/ldconfig

%postun -n liblttoolbox3-3_3-0 -p /sbin/ldconfig

%changelog
* Fri Sep 05 2014 Tino Didriksen <mail@tinodidriksen.com> 3.3.0
- Initial version of the package
