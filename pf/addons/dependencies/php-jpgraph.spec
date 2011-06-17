# $Id$
# Authority: dag

%define real_name jpgraph

Summary: OO Graph Library for PHP
Name: php-jpgraph
Version: 2.3.4
Release: 1%{?dist}
License: QPL
Group: Development/Languages
URL: http://www.aditus.nu/jpgraph/

Source: http://members.chello.se/jpgraph/jpgdownloads/jpgraph-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildArch: noarch
Requires: webserver, php >= 5.0.0
Obsoletes: jpgraph
Provides: jpgraph

%description
JpGraph is an OO class library for PHP 5 (or higher). JpGraph makes it
easy to draw both "quick and dirty" graphs with a minimum of code and
complex professional graphs which requires a very fine grain control.

JpGraph is equally well suited for both scientific and business type of graphs.

An important feature of the library is that it assigns context sensitive
default values for most of the parameters which radically minimizes the
learning curve. The features are there when you need it - they don't get
in your way when you don't need them!

%package docs
Summary: Documentation for package %{name}
Group: Documentation

%description docs
JpGraph is an OO class library for PHP 5 (or higher). JpGraph makes it
easy to draw both "quick and dirty" graphs with a minimum of code and
complex professional graphs which requires a very fine grain control.

This package includes the documentation for %{name}.

%prep
%setup -n %{real_name}-%{version}

### Change the default TTF_DIR to Red Hat's TTF_DIR.
%{__perl} -pi.orig -e 's|/usr/X11R6/lib/X11/fonts/truetype/|/usr/X11R6/lib/X11/fonts/TTF/|' src/jpgraph.php

%build

%install
%{__rm} -rf %{buildroot}
%{__install} -d -m0755 %{buildroot}%{_localstatedir}/www/%{real_name}-%{version}
%{__install} -p -m0644 src/*.php src/*.dat %{buildroot}%{_localstatedir}/www/%{real_name}-%{version}/

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-, root, root, 0755)
%doc QPL.txt README
%{_localstatedir}/www/%{real_name}-%{version}/

%files docs
%defattr(-, root, root, 0755)
%doc docs/* src/Examples/

%changelog
* Wed Jun 01 2011 Olivier Bilodeau <obilodeau@inverse.ca> - 2.3.4-1
- An old upstream release rebuild

* Sat Apr 08 2006 Dries Verachtert <dries@ulyssis.org> - 1.19-1.2
- Rebuild for Fedora Core 5.

* Fri Jul 22 2005 Dries Verachtert <dries@ulyssis.org> - 1.19-1
- Updated to release 1.19.

* Tue Feb 17 2004 Dag Wieers <dag@wieers.com> - 1.14-1
- Added missing dat files. (Matti Lindell)

* Mon Feb 16 2004 Dag Wieers <dag@wieers.com> - 1.14-0
- Added missing inc files. (Matti Lindell)
- Updated to release 1.14.

* Tue Sep 16 2003 Dag Wieers <dag@wieers.com> - 1.13-0
- Updated to release 1.13.

* Mon Feb 17 2003 Dag Wieers <dag@wieers.com> - 1.10-0
- Initial package. (using DAR)
