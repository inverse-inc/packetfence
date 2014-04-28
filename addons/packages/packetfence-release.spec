# PacketFence RPM SPEC
#
# NEW (since git migration):
#
#   Expecting a standard tarball with packetfence-<version>/...
# 
# BUILDING FOR RELEASE
# 
# - Build
#  - define ver <version>
#  - define dist based on target distro (for centos/rhel => .el5)
#  - define rev based on package revision (must be > 0 for proprer upgrade from snapshots)
# ex:
# cd /usr/src/redhat/
# rpmbuild -ba --define 'version 3.3.0' --define 'dist .el5' --define 'rev 1' SPECS/packetfence.spec
#
#
# BUILDING FOR A SNAPSHOT (PRE-RELEASE)
#
# - Build
#  - define ver <version>
#  - define snapshot 1
#  - define dist based on target distro (for centos/rhel => .el5)
#  - define rev to 0.<date> this way one can upgrade from snapshot to release
# ex:
# cd /usr/src/redhat/
# rpmbuild -ba --define 'version 3.3.0' --define 'snapshot 1' --define 'dist .el5' --define 'rev 0.20100506' SPECS/packetfence.spec
#
Summary: PacketFence release file and RPM repository configuration
%global real_name packetfence-release
Name: %{real_name}
Version: %{ver}
Release: %{rev}%{?dist}
License: GPL
Group: System Environment/Base
URL: http://www.packetfence.org
BuildRoot: %{_tmppath}/%{real_name}-%{version}-%{rev}-root
# disables the creation of the debug package for our setuid C wrapper
%define debug_package %{nil}

Packager: Inverse inc. <support@inverse.ca>
Vendor: PacketFence, http://www.packetfence.org

# if --define 'snapshot 1' not written when calling rpmbuild then we assume it is to package a release
%define is_release %{?snapshot:0}%{!?snapshot:1}
%if %{is_release}
# used for official releases
Source: http://www.packetfence.org/downloads/PacketFence/src/%{real_name}-%{version}.tar.gz
%else
# used for snapshot releases
Source: http://www.packetfence.org/downloads/PacketFence/src/%{real_name}-%{version}-%{rev}.tar.gz
%endif

%description

PacketFence release file. This package contains yum configuration
for the PacketFence RPM Repository.

%prep
%setup -q -n %{real_name}-%{version}

%{__cat} <<EOF >/etc/yum.repos.d/packetfence.repo
## PacketFence RPM Repository for RHEL/Centos 6
[packetfence]
name=PacketFence Repository
baseurl=http://inverse.ca/downloads/PacketFence/RHEL$releasever/$basearch
gpgcheck=0
enabled=0

[packetfence-devel]
name=PacketFence Devel Repository
baseurl=http://inverse.ca/downloads/PacketFence/RHEL$releasever/devel/$basearch
gpgcheck=0
enabled=0
EOF

%build
%install
%clean

%files -n %{real_name}
%defattr(0755, root, root)
%config /etc/yum.repos.d/packetfence.repo


%changelog
* Fri Apr 25 2014 Loick Pelet <lpelet@inverse.ca>
- Release file created. 
