Name:           libvoikko
Version:        4.0.2
Release:        1%{?dist}
Summary:        Voikko is a library for spellcheckers and hyphenators

Group:          System Environment/Libraries
License:        GPL-2.0+
URL:            http://voikko.puimula.org/
Source0:        %{name}_%{version}.orig.tar.bz2

BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  gcc-c++
BuildRequires:  hfst-ospell-devel
BuildRequires:  libtool
BuildRequires:  pkgconfig
BuildRequires:  python3-devel

%description
Libvoikko is a library of free natural language processing tools. It
aims to provide support for languages that are not well served by
other existing free linguistic tools.

%package -n     libvoikko1
Summary:        Voikko is a library for spellcheckers and hyphenators
Group:          System Environment/Libraries
Provides:       libvoikko = %{version}-%{release}
Obsoletes:      libvoikko < %{version}-%{release}

%description -n libvoikko1
Libvoikko is a library of free natural language processing tools. It
aims to provide support for languages that are not well served by
other existing free linguistic tools.

%package        devel
Summary:        Development files for %{name}
Group:          Development/Libraries
Requires:       libvoikko1 = %{version}-%{release}
Requires:       pkgconfig

%description    devel
The %{name}-devel package contains libraries and header files for
developing applications that use %{name}.

%package -n     voikko-tools
Summary:        Test tools for %{name}
Group:          Applications/Text

%description -n voikko-tools
This package contains voikkospell and voikkohyphenate, small command line
tools for testing libvoikko. These tools may also be useful for shell
scripts.

%package -n     python3-libvoikko
Summary:        Python interface to %{name}
Group:          Development/Libraries
Requires:       libvoikko1 = %{version}-%{release}
BuildArch:      noarch

%description -n python3-libvoikko
Python interface to libvoikko, library of language tools.
This module can be used to perform various natural language analysis
tasks on text.


%prep
%setup -q -n %{name}-%{version}


%build
autoreconf -fi
%configure --with-dictionary-path=%{_libdir}/voikko:%{_datadir}/voikko:/usr/lib/voikko
make %{?_smp_mflags}


%install
make install INSTALL="install -p" DESTDIR=$RPM_BUILD_ROOT
find $RPM_BUILD_ROOT -name '*.la' -exec rm -f {} ';'
find $RPM_BUILD_ROOT -name '*.a' -exec rm -f {} ';'
install -d $RPM_BUILD_ROOT%{python3_sitelib}
install -pm 0644 python/libvoikko.py $RPM_BUILD_ROOT%{python3_sitelib}/


%post -n libvoikko1 -p /sbin/ldconfig

%postun -n libvoikko1 -p /sbin/ldconfig


%files -n libvoikko1
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

%files -n python3-libvoikko
%defattr(-,root,root)
%{python3_sitelib}/*

%changelog
* Fri Feb 19 2016 Tino Didriksen <tino@didriksen.cc> 4.0.2
- Packaging based on work by Ville-Pekka Vainio <vpvainio AT iki.fi>
