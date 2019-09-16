Name: apertium-all-dev
Version: 3.6.1
Release: 1%{?dist}
Summary: Metapackage for all tools required for Apertium development
Group: Development/Tools
License: GPL-3.0+
URL: https://apertium.org/
Source0: %{name}_%{version}.orig.tar.bz2
BuildArch: noarch
Provides: apertium-all-devel = %{version}-%{release}

Requires: apertium-anaphora >= 0.0.1
Requires: apertium-devel >= 3.6.0
Requires: apertium-eval-translator
Requires: apertium-lex-tools >= 0.2.1
Requires: apertium-recursive >= 0.0.1
Requires: apertium-separable >= 0.3.2
Requires: autoconf
Requires: automake
Requires: cg3 >= 1.3.0
Requires: git
Requires: hfst >= 3.15.1
Requires: libcg3-devel >= 1.3.0
Requires: libhfst-devel >= 3.15.1
Requires: libxml2
Requires: libxslt
Requires: lttoolbox-devel >= 3.5.0

%description
Metapackage to get all tools required for development of Apertium
languages and pairs, such as lttoolbox, apertium, apertium-lex-tools,
cg3, and hfst.

%prep
%setup -q -n %{name}-%{version}

%files
%defattr(-,root,root)
%doc README

%changelog
* Thu Sep 12 2019 Tino Didriksen <tino@didriksen.cc> 3.6.1
- Initial version of the package
