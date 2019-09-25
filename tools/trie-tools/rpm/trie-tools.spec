Name: trie-tools
Version: 0.8.2.10503
Release: 1%{?dist}
Summary: Tools for creating and working with tries
Group: Development/Tools
License: GPL-3.0+
URL: https://github.com/TinoDidriksen/trie-tools
Source0: %{name}_%{version}.orig.tar.bz2

BuildRequires: gcc-c++
%if 0%{?el7}
BuildRequires: cmake3
# Multiple packages provide libpython27, so picking the one from CentOS main repo
BuildRequires: python-libs
%else
BuildRequires: cmake >= 3.0
%endif
BuildRequires: boost-devel

%description
Tools for creating, browsing, printing, and working with tries for various
purposes such as spell checking, title browsing, tokenization, etc.


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
%doc ChangeLog COPYING README.md
%{_bindir}/*

%changelog
* Fri Sep 05 2014 Tino Didriksen <tino@didriksen.cc> 0.8.2.10503
- Initial version of the package
