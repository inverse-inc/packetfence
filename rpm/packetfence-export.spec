Name:       packetfence-export
Version:    11.0.0
Release:    1%{?dist}
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
%{__make} DESTDIR=%{buildroot} install

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-, pf, pf)
# add files in package **and** set permissions
# we only add files install during install process
%attr(0755, -, -)     /usr/local/pf/addons/full-import/export.sh
%attr(0755, -, -)     /usr/local/pf/addons/full-import/find-extra-files.pl
%attr(0644, -, -)     /usr/local/pf/addons/full-import/*.functions

%changelog
* Wed Jul 21 2021 Nicolas Quiniou-Briand <nquiniou@akamai.com> - 11.0.0-1
- Package creation for 11.0 release
