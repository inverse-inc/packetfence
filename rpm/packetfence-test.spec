Name:       packetfence-test
Version:    14.1.0
Release:    1%{?dist}
BuildArch:  noarch
Summary:    PacketFence test files
Packager:   Inverse inc. <support@inverse.ca>
Group:      System Environment/Base
License:    GPL
URL:        http://www.packetfence.org
Source0:    %{name}-%{version}.tar
BuildRoot:  %{_tmppath}/%{name}-root
Vendor:     PacketFence, http://www.packetfence.org

%description

PacketFence test files. This package contains all files related to PacketFence tests.

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
%{__make} DESTDIR=%{buildroot} test_install

%clean
%{__rm} -rf %{buildroot}

%files
# add all files and directories under t in package
/usr/local/pf/t

## Permissions
# t
%attr(0755, -, -)     /usr/local/pf/t/*.pl
%attr(0755, -, -)     /usr/local/pf/t/*.sh
%attr(0755, -, -)     /usr/local/pf/t/*.t
%attr(0755, -, -)     /usr/local/pf/t/pfconfig-test
%attr(0755, -, -)     /usr/local/pf/t/pfconfig-test-serial

# benchmarks
%attr(0755, -, -)     /usr/local/pf/t/benchmarks/*.pl
%attr(0755, -, -)     /usr/local/pf/t/benchmarks/webservices_client/*.pl

# dao
%attr(0755, -, -)     /usr/local/pf/t/dao/*.t

# db
%attr(0755, -, -)     /usr/local/pf/t/db/*.t
%attr(0755, -, -)     /usr/local/pf/t/db/*.pl

# integration
%attr(0755, -, -)     /usr/local/pf/t/integration/*.t

# mock-servers
%attr(0755, -, -)     /usr/local/pf/t/mock_servers/*.pl

# network-devices
%attr(0755, -, -)     /usr/local/pf/t/network-devices/*.t

# serialized_unittests
%attr(0755, -, -)     /usr/local/pf/t/serialized_unittests/*.t
%attr(0755, -, -)     /usr/local/pf/t/serialized_unittests/db/*.t
%attr(0755, -, -)     /usr/local/pf/t/serialized_unittests/UnifiedApi/Controller/*.t

# stress-test
%attr(0755, -, -)     /usr/local/pf/t/stress-test/*.pl

# unittest
%attr(0755, -, -)    /usr/local/pf/t/unittest/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/Portal/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/pfconfig/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/config/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/config/builder/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/config/builder/filter_engine/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/Switch/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/Switch/Dell/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/detect/parser/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/dhcp/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/api/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/access_filter/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/condition/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/pfappserver/Base/Form/Role/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/pfappserver/Form/Config/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/ConfigStore/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/util/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/SQL/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/factory/condition/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/I18N/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/UnifiedApi/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/UnifiedApi/OpenAPI/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/UnifiedApi/OpenAPI/Generator/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/UnifiedApi/Controller/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/UnifiedApi/Controller/Users/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/UnifiedApi/Controller/Config/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/UnifiedApi/Controller/Config/Sources/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/UnifiedApi/Controller/Config/FilterEngines/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/UnifiedApi/Controller/Fingerbank/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/UnifiedApi/Search/Builder/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/cmd/pf/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/provisioner/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/pfcron/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/pfcron/task/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/Authentication/*.t
%attr(0755, -, -)    /usr/local/pf/t/unittest/Authentication/Source/*.t

# Venom
%attr(0755, -, -)     /usr/local/pf/t/venom/*.sh
%attr(0755, -, -)     /usr/local/pf/t/venom/utils/*.sh

# addons/functions tests
%attr(0755, -, -)     /usr/local/pf/t/addons-functions/*.tests

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

* Thu Sep 02 2021 Inverse <info@inverse.ca> - 11.1.0-1
- New release 11.1.0

* Thu Sep 02 2021 Inverse <info@inverse.ca> - 11.1.0-1
- New release 11.1.0

* Thu Sep 02 2021 Inverse <info@inverse.ca> - 11.0.0-1
- New release 11.0.0

* Wed Jul 21 2021 Nicolas Quiniou-Briand <nquiniou@akamai.com> - 11.0.0-1
- Package creation for 11.0 release
