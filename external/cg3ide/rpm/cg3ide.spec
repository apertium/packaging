Name: cg3ide
Version: 0.6.0.9508
Release: 1%{?dist}
Summary: IDE for CG-3
Group: Development/Tools
License: GPL-3.0+
URL: http://visl.sdu.dk/cg3.html
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: gcc-c++
BuildRequires: pkgconfig
%if 0%{?suse_version}
BuildRequires: libqt5-qtbase-devel
%else
BuildRequires: qt5-qtbase-devel
%endif
Requires: cg3

%description
IDE for developing and debugging CG-3 grammars.


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
cp cg3ide cg3processor %{buildroot}%{_bindir}/

%files
%defattr(-,root,root)
%doc AUTHORS ChangeLog COPYING TODO
%{_bindir}/*

%changelog
* Fri Sep 05 2014 Tino Didriksen <tino@didriksen.cc> 0.6.0.9508-1
- Initial version of the package
