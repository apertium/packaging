Name: apertium-init
Version: 2.3.0
Release: 1%{?dist}
Summary: Helper to create and re-create Apertium languages and pairs
Group: Development/Tools
License: GPL-3.0+
URL: https://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2
BuildArch: noarch

Requires: apertium-devel >= 3.8.0
Requires: python3

%description
Helper to create and re-create Apertium languages and pairs

%prep
%setup -q -n %{name}-%{version}

%build
make %{?_smp_mflags}

%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT PREFIX=/usr

%files
%defattr(-,root,root)
%doc README.md
%{_bindir}/*

%changelog
* Thu Sep 17 2020 Tino Didriksen <tino@didriksen.cc> 2.3.0
- Initial version of the package
