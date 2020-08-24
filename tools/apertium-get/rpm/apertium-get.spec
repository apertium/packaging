Name: apertium-get
Version: 1.0.0
Release: 1%{?dist}
Summary: Helper to download and build Apertium and Giellatekno languages and pairs
Group: Development/Tools
License: GPL-3.0+
URL: https://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2
BuildArch: noarch

%if 0%{?el7}
BuildRequires: cmake3
%else
BuildRequires: cmake >= 3.0.0
%endif

Requires: apertium-devel >= 3.6.0

%description
Script to download and build Apertium and Giellatekno languages and pairs

%prep
%setup -q -n %{name}-%{version}

%build
%if 0%{?suse_version}
%cmake
%else
%if 0%{?el7}
%cmake3 .
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
%doc README.org
%{_bindir}/*

%changelog
* Mon Aug 24 2020 Tino Didriksen <tino@didriksen.cc> 1.0.0
- Initial version of the package
