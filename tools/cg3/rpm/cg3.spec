Name: cg3
Version: 1.3.0
Release: 1%{?dist}
Summary: Tools for using the 3rd edition of Constraint Grammar (CG-3)
Group: Development/Tools
License: GPL-3.0+
URL: https://visl.sdu.dk/cg3.html
Source0: %{name}_%{version}.orig.tar.bz2
Provides: vislcg3 = %{version}-%{release}

BuildRequires: gcc-c++
%if 0%{?el7}
BuildRequires: devtoolset-11-gcc-c++
BuildRequires: cmake3
# Multiple packages provide libpython27, so picking the one from CentOS main repo
BuildRequires: python-libs
%else
BuildRequires: cmake >= 3.0.0
%endif
BuildRequires: boost-devel
BuildRequires: libicu-devel
BuildRequires: sqlite-devel
BuildRequires: pkgconfig
%if ! ( 0%{?el7} )
BuildRequires: swig
BuildRequires: python3
BuildRequires: python3-devel
%endif

Requires: libcg3-1 = %{version}-%{release}
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

See https://visl.sdu.dk/cg3.html for more documentation

%package -n libcg3-1
Summary: Runtime for CG-3
Group: Development/Libraries
Provides: libcg3 = %{version}-%{release}
Obsoletes: libcg3 < %{version}-%{release}

%description -n libcg3-1
Runtime library for applications using the CG-3 API.

It is recommended to instrument the CLI tools instead of using this API.

See https://visl.sdu.dk/cg3.html for more documentation


%package -n libcg3-devel
Summary: Headers and static library to develop using the CG-3 library
Group: Development/Libraries
Requires: libcg3-1 = %{version}-%{release}

%description -n libcg3-devel
Development files to use the CG-3 API.

It is recommended to instrument the CLI tools instead of using this API.

See https://visl.sdu.dk/cg3.html for more documentation


%package -n cg3-devel
Summary: Metapackage providing both CG-3 CLI dev tools and dev library
Group: Development/Tools
Requires: cg3 = %{version}-%{release}
Requires: libcg3-devel = %{version}-%{release}

%description -n cg3-devel
Development files to use the CG-3 CLI tools and library API.

See https://visl.sdu.dk/cg3.html for more documentation


%if ! ( 0%{?el7} )
%package -n python3-cg3
Summary: Python 3 module for CG-3
Requires: libcg3-1 = %{version}-%{release}

%description -n python3-cg3
Python 3 module for CG-3
%endif


%prep
%setup -q -n %{name}-%{version}

%build
%if 0%{?suse_version}
	%cmake -DCMAKE_BUILD_RPATH_USE_ORIGIN=ON -DENABLE_PYTHON_BINDINGS=ON
%else
	%if 0%{?el7}
		source /opt/rh/devtoolset-11/enable
		%cmake3 .
	%else
		%cmake -DCMAKE_BUILD_RPATH_USE_ORIGIN=ON -DENABLE_PYTHON_BINDINGS=ON .
	%endif
%endif
%if 0%{?fedora} >= 33
	%cmake_build %{?_smp_mflags}
%else
	make %{?_smp_mflags}
%endif

%install
%if 0%{?el7}
	source /opt/rh/devtoolset-11/enable
%endif
%if 0%{?suse_version} || 0%{?fedora} >= 33
	%cmake_install
%else
	rm -rf $RPM_BUILD_ROOT
	make install DESTDIR=$RPM_BUILD_ROOT
%endif
rm -f %{buildroot}/%{python3_sitelib}/*.py[co]
ln -s vislcg3 %{buildroot}%{_bindir}/cg3
ln -s vislcg3.1.gz %{buildroot}%{_datadir}/man/man1/cg3.1.gz

%check
%if 0%{?fedora} >= 33
	cd %{_vpath_builddir}
%endif
make test

%files
%defattr(-,root,root)
%doc AUTHORS COPYING README.md
%{_bindir}/*
%{_datadir}/man/man1/*
%{_datadir}/emacs/site-lisp/*

%files -n libcg3-1
%defattr(-,root,root)
%{_libdir}/*.so.*

%files -n libcg3-devel
%defattr(-,root,root)
%{_includedir}/*
%{_libdir}/pkgconfig/*
%{_libdir}/*.so

%if ! ( 0%{?el7} )
%files -n python3-cg3
%defattr(-,root,root)
%{python3_sitearch}/*
%endif

%post -n libcg3-1 -p /sbin/ldconfig

%postun -n libcg3-1 -p /sbin/ldconfig

%changelog
* Fri Sep 05 2014 Tino Didriksen <tino@didriksen.cc> 0.9.8.10063-1
- Initial version of the package
