Name: trie-tools
Version: 0.8.2.10503
Release: 1%{?dist}
Summary: Tools for creating and working with tries
Group: Development/Tools
License: GPL-3.0+
URL: https://github.com/TinoDidriksen/trie-tools
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: gcc-c++
%if 0%{?el6}
BuildRequires: cmake28 >= 2.8.9
%else
BuildRequires: cmake >= 2.8.9
%endif
BuildRequires: boost-devel >= 1.48.0

%description
Tools for creating, browsing, printing, and working with tries for various
purposes such as spell checking, title browsing, tokenization, etc.


%prep
%setup -q -n %{name}-%{version}

%build
%if 0%{?el6}
%cmake28 .
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
%doc ChangeLog COPYING README.md
%{_bindir}/*

%changelog
* Fri Sep 05 2014 Tino Didriksen <tino@didriksen.cc> 0.8.2.10503
- Initial version of the package
