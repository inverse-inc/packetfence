Name:       packetfence-release
Version:    2.4.0
Release:    1%{?dist}
BuildArch:  noarch
Summary:    PacketFence release file and RPM repository configuration
Packager:   Inverse inc. <support@inverse.ca>
Group:      System Environment/Base
License:    GPL
URL:        http://www.packetfence.org
# don't use any source
#Source0:
BuildRoot:  %{_tmppath}/%{name}-root
Vendor:     PacketFence, http://www.packetfence.org

%description

PacketFence release file. This package contains yum configuration
for the PacketFence RPM repository.

%prep

%{__cat} <<EOF > %{_builddir}/packetfence.repo
## PacketFence RPM Repository for RHEL/Centos
[packetfence]
name=PacketFence Repository
baseurl=http://inverse.ca/downloads/PacketFence/RHEL\$releasever/%{pf_minor_release}/\$basearch
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-PACKETFENCE-CENTOS
gpgcheck=1
enabled=0
module_hotfixes=1

[packetfence-extra]
name=PacketFence Extra Repository
baseurl=http://inverse.ca/downloads/PacketFence/RHEL\$releasever/extra/\$basearch
gpgcheck=0
enabled=0
module_hotfixes=1

[packetfence-branches]
name=PacketFence Branches Repository
baseurl=http://inverse.ca/downloads/PacketFence/RHEL\$releasever/branches/\$basearch
gpgcheck=0
enabled=0
module_hotfixes=1

EOF

%{__cat} <<EOF > %{_builddir}/RPM-GPG-KEY-PACKETFENCE-CENTOS
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

%{__cat} <<EOF > %{_builddir}/RPM-GPG-KEY-PACKETFENCE-MONITORING
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQENBFgBPXMBCACwH15Boe8a8870M8NbM+oH4ZaotUbunjyY/En9Hx99srODbjy3
0uR+yeSfrdDDqHr+raW8pbP5dtVyWrv8U28fdjglh+0CEfSmNo/2bYfKNop+wQBD
h6rvosyBCSiqrqoyO+Q4DCB3et/rYaXhhx0zljv2AvAC0TFEAxf9f1RSj3e8K2RG
xBsuzuF+zcyidOGE+EPKEm6Sog697kwV3BN5shsRl2N/rylDWg/4R9uOgb6flLXa
kzKfiMFV6DoQKddGzkRZmDVUi6bW91XEWDuH0AqhGGjAqaKVUs8CAySooPxfxxSj
cHkpsazQOu/S6CZmYMpnfF3qHA0c1W3WF8cxABEBAAG0M0ludmVyc2UgSW5jLiAo
TW9uaXRvcmluZyBTY3JpcHRzKSA8aW5mb0BpbnZlcnNlLmNhPokBOAQTAQIAIgUC
WAE9cwIbAwYLCQgHAwIGFQgCCQoLBBYCAwECHgECF4AACgkQl21ZKOOigzQ/mQf/
cdMSWwWt7vuh/MO3sofW+4XAtjd3v4kZpfhhYlfwejb6FEGvlv4/eN9SAaqDDR8Y
9ngt7ui2m02IFZbNqhaxJ3n8PLfrf6WMEOH3+cYUfyZJWUmnZiMeJ+nGPXd9WX1w
V0mx3mZ5S7mlRNgejProP3Fze8+muMVbXCUjkjfggiIcdt9oZx2Tk5Rg7df9RV+8
4p11DkBsVYRwu2gOI9Rp3OIRIERAA+9Z4sZQeP++wSQnk5baiYx/KjA1BWj1hWLf
j5bmWp9U/hqZzrXwgF6yjVPuv/NaVw5q+gp5iRcBEfwKhioqf5GV+4GNdnJ36AUm
TuuAzX9zHPIhO43rvhP1hbkBDQRYAT1zAQgA+Tdl6trMRRVee6IdJZSY8tSOd55P
gm5dSJITk3dk+kPFck5MSb5OnlPD5BWTO5je+7f/zm0rlbRk5DMU3ehCa3kQKwZo
UHehQHEn9xN6XNy48s5LGIKtRnjazcT2MkNwoghecXYVh8WntwU4sR0lIWP7/BXc
hM1jrrmNH4LoL7owmO+msSHKo8JfAIfKISGSdIXS/7y977DL7H1HBFssc7r23uWN
7K9P4QY1p0xF6Au7IBndsLvkmuJduNXjPpkioea0d8qHlUKTTHwVfq1tQULxodYF
Hm5PAb3B2cNkUbRYqiXnB/4M14uDV4AsHoVK1eWTKIXrmnf4bEybEe601wARAQAB
iQEfBBgBAgAJBQJYAT1zAhsMAAoJEJdtWSjjooM0nHYIAIwP6IRJICyAAGSiH5oi
LMkOPmay+svlaVVC/WPKjH5ru+K1pdnar/53d7hxojOn+R3WT02Nd7iNs3ooYVC0
DU0++TZE2UD+nIYqa/V0kINRBfoVY8qI9OTX9jypE5eMATInDpKb1uyTxKvizXcX
M+6uMuFojWkYANHdMuc+btbkxGdvGNx7JpUjFFpKhVx9P4DR2I4TsUl1f5tDbjT/
IAVJ1HxeEawk8PQww0hrdrD/kO+7MvzCUUR/FBZoO7IAQtE92AwRg14hjvD7sq87
vO3AJx6mqQazcUowYI1ENzjByK52XE2NGsOWKfk7WpaNV+g9TO1oA3oVdNVMePk0
1J0=
=HRaj
-----END PGP PUBLIC KEY BLOCK-----
EOF


%build

%install
%{__rm} -rf %{buildroot}
mkdir -p %{buildroot}/etc/yum.repos.d/
mkdir -p %{buildroot}/etc/pki/rpm-gpg/
cp %{_builddir}/packetfence.repo %{buildroot}/etc/yum.repos.d/packetfence.repo
cp %{_builddir}/RPM-GPG-KEY-PACKETFENCE-CENTOS %{buildroot}%{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-PACKETFENCE-CENTOS
cp %{_builddir}/RPM-GPG-KEY-PACKETFENCE-MONITORING %{buildroot}%{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-PACKETFENCE-MONITORING

%clean
%{__rm} -rf %{buildroot}

%files -n %{name}
%defattr(0644, root, root)
%config /etc/yum.repos.d/packetfence.repo
/etc/pki/rpm-gpg/RPM-GPG-KEY-PACKETFENCE-CENTOS
/etc/pki/rpm-gpg/RPM-GPG-KEY-PACKETFENCE-MONITORING


%changelog
* Mon Oct 04 2021 Nicolas Quiniou-Briand <nquiniou@akamai.com> - 2.4.0-1
- Add GPG key used to sign monitoring scripts

* Mon Jul 19 2021 Nicolas Quiniou-Briand <nquiniou@akamai.com> - 2.3.0-1
- Create files in BUILD directory in place of filesystem

* Mon May 31 2021 Nicolas Quiniou-Briand <nquiniou@akamai.com> - 2.2.0-1
- Manage one repository per version to simplify maintenance and release process

* Wed Apr 15 2020 Nicolas Quiniou-Briand <nqb@inverse.ca> - 2.1.0-1
- Add packetfence-branches and packetfence-gitlab repositories

* Sat Jul 13 2019 Nicolas Quiniou-Briand <nqb@inverse.ca> - 2.0.0-1
- Adapt spec file to CI

* Sat Jul 13 2019 Nicolas Quiniou-Briand <nqb@inverse.ca> - 2.0.0-1
- Adapt spec file to CI

* Wed Apr 12 2017 Inverse inc. <info@inverse.ca> - 1.2-7
- Permission fix. 

* Thu Jan 05 2017 Inverse inc. <info@inverse.ca> - 1.2-6
- Merged changes from the build system for dynamic versioning
- Added GPG key
- Activated gpgcheck

* Thu May 01 2014 Inverse inc. <info@inverse.ca>
- fixed variable issue

* Fri Apr 25 2014 Inverse inc. <info@inverse.ca>
- Release file created.
