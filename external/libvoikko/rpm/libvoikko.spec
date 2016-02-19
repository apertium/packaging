Name:           libvoikko
Version:        4.0.2
Release:        1%{?dist}
Summary:        Voikko is a library for spellcheckers and hyphenators

Group:          System Environment/Libraries
License:        GPLv2+
URL:            http://voikko.puimula.org/
Source0:        %{name}_%{version}.orig.tar.bz2

BuildRequires:  hfst-ospell-devel
BuildRequires:  pkgconfig
BuildRequires:  python-devel

%description
Libvoikko is a library of free natural language processing tools. It
aims to provide support for languages that are not well served by
other existing free linguistic tools.

%package        devel
Summary:        Development files for %{name}
Group:          Development/Libraries
Requires:       %{name}%{?_isa} = %{version}-%{release}
Requires:       pkgconfig

%description    devel
The %{name}-devel package contains libraries and header files for
developing applications that use %{name}.

%package -n     voikko-tools
Summary:        Test tools for %{name}
Group:          Applications/Text
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description -n voikko-tools
This package contains voikkospell and voikkohyphenate, small command line
tools for testing libvoikko. These tools may also be useful for shell
scripts.

%package -n     python-libvoikko
Summary:        Python interface to %{name}
Group:          Development/Libraries
Requires:       %{name} = %{version}-%{release}
BuildArch:      noarch

%description -n python-libvoikko
Python interface to libvoikko, library of language tools.
This module can be used to perform various natural language analysis
tasks on text.


%prep
%setup -q -n %{name}-%{version}


%build
%configure --with-dictionary-path=%{_libdir}/voikko:%{_datadir}/voikko:/usr/lib/voikko
make %{?_smp_mflags}


%install
make install INSTALL="install -p" DESTDIR=$RPM_BUILD_ROOT
find $RPM_BUILD_ROOT -name '*.la' -exec rm -f {} ';'
find $RPM_BUILD_ROOT -name '*.a' -exec rm -f {} ';'
install -d $RPM_BUILD_ROOT%{python_sitelib}
install -pm 0644 python/libvoikko.py $RPM_BUILD_ROOT%{python_sitelib}/


%post -p /sbin/ldconfig

%postun -p /sbin/ldconfig


%files
%defattr(-,root,root)
%doc ChangeLog COPYING README
%{_libdir}/*.so.*

%files -n voikko-tools
%defattr(-,root,root)
%{_bindir}/*
%{_mandir}/man1/*

%files devel
%defattr(-,root,root)
%{_includedir}/*
%{_libdir}/*.so
%{_libdir}/pkgconfig/*

%files -n python-libvoikko
%defattr(-,root,root)
%{python_sitelib}/*

%changelog
* Fri Feb 19 2016 Tino Didriksen <tino@didriksen.cc> 4.0.2
- Packaging based on work by Ville-Pekka Vainio <vpvainio AT iki.fi>
