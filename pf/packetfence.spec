#rpmbuild should be done in several steps:
#1) rpmbuild -bs SPECS/packetfence.spec
#on each target distribution
#2) rpmbuild --rebuild --define 'dist .el5' SRPMS/packetfence-1.8.2-1.src.rpm
Summary: PacketFence network registration / worm mitigation system
Name: packetfence
Version: 1.8.2
Release: 1%{?dist}
License: GPL
Group: System Environment/Daemons
URL: http://www.packetfence.org
AutoReqProv: 0
BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-%{version}-root

Packager: Dominik Gehl <dgehl@inverse.ca>
Vendor: PacketFence, http://www.packetfence.org

Source: http://prdownloads.sourceforge.net/packetfence/%{name}-%{version}.tar.gz

BuildRequires: gettext, perl(Parse::RecDescent), httpd
Requires: chkconfig, coreutils, grep, iproute, openssl, sed, tar, wget
Requires: libpcap, libxml2, zlib, zlib-devel, glibc-common,
Requires: httpd, mod_ssl, php, php-gd, php-pear
Requires: net-tools, net-snmp
Requires: mysql, perl-DBD-MySQL
Requires: perl >= 5.8.0, perl-suidperl
Requires: perl(Apache::Htpasswd)
Requires: perl(Bit::Vector)
Requires: perl(CGI::Session)
Requires: perl(Config::IniFiles) >= 2.40
Requires: perl(Class::Data::Inheritable)
Requires: perl(Class::Gomor)
Requires: perl(Data::Phrasebook), perl(Data::Phrasebook::Loader::YAML)
Requires: perl(Date::Parse)
Requires: perl(DBI)
Requires: perl(DBD::mysql)
Requires: perl(File::Tail)
Requires: perl(List::MoreUtils)
Requires: perl(Locale::gettext)
Requires: perl(Log::Log4perl) >= 1.11
Requires: perl(LWP::UserAgent)
Requires: perl(Net::IPv4Addr), perl(Net::IPv6Addr)
Requires: perl(Net::MAC), perl(Net::MAC::Vendor)
Requires: perl(Net::Netmask)
Requires: perl(Net::Pcap) >= 0.16
Requires: perl(Net::SNMP)
Requires: perl(Net::Telnet)
Requires: perl(Parse::RecDescent)
Requires: perl(Readonly)
Requires: perl(Regexp::Common)
Requires: perl(RRDs)
Requires: perl(Template)
Requires: perl(Term::ReadKey)
Requires: perl(Test::Perl::Critic)
Requires: perl(Test::Pod), perl(Test::Pod::Coverage)
Requires: perl(Thread::Pool)
Requires: perl(UNIVERSAL::require)
Requires: perl(YAML)

%description

PacketFence is an open source network access control (NAC) system. 
It can be used to effectively secure networks, from small to very large 
heterogeneous networks. PacketFence provides features such 
as 
* registration of new network devices
* detection of abnormal network activities
* isolation of problematic devices
* remediation through a captive portal 
* registration-based and scheduled vulnerability scans.

%package remote-snort-sensor
Group: System Environment/Daemons
Requires: perl >= 5.8.0, snort, perl(File::Tail), perl(Config::IniFiles), perl(IO::Socket::SSL), perl(XML::Parser), perl(Crypt::SSLeay)
Conflicts: packetfence
AutoReqProv: 0
Summary: Files needed for sending snort alerts to packetfence

%description remote-snort-sensor
The packetfence-remote-snort-sensor package contains the files needed
for sending snort alerts from a remote snort sensor to a PacketFence
server.

%prep
%setup -n pf

%build
# generate pfcmd_pregrammar
/usr/bin/perl -w -e 'use strict; use warnings; use diagnostics; use Parse::RecDescent; use lib "./lib"; use pf::pfcmd::pfcmd; Parse::RecDescent->Precompile($grammar, "pfcmd_pregrammar");'
mv pfcmd_pregrammar.pm lib/pf/pfcmd/

# generate translations
/usr/bin/msgfmt conf/locale/en/LC_MESSAGES/packetfence.po
mv packetfence.mo conf/locale/en/LC_MESSAGES/
/usr/bin/msgfmt conf/locale/es/LC_MESSAGES/packetfence.po
mv packetfence.mo conf/locale/es/LC_MESSAGES/
/usr/bin/msgfmt conf/locale/fr/LC_MESSAGES/packetfence.po
mv packetfence.mo conf/locale/fr/LC_MESSAGES/
/usr/bin/msgfmt conf/locale/nl/LC_MESSAGES/packetfence.po
mv packetfence.mo conf/locale/nl/LC_MESSAGES/

%install
%{__rm} -rf $RPM_BUILD_ROOT
%{__install} -D -m0755 packetfence.init $RPM_BUILD_ROOT%{_initrddir}/packetfence
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/logs
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/var/session
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/var/rrd
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/addons
cp -r bin $RPM_BUILD_ROOT/usr/local/pf/
cp -r addons/802.1X/ $RPM_BUILD_ROOT/usr/local/pf/addons/
cp -r addons/mrtg/ $RPM_BUILD_ROOT/usr/local/pf/addons/
cp -r addons/snort/ $RPM_BUILD_ROOT/usr/local/pf/addons/
cp addons/*.pl $RPM_BUILD_ROOT/usr/local/pf/addons/
cp -r sbin $RPM_BUILD_ROOT/usr/local/pf/
cp -r cgi-bin $RPM_BUILD_ROOT/usr/local/pf/
cp -r conf $RPM_BUILD_ROOT/usr/local/pf/
#pfdetect_remote
mv addons/pfdetect_remote/initrd/pfdetectd $RPM_BUILD_ROOT%{_initrddir}/
mv addons/pfdetect_remote/sbin/pfdetect_remote $RPM_BUILD_ROOT/usr/local/pf/sbin
mv addons/pfdetect_remote/conf/pfdetect_remote.conf $RPM_BUILD_ROOT/usr/local/pf/conf
rmdir addons/pfdetect_remote/sbin
rmdir addons/pfdetect_remote/initrd
rmdir addons/pfdetect_remote/conf
rmdir addons/pfdetect_remote
#end pfdetect_remote
cp -r test $RPM_BUILD_ROOT/usr/local/pf/
cp -r t $RPM_BUILD_ROOT/usr/local/pf/
cp -r db $RPM_BUILD_ROOT/usr/local/pf/
cp -r docs $RPM_BUILD_ROOT/usr/local/pf/
cp -r html $RPM_BUILD_ROOT/usr/local/pf/
cp -r lib $RPM_BUILD_ROOT/usr/local/pf/
cp -r configurator.pl $RPM_BUILD_ROOT/usr/local/pf/
cp -r installer.pl $RPM_BUILD_ROOT/usr/local/pf/
cp -r README $RPM_BUILD_ROOT/usr/local/pf/
cp -r README_SWITCHES $RPM_BUILD_ROOT/usr/local/pf/
cp -r CHANGES $RPM_BUILD_ROOT/usr/local/pf/
cp -r COPYING $RPM_BUILD_ROOT/usr/local/pf/

#start create symlinks
curdir=`pwd`

#pfschema symlink
cd $RPM_BUILD_ROOT/usr/local/pf/db
ln -s pfschema.mysql.181 ./pfschema.mysql

#httpd.conf symlink
cd $RPM_BUILD_ROOT/usr/local/pf/conf/templates
if (/usr/sbin/httpd -v | egrep 'Apache/2\.[2-9]\.' > /dev/null)
then
  ln -s httpd.conf.apache22 ./httpd.conf
else
  ln -s httpd.conf.pre_apache22 ./httpd.conf
fi

cd $curdir
#end create symlinks


%pre

if ! /usr/bin/id pf &>/dev/null; then
	/usr/sbin/useradd -r -d "/usr/local/pf" -s /bin/sh -c "PacketFence" -M pf || \
		echo Unexpected error adding user "pf" && exit
fi

#if [ ! `tty | cut -c0-8` = "/dev/tty" ];
#then
#  echo You must be on a directly connected console to install this package!
#  exit
#fi

if [ ! `id -u` = "0" ];
then
  echo You must install this package as root!
  exit
fi

#if [ ! `cat /proc/modules | grep ^ip_tables|cut -f1 -d" "` = "ip_tables" ];
#then
#  echo Required module "ip_tables" does not appear to be loaded - now loading
#  /sbin/modprobe ip_tables
#fi


%pre remote-snort-sensor

if ! /usr/bin/id pf &>/dev/null; then
	/usr/sbin/useradd -r -d "/usr/local/pf" -s /bin/sh -c "PacketFence" -M pf || \
		echo Unexpected error adding user "pf" && exit
fi

%post
echo "Adding PacketFence startup script"
/sbin/chkconfig --add packetfence
for service in snortd httpd snmptrapd
do
  if /sbin/chkconfig --list | grep $service > /dev/null 2>&1; then
    echo "Disabling $service startup script"
    /sbin/chkconfig --del $service > /dev/null 2>&1
  fi
done

#touch /usr/local/pf/conf/dhcpd/dhcpd.leases && chown pf:pf /usr/local/pf/conf/dhcpd/dhcpd.leases

if [ -e /etc/logrotate.d/snort ]; then
  echo Removing /etc/logrotate.d/snort - it kills snort every night
  rm -f /etc/logrotate.d/snort
fi

if [ -d /usr/local/pf/html/user/content/docs ]; then
  echo Removing legacy docs directory
  rm -rf /usr/local/pf/html/user/content/docs
fi

echo Installation complete
echo "  * Please cd /usr/local/pf && ./installer.pl to install necessary Perl modules and configure PF"

%post remote-snort-sensor
echo "Adding PacketFence remote Snort Sensor startup script"
/sbin/chkconfig --add pfdetectd

%preun
if [ $1 -eq 0 ] ; then
	/sbin/service packetfence stop &>/dev/null || :
	/sbin/chkconfig --del packetfence
fi
#rm -f /usr/local/pf/conf/dhcpd/dhcpd.leases

%preun remote-snort-sensor
if [ $1 -eq 0 ] ; then
	/sbin/service pfdetectd stop &>/dev/null || :
	/sbin/chkconfig --del pfdetectd
fi

%postun
if [ $1 -eq 0 ]; then
	/usr/sbin/userdel pf || %logmsg "User \"pf\" could not be deleted."
#	/usr/sbin/groupdel pf || %logmsg "Group \"pf\" could not be deleted."
#else
#	/sbin/service pf condrestart &>/dev/null || :
fi

%postun remote-snort-sensor
if [ $1 -eq 0 ]; then
	/usr/sbin/userdel pf || %logmsg "User \"pf\" could not be deleted."
fi

%files

%defattr(-, pf, pf)
#%config %{_initrddir}/packetfence
%attr(0755, root, root) %{_initrddir}/packetfence
%dir /usr/local/pf
%dir /usr/local/pf/bin
%dir /usr/local/pf/sbin
%attr(6755, root, root) /usr/local/pf/bin/pfcmd
%attr(0755, pf, pf) /usr/local/pf/bin/pfcmd_vlan
%attr(0755, pf, pf) /usr/local/pf/bin/flip.pl
%attr(0755, pf, pf) /usr/local/pf/sbin/pfdetect
%attr(0755, pf, pf) /usr/local/pf/sbin/pfredirect
%attr(0755, pf, pf) /usr/local/pf/sbin/pfmon
%attr(0755, pf, pf) /usr/local/pf/sbin/pfdhcplistener
%attr(0755, pf, pf) /usr/local/pf/sbin/pfsetvlan
%dir /usr/local/pf/cgi-bin
%attr(0755, pf, pf) /usr/local/pf/cgi-bin/pdp.cgi
%attr(0755, pf, pf) /usr/local/pf/cgi-bin/redir.cgi
%attr(0755, pf, pf) /usr/local/pf/cgi-bin/register.cgi
%attr(0755, pf, pf) /usr/local/pf/cgi-bin/release.cgi
%dir /usr/local/pf/conf
#%config(noreplace) /usr/local/pf/conf/pf.conf
%config(noreplace) /usr/local/pf/conf/networks.conf
%config(noreplace) /usr/local/pf/conf/violations.conf
#%config /usr/local/pf/conf/services.conf
%config(noreplace) /usr/local/pf/conf/ui.conf
%config(noreplace) /usr/local/pf/conf/ui-global.conf
%config(noreplace) /usr/local/pf/conf/switches.conf
%config(noreplace) /usr/local/pf/conf/log.conf
%config /usr/local/pf/conf/pf.conf.defaults
%config(noreplace) /usr/local/pf/conf/templates/snmptrapd.conf
%config /usr/local/pf/conf/documentation.conf
/usr/local/pf/conf/pf-release
%config /usr/local/pf/conf/dhcp_fingerprints.conf
%config /usr/local/pf/conf/oui.txt
%dir /usr/local/pf/test
%attr(0755, pf, pf) /usr/local/pf/test/dhcp_dumper
%attr(0755, pf, pf) /usr/local/pf/test/connect_and_read.pl
%dir /usr/local/pf/t
%attr(0755, pf, pf) /usr/local/pf/t/all.t
%attr(0755, pf, pf) /usr/local/pf/t/binaries.t
%attr(0755, pf, pf) /usr/local/pf/t/critic.t
%attr(0755, pf, pf) /usr/local/pf/t/person.t
%attr(0755, pf, pf) /usr/local/pf/t/pfcmd.t
%attr(0755, pf, pf) /usr/local/pf/t/pf.t
%attr(0755, pf, pf) /usr/local/pf/t/php.t
%attr(0755, pf, pf) /usr/local/pf/t/pod.t
%attr(0755, pf, pf) /usr/local/pf/t/SNMP.t
%attr(0755, pf, pf) /usr/local/pf/t/SwitchFactory.t
%dir /usr/local/pf/t/data
/usr/local/pf/t/data/switches.conf
%dir /usr/local/pf/addons
%dir /usr/local/pf/addons/mrtg
/usr/local/pf/addons/mrtg/*
%dir /usr/local/pf/addons/802.1X
%doc /usr/local/pf/addons/802.1X/README
%attr(0755, pf, pf) /usr/local/pf/addons/802.1X/pfcmd_ap.pl
%attr(0755, pf, pf) /usr/local/pf/addons/802.1X/rlm_perl_packetfence.pl
%dir /usr/local/pf/addons/snort
/usr/local/pf/addons/snort/oinkmaster.conf
%attr(0755, pf, pf) /usr/local/pf/addons/accounting.pl
%attr(0755, pf, pf) /usr/local/pf/addons/recovery.pl
%attr(0755, pf, pf) /usr/local/pf/addons/monitorpfsetvlan.pl
%attr(0755, pf, pf) /usr/local/pf/addons/autodiscover.pl
%attr(0755, pf, pf) /usr/local/pf/addons/convertToPortSecurity.pl
%dir /usr/local/pf/html
%dir /usr/local/pf/html/user
%dir /usr/local/pf/html/user/3rdparty
/usr/local/pf/html/user/3rdparty/timerbar.js
%dir /usr/local/pf/html/user/content
%config(noreplace) /usr/local/pf/html/user/content/header.html
%config(noreplace) /usr/local/pf/html/user/content/footer.html
/usr/local/pf/html/user/content/index.php
/usr/local/pf/html/user/content/style.php
%dir /usr/local/pf/html/user/content/images
/usr/local/pf/html/user/content/images/*
%dir /usr/local/pf/html/user/content/templates
%config(noreplace) /usr/local/pf/html/user/content/templates/*
%dir /usr/local/pf/html/user/content/violations
%config(noreplace) /usr/local/pf/html/user/content/violations/*
%dir /usr/local/pf/html/admin
/usr/local/pf/html/admin/*
%dir /usr/local/pf/html/common
/usr/local/pf/html/common/*
%dir /usr/local/pf/conf/dhcpd
/usr/local/pf/conf/dhcpd/dhcpd.leases
%dir /usr/local/pf/conf/snort
/usr/local/pf/conf/snort/*
%dir /usr/local/pf/conf/ssl
%dir /usr/local/pf/conf/users
%dir /usr/local/pf/conf/templates
%config /usr/local/pf/conf/templates/dhcpd.conf
%config /usr/local/pf/conf/templates/dhcpd_vlan.conf
%config /usr/local/pf/conf/templates/named_vlan.conf
%config(noreplace) /usr/local/pf/conf/templates/named-registration.ca
%config(noreplace) /usr/local/pf/conf/templates/named-isolation.ca
%dir /usr/local/pf/conf/named
%config /usr/local/pf/conf/templates/httpd.conf
%config(noreplace) /usr/local/pf/conf/templates/iptables.conf
%config /usr/local/pf/conf/templates/httpd.conf.pre_apache22
%config /usr/local/pf/conf/templates/httpd.conf.apache22
%config /usr/local/pf/conf/templates/snort.conf
%dir /usr/local/pf/conf/authentication
%config(noreplace) /usr/local/pf/conf/authentication/local.pm
%config(noreplace) /usr/local/pf/conf/authentication/ldap.pm
%config(noreplace) /usr/local/pf/conf/authentication/radius.pm
%dir /usr/local/pf/conf/templates/configurator
/usr/local/pf/conf/templates/configurator/*
%config(noreplace) /usr/local/pf/conf/templates/popup.msg
%config(noreplace) /usr/local/pf/conf/templates/listener.msg
%dir /usr/local/pf/conf/locale
%dir /usr/local/pf/conf/locale/en
%dir /usr/local/pf/conf/locale/es
%dir /usr/local/pf/conf/locale/fr
%dir /usr/local/pf/conf/locale/nl
%dir /usr/local/pf/conf/locale/en/LC_MESSAGES
%dir /usr/local/pf/conf/locale/es/LC_MESSAGES
%dir /usr/local/pf/conf/locale/fr/LC_MESSAGES
%dir /usr/local/pf/conf/locale/nl/LC_MESSAGES
%config(noreplace) /usr/local/pf/conf/locale/en/LC_MESSAGES/packetfence.po
%config(noreplace) /usr/local/pf/conf/locale/en/LC_MESSAGES/packetfence.mo
%config(noreplace) /usr/local/pf/conf/locale/es/LC_MESSAGES/packetfence.po
%config(noreplace) /usr/local/pf/conf/locale/es/LC_MESSAGES/packetfence.mo
%config(noreplace) /usr/local/pf/conf/locale/fr/LC_MESSAGES/packetfence.po
%config(noreplace) /usr/local/pf/conf/locale/fr/LC_MESSAGES/packetfence.mo
%config(noreplace) /usr/local/pf/conf/locale/nl/LC_MESSAGES/packetfence.po
%config(noreplace) /usr/local/pf/conf/locale/nl/LC_MESSAGES/packetfence.mo
%dir /usr/local/pf/db
/usr/local/pf/db/*
%dir /usr/local/pf/docs
%doc /usr/local/pf/docs/*.odt
%doc /usr/local/pf/docs/fdl-1.2.txt
%dir /usr/local/pf/docs/MIB
%doc /usr/local/pf/docs/MIB/Inverse-PacketFence-Notification.mib
%dir /usr/local/pf/lib
%dir /usr/local/pf/var
%dir /usr/local/pf/var/session
%dir /usr/local/pf/var/rrd
%dir /usr/local/pf/lib/pf
/usr/local/pf/lib/pf/*.pm
%dir /usr/local/pf/lib/pf/lookup
%config(noreplace) /usr/local/pf/lib/pf/lookup/node.pm
%config(noreplace) /usr/local/pf/lib/pf/lookup/person.pm
%dir /usr/local/pf/lib/pf/SNMP
/usr/local/pf/lib/pf/SNMP/*
%dir /usr/local/pf/lib/pf/pfcmd
/usr/local/pf/lib/pf/pfcmd/*
%dir /usr/local/pf/lib/pf/vlan
%config(noreplace) /usr/local/pf/lib/pf/vlan/custom.pm
%dir /usr/local/pf/logs
%attr(0755, pf, pf) /usr/local/pf/configurator.pl
%attr(0755, pf, pf) /usr/local/pf/installer.pl
%doc /usr/local/pf/CHANGES
%doc /usr/local/pf/COPYING
%doc /usr/local/pf/README
%doc /usr/local/pf/README_SWITCHES

%files remote-snort-sensor
%defattr(-, pf, pf)
%attr(0755, root, root) %{_initrddir}/pfdetectd
%dir /usr/local/pf
%dir /usr/local/pf/var
%dir /usr/local/pf/sbin
%dir /usr/local/pf/conf
%attr(0755, pf, pf) /usr/local/pf/sbin/pfdetect_remote
%config(noreplace) /usr/local/pf/conf/pfdetect_remote.conf


%changelog
* Mon Apr 30 2008 - Dominik Gehl
- 1.7.0 rc4
* Wed Oct 10 2007 - Dominik Gehl
- 1.7.0 v1
