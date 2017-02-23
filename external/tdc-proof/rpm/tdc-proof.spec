Name: tdc-proof
Version: 1.0.0.r97
Release: 1%{?dist}
Summary: Wrappers to integrate HFST-based proofing tools with frontends
Group: Development/Tools
License: GPL-3.0+
URL: https://github.com/TinoDidriksen/spellers
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: gcc-c++
%if 0%{?el7}
BuildRequires: cmake3 >= 3.0
%else
BuildRequires: cmake >= 3.0
%endif
BuildRequires: glibc-devel
BuildRequires: pkgconfig
BuildRequires: hfst-ospell-devel

%description
Proofing tool wrappers for HFST-based spellers, hyphenators,
and grammar checkers


%prep
%setup -q -n %{name}-%{version}

%build
%if 0%{?el6}
%cmake3 .
%else
%if 0%{?suse_version}
%cmake
%else
%cmake .
%endif
%endif
make %{?_smp_mflags}

%install
%if 0%{?suse_version}
%cmake_install
%else
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT
%endif

%files
%defattr(-,root,root)
%doc COPYING README.md
%{_libdir}/*

%changelog
* Fri Sep 05 2014 Tino Didriksen <tino@didriksen.cc> 1.0.0.r97
- Initial version of the package
