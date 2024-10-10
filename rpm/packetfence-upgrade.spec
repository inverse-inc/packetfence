Name:       packetfence-upgrade
Version:    14.1.0
Release:    1%{?dist}
BuildArch:  noarch
Summary:    PacketFence upgrade files
Packager:   Inverse inc. <support@inverse.ca>
Group:      System Environment/Base
License:    GPL
URL:        http://www.packetfence.org
Source0:    %{name}-%{version}.tar
BuildRoot:  %{_tmppath}/%{name}-root
Vendor:     PacketFence, http://www.packetfence.org

%description

PacketFence upgrade files. This package contains all files related to upgrade mechanism.
This package should only be installed on releases after v11.

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
%{__make} -C full-upgrade DESTDIR=%{buildroot} install

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-, pf, pf)
# base directory need to be added to package to be removed during uninstall
%dir /usr/local/pf/addons/full-upgrade
# add files in package **and** set permissions
# we only add files install during install process
%attr(0755, -, -)     /usr/local/pf/addons/full-upgrade/run-upgrade.sh
%attr(0644, -, -)     /usr/local/pf/addons/full-upgrade/*.functions
%dir /usr/local/pf/addons/full-upgrade/hooks
%attr(0755, -, -)     /usr/local/pf/addons/full-upgrade/hooks/*

%changelog
* Mon Sep 09 2024 Inverse <info@inverse.ca> - 14.1.0-1
- New release 14.1.0

* Fri May 17 2024 Inverse <info@inverse.ca> - 14.0.0-1
- New release 14.0.0

* Mon Jan 22 2024 Inverse <info@inverse.ca> - 13.2.0-1
- New release 13.2.0

* Thu Aug 10 2023 Inverse <info@inverse.ca> - 13.1.0-1
- New release 13.1.0

* Thu Mar 09 2023 Inverse <info@inverse.ca> - 13.0.0-1
- New release 13.0.0

* Tue Nov 22 2022 Inverse <info@inverse.ca> - 12.2.0-1
- New release 12.2.0

* Wed Sep 14 2022 Inverse <info@inverse.ca> - 12.1.0-1
- New release 12.1.0

* Fri Sep 02 2022 Inverse <info@inverse.ca> - 12.0.0-1
- New release 12.0.0

* Wed Feb 23 2022 Inverse <info@inverse.ca> - 11.3.0-1
- New release 11.3.0

* Fri Oct 29 2021 Inverse <info@inverse.ca> - 11.2.0-1
- New release 11.2.0

* Wed Sep 29 2021 Inverse <info@inverse.ca> - 11.1.0-1
- Package creation for 11.1.0 release

