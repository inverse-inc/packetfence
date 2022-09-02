Name:       packetfence-export
Version:    12.0.0
Release:    2%{?dist}
BuildArch:  noarch
Summary:    PacketFence export files
Packager:   Inverse inc. <support@inverse.ca>
Group:      System Environment/Base
License:    GPL
URL:        http://www.packetfence.org
Source0:    %{name}-%{version}.tar
BuildRoot:  %{_tmppath}/%{name}-root
Vendor:     PacketFence, http://www.packetfence.org

%description

PacketFence export files. This package contains all files related to export mechanism.
This package should only be installed on releases before v11.

#==============================================================================
# Source preparation
#==============================================================================
%prep
%setup -q -n %{name}-%{version}

#==============================================================================
# Build
#==============================================================================

%build

%install
%{__rm} -rf %{buildroot}
%{__make} -C full-import DESTDIR=%{buildroot} install

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-, pf, pf)
# base directory need to be added to package to be removed during uninstall
%dir /usr/local/pf/addons/full-import
%dir /usr/local/pf/addons/functions
# add files in package **and** set permissions
# we only add files install during install process
%attr(0755, -, -)     /usr/local/pf/addons/full-import/export.sh
%attr(0755, -, -)     /usr/local/pf/addons/full-import/find-extra-files.pl
%attr(0644, -, -)     /usr/local/pf/addons/functions/*.functions

%changelog
* Fri Sep 02 2022 Inverse <info@inverse.ca> - 12.0.0-1
- New release 12.0.0

* Wed Feb 23 2022 Inverse <info@inverse.ca> - 11.3.0-1
- New release 11.3.0

* Fri Oct 29 2021 Inverse <info@inverse.ca> - 11.2.0-1
- New release 11.2.0

* Thu Sep 30 2021 Inverse <info@inverse.ca> - 11.1.0-2
- Package functions from addons/functions

* Thu Sep 02 2021 Inverse <info@inverse.ca> - 11.1.0-1
- New release 11.1.0

* Wed Jul 21 2021 Nicolas Quiniou-Briand <nquiniou@akamai.com> - 11.0.0-1
- Package creation for 11.0 release
