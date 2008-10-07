#rpmbuild should be done in several steps:
#1) rpmbuild -bs packetfence.spec
#on each target distribution
#2) rpmbuild --rebuild --define 'dist .el5' packetfence-1.8-mtn.src.rpm
Summary: PacketFence network registration / worm mitigation system
Name: packetfence
Version: 1.8.0
Release: mtn%{?dist}
License: GPL
Group: System Environment/Daemons
URL: http://www.packetfence.org
AutoReqProv: 0
BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-%{version}-root

#currently IPTables::IPv4 should be installed through CPAN
Conflicts: perl(IPTables::IPv4) 

Packager: Dominik Gehl <dgehl@inverse.ca>
Vendor: PacketFence, http://www.packetfence.org

Source: http://prdownloads.sourceforge.net/packetfence/%{name}-%{version}.tar.gz

BuildRequires: gettext, perl(Parse::RecDescent), httpd
Requires: perl >= 5.8.0, perl-suidperl, httpd, mod_ssl, php, php-gd, libpcap, libxml2, zlib, zlib-devel, coreutils, net-snmp, iproute, sed
Requires: gcc, mysql, perl-DBD-MySQL
Requires: perl(CPAN)
Requires: perl(Time::HiRes), perl(Config::IniFiles), perl(Net::Netmask), perl(Date::Parse), perl(Parse::RecDescent), perl(Net::RawIP) = 0.2, perl(Net::Pcap) >= 0.16, perl(CGI), perl(CGI::Session), perl(Term::ReadKey), perl(File::Tail), perl(Net::MAC::Vendor), perl(Net::SNMP), perl(LWP::UserAgent), perl(Net::Telnet), perl(Net::Appliance::Session), perl(Log::Log4perl) >= 1.11, perl(Thread::Pool), perl(Locale::gettext), perl(Template), perl(Apache::Htpasswd), perl(Net::MAC)

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

%package remote-dhcp-listener
Group: System Environment/Daemons
Requires: perl >= 5.8.0, perl(Config::IniFiles), libpcap, perl-DBD-MySQL, perl(Net::Pcap)
Conflicts: packetfence
AutoReqProv: 0
Summary: Files needed for the dhcp listener on a remote machine

%description remote-dhcp-listener
The packetfence-remote-dhcp-listener package contains the files needed
for running the dhcp listener on a remote machine. This service will
inject the IP-MAC associations and DHCP fingerprints directly into the
main PacketFence database.

%prep
%setup -n pf

%build
#bug 745
/usr/bin/perl -w -e 'use strict; use warnings; use diagnostics; use Parse::RecDescent; use lib "./lib"; use pf::pfcmd::pfcmd; Parse::RecDescent->Precompile($grammar, "pfcmd_pregrammar");'
mv pfcmd_pregrammar.pm lib/pf/pfcmd/
#fin bug 745
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
cp -r bin $RPM_BUILD_ROOT/usr/local/pf/
cp -r cgi-bin $RPM_BUILD_ROOT/usr/local/pf/
cp -r conf $RPM_BUILD_ROOT/usr/local/pf/
#pfdetect_remote
mv contrib/pfdetect_remote/initrd/pfdetectd $RPM_BUILD_ROOT%{_initrddir}/
mv contrib/pfdetect_remote/bin/pfdetect_remote $RPM_BUILD_ROOT/usr/local/pf/bin
mv contrib/pfdetect_remote/conf/pfdetect_remote.conf $RPM_BUILD_ROOT/usr/local/pf/conf
rmdir contrib/pfdetect_remote/bin
rmdir contrib/pfdetect_remote/initrd
rmdir contrib/pfdetect_remote/conf
rmdir contrib/pfdetect_remote
#end pfdetect_remote
#remote pfdhcplistener
mv contrib/pfdhcplistener_remote/initrd/pfdhcplistenerd $RPM_BUILD_ROOT%{_initrddir}/
mkdir $RPM_BUILD_ROOT/etc/sysconfig
mv contrib/pfdhcplistener_remote/sysconfig/pfdhcplistener $RPM_BUILD_ROOT/etc/sysconfig/
rmdir contrib/pfdhcplistener_remote/initrd
rmdir contrib/pfdhcplistener_remote/sysconfig
rmdir contrib/pfdhcplistener_remote
#end remote pfdhcplistener
cp -r contrib $RPM_BUILD_ROOT/usr/local/pf/
cp -r test $RPM_BUILD_ROOT/usr/local/pf/
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

#start and stop symlinks
cd $RPM_BUILD_ROOT/usr/local/pf/bin
ln -s pfcmd ./start
ln -s pfcmd ./stop

#pfschema symlink
cd $RPM_BUILD_ROOT/usr/local/pf/db
ln -s pfschema.mysql.171 ./pfschema.mysql

#httpd.conf and local.conf symlink
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

%pre remote-dhcp-listener

if ! /usr/bin/id pf &>/dev/null; then
	/usr/sbin/useradd -r -d "/usr/local/pf" -s /bin/sh -c "PacketFence" -M pf || \
		echo Unexpected error adding user "pf" && exit
fi

%post
echo "Adding PacketFence startup script"
/sbin/chkconfig --add packetfence
for service in snortd httpd named snmptrapd
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

%post remote-dhcp-listener
echo "Adding PacketFence remote DHCP listener startup script"
/sbin/chkconfig --add pfdhcplistenerd

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

%preun remote-dhcp-listener
if [ $1 -eq 0 ] ; then
	/sbin/service pfdhcplistenerd stop &>/dev/null || :
	/sbin/chkconfig --del pfdhcplistenerd
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

%postun remote-dhcp-listener
if [ $1 -eq 0 ]; then
	/usr/sbin/userdel pf || %logmsg "User \"pf\" could not be deleted."
fi

%files

%defattr(-, pf, pf)
#%config %{_initrddir}/packetfence
%attr(0755, root, root) %{_initrddir}/packetfence
%dir /usr/local/pf
%dir /usr/local/pf/bin
/usr/local/pf/bin/dhcp_dumper
%attr(6755, root, root) /usr/local/pf/bin/pfcmd
/usr/local/pf/bin/pfcmd_vlan
%config(noreplace) /usr/local/pf/bin/flip.pl
/usr/local/pf/bin/pfdetect
/usr/local/pf/bin/pfredirect
/usr/local/pf/bin/pfmon
/usr/local/pf/bin/accounting.pl
%attr(0755, pf, pf) /usr/local/pf/bin/pfdhcplistener
%config(noreplace) /usr/local/pf/bin/lookup_node.pl
%config(noreplace) /usr/local/pf/bin/lookup_person.pl
/usr/local/pf/bin/pfsetvlan
/usr/local/pf/bin/start
/usr/local/pf/bin/stop
/usr/local/pf/bin/ip2interface.pl
%dir /usr/local/pf/cgi-bin
#%attr(6755, root, root) /usr/local/pf/cgi-bin/redir.cgi
#%attr(6755, root, root) /usr/local/pf/cgi-bin/register.cgi
#%attr(6755, root, root) /usr/local/pf/cgi-bin/release.cgi
/usr/local/pf/cgi-bin/pdp.cgi
/usr/local/pf/cgi-bin/redir.cgi
/usr/local/pf/cgi-bin/register.cgi
/usr/local/pf/cgi-bin/release.cgi
%dir /usr/local/pf/conf
#%config(noreplace) /usr/local/pf/conf/pf.conf
%config(noreplace) /usr/local/pf/conf/violations.conf
%config(noreplace) /usr/local/pf/conf/iptables.pre
#%config /usr/local/pf/conf/services.conf
%config(noreplace) /usr/local/pf/conf/ui.conf
%config(noreplace) /usr/local/pf/conf/ui-global.conf
%config(noreplace) /usr/local/pf/conf/switches.conf
%config(noreplace) /usr/local/pf/conf/log.conf
%config(noreplace) /usr/local/pf/conf/pfsetvlan.pm
%config /usr/local/pf/conf/pf.conf.defaults
%config(noreplace) /usr/local/pf/conf/templates/snmptrapd.conf
%config /usr/local/pf/conf/documentation.conf
/usr/local/pf/conf/pf-release
%config /usr/local/pf/conf/dhcp_fingerprints.conf
%config /usr/local/pf/conf/oui.txt
%dir /usr/local/pf/test
/usr/local/pf/test/connect_and_read.pl
/usr/local/pf/test/testSecureMACs.pl
%dir /usr/local/pf/contrib/lookup
/usr/local/pf/contrib/lookup/*
%dir /usr/local/pf/contrib/mrtg
/usr/local/pf/contrib/mrtg/*
%dir /usr/local/pf/contrib/802.1X
/usr/local/pf/contrib/802.1X/*
/usr/local/pf/contrib/oinkmaster.conf
%dir /usr/local/pf/contrib/addons
/usr/local/pf/contrib/addons/recovery.pl
/usr/local/pf/contrib/addons/monitorpfsetvlan.pl
/usr/local/pf/contrib/addons/autodiscover.pl
/usr/local/pf/contrib/addons/convertToPortSecurity.pl
%dir /usr/local/pf/html/user
%dir /usr/local/pf/html/user/3rdparty
/usr/local/pf/html/user/3rdparty/timerbar.js
%dir /usr/local/pf/html/user/content
%config(noreplace) /usr/local/pf/html/user/content/header.html
%config(noreplace) /usr/local/pf/html/user/content/footer.html
/usr/local/pf/html/user/content/index.php
/usr/local/pf/html/user/content/style.php
/usr/local/pf/html/user/content/reboot.php
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
%dir /usr/local/pf/conf/named
/usr/local/pf/conf/named/*
%dir /usr/local/pf/conf/snort
/usr/local/pf/conf/snort/*
%dir /usr/local/pf/conf/ssl
%dir /usr/local/pf/conf/users
%dir /usr/local/pf/conf/templates
/usr/local/pf/conf/templates/dhcpd.conf
/usr/local/pf/conf/templates/httpd.conf
/usr/local/pf/conf/templates/httpd.conf.pre_apache22
/usr/local/pf/conf/templates/httpd.conf.apache22
%config(noreplace) /usr/local/pf/conf/templates/named.conf
/usr/local/pf/conf/templates/snort.conf
/usr/local/pf/conf/templates/sysctl.conf
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
/usr/local/pf/docs/*
%dir /usr/local/pf/lib
%dir /usr/local/pf/var/session
%dir /usr/local/pf/lib/pf
/usr/local/pf/lib/pf/*
%dir /usr/local/pf/logs
/usr/local/pf/configurator.pl
/usr/local/pf/installer.pl
%doc /usr/local/pf/CHANGES
%doc /usr/local/pf/COPYING
%doc /usr/local/pf/README
%doc /usr/local/pf/README_SWITCHES

%files remote-snort-sensor
%defattr(-, pf, pf)
%attr(0755, root, root) %{_initrddir}/pfdetectd
%dir /usr/local/pf
%dir /usr/local/pf/var
%dir /usr/local/pf/bin
%dir /usr/local/pf/conf
%attr(0755, pf, pf) /usr/local/pf/bin/pfdetect_remote
%config(noreplace) /usr/local/pf/conf/pfdetect_remote.conf

%files remote-dhcp-listener
%defattr(-, pf, pf)
%attr(0755, root, root) %{_initrddir}/pfdhcplistenerd
%config(noreplace) /etc/sysconfig/pfdhcplistener
%dir /usr/local/pf
%dir /usr/local/pf/var
%dir /usr/local/pf/bin
%dir /usr/local/pf/conf
%config /usr/local/pf/conf/pf.conf.defaults
%config /usr/local/pf/conf/documentation.conf
%dir /usr/local/pf/logs
%dir /usr/local/pf/lib
%dir /usr/local/pf/lib/pf
/usr/local/pf/lib/pf/config.pm
/usr/local/pf/lib/pf/iplog.pm
/usr/local/pf/lib/pf/db.pm
/usr/local/pf/lib/pf/util.pm
/usr/local/pf/lib/pf/person.pm
/usr/local/pf/lib/pf/node.pm
/usr/local/pf/lib/pf/class.pm
/usr/local/pf/lib/pf/violation.pm
/usr/local/pf/lib/pf/trigger.pm
/usr/local/pf/lib/pf/services.pm
/usr/local/pf/lib/pf/os.pm
/usr/local/pf/lib/pf/action.pm
/usr/local/pf/lib/pf/iptables.pm
/usr/local/pf/lib/pf/rawip.pm
/usr/local/pf/lib/pf/locationlog.pm
%attr(0755, pf, pf) /usr/local/pf/bin/pfdhcplistener
%config(noreplace) /usr/local/pf/bin/lookup_node.pl
%attr(6755, root, root) /usr/local/pf/bin/pfcmd
%dir /usr/local/pf/lib/pf/pfcmd
/usr/local/pf/lib/pf/pfcmd/pfcmd.pm
/usr/local/pf/lib/pf/pfcmd/help.pm
/usr/local/pf/lib/pf/pfcmd/pfcmd_pregrammar.pm

%changelog
* Mon Apr 30 2008 - Dominik Gehl
- 1.7.0 rc4
* Wed Oct 10 2007 - Dominik Gehl
- 1.7.0 v1
