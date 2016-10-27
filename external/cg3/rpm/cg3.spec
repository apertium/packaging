Name: cg3
Version: 0.9.8.10184
Release: 1%{?dist}
Summary: Tools for using the 3rd edition of Constraint Grammar (CG-3)
Group: Development/Tools
License: GPL-3.0+
URL: http://visl.sdu.dk/cg3.html
Source0: %{name}_%{version}.orig.tar.bz2
Provides: vislcg3 = %{version}-%{release}

BuildRequires: gcc-c++
BuildRequires: cmake >= 2.8.9
BuildRequires: boost-devel >= 1.48.0
BuildRequires: libicu-devel >= 4.2
BuildRequires: pkgconfig
# OpenSUSE can't detect Perl dependencies, so list them
Requires: perl(Digest::SHA1)
Requires: perl(File::Spec)
Requires: perl(Getopt::Long)

%description
Constraint Grammar compiler and applicator for the 3rd edition of CG
that is developed and maintained by VISL SDU and GrammarSoft ApS.

CG-3 can be used for disambiguation of morphology, syntax, semantics, etc;
dependency markup, target language lemma choice for MT, QA systems, and
much more. The core idea is that you choose what to do based on the whole
available context, as opposed to n-grams.

See http://visl.sdu.dk/cg3.html for more documentation

%package -n libcg3-0
Summary: Runtime for CG-3
Group: Development/Libraries
Provides: libcg3 = %{version}-%{release}
Obsoletes: libcg3 < %{version}-%{release}

%description -n libcg3-0
Runtime library for applications using the CG-3 API.

It is recommended to instrument the CLI tools instead of using this API.

See http://visl.sdu.dk/cg3.html for more documentation


%package -n libcg3-devel
Summary: Headers and static library to develop using the CG-3 library
Group: Development/Libraries
Requires: libcg3-0 = %{version}-%{release}

%description -n libcg3-devel
Development files to use the CG-3 API.

It is recommended to instrument the CLI tools instead of using this API.

See http://visl.sdu.dk/cg3.html for more documentation


%prep
%setup -q -n %{name}-%{version}

%build
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
ln -s vislcg3 %{buildroot}%{_bindir}/cg3
ln -s vislcg3.1.gz %{buildroot}%{_datadir}/man/man1/cg3.1.gz

# Breaks under CentOS 6's own CMake, for some odd reason
%if !0%{?el6}
%check
make test
%endif

%files
%defattr(-,root,root)
%doc AUTHORS ChangeLog COPYING README.md TODO
%{_bindir}/*
%{_datadir}/man/man1/*
%{_datadir}/emacs/site-lisp/*

%files -n libcg3-0
%defattr(-,root,root)
%{_libdir}/*.so.*

%files -n libcg3-devel
%defattr(-,root,root)
%{_includedir}/*
%{_libdir}/pkgconfig/*
%{_libdir}/*.so

%post -n libcg3-0 -p /sbin/ldconfig

%postun -n libcg3-0 -p /sbin/ldconfig

%changelog
* Fri Sep 05 2014 Tino Didriksen <tino@didriksen.cc> 0.9.8.10063-1
- Initial version of the package
