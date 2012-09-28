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
Summary: PacketFence network registration / worm mitigation system
%global real_name packetfence
Name: %{real_name}-source
Version: %{ver}
Release: %{rev}%{?dist}
License: GPL
Group: System Environment/Daemons
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

# Log related globals
%global logfiles packetfence.log snmptrapd.log access_log error_log admin_access_log admin_error_log admin_debug_log pfdetect pfmon pfredirect
%global logdir /usr/local/pf/logs

BuildRequires: gettext, httpd, rpm-macros-rpmforge, bind
BuildRequires: perl(Parse::RecDescent)
# Required to build documentation
# See docs/docbook/README.asciidoc for more info about installing requirements.
# TODO fop on EL5 is actually xmlgraphics-fop
%{?el6:BuildRequires: asciidoc >= 8.6.2, fop, libxslt, docbook-style-xsl, xalan-j2 }

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

# arch-specific pfcmd-suid subpackage required us to move all of PacketFence
# into a noarch subpackage and have the top level package virtual.
%package -n %{real_name}
Group: System Environment/Daemons
Summary: PacketFence network registration / worm mitigation system
BuildArch: noarch
# TODO we might consider re-enabling this to simplify our SPEC
AutoReqProv: 0

Requires: chkconfig, coreutils, grep, iproute, openssl, sed, tar, wget, gettext
# for process management
Requires: procps
Requires: libpcap, libxml2, zlib, zlib-devel, glibc-common,
Requires: httpd, mod_ssl, php, php-gd
Requires: mod_perl
Requires: dhcp, bind
# FreeRADIUS version >= 2.1.12 and the name changed between the RHEL 5 and 6 releases
%{?el5:Requires: freeradius2 >= 2.1.12, freeradius2-mysql, freeradius2-perl, freeradius2-ldap, freeradius2-utils }
%{?el6:Requires: freeradius >= 2.1.12, freeradius-mysql, freeradius-perl, freeradius-ldap, freeradius-utils }
Requires: make
# php-pear-Log required not php-pear, fixes #804
Requires: php-pear-Log
Requires: net-tools
Requires: net-snmp >= 5.3.2.2
Requires: mysql, mysql-server, perl(DBD::mysql)
Requires: perl >= 5.8.8
# replaces the need for perl-suidperl which was deprecated in perl 5.12 (Fedora 14)
Requires: %{real_name}-pfcmd-suid
Requires: perl(Bit::Vector)
Requires: perl(CGI::Session), perl(JSON), perl(PHP::Session)
Requires: perl(Class::Accessor)
Requires: perl(Class::Accessor::Fast::Contained)
Requires: perl(Class::Data::Inheritable)
Requires: perl(Class::Gomor)
Requires: perl(Config::IniFiles) >= 2.40
Requires: perl(Data::Phrasebook), perl(Data::Phrasebook::Loader::YAML)
Requires: perl(DBI)
Requires: perl(File::Tail)
Requires: perl(IPC::Cmd)
Requires: perl(IPTables::ChainMgr)
Requires: perl(IPTables::Parse)
# Perl core modules but still explicitly defined just in case distro's core perl get stripped
Requires: perl(Time::HiRes)
# Required for inline mode. Specific version matches system's iptables version.
# CentOS 5 (iptables 1.3.5)
%{?el5:Requires: perl(IPTables::libiptc) = 0.14}
%{?el6:Requires: perl(IPTables::libiptc)}
Requires: perl(Net::LDAP)
# TODO: we depend on perl modules not perl-libwww-perl
# find out what they are and specify them as perl(...::...) instead of perl-libwww-perl
Requires: perl-libwww-perl, perl(LWP::Protocol::https)
Requires: perl(List::MoreUtils)
Requires: perl(Locale::gettext)
Requires: perl(Log::Log4perl) >= 1.11
# Required by switch modules
# Net::Appliance::Session specific version added because newer versions broke API compatibility (#1312)
# We would need to port to the new 3.x API (tracked by #1313)
Requires: perl(Net::Appliance::Session) = 1.36
# Required by configurator script, pf::config
Requires: perl(Net::Interface)
Requires: perl(Net::MAC), perl(Net::MAC::Vendor)
Requires: perl(Net::Netmask)
# pfmon, pfdhcplistener
Requires: perl(Net::Pcap) >= 0.16
# pfdhcplistener
Requires: perl(NetPacket) >= 1.2.0
# RADIUS CoA support
Requires: perl(Net::Radius::Dictionary), perl(Net::Radius::Packet)
# SNMP to network hardware
Requires: perl(Net::SNMP)
# for SNMPv3 AES as privacy protocol, fixes #775
Requires: perl(Crypt::Rijndael)
Requires: perl(Net::Telnet)
Requires: perl(Parse::Nessus::NBE)
Requires: perl(Parse::RecDescent)
# for nessus scan, this version add the NBE download (inverse patch)
Requires: perl(Net::Nessus::XMLRPC) >= 0.40
# Note: portability for non-x86 is questionnable for Readonly::XS
Requires: perl(Readonly), perl(Readonly::XS)
Requires: perl(Regexp::Common)
Requires: rrdtool, perl-rrdtool
Requires: perl(SOAP::Lite)
# Template::Toolkit - captive portal template system
Requires: perl(Template)
# Used by installer / configurator scripts
Requires: perl(Term::ReadKey)
Requires: perl(Thread::Pool)
Requires: perl(Date::Parse)
Requires: perl(UNIVERSAL::require)
Requires: perl(YAML)
Requires: php-ldap
Requires: perl(Try::Tiny)
Requires: perl(Crypt::GeneratePassword)
Requires: perl(MIME::Lite::TT)
Requires: perl(Cache::Cache), perl(HTML::Parser)
Requires: perl(URI::Escape)
# Used by Captive Portal authentication modules
Requires: perl(Apache::Htpasswd)
Requires: perl(Authen::Radius)
Requires: perl(Authen::Krb5::Simple)
# Required for importation feature
Requires: perl(Text::CSV)
Requires: perl(Text::CSV_XS)
# BILLING ENGINE
Requires: perl(LWP::UserAgent)
Requires: perl(HTTP::Request::Common)
# Catalyst
Requires: perl(Catalyst::Runtime), perl(Catalyst::Plugin::ConfigLoader)
Requires: perl(Catalyst::Plugin::Static::Simple), perl(Catalyst::Action::RenderView)
Requires: perl(Config::General), perl(Catalyst::Plugin::StackTrace)
Requires: perl(Catalyst::Plugin::Session), perl(Catalyst::Plugin::Session::Store::File)
Requires: perl(Catalyst::Plugin::Session::State::Cookie)
Requires: perl(Catalyst::Plugin::I18N)
Requires: perl(Catalyst::View::TT)
Requires: perl(Catalyst::View::JSON), perl(Log::Log4perl::Catalyst)
Requires: perl(Catalyst::Plugin::Authentication)
Requires: perl(Catalyst::Authentication::Credential::HTTP)
Requires: perl(Catalyst::Authentication::Store::Htpasswd)
Requires: perl(Catalyst::Controller::HTML::FormFu)
Requires: perl(Params::Validate) >= 0.97
# for Catalyst stand-alone server
Requires: perl(Catalyst::Devel)
# these are probably missing dependencies for the above. 
# I shall file upstream tickets to openfusion before we integrate
Requires: perl(Plack), perl(Plack::Middleware::ReverseProxy)
Requires: perl(MooseX::Types::LoadableClass)
# configuration-wizard
Requires: perl(IO::Interface::Simple)
Requires: vconfig
#
# TESTING related
#
Requires: perl(Test::MockObject), perl(Test::MockModule)
Requires: perl(Test::Perl::Critic), perl(Test::WWW::Mechanize)
Requires: perl(Test::Pod), perl(Test::Pod::Coverage), perl(Test::Exception)
Requires: perl(Test::NoWarnings)
# required for the fake CoA server
Requires: perl(Net::UDP)

%description -n %{real_name}

PacketFence is an open source network access control (NAC) system. 
It can be used to effectively secure networks, from small to very large 
heterogeneous networks. PacketFence provides features such 
as 
* registration of new network devices
* detection of abnormal network activities
* isolation of problematic devices
* remediation through a captive portal 
* registration-based and scheduled vulnerability scans.


%package -n %{real_name}-remote-snort-sensor
Group: System Environment/Daemons
Requires: perl >= 5.8.0, snort, perl(File::Tail), perl(Config::IniFiles), perl(IO::Socket::SSL), perl(XML::Parser), perl(Crypt::SSLeay)
Requires: perl(SOAP::Lite)
Conflicts: %{real_name}
AutoReqProv: 0
Summary: Files needed for sending snort alerts to packetfence
BuildArch: noarch

%description -n %{real_name}-remote-snort-sensor
The %{real_name}-remote-snort-sensor package contains the files needed
for sending snort alerts from a remote snort sensor to a PacketFence
server.


%package -n %{real_name}-pfcmd-suid
Group: System Environment/Daemons
BuildRequires: gcc
Requires: %{real_name} >= 3.6.0
AutoReqProv: 0
Summary: Replace pfcmd by a C wrapper for suid

%description -n %{real_name}-pfcmd-suid
The %{real_name}-pfcmd-suid is a C wrapper to replace perl-suidperl dependency.
See https://bugzilla.redhat.com/show_bug.cgi?id=611009


%prep
%setup -q -n %{real_name}-%{version}

%build
# generate pfcmd_pregrammar
/usr/bin/perl -w -e 'use strict; use warnings; use diagnostics; use Parse::RecDescent; use lib "./lib"; use pf::pfcmd::pfcmd; Parse::RecDescent->Precompile($grammar, "pfcmd_pregrammar");'
mv pfcmd_pregrammar.pm lib/pf/pfcmd/

# generate translations
# TODO this is duplicated in debian/rules, we should aim to consolidate in a 'make' style step
for TRANSLATION in de en es fr he_IL it nl pt_BR; do 
    /usr/bin/msgfmt conf/locale/$TRANSLATION/LC_MESSAGES/packetfence.po
    mv packetfence.mo conf/locale/$TRANSLATION/LC_MESSAGES/
done

# RHEL6 only: generating PDF guides
%if 0%{?el6}
# generating custom XSL for titlepage
xsltproc -o docs/docbook/xsl/titlepage-fo.xsl \
    /usr/share/sgml/docbook/xsl-stylesheets/template/titlepage.xsl \
    docs/docbook/xsl/titlepage-fo.xml
# admin, network device config, devel and ZEN install guides
for GUIDE in PacketFence_Administration_Guide PacketFence_Developers_Guide PacketFence_Network_Devices_Configuration_Guide PacketFenceZEN_Installation_Guide; do 
asciidoc -a docinfo2 -b docbook -d book \
    -o docs/docbook/$GUIDE.docbook \
    docs/$GUIDE.asciidoc
fop -c docs/fonts/fop-config.xml \
    -xml docs/docbook/$GUIDE.docbook \
    -xsl docs/docbook/xsl/packetfence-fo.xsl \
    -pdf docs/$GUIDE.pdf
done
%endif
# build pfcmd C wrapper
gcc -g0 src/pfcmd.c -o bin/pfcmd

%install
%{__rm} -rf $RPM_BUILD_ROOT
%{__install} -D -m0755 packetfence.init $RPM_BUILD_ROOT%{_initrddir}/packetfence
%{__install} -D -m0755 pfappserver.init $RPM_BUILD_ROOT%{_initrddir}/pfappserver
%{__install} -d $RPM_BUILD_ROOT/etc/logrotate.d
# creating path components that are no longer in the tarball since we moved to git
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/addons
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/conf/radiusd
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/conf/users
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/conf/ssl
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/html/admin/mrtg
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/html/admin/scan/results
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/html/admin/traplog
%{__install} -d $RPM_BUILD_ROOT%logdir
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/var/conf
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/var/dhcpd
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/var/named
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/var/run
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/var/rrd 
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/var/session
%{__install} -d $RPM_BUILD_ROOT/usr/local/pf/var/webadmin_cache
cp -r bin $RPM_BUILD_ROOT/usr/local/pf/
cp -r addons/captive-portal/ $RPM_BUILD_ROOT/usr/local/pf/addons/
cp -r addons/dev-helpers/ $RPM_BUILD_ROOT/usr/local/pf/addons/
cp -r addons/high-availability/ $RPM_BUILD_ROOT/usr/local/pf/addons/
cp -r addons/integration-testing/ $RPM_BUILD_ROOT/usr/local/pf/addons/
cp -r addons/mrtg/ $RPM_BUILD_ROOT/usr/local/pf/addons/
cp -r addons/packages/ $RPM_BUILD_ROOT/usr/local/pf/addons/
cp -r addons/snort/ $RPM_BUILD_ROOT/usr/local/pf/addons/
cp -r addons/soh/ $RPM_BUILD_ROOT/usr/local/pf/addons/
cp -r addons/upgrade/ $RPM_BUILD_ROOT/usr/local/pf/addons/
cp -r addons/watchdog/ $RPM_BUILD_ROOT/usr/local/pf/addons/
cp addons/*.pl $RPM_BUILD_ROOT/usr/local/pf/addons/
cp addons/*.sh $RPM_BUILD_ROOT/usr/local/pf/addons/
cp addons/logrotate $RPM_BUILD_ROOT/usr/local/pf/addons/
cp addons/logrotate $RPM_BUILD_ROOT/etc/logrotate.d/packetfence
cp -r sbin $RPM_BUILD_ROOT/usr/local/pf/
cp -r conf $RPM_BUILD_ROOT/usr/local/pf/
cp -r raddb $RPM_BUILD_ROOT/usr/local/pf/
#pfdetect_remote
mv addons/pfdetect_remote/initrd/pfdetectd $RPM_BUILD_ROOT%{_initrddir}/
mv addons/pfdetect_remote/sbin/pfdetect_remote $RPM_BUILD_ROOT/usr/local/pf/sbin
mv addons/pfdetect_remote/conf/pfdetect_remote.conf $RPM_BUILD_ROOT/usr/local/pf/conf
rmdir addons/pfdetect_remote/sbin
rmdir addons/pfdetect_remote/initrd
rmdir addons/pfdetect_remote/conf
rmdir addons/pfdetect_remote
#end pfdetect_remote
cp -r ChangeLog $RPM_BUILD_ROOT/usr/local/pf/
cp -r COPYING $RPM_BUILD_ROOT/usr/local/pf/
cp -r db $RPM_BUILD_ROOT/usr/local/pf/
cp -r docs $RPM_BUILD_ROOT/usr/local/pf/
rm -r $RPM_BUILD_ROOT/usr/local/pf/docs/archives
rm -r $RPM_BUILD_ROOT/usr/local/pf/docs/docbook
rm -r $RPM_BUILD_ROOT/usr/local/pf/docs/fonts
rm -r $RPM_BUILD_ROOT/usr/local/pf/docs/images
cp -r html $RPM_BUILD_ROOT/usr/local/pf/
cp -r lib $RPM_BUILD_ROOT/usr/local/pf/
cp -r NEWS $RPM_BUILD_ROOT/usr/local/pf/
cp -r README $RPM_BUILD_ROOT/usr/local/pf/
cp -r README.network-devices $RPM_BUILD_ROOT/usr/local/pf/
cp -r UPGRADE $RPM_BUILD_ROOT/usr/local/pf/
# logfiles
for LOG in %logfiles; do
    touch $RPM_BUILD_ROOT%logdir/$LOG
done

#start create symlinks
curdir=`pwd`

#pf-schema.sql symlinks to current schema
if [ ! -e "$RPM_BUILD_ROOT/usr/local/pf/db/pf-schema.sql" ]; then
    cd $RPM_BUILD_ROOT/usr/local/pf/db
    VERSIONSQL=$(ls pf-schema-* |sort -r | head -1)
    ln -s $VERSIONSQL ./pf-schema.sql
fi

#httpd.conf symlink
#We dropped support for pre 2.2.0 but keeping the symlink trick alive since Apache 2.4 is coming
cd $RPM_BUILD_ROOT/usr/local/pf/conf
ln -s httpd.conf.apache22 ./httpd.conf
#if (/usr/sbin/httpd -v | egrep 'Apache/2\.[2-9]\.' > /dev/null)
#then
#  ln -s httpd.conf.apache22 ./httpd.conf
#else
#  ln -s httpd.conf.pre_apache22 ./httpd.conf
#fi

#named.conf symlink
#We added the support fort BIND 9.7+ for getting rid of the session-keyfile error
cd $RPM_BUILD_ROOT/usr/local/pf/conf
if ( /usr/sbin/named -v | egrep 'BIND\ 9.[7-9]' > /dev/null )
then
    ln -s named.conf.bind97 ./named.conf
else
    ln -s named.conf.pre_bind97 ./named.conf
fi

cd $curdir
#end create symlinks

%clean
rm -rf $RPM_BUILD_ROOT

%pre -n %{real_name}

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


%pre -n %{real_name}-remote-snort-sensor

if ! /usr/bin/id pf &>/dev/null; then
        /usr/sbin/useradd -r -d "/usr/local/pf" -s /bin/sh -c "PacketFence" -M pf || \
                echo Unexpected error adding user "pf" && exit
fi

%post -n %{real_name}
echo "Adding PacketFence startup script"
/sbin/chkconfig --add packetfence
echo "Adding pfappserver startup script"
/sbin/chkconfig --add pfappserver

#Check if log files exist and create them with the correct owner
for fic_log in packetfence.log access_log error_log admin_access_log admin_error_log
do
if [ ! -e /usr/local/pf/logs/$fic_log ]; then
  touch /usr/local/pf/logs/$fic_log
  chown pf.pf /usr/local/pf/logs/$fic_log
fi
done

#Make ssl certificate
if [ ! -f /usr/local/pf/conf/ssl/server.crt ]; then
    openssl req -x509 -new -nodes -days 365 -batch\
    	-out /usr/local/pf/conf/ssl/server.crt\
    	-keyout /usr/local/pf/conf/ssl/server.key\
    	-nodes -config /usr/local/pf/conf/openssl.cnf
fi


for service in snortd httpd snmptrapd
do
  if /sbin/chkconfig --list | grep $service > /dev/null 2>&1; then
    echo "Disabling $service startup script"
    /sbin/chkconfig --del $service > /dev/null 2>&1
  fi
done

if [ -e /etc/logrotate.d/snort ]; then
  echo Removing /etc/logrotate.d/snort - it kills snort every night
  rm -f /etc/logrotate.d/snort
fi

#Check if RADIUS have a dh
if [ ! -f /usr/local/pf/raddb/certs/dh ]; then
  echo "Building default RADIUS certificates..."
  cd /usr/local/pf/raddb/certs
  make dh
else
  echo "DH already exists, won't touch it!"
fi

#Start pfappserver
service pfappserver start

echo Installation complete
echo "  * Please fire up your Web browser and go to http://@ip_packetfence:3000/configurator to complete your PacketFence configuration."

%post -n %{real_name}-remote-snort-sensor
echo "Adding PacketFence remote Snort Sensor startup script"
/sbin/chkconfig --add pfdetectd

%preun -n %{real_name}
if [ $1 -eq 0 ] ; then
        /sbin/service packetfence stop &>/dev/null || :
        /sbin/chkconfig --del packetfence
fi

%preun -n %{real_name}-remote-snort-sensor
if [ $1 -eq 0 ] ; then
        /sbin/service pfdetectd stop &>/dev/null || :
        /sbin/chkconfig --del pfdetectd
fi

%postun -n %{real_name}
if [ $1 -eq 0 ]; then
        /usr/sbin/userdel pf || %logmsg "User \"pf\" could not be deleted."
#       /usr/sbin/groupdel pf || %logmsg "Group \"pf\" could not be deleted."
#else
#       /sbin/service pf condrestart &>/dev/null || :
fi

%postun -n %{real_name}-remote-snort-sensor
if [ $1 -eq 0 ]; then
        /usr/sbin/userdel pf || %logmsg "User \"pf\" could not be deleted."
fi

# TODO we should simplify this file manifest to the maximum keeping treating 
# only special attributes explicitly 
# "To make this situation a bit easier, if the %files list contains a path 
# to a directory, RPM will automatically package every file in that 
# directory, as well as every file in each subdirectory."
# -- http://www.rpm.org/max-rpm/s1-rpm-inside-files-list.html
%files -n %{real_name}

%defattr(-, pf, pf)
%attr(0755, root, root) %{_initrddir}/packetfence
%attr(0755, root, root) %{_initrddir}/pfappserver
%dir                    %{_sysconfdir}/logrotate.d
%config                 %{_sysconfdir}/logrotate.d/packetfence

%dir                    /usr/local/pf
%dir                    /usr/local/pf/addons
%attr(0755, pf, pf)     /usr/local/pf/addons/*.pl
%attr(0755, pf, pf)     /usr/local/pf/addons/*.sh
%dir                    /usr/local/pf/addons/captive-portal/
                        /usr/local/pf/addons/captive-portal/*
%dir                    /usr/local/pf/addons/dev-helpers/
                        /usr/local/pf/addons/dev-helpers/*
%dir                    /usr/local/pf/addons/high-availability/
                        /usr/local/pf/addons/high-availability/*
%dir                    /usr/local/pf/addons/integration-testing/
                        /usr/local/pf/addons/integration-testing/*
                        /usr/local/pf/addons/logrotate
%dir                    /usr/local/pf/addons/mrtg
                        /usr/local/pf/addons/mrtg/*
%dir                    /usr/local/pf/addons/packages
                        /usr/local/pf/addons/packages/*
%dir                    /usr/local/pf/addons/snort
%attr(0755, pf, pf)     /usr/local/pf/addons/snort/update_rules.pl
                        /usr/local/pf/addons/snort/oinkmaster.conf
                        /usr/local/pf/addons/snort/oinkmaster.conf.2.8.6
%dir                    /usr/local/pf/addons/soh
%doc                    /usr/local/pf/addons/soh/README.rst
%dir                    /usr/local/pf/addons/upgrade
%attr(0755, pf, pf)     /usr/local/pf/addons/upgrade/*.pl
%dir                    /usr/local/pf/addons/watchdog
%attr(0755, pf, pf)     /usr/local/pf/addons/watchdog/*.sh
%dir                    /usr/local/pf/bin
%attr(0755, pf, pf)     /usr/local/pf/bin/pfcmd.pl
%attr(0755, pf, pf)     /usr/local/pf/bin/pfcmd_vlan
%doc                    /usr/local/pf/ChangeLog
%dir                    /usr/local/pf/conf
%config(noreplace)      /usr/local/pf/conf/admin.perm
%config(noreplace)      /usr/local/pf/conf/admin_ldap.conf
%dir                    /usr/local/pf/conf/authentication
%config(noreplace)      /usr/local/pf/conf/authentication/guest_managers.pm
%config(noreplace)      /usr/local/pf/conf/authentication/kerberos.pm
%config(noreplace)      /usr/local/pf/conf/authentication/local.pm
%config(noreplace)      /usr/local/pf/conf/authentication/ldap.pm
%config(noreplace)      /usr/local/pf/conf/authentication/preregistered_guests.pm
%config(noreplace)      /usr/local/pf/conf/authentication/radius.pm
%config                 /usr/local/pf/conf/dhcp_fingerprints.conf
%config                 /usr/local/pf/conf/documentation.conf
%config(noreplace)      /usr/local/pf/conf/floating_network_device.conf
%config(noreplace)      /usr/local/pf/conf/guest-managers.conf
%dir                    /usr/local/pf/conf/locale
%dir                    /usr/local/pf/conf/locale/de
%dir                    /usr/local/pf/conf/locale/de/LC_MESSAGES
%config(noreplace)      /usr/local/pf/conf/locale/de/LC_MESSAGES/packetfence.po
%config(noreplace)      /usr/local/pf/conf/locale/de/LC_MESSAGES/packetfence.mo
%dir                    /usr/local/pf/conf/locale/en
%dir                    /usr/local/pf/conf/locale/en/LC_MESSAGES
%config(noreplace)      /usr/local/pf/conf/locale/en/LC_MESSAGES/packetfence.po
%config(noreplace)      /usr/local/pf/conf/locale/en/LC_MESSAGES/packetfence.mo
%dir                    /usr/local/pf/conf/locale/es
%dir                    /usr/local/pf/conf/locale/es/LC_MESSAGES
%config(noreplace)      /usr/local/pf/conf/locale/es/LC_MESSAGES/packetfence.po
%config(noreplace)      /usr/local/pf/conf/locale/es/LC_MESSAGES/packetfence.mo
%dir                    /usr/local/pf/conf/locale/fr
%dir                    /usr/local/pf/conf/locale/fr/LC_MESSAGES
%config(noreplace)      /usr/local/pf/conf/locale/fr/LC_MESSAGES/packetfence.po
%config(noreplace)      /usr/local/pf/conf/locale/fr/LC_MESSAGES/packetfence.mo
%dir                    /usr/local/pf/conf/locale/he_IL
%dir                    /usr/local/pf/conf/locale/he_IL/LC_MESSAGES
%config(noreplace)      /usr/local/pf/conf/locale/he_IL/LC_MESSAGES/packetfence.po
%config(noreplace)      /usr/local/pf/conf/locale/he_IL/LC_MESSAGES/packetfence.mo
%dir                    /usr/local/pf/conf/locale/it
%dir                    /usr/local/pf/conf/locale/it/LC_MESSAGES
%config(noreplace)      /usr/local/pf/conf/locale/it/LC_MESSAGES/packetfence.po
%config(noreplace)      /usr/local/pf/conf/locale/it/LC_MESSAGES/packetfence.mo
%dir                    /usr/local/pf/conf/locale/nl
%dir                    /usr/local/pf/conf/locale/nl/LC_MESSAGES
%config(noreplace)      /usr/local/pf/conf/locale/nl/LC_MESSAGES/packetfence.po
%config(noreplace)      /usr/local/pf/conf/locale/nl/LC_MESSAGES/packetfence.mo
%dir                    /usr/local/pf/conf/locale/pt_BR
%dir                    /usr/local/pf/conf/locale/pt_BR/LC_MESSAGES
%config(noreplace)      /usr/local/pf/conf/locale/pt_BR/LC_MESSAGES/packetfence.po
%config(noreplace)      /usr/local/pf/conf/locale/pt_BR/LC_MESSAGES/packetfence.mo
%config(noreplace)      /usr/local/pf/conf/log.conf
%dir                    /usr/local/pf/conf/nessus
%config(noreplace)      /usr/local/pf/conf/nessus/remotescan.nessus
%config(noreplace)      /usr/local/pf/conf/networks.conf
%config                 /usr/local/pf/conf/openssl.cnf
%config                 /usr/local/pf/conf/oui.txt
#%config(noreplace)      /usr/local/pf/conf/pf.conf
%config                 /usr/local/pf/conf/pf.conf.defaults
                        /usr/local/pf/conf/pf-release
#%config                 /usr/local/pf/conf/services.conf
%dir			/usr/local/pf/conf/radiusd
%config(noreplace)	/usr/local/pf/conf/radiusd/eap.conf
%config(noreplace)	/usr/local/pf/conf/radiusd/radiusd.conf
%config(noreplace)	/usr/local/pf/conf/radiusd/sql.conf
%dir                    /usr/local/pf/conf/snort
%config(noreplace)      /usr/local/pf/conf/snort/classification.config
%config(noreplace)      /usr/local/pf/conf/snort/local.rules
%config(noreplace)      /usr/local/pf/conf/snort/reference.config
%dir                    /usr/local/pf/conf/ssl
%config(noreplace)      /usr/local/pf/conf/switches.conf
%config                 /usr/local/pf/conf/dhcpd.conf
%config                 /usr/local/pf/conf/httpd.conf
%dir                    /usr/local/pf/conf/httpd.conf.d
%config                 /usr/local/pf/conf/httpd.conf.d/*
%config                 /usr/local/pf/conf/httpd.conf.apache22
%config(noreplace)      /usr/local/pf/conf/iptables.conf
%config(noreplace)      /usr/local/pf/conf/listener.msg
%config(noreplace)      /usr/local/pf/conf/named-inline.ca
%config(noreplace)      /usr/local/pf/conf/named-isolation.ca
%config(noreplace)      /usr/local/pf/conf/named-registration.ca
%config                 /usr/local/pf/conf/named.conf
%config                 /usr/local/pf/conf/named.conf.pre_bind97
%config                 /usr/local/pf/conf/named.conf.bind97
%config(noreplace)      /usr/local/pf/conf/popup.msg
%config(noreplace)      /usr/local/pf/conf/snmptrapd.conf
%config(noreplace)      /usr/local/pf/conf/snort.conf
%config(noreplace)      /usr/local/pf/conf/snort.conf.pre_snort-2.8
%config(noreplace)      /usr/local/pf/conf/ssl-certificates.conf
%config(noreplace)      /usr/local/pf/conf/suricata.yaml
%dir                    /usr/local/pf/conf/templates
%config(noreplace)      /usr/local/pf/conf/templates/*
%config                 /usr/local/pf/conf/ui.conf
%config                 /usr/local/pf/conf/ui.conf.es_ES
%config(noreplace)      /usr/local/pf/conf/ui-global.conf
%dir                    /usr/local/pf/conf/users
%config(noreplace)      /usr/local/pf/conf/violations.conf
%doc                    /usr/local/pf/COPYING
%dir                    /usr/local/pf/db
                        /usr/local/pf/db/*
%dir                    /usr/local/pf/docs
%doc                    /usr/local/pf/docs/*.asciidoc
%{?el6:%doc             /usr/local/pf/docs/*.pdf }
%doc                    /usr/local/pf/docs/*.xml
%doc                    /usr/local/pf/docs/fdl-1.2.txt
%dir                    /usr/local/pf/docs/includes
%doc                    /usr/local/pf/docs/includes/*.asciidoc
%dir                    /usr/local/pf/docs/MIB
%doc                    /usr/local/pf/docs/MIB/Inverse-PacketFence-Notification.mib
%dir                    /usr/local/pf/html
%dir                    /usr/local/pf/html/admin
                        /usr/local/pf/html/admin/*
%dir                    /usr/local/pf/html/admin/templates
%config(noreplace)      /usr/local/pf/html/admin/templates/*
%dir                    /usr/local/pf/html/captive-portal
%attr(0755, pf, pf)     /usr/local/pf/html/captive-portal/*.cgi
                        /usr/local/pf/html/captive-portal/*.php
%config(noreplace)      /usr/local/pf/html/captive-portal/content/responsive.css
%config(noreplace)      /usr/local/pf/html/captive-portal/content/styles.css
%config(noreplace)      /usr/local/pf/html/captive-portal/content/print.css
                        /usr/local/pf/html/captive-portal/content/guest-management.js
                        /usr/local/pf/html/captive-portal/content/timerbar.js
%dir                    /usr/local/pf/html/captive-portal/content/images
                        /usr/local/pf/html/captive-portal/content/images/*
%dir                    /usr/local/pf/html/captive-portal/templates
%config(noreplace)      /usr/local/pf/html/captive-portal/templates/*
%dir                    /usr/local/pf/html/captive-portal/violations
%config(noreplace)      /usr/local/pf/html/captive-portal/violations/*
%dir                    /usr/local/pf/html/common
                        /usr/local/pf/html/common/*
                        /usr/local/pf/html/pfappserver/
                        /usr/local/pf/lib
%config(noreplace)      /usr/local/pf/lib/pf/billing/custom.pm
%config(noreplace)      /usr/local/pf/lib/pf/floatingdevice/custom.pm
%config(noreplace)      /usr/local/pf/lib/pf/inline/custom.pm
%config(noreplace)      /usr/local/pf/lib/pf/lookup/node.pm
%config(noreplace)      /usr/local/pf/lib/pf/lookup/person.pm
%dir                    /usr/local/pf/lib/pf/pfcmd
                        /usr/local/pf/lib/pf/pfcmd/*
%dir                    /usr/local/pf/lib/pf/Portal
                        /usr/local/pf/lib/pf/Portal/*
%dir                    /usr/local/pf/lib/pf/radius
                        /usr/local/pf/lib/pf/radius/constants.pm
%config(noreplace)      /usr/local/pf/lib/pf/radius/custom.pm
%config(noreplace)      /usr/local/pf/lib/pf/roles/custom.pm
%config(noreplace)      /usr/local/pf/lib/pf/soh/custom.pm
%config(noreplace)      /usr/local/pf/lib/pf/vlan/custom.pm
%config(noreplace)      /usr/local/pf/lib/pf/web/custom.pm
%dir                    /usr/local/pf/logs
# logfiles
%ghost                  %logdir/packetfence.log
%ghost                  %logdir/snmptrapd.log
%ghost                  %logdir/access_log
%ghost                  %logdir/error_log
%ghost                  %logdir/admin_access_log
%ghost                  %logdir/admin_error_log
%ghost                  %logdir/admin_debug_log
%ghost                  %logdir/pfdetect
%ghost                  %logdir/pfmon
%ghost                  %logdir/pfredirect
%doc                    /usr/local/pf/NEWS
%doc                    /usr/local/pf/README
%doc                    /usr/local/pf/README.network-devices
%dir                    /usr/local/pf/sbin
%attr(0755, pf, pf)     /usr/local/pf/sbin/pfdetect
%attr(0755, pf, pf)     /usr/local/pf/sbin/pfdhcplistener
%attr(0755, pf, pf)     /usr/local/pf/sbin/pfmon
%attr(0755, pf, pf)     /usr/local/pf/sbin/pfredirect
%attr(0755, pf, pf)     /usr/local/pf/sbin/pfsetvlan
%doc                    /usr/local/pf/UPGRADE
%dir                    /usr/local/pf/var
%dir                    /usr/local/pf/var/conf
%dir                    /usr/local/pf/var/dhcpd
%dir                    /usr/local/pf/var/named
%dir			/usr/local/pf/raddb
			/usr/local/pf/raddb/*
%config			/usr/local/pf/raddb/clients.conf
%config			/usr/local/pf/raddb/packetfence.pm
%attr(0755, pf, pf)	/usr/local/pf/raddb/packetfence.pm
%config			/usr/local/pf/raddb/packetfence-soh.pm
%attr(0755, pf, pf)	/usr/local/pf/raddb/packetfence-soh.pm
%config			/usr/local/pf/raddb/proxy.conf
%config			/usr/local/pf/raddb/users
%config			/usr/local/pf/raddb/modules/mschap
%config                 /usr/local/pf/raddb/modules/perl
%config			/usr/local/pf/raddb/sites-available/packetfence
%attr(0755, pf, pf)	/usr/local/pf/raddb/sites-available/packetfence
%config		        /usr/local/pf/raddb/sites-available/packetfence-soh
%attr(0755, pf, pf)	/usr/local/pf/raddb/sites-available/packetfence-soh
%config		        /usr/local/pf/raddb/sites-available/packetfence-tunnel
%attr(0755, pf, pf)	/usr/local/pf/raddb/sites-available/packetfence-tunnel
%config                 /usr/local/pf/raddb/sites-enabled/packetfence
%attr(0755, pf, pf)     /usr/local/pf/raddb/sites-enabled/packetfence
%config                 /usr/local/pf/raddb/sites-enabled/packetfence-soh
%attr(0755, pf, pf)     /usr/local/pf/raddb/sites-enabled/packetfence-soh
%config                 /usr/local/pf/raddb/sites-enabled/packetfence-tunnel
%attr(0755, pf, pf)     /usr/local/pf/raddb/sites-enabled/packetfence-tunnel
%dir                    /usr/local/pf/var/run
%dir                    /usr/local/pf/var/rrd
%dir                    /usr/local/pf/var/session
%dir                    /usr/local/pf/var/webadmin_cache

# Remote snort sensor file list
%files -n %{real_name}-remote-snort-sensor
%defattr(-, pf, pf)
%attr(0755, root, root) %{_initrddir}/pfdetectd
%dir                    /usr/local/pf
%dir                    /usr/local/pf/conf
%config(noreplace)      /usr/local/pf/conf/pfdetect_remote.conf
%dir                    /usr/local/pf/sbin
%attr(0755, pf, pf)     /usr/local/pf/sbin/pfdetect_remote
%dir                    /usr/local/pf/var


%files -n %{real_name}-pfcmd-suid
%attr(6755, root, root) /usr/local/pf/bin/pfcmd

%changelog
* Mon Sep 17 2012 Olivier Bilodeau <obilodeau@inverse.ca>
- Made packetfence a a noarch subpackage of a new virtual packetfence-source
  so we can build -pfcmd-suid as arch-specific.

* Wed Sep 05 2012 Olivier Bilodeau <obilodeau@inverse.ca> - 3.5.1-1
- New release 3.5.1

* Fri Aug 24 2012 Olivier Bilodeau <obilodeau@inverse.ca>
- Added clean to avoid filling up build systems.. Sorry about that.

* Mon Aug 01 2012 Derek Wuelfrath <dwuelfrath@inverse.ca> - 3.5.0-1
- New release 3.5.0

* Thu Jul 12 2012 Francois Gaudreault <fgaudreault@inverse.ca>
- Adding some RADIUS deps

* Mon Jun 18 2012 Olivier Bilodeau <obilodeau@inverse.ca> - 3.4.1-1
- New release 3.4.1

* Wed Jun 13 2012 Olivier Bilodeau <obilodeau@inverse.ca> - 3.4.0-1
- New release 3.4.0

* Wed Apr 25 2012 Francois Gaudreault <fgaudreault@inverse.ca>
- Changing directory for raddb configuration

* Thu Apr 23 2012 Olivier Bilodeau <obilodeau@inverse.ca> - 3.3.2-1
- New release 3.3.2

* Tue Apr 17 2012 Francois Gaudreault <fgaudreault@inverse.ca>
- Dropped configuration package for FR.  We now have everything
in /usr/local/pf

* Thu Apr 16 2012 Olivier Bilodeau <obilodeau@inverse.ca> - 3.3.1-1
- New release 3.3.1

* Thu Apr 13 2012 Olivier Bilodeau <obilodeau@inverse.ca> - 3.3.0-2
- New release 3.3.0 (for real this time!)
- directories missing in tarball since git migration now created in install

* Thu Apr 12 2012 Olivier Bilodeau <obilodeau@inverse.ca> - 3.3.0-1
- New release 3.3.0

* Sun Mar 11 2012 Olivier Bilodeau <obilodeau@inverse.ca>
- Dependencies in recommended perl(A::B) notation instead of perl-A-B

* Thu Mar 08 2012 Olivier Bilodeau <obilodeau@inverse.ca>
- extracted version out of package (we are getting rid of versions in files 
  to simplify devel/stable branch management)
- source tarball changed: prefixed packetfence-<version>/ instead of pf/ 

* Wed Feb 22 2012 Olivier Bilodeau <obilodeau@inverse.ca> - 3.2.0-1
- New release 3.2.0

* Tue Feb 14 2012 Derek Wuelfrath <dwuelfrath@inverse.ca>
- Added perl(LWP::UserAgent) dependency for billing engine

* Fri Nov 23 2011 Olivier Bilodeau <obilodeau@inverse.ca> - 3.1.0-1
- New release 3.1.0

* Mon Nov 21 2011 Olivier Bilodeau <obilodeau@inverse.ca> - 3.0.3-1
- New release 3.0.3

* Wed Nov 16 2011 Derek Wuelfrath <dwuelfrath@inverse.ca>
- Create symlink for named.conf according to the BIND version (9.7)

* Thu Nov 03 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Adding SoH support in freeradius2 configuration pack

* Mon Oct 24 2011 Olivier Bilodeau <obilodeau@inverse.ca> - 3.0.2-1
- New release 3.0.2

* Mon Oct 03 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Won't create symlinks in sites-enabled if they already exists

* Fri Sep 23 2011 Ludovic Marcotte <lmarcotte@inverse.ca> - 3.0.1-1
- New release 3.0.1

* Wed Sep 21 2011 Olivier Bilodeau <obilodeau@inverse.ca> - 3.0.0-1
- New release 3.0.0

* Tue Sep 13 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Added dependendy on freeradius-mysql for our configuration
  package

* Mon Aug 15 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Added named, and dhcpd as dependencies

* Fri Aug 12 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Adding Accouting support into the freeradius2 configuration
  package

* Thu Aug 11 2011 Derek Wuelfrath <dwuelfrath@inverse.ca>
- Updated db schema

* Fri Aug 05 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Missing release.pm in the file list

* Tue Jul 26 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Adding certificate compilation for the freeradius2 config package

* Thu Jun 16 2011 Olivier Bilodeau <obilodeau@inverse.ca> - 2.2.1-1
- New release 2.2.1

* Mon May 15 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Added file freeradius-watchdog.sh

* Thu May 03 2011 Olivier Bilodeau <obilodeau@inverse.ca> - 2.2.0-2
- Package rebuilt to resolve issue #1212

* Tue May 03 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Fixed copy typo for the perl module backup file

* Thu May 03 2011 Olivier Bilodeau <obilodeau@inverse.ca> - 2.2.0-1
- New release 2.2.0

* Wed Apr 13 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Fixed problems in the install part for freeradius2 package

* Wed Apr 12 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Added support for perl module configuration in the packetfence-
  freeradius2 package
>
* Wed Mar 30 2011 Olivier Bilodeau <obilodeau@inverse.ca>
- Added perl(Authen::Krb5::Simple) as a dependency. Required by new Kerberos
  Captive Portal authentication module.

* Tue Mar 22 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Added dependency for perl-SOAP-Lite for the freeradius2 package

* Tue Mar 22 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Removed perl-Class-Inspector as a required package,
  dependency is now insured by perl-SOAP-Lite.

* Thu Mar 17 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Now installing logrotate script by default

* Thu Mar 17 2011 Francois Gaudreault <fgaudreault@inverse.ca>
- Added the packetfence-freeradius2 package definition

* Mon Mar 07 2011 Olivier Bilodeau <obilodeau@inverse.ca>
- Bumped version so that snapshots versions will be greater than latest
  released version
- Added German translation files

* Thu Mar 03 2011 Olivier Bilodeau <obilodeau@inverse.ca> - 2.1.0-0
- New release 2.1.0

* Mon Feb 28 2011 Olivier Bilodeau <obilodeau@inverse.ca>
- Added Brazilian Portugese translation files.

* Fri Feb 25 2011 Olivier Bilodeau <obilodeau@inverse.ca>
- Added perl(Class::Inspector) as a dependency. Upstream SOAP::Lite depend
  on it but current package doesn't provide it. See #1194.

* Fri Feb 18 2011 Olivier Bilodeau <obilodeau@inverse.ca>
- Added perl(JSON) as a dependency

* Thu Feb 11 2011 Olivier Bilodeau <obilodeau@inverse.ca>
- Explicitly remove fonts from package. For now.

* Thu Feb 03 2011 Olivier Bilodeau <obilodeau@inverse.ca>
- Explicitly remove docbook doc and images from package. For now.

* Fri Jan 28 2011 Olivier Bilodeau <obilodeau@inverse.ca>
- Configuration files in conf/templates/ are now in conf/. See #1166.

* Fri Jan 28 2011 Olivier Bilodeau <obilodeau@inverse.ca>
- More changes related to #1014. Some more conf -> var movement.

* Thu Jan 27 2011 Olivier Bilodeau <obilodeau@inverse.ca>
- New directories var/conf, var/dhcpd, var/named and var/run. See #1014.

* Wed Jan 26 2011 Olivier Bilodeau <obilodeau@inverse.ca> - 2.0.1-1
- New release 2.0.1

* Mon Dec 13 2010 Olivier Bilodeau <obilodeau@inverse.ca> - 2.0.0-1
- Version bump to 2.0.0
- File name changes

* Thu Nov 25 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Got rid of the test directory. Binaries are now in addons/.
- Renamed rlm_perl_packetfence to packetfence.pm in 802.1X 

* Mon Nov 22 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Minor changes to the addons/ directory layout that needed to be reflected
  here

* Tue Nov 16 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- New dependencies: perl-Text-CSV and perl-Text-CSV_XS used node importation

* Mon Nov 01 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Added new pf/lib/pf/web/* to package which should hold captive portal related
  submodules.

* Wed Oct 27 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Added new pf::web::custom module which is meant to be controlled by clients
  (so we don't overwrite it by default)

* Tue Oct 26 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- New dir and files for pf::services... submodules.
- Added addons/freeradius-integration/ files to package.

* Tue Sep 28 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Removed pf/cgi-bin/pdp.cgi from files manifest. It was removed from source
  tree.

* Fri Sep 24 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Added lib/pf/*.pl to the file list for new lib/pf/mod_perl_require.pl

* Tue Sep 22 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Version bump, doing 1.9.2 pre-release snapshots now
- Removing perl-LWP-UserAgent-Determined as a dependency of remote-snort-sensor.
  See #882;
  http://www.packetfence.org/bugs/view.php?id=882

* Tue Sep 22 2010 Olivier Bilodeau <obilodeau@inverse.ca> - 1.9.1-0
- New upstream release 1.9.1

* Tue Sep 21 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Added mod_perl as a dependency. Big captive portal performance gain. 
  Fixes #879;

* Wed Aug 25 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Added perl(Authen::Radius) as a dependency. Required by the optional radius
  authentication in the captive portal. Fixes #1047;

* Wed Aug 04 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Version bump, doing 1.9.1 pre-release snapshots now

* Tue Jul 27 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Added conf/admin.perm file to the files manifest

* Tue Jul 15 2010 Olivier Bilodeau <obilodeau@inverse.ca> - 1.9.0
- New upstream release 1.9.0

* Tue May 18 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Added missing file for Floating Network Device support: 
  floating_network_device.conf

* Fri May 07 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Added new files for Floating Network Device support
- Added perl(Test::NoWarnings) as a build-time dependency (used for tests)

* Thu May 06 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Fixed packaging of 802.1x rlm_perl_packetfence_* files and new radius files
- Removing the pinned perl(Parse::RecDescent) version. Fixes #833;
- Snapshot vs releases is now defined by an rpmbuild argument
- source_release should now be passed as an argument to simplify our nightly 
  build system. Fixes #946;
- Fixed a problem with addons/integration-testing files
- Perl required version is now 5.8.8 since a lot of our source files explictly
  ask for 5.8.8. Fixes #868;
- Added perl(Test::MockModule) as a build dependency (required for tests)
- Test modules are now required for building instead of required for package
  install. Fixes #866;

* Thu Apr 29 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Added mod_perl as a dependency

* Wed Apr 28 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- Added perl(Try::Tiny) and perl(Test::Exception) as a dependency used for 
  exception-handling and its testing
- Linking to new database schema

* Fri Apr 23 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- New addons/integration-testing folder with integration-testing scripts. More
  to come!
- Added perl(Readonly::XS) as a dependency. Readonly becomes faster with it. 

* Mon Apr 19 2010 Olivier Bilodeau <obilodeau@inverse.ca>
- packetfence-remote-snort-sensor back to life. Fixes #888;
  http://www.packetfence.org/mantis/view.php?id=888

* Tue Apr 06 2010 Olivier Bilodeau <obilodeau@inverse.ca> - 1.8.8-0.20100406
- Version bump to snapshot 20100406

* Tue Mar 16 2010 Olivier Bilodeau <obilodeau@inverse.ca> - 1.8.7-2
- Fix upgrade bug from 1.8.4: Changed perl-Locale-gettext dependency to use the
  perl namespace version perl(Locale-gettext). Fixes #931;
  http://www.packetfence.org/mantis/view.php?id=931

* Tue Mar 11 2010 Olivier Bilodeau <obilodeau@inverse.ca> - 1.8.8-0.20100311
- Version bump to snapshot 20100311

* Tue Jan 05 2010 Olivier Bilodeau <obilodeau@inverse.ca> - 1.8.7-1
- Version bump to 1.8.7

* Thu Dec 17 2009 Olivier Bilodeau <obilodeau@inverse.ca> - 1.8.6-3
- Added perl-SOAP-Lite as a dependency of remote-snort-sensor. Fixes #881;
  http://www.packetfence.org/mantis/view.php?id=881
- Added perl-LWP-UserAgent-Determined as a dependency of remote-snort-sensor.
  Fixes #882;
  http://www.packetfence.org/mantis/view.php?id=882

* Tue Dec 04 2009 Olivier Bilodeau <obilodeau@inverse.ca> - 1.8.6-2
- Fixed link to database schema
- Rebuilt packages

* Tue Dec 01 2009 Olivier Bilodeau <obilodeau@inverse.ca> - 1.8.6-1
- Version bump to 1.8.6
- Changed Source of the snapshot releases to packetfence.org

* Fri Nov 20 2009 Olivier Bilodeau <obilodeau@inverse.ca> - 1.8.6-0.20091120
- Version bump to snapshot 20091120
- Changed some default behavior for overwriting config files (for the better)

* Fri Oct 30 2009 Olivier Bilodeau <obilodeau@inverse.ca> - 1.8.5-2
- Modifications made to the dependencies to avoid installing Parse::RecDescent 
  that doesn't work with PacketFence

* Wed Oct 28 2009 Olivier Bilodeau <obilodeau@inverse.ca> - 1.8.5-1
- Version bump to 1.8.5

* Tue Oct 27 2009 Olivier Bilodeau <obilodeau@inverse.ca> - 1.8.5-0.20091027
- Added build instructions to avoid badly named release tarball
- Version bump to snapshot 20091027

* Mon Oct 26 2009 Olivier Bilodeau <obilodeau@inverse.ca> - 1.8.5-0.20091026
- Parse::RecDescent is a build dependency AND a runtime one. Fixes #806;
  http://packetfence.org/mantis/view.php?id=806
- Pulling php-pear-Log instead of php-pear. Fixes #804
  http://packetfence.org/mantis/view.php?id=804
- New dependency for SNMPv3 support with AES: perl-Crypt-Rijndael. Fixes #775;
  http://packetfence.org/mantis/view.php?id=775

* Fri Oct 23 2009 Olivier Bilodeau <obilodeau@inverse.ca> - 1.8.5-0.20091023
- Major improvements to the SPEC file. Starting changelog
