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
for the PacketFence RPM repository.

%prep

%{__cat} <<EOF >/etc/yum.repos.d/packetfence.repo
## PacketFence RPM Repository for RHEL/Centos
[packetfence]
name=PacketFence Repository
baseurl=http://inverse.ca/downloads/PacketFence/RHEL$releasever/$basearch
gpgcheck=1
enabled=0

[packetfence-devel]
name=PacketFence Devel Repository
baseurl=http://inverse.ca/downloads/PacketFence/RHEL$releasever/devel/$basearch
gpgcheck=1
enabled=0

[packetfence-extra]
name=PacketFence Extra Repository
baseurl=http://inverse.ca/downloads/PacketFence/RHEL$releasever/extra/\$basearch
gpgcheck=0
enabled=0

EOF

%{__cat} <<EOF > /etc/pki/rpm-gpg/RPM-GPG-KEY-PACKETFENCE-CENTOS
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.12 (GNU/Linux)

mQINBFboV/kBEAD0lENE/obEKUnHhRJzr/y+27BVHI0KUia4CbXESHBYla/+ZMS/
Kr91b8JFgfhw52BMDeB/73vN1HKoPvO8THzimOJA3CoN8C9I/0eqyE32SsqGA/c2
6FL9a1zTRff7BVkQTsiq3gPjLfykERzIpmfWB/FML0S+guGmS6BY04P15MOhGCwH
1emW931uwZyMv7VpNffnaUoxoMjkh4PPo7ferNRpU+cCaiokmvVS+1l+ZWeehq9N
YrNJzupQao5HdG2t2tj1n+IJChrCo5qDBZ6YlnjYxaNSaaa8bK4nPmbdmjm/3YFK
On2DIriAU0CRaJVYkWgvhEQznHwGzKeXm6x8K7Px+uvNx/OAfiwBti43WMlxbyw4
Z5fkKfRErm1BBlHI7FQkOi0sY+g7yCrlTx6+4evJC6kJ+xPyk5wFgwrs+A9iEpj2
kXkvYOPuZttA5XsqKo1tsC85j2zRnC5X53WV4ccPWiRM6cpsvDZrpi32pP6I4WE2
oE9Dt25RVA4VTovaYZKXq0H7FIIVtCTxyHXNevAmPpZKmdAnSi9vb3Yj329p5JFf
3BHtZH8li+bg5dSUSUyxS2Kdb+4q63n4NAYz52wex0t7evutEo1rzpTjNQuSp/aa
Y9mspj9xV/LdlMce9v822wGUKtvaXFUhhor0XV5icYsv93NEl3NBSnpnfQARAQAB
tDpJbnZlcnNlIFN1cHBvcnQgKFJQTSBwYWNrYWdlIHNpZ25pbmcpIDxzdXBwb3J0
QGludmVyc2UuY2E+iQI4BBMBAgAiBQJW6Ff5AhsDBgsJCAcDAgYVCAIJCgsEFgID
AQIeAQIXgAAKCRDLLToqoAMOLFyKEADV1/4XeP7maHYqRdzEfovd8dSqRTgnQKxb
gErvBdpna1vR7QNGY19zMKduSQKTIOI704s8jrtGmORrtlM5OJgrfYA1HDiTIkRp
1L6yps7Vz7qBSxGhKaT5sDsolYHX9MlgJBIQ4rs5lxZ0oQFLbaNUgRf333v+SyJC
Y720OohUa9qtur6uK2VDrJqgzl1huWctZ3FdxcbKrMwn93//W27VNdPCaRxcpbeO
qy8hJ74F+Iom9Kqw5YBPAABdSlJ2DEwxN+ItyiMExYqkTidcQmk+LdNkP2eN4OIM
d59Lp2iWP2zIqaJ9hKURwdUKYajrsFpAS7eubUprN436sK/dFpv4NL7grnoD4seB
wvk8eqxIyzONZqgZH5nhilf6QJ340SYHglQ2gChkAC5MENsUk2Cr8+R72GRtOvAP
N2GTU+v7KWtudl2jpWorlxNWRSqpFynHIUbnDdn6t0VQWnpNJWhgZBGhzA0eIYgl
7rtqJ/hlU7Cu7CzWtM3XluWhrNw4/K3lmngj2UNJkIxbZKi3K/UKsuHtvHAt6B1H
LOoD07gvX25E1Kx14KxW6oq4lsnjg/vdUwKYDdmGZCDCSsUCMdHcMQPNbLhEoBNl
B2RzxDpxO81bCL692Wxx50JFFhspOLR1a09ljrwAHtWrX5zV3Pb4qrTeiQpMgeZq
yglRDT063w==
=sdaP
-----END PGP PUBLIC KEY BLOCK-----
EOF


%build
%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/etc/yum.repos.d/
cp /etc/yum.repos.d/packetfence.repo $RPM_BUILD_ROOT/etc/yum.repos.d/packetfence.repo
cp /etc/pki/rpm-gpg/RPM-GPG-KEY-PACKETFENCE-CENTOS $RPM_BUILD_ROOT%{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-PACKETFENCE-CENTOS
%clean
rm -rf $RPM_BUILD_ROOT

%files -n %{real_name}
%defattr(0755, root, root)
%config /etc/yum.repos.d/packetfence.repo
/etc/pki/rpm-gpg/RPM-GPG-KEY-PACKETFENCE-CENTOS


%changelog
* Thu Jan 05 2017 Inverse inc. <support@inverse.ca>
- Merged changes from the build system for dynamic versioning
- Added GPG key
- Activated gpgcheck
* Thu May 01 2014 Inverse inc. <support@inverse.ca>
- fixed variable issue
* Fri Apr 25 2014 Inverse inc. <support@inverse.ca>
- Release file created.
