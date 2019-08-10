Name: apertium-anaphora
Version: 0.0.1
Release: 1%{?dist}
Summary: Anaphora resolution module
Group: Development/Tools
License: GPL-3.0
URL: https://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: cmake
BuildRequires: gcc-c++
BuildRequires: lttoolbox-devel
BuildRequires: libtool
BuildRequires: libxml2-devel
BuildRequires: pkgconfig

%description
Anaphora resolution module used by Apertium

%prep
%setup -q -n %{name}-%{version}

%build
export LC_ALL=%(locale -a | grep -i utf | head -n1)
%if 0%{?suse_version}
%cmake
%else
%cmake .
%endif
make %{?_smp_mflags}

%install
%if 0%{?suse_version}
%cmake_install
%else
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT
%endif
rm -f %{buildroot}/%{_libdir}/*.la

%files
%defattr(-,root,root)
%{_bindir}/*

%changelog
* Sun Jan 18 2015 Tino Didriksen <tino@didriksen.cc> 0.0.1
- Initial version of the package
