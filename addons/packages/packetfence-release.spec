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

%description

PacketFence release file. This package contains yum configuration
for the PacketFence RPM Repository.

%prep

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
rm -rf %{buildroot}
mkdir -p %{buildroot}/etc/yum.repos.d/
cp /etc/yum.repos.d/packetfence.repo $RPM_BUILD_ROOT/etc/yum.repos.d/packetfence.repo
%clean
rm -rf $RPM_BUILD_ROOT

%files -n %{real_name}
%defattr(0755, root, root)
%config /etc/yum.repos.d/packetfence.repo


%changelog
* Fri Apr 25 2014 Loick Pelet <lpelet@inverse.ca>
- Release file created.
