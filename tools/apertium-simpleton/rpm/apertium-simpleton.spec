Name: apertium-simpleton
Version: 0.1.0
Release: 1%{?dist}
Summary: Minimal GUI for Apertium
Group: Development/Tools
License: GPL-3.0+
URL: https://wiki.apertium.org/wiki/Apertium_Simpleton_UI
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: gcc-c++
BuildRequires: pkgconfig
%if 0%{?suse_version}
BuildRequires: libqt5-qtbase-devel
%else
BuildRequires: qt5-qtbase-devel
%endif
Requires: apertium
Requires: binutils
Requires: cg3
Requires: lttoolbox
Requires: hfst

%description
Minimal GUI for Apertium translations.


%prep
%setup -q -n %{name}-%{version}

%build
rm -rf build
mkdir build
cd build
%if 0%{?suse_version}
qmake-qt5 QMAKE_CFLAGS+="%optflags" QMAKE_CXXFLAGS+="%optflags" QMAKE_STRIP="/bin/true" ../%{name}.pro
%else
%_qt5_qmake ../%{name}.pro
%endif
make %{?_smp_mflags}

%install
cd build
install -d %{buildroot}%{_bindir}
cp apertium-simpleton %{buildroot}%{_bindir}/

%files
%defattr(-,root,root)
%doc AUTHORS ChangeLog COPYING
%{_bindir}/*

%changelog
* Fri Sep 05 2014 Tino Didriksen <tino@didriksen.cc> 0.1.0-1
- Initial version of the package
