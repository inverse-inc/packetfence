Name:       packetfence-upgrade
Version:    11.3.0
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
%attr(0755, -, -)     /usr/local/pf/addons/full-upgrade/hooks/*.sh

%changelog
* Wed Feb 23 2022 Inverse <info@inverse.ca> - 11.3.0-1
- New release 11.3.0

* Fri Oct 29 2021 Inverse <info@inverse.ca> - 11.2.0-1
- New release 11.2.0

* Wed Sep 29 2021 Inverse <info@inverse.ca> - 11.1.0-1
- Package creation for 11.1.0 release

