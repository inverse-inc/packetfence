package pf::config;

=head1 NAME

pf::config - PacketFence configuration

=cut

=head1 DESCRIPTION

pf::config contains the code necessary to read and manipulate the
PacketFence configuration files.

It automatically imports gazillions of globals into your namespace. You
have been warned.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following configuration files: F<log.conf>, F<pf.conf>,
F<pf.conf.defaults>, F<networks.conf>, F<dhcp_fingerprints.conf>, F<oui.txt>, F<floating_network_device.conf>.

=cut

use strict;
use warnings;
use pf::log;
use pf::constants;
use Date::Parse;
use File::Basename qw(basename);
use File::Spec;
use Net::Interface;
use pfconfig::objects::Net::Netmask;
use POSIX;
use Readonly;
use threads;
use Try::Tiny;
use File::Which;
use Socket;
use Time::Local;
use Linux::Distribution;
use DateTime;
use pf::constants::Connection::Profile;
use pf::config::cluster;
use pf::constants::config qw(
  $IF_ENFORCEMENT_DNS
  $IF_ENFORCEMENT_VLAN
  $IF_ENFORCEMENT_INLINE
  $IF_ENFORCEMENT_INLINE_L2
  $IF_ENFORCEMENT_INLINE_L3

  $NET_TYPE_DNS_ENFORCEMENT
  $NET_TYPE_VLAN_REG
  $NET_TYPE_VLAN_ISOL
  $NET_TYPE_INLINE
  $NET_TYPE_INLINE_L2
  $NET_TYPE_INLINE_L3

  $TIME_MODIFIER_RE
  $ACCT_TIME_MODIFIER_RE
  $DEADLINE_UNIT

  $SELFREG_MODE_EMAIL
  $SELFREG_MODE_SMS
  $SELFREG_MODE_SPONSOR
  $SELFREG_MODE_GOOGLE
  $SELFREG_MODE_FACEBOOK
  $SELFREG_MODE_GITHUB
  $SELFREG_MODE_INSTAGRAM
  $SELFREG_MODE_LINKEDIN
  $SELFREG_MODE_PINTEREST
  $SELFREG_MODE_WIN_LIVE
  $SELFREG_MODE_TWITTER
  $SELFREG_MODE_NULL
  $SELFREG_MODE_KICKBOX
  $SELFREG_MODE_BLACKHOLE
  %NET_INLINE_TYPES

  $WIRELESS_802_1X
  $WIRELESS_MAC_AUTH
  $WIRED_802_1X
  $WIRED_MAC_AUTH
  $WIRED_SNMP_TRAPS
  $UNKNOWN
  $INLINE
  $WEBAUTH
  $WEBAUTH_WIRED
  $WEBAUTH_WIRELESS
    
  $WIRELESS
  $WIRED
  $EAP

  %connection_type
  %connection_type_to_str
  %connection_type_explained
  %connection_type_explained_to_str
  %connection_group
  %connection_group_to_str
);
use pfconfig::cached_array;
use pfconfig::cached_scalar;
use pfconfig::cached_hash;
use pf::util;

# Categorized by feature, pay attention when modifying
our (
    @listen_ints, @dhcplistener_ints, @ha_ints, $monitor_int,
    @internal_nets, @routed_isolation_nets, @routed_registration_nets, @inline_nets, @portal_ints,@radius_ints,
    @inline_enforcement_nets, @vlan_enforcement_nets, $management_network,
#pf.conf.default variables
    %Default_Config,
#pf.conf variables
    %Config,
#network.conf variables
    %ConfigNetworks,
# authentication.conf vaiables
    %ConfigAuthentication,
#oauth2 variables
    %ConfigOAuth,
#documentation.conf variables
    %Doc_Config,
#floating_network_device.conf variables
    %ConfigFloatingDevices,
#firewall_sso.conf variables
    %ConfigFirewallSSO,
#profiles.conf variables
    @Profile_Filters, %Profiles_Config,

    %mark_type_to_str, %mark_type,
    $thread, $fqdn, $reverse_fqdn,
    %CAPTIVE_PORTAL,
#realm.conf
    %ConfigRealm,
#provisioning.conf
    %ConfigProvisioning,
#domain.conf
    %ConfigDomain,
#scan.conf
    %ConfigScan,
#wmi.conf
    %ConfigWmi,

    %ConfigPKI_Provider,
#pfdetect.conf
    %ConfigDetect,
#billing_tiers.conf
    %ConfigBillingTiers,
#adminroles.conf
    %ConfigAdminRoles,
#portal_modules.conf
    %ConfigPortalModules,
#conf/local_secret
    $local_secret,
#conf/unified_api_system_pass
    $unified_api_system_user,
#Switches Group
    %ConfigSwitchesGroup,
#Switches List
    %ConfigSwitchesList,
#Reports
    %ConfigReport,
#Surveys
    %ConfigSurvey,
#Roles
    %ConfigRoles,
#device_Registration.conf
    %ConfigDeviceRegistration,
#ldap authentication sources
    %ConfigAuthenticationLdap,
# Radius sources
    %ConfigAuthenticationRadius,
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    # Categorized by feature, pay attention when modifying
    @EXPORT_OK = qw(
        @listen_ints @dhcplistener_ints @ha_ints $monitor_int
        @internal_nets @routed_isolation_nets @routed_registration_nets @inline_nets $management_network @portal_ints @radius_ints
        @inline_enforcement_nets @vlan_enforcement_nets
        $IPTABLES_MARK_UNREG $IPTABLES_MARK_REG $IPTABLES_MARK_ISOLATION
        %mark_type_to_str %mark_type
        $MAC $PORT $SSID $ALWAYS
        %Default_Config
        %Config
        %ConfigNetworks %ConfigAuthentication %ConfigOAuth
        %ConfigFloatingDevices
        $ACCOUNTING_POLICY_TIME $ACCOUNTING_POLICY_BANDWIDTH
        $WIPS_SECURITY_EVENT_ID $thread $fqdn $reverse_fqdn
        $IF_INTERNAL $IF_ENFORCEMENT_VLAN $IF_ENFORCEMENT_INLINE $IF_ENFORCEMENT_DNS
        $WIRELESS_802_1X $WIRELESS_MAC_AUTH $WIRED_802_1X $WIRED_MAC_AUTH $WIRED_SNMP_TRAPS $UNKNOWN $INLINE $WEBAUTH $WEBAUTH_WIRED $WEBAUTH_WIRELESS
        $NET_TYPE_INLINE $NET_TYPE_INLINE_L2 $NET_TYPE_INLINE_L3
        $WIRELESS $WIRED $EAP
        $WEB_ADMIN_NONE $WEB_ADMIN_ALL
        $VOIP $NO_VOIP $NO_PORT $NO_VLAN
        %connection_type %connection_type_to_str %connection_type_explained %connection_type_explained_to_str
        %connection_group %connection_group_to_str
        $RADIUS_API_LEVEL $ROLE_API_LEVEL $INLINE_API_LEVEL $AUTHENTICATION_API_LEVEL $BILLING_API_LEVEL
        $ROLES_API_LEVEL
        $SELFREG_MODE_EMAIL $SELFREG_MODE_SMS $SELFREG_MODE_SPONSOR $SELFREG_MODE_GOOGLE $SELFREG_MODE_FACEBOOK $SELFREG_MODE_GITHUB $SELFREG_MODE_INSTAGRAM $SELFREG_MODE_LINKEDIN $SELFREG_MODE_PRINTEREST $SELFREG_MODE_WIN_LIVE $SELFREG_MODE_TWITTER $SELFREG_MODE_NULL $SELFREG_MODE_KICKBOX $SELFREG_MODE_BLACKHOLE
        %CAPTIVE_PORTAL
        $HTTP $HTTPS
        access_duration
        $BANDWIDTH_DIRECTION_RE $BANDWIDTH_UNITS_RE
        is_vlan_enforcement_enabled is_inline_enforcement_enabled is_dns_enforcement_enabled is_type_inline
        $LOG4PERL_RELOAD_TIMER
        @Profile_Filters %Profiles_Config
        %ConfigFirewallSSO
        $OS
        $DISTRIB $DIST_VERSION
        %Doc_Config
        %ConfigRealm
        %ConfigProvisioning
        %ConfigDomain
        $default_pid
        %ConfigScan
        %ConfigWmi
        %ConfigPKI_Provider
        %ConfigDetect
        %ConfigBillingTiers
        %ConfigAdminRoles
        %ConfigPortalModules
        $local_secret
        $unified_api_system_user
        %ConfigSwitchesGroup
        %ConfigSwitchesList
        %ConfigReport
        %ConfigSurvey
        %ConfigRoles
        %ConfigDeviceRegistration
        %ConfigAuthenticationLdap
        %ConfigAuthenticationRadius
    );
}

tie %Doc_Config, 'pfconfig::cached_hash', 'config::Documentation';

my $host_id = $pf::config::cluster::host_id;
# Cluster compatible namespaces requiring the host ID to be provided
tie %Config, 'pfconfig::cached_hash', "config::Pf($host_id)";
tie @dhcplistener_ints,  'pfconfig::cached_array', "interfaces::dhcplistener_ints($host_id)";
tie @ha_ints, 'pfconfig::cached_array', "interfaces::ha_ints($host_id)";
tie @listen_ints, 'pfconfig::cached_array', "interfaces::listen_ints($host_id)";
tie @inline_enforcement_nets, 'pfconfig::cached_array', "interfaces::inline_enforcement_nets($host_id)";
tie @internal_nets, 'pfconfig::cached_array', "interfaces::internal_nets($host_id)";
tie @portal_ints, 'pfconfig::cached_array', "interfaces::portal_ints($host_id)";
tie @radius_ints, 'pfconfig::cached_array', "interfaces::radius_ints($host_id)";
tie @vlan_enforcement_nets, 'pfconfig::cached_array', "interfaces::vlan_enforcement_nets($host_id)";
tie $management_network, 'pfconfig::cached_scalar', "interfaces::management_network($host_id)";
tie $monitor_int, 'pfconfig::cached_scalar', "interfaces::monitor_int($host_id)";
tie @routed_isolation_nets, 'pfconfig::cached_array', "interfaces::routed_isolation_nets($host_id)";
tie @routed_registration_nets, 'pfconfig::cached_array', "interfaces::routed_registration_nets($host_id)";
tie @inline_nets, 'pfconfig::cached_array', "interfaces::inline_nets($host_id)";
tie %ConfigDomain, 'pfconfig::cached_hash', "config::Domain($host_id)";
tie %ConfigNetworks, 'pfconfig::cached_hash', "config::Network($host_id)";

tie %Default_Config, 'pfconfig::cached_hash', 'config::PfDefault';

tie %CAPTIVE_PORTAL, 'pfconfig::cached_hash', 'resource::CaptivePortal';
tie $fqdn, 'pfconfig::cached_scalar', 'resource::fqdn';
tie $reverse_fqdn, 'pfconfig::cached_scalar', 'resource::reverse_fqdn';

tie %Profiles_Config, 'pfconfig::cached_hash', 'config::Profiles';
tie @Profile_Filters, 'pfconfig::cached_array', 'resource::Profile_Filters';

tie %ConfigAuthentication, 'pfconfig::cached_hash', 'resource::authentication_config_hash';
tie %ConfigFloatingDevices, 'pfconfig::cached_hash', 'config::FloatingDevices';

tie %ConfigFirewallSSO, 'pfconfig::cached_hash', 'config::Firewall_SSO';

tie %ConfigRealm, 'pfconfig::cached_hash', 'config::Realm', tenant_id_scoped => 1;

tie %ConfigProvisioning, 'pfconfig::cached_hash', 'config::Provisioning';

tie %ConfigScan, 'pfconfig::cached_hash', 'config::Scan';

tie %ConfigWmi, 'pfconfig::cached_hash', 'config::Wmi';

tie %ConfigPKI_Provider, 'pfconfig::cached_hash', 'config::PKI_Provider';

tie %ConfigDetect, 'pfconfig::cached_hash', 'config::Pfdetect';

tie %ConfigBillingTiers, 'pfconfig::cached_hash', 'config::BillingTiers';

tie %ConfigAdminRoles, 'pfconfig::cached_hash', 'config::AdminRoles';

tie %ConfigPortalModules, 'pfconfig::cached_hash', 'config::PortalModules';

tie $local_secret, 'pfconfig::cached_scalar', 'resource::local_secret';

tie $unified_api_system_user, 'pfconfig::cached_scalar', 'resource::unified_api_system_user';

tie %ConfigSwitchesGroup, 'pfconfig::cached_hash', 'resource::switches_group';

tie %ConfigSwitchesList, 'pfconfig::cached_hash', 'resource::switches_list';

tie %ConfigReport, 'pfconfig::cached_hash', 'config::Report';

tie %ConfigSurvey, 'pfconfig::cached_hash', 'config::Survey';

tie %ConfigRoles, 'pfconfig::cached_hash', 'config::Roles';

tie %ConfigDeviceRegistration, 'pfconfig::cached_hash', 'config::DeviceRegistration';

tie %ConfigAuthenticationLdap, 'pfconfig::cached_hash', 'resource::authentication_sources_ldap';

tie %ConfigAuthenticationRadius, 'pfconfig::cached_hash', 'resource::authentication_sources_radius';

$thread = 0;

my $logger = get_logger();


# Accounting trigger policies
Readonly::Scalar our $ACCOUNTING_POLICY_TIME => 'TimeExpired';
Readonly::Scalar our $ACCOUNTING_POLICY_BANDWIDTH => 'BandwidthExpired';


Readonly our $WIPS_SECURITY_EVENT_ID => '1100020';

# OS Specific
Readonly::Scalar our $OS => os_detection();

# OS Version Specific
Readonly::Scalar our $LINUX => Linux::Distribution->new;
Readonly::Scalar our $DISTRIB => $LINUX->distribution_name();
Readonly::Scalar our $DIST_VERSION => $LINUX->distribution_version();

# Interface types
Readonly our $IF_INTERNAL => 'internal';

# Catalyst-based access level constants
Readonly::Scalar our $ADMIN_USERNAME => 'admin';
Readonly our $WEB_ADMIN_NONE => 0;
Readonly our $WEB_ADMIN_ALL => 4294967295;

# VoIP constants
Readonly our $VOIP    => 'yes';
Readonly our $NO_VOIP => 'no';

# API version constants
Readonly::Scalar our $RADIUS_API_LEVEL => 1.02;
Readonly::Scalar our $ROLE_API_LEVEL => 1.04;
Readonly::Scalar our $INLINE_API_LEVEL => 1.01;
Readonly::Scalar our $AUTHENTICATION_API_LEVEL => 1.11;
Readonly::Scalar our $BILLING_API_LEVEL => 1.00;
Readonly::Scalar our $ROLES_API_LEVEL => 0.90;

# to shut up strict warnings
$ENV{PATH} = '/sbin:/bin:/usr/bin:/usr/sbin';

# Inline related
# Ip mash marks
# Warning: make sure to verify conf/iptables.conf for hard-coded marks if you change the marks here.
Readonly::Scalar our $IPTABLES_MARK_REG => "1";
Readonly::Scalar our $IPTABLES_MARK_ISOLATION => "2";
Readonly::Scalar our $IPTABLES_MARK_UNREG => "3";

%mark_type = (
    'Reg'   => $IPTABLES_MARK_REG,
    'Isol' => $IPTABLES_MARK_ISOLATION,
    'Unreg'          => $IPTABLES_MARK_UNREG,
);

# Their string equivalent for database storage
%mark_type_to_str = (
    $IPTABLES_MARK_REG => 'Reg',
    $IPTABLES_MARK_ISOLATION => 'Isol',
    $IPTABLES_MARK_UNREG => 'Unreg',
);

# Use for match radius attributes

Readonly::Scalar our $MAC => "mac";
Readonly::Scalar our $PORT => "port";
Readonly::Scalar our $SSID => "ssid";
Readonly::Scalar our $ALWAYS => "always";


Readonly::Scalar our $NO_PORT => 0;
Readonly::Scalar our $NO_VLAN => 0;

# Log Reload Timer in seconds
Readonly our $LOG4PERL_RELOAD_TIMER => 5 * 60;

# simple cache for faster config lookup
my $cache_vlan_enforcement_enabled;
my $cache_inline_enforcement_enabled;
my $cache_dns_enforcement_enabled;

# Bandwdith accounting values
our $BANDWIDTH_DIRECTION_RE = qr/IN|OUT|TOT/;
our $BANDWIDTH_UNITS_RE = qr/B|KB|MB|GB|TB/;

=head1 SUBROUTINES

=over

=item os_detection -  check the os system

=cut

sub os_detection {
    my $logger = get_logger();
    if (-e '/etc/debian_version') {
        return "debian";
    }elsif (-e '/etc/redhat-release') {
        return "rhel";
    }
}

=item access_duration

Calculate the unregdate from from specific trigger.

Returns a formatted date (YYYY-MM-DD HH:MM:SS).

=cut

sub access_duration {
    my $trigger = shift;
    my $refdate = shift || time;
    if ( $trigger =~ /^(\d+)($TIME_MODIFIER_RE)$/ ) {
        # absolute value with respect to the reference date
        # ex: access_duration(1W, 2001-01-01 12:00, 2001-08-01 12:00)
        return POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime($refdate + normalize_time($trigger)));
    }
    elsif ($trigger =~ /^(\d+)($TIME_MODIFIER_RE)($DEADLINE_UNIT)([-+])?(\d+)?($TIME_MODIFIER_RE)?$/) {
        # we match the beginning of the period
        my ($tvalue,$modifier,$advance_type,$sign,$delta_value,$delta_type,$delta);
        if ( defined ($4) && defined ($5) && defined ($6)) {
            ($tvalue,$modifier,$advance_type,$sign,$delta_value,$delta_type) = ($1,$2,$3,$4,$5,$6);
            $delta = normalize_time($delta_value.$delta_type);
            if ($sign eq "-") {
                $delta *= -1;
            }
        } else {
            ($tvalue,$modifier,$advance_type) = ($1,$2,$3);
            $delta = 0;
        }
        if ($advance_type eq 'R') { # relative
            # ex: access_duration(1WR+1D, 2001-01-01 12:00, 2001-08-02 00:00) (week starts on Monday)
            return POSIX::strftime("%Y-%m-%d %H:%M:%S",
                                   localtime( start_date($modifier, $refdate) + duration($tvalue.$modifier, $refdate) + $delta ));
        }
        elsif ($advance_type eq 'F') { # fixed
            # ex: access_duration(1WF+1D, 2001-01-01 12:00, 2001-09-01 00:00)
            my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($refdate);
            my $today_sec = ($hour * 3600) + ($min * 60) + $sec;
            return POSIX::strftime("%Y-%m-%d %H:%M:%S",
                                   localtime( ($refdate + normalize_time($tvalue.$modifier)) - $today_sec + $delta ));
        } else {
            return $FALSE;
        }
    }
    $logger->warn("We were unable to calculate the access duration");
}

=item dynamic_unreg_date

We compute the unreg date dynamicaly
If the year is lower than the current year, year is zero or not defined.

=cut

sub dynamic_unreg_date {
    my $trigger = shift;
    my $current_date = time;
    my $unreg_date;

    unless(defined($trigger)){
        $logger->warn("Trying to compute the unreg date from an undefined value. Stopping processing and making unreg date undefined.");
        return $trigger;
    }

    if($trigger =~ /0000-00-00/){
        $logger->debug("Stopping dynamic unreg date handling because unreg date is set to infinite : $trigger");
        return $trigger;
    }

    my ($year,$month,$day) = $trigger =~ /(\d{1,4})?-?(\d{2})-(\d{2})/;
    my $current_year = POSIX::strftime("%Y",localtime($current_date));

    if ( !defined $year || $year == 0 || $year < $current_year ) {
        $year = $current_year;
        $trigger = "$year-$month-$day";
        $logger->warn("The year was past, null or undefined. We used current year");
    }

    try {
        my $time_zone = DateTime::TimeZone->new( name => 'local' );
        if (DateTime->new(year => $year, month => $month, day => $day, time_zone => $time_zone )->epoch <= DateTime->now(time_zone => $time_zone)->epoch) {
            $logger->warn("The DAY is today or before today. Setting date to next year");
            $year += 1;
            $unreg_date = "$year-$month-$day";
        } else {
            $unreg_date = "$year-$month-$day";
        }
    } catch {
        $logger->error("Couldn't compute unregistration date from value '$trigger'. Unregistration date will be undefined.");
        $unreg_date = undef;
    };

    return $unreg_date;
}

=item start_date

Calculate the beginning of the period.

=over

=item The beginning of a day is at midnight

=item The beginning of the week is on Monday at midnight

=item The beginning of the month is on the first at midnight

=item The beginning of the year is on Januaray 1st at midnight

=back

Returns the number of seconds since the Epoch.

=cut

sub start_date {
    my $date = shift;
    my $refdate = shift || time;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($refdate);
    my ($modifier) = $date =~ /^($TIME_MODIFIER_RE)$/ or return (0);
    if ( $modifier eq "D" ) {
        return ($refdate - (($hour * 3600) + ($min * 60) + $sec));
    } elsif ( $modifier eq "W" ) {
        if ($wday eq '0') {
           $wday = 6;
        } else {
           $wday = ($wday -1);
        }
        return ($refdate - (($wday * 86400) + ($hour * 3600) + ($min * 60) + $sec));
    } elsif ( $modifier eq "M" ) {
        return (mktime(0,0,0,1,$mon,$year));
    } elsif ( $modifier eq "Y" ) {
        return (mktime(0,0,0,1,0,$year));
    } elsif ( $modifier eq "h" ) {
        return ($refdate - (($min * 60) + $sec));
    } elsif ( $modifier eq "m" ) {
        return ($refdate - $sec);
    }

    return $refdate;
}

=item duration

Calculate the number of seconds to reach the end of the period from the beginning
of the period.

=over

=item Example: duration(1D, 2001-01-02 12:00:00) returns 1 * 24 * 60 * 60

=item Example: duration(2W, 2001-01-02 12:00:00) returns 2 * 7 * 24 * 60 * 60

=item Example: duration(2M, 2001-01-02 12:00:00) returns (31+28) * 24 * 60 * 60

=back

=cut

sub duration {
    my $date = shift;
    my $refdate = shift || time;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($refdate);
    my ($num, $modifier) = $date =~ /^(\d+)($TIME_MODIFIER_RE)$/ or return (0);
    if ($modifier eq "D") {
        return ($num * 86400);
    } elsif ($modifier eq "W") {
        return ($num * 604800);
    } elsif ($modifier eq "M") {
        # We have to calculate the number of days in the next month(s)
        my $days_month = 0;
        while ($num != 0) {
            if ($mon eq 11) {
                $mon = 0;
                $year ++;
            }
            my $next_month = timelocal(0, 0, 0, 1, $mon + 1 , $year);
            $days_month += (localtime($next_month - 86400))[3];
            $mon ++;
            $num --;
        }
        return ($days_month * 86400);
    } elsif ($modifier eq "Y") {
        # We have to calculate the number of days in the next year(s)
        my $days_year = 0;
        $year = $year + 1900;
        while ($num != 0) {
            if ((($year & 3) == 0) && (($year % 100 != 0) || ($year % 400 == 0))) {
                $days_year += 366;
            } else {
                $days_year += 365;
            }
            $num --;
            $year ++;
        }
        return ($days_year * 86400);
    }
}

=item is_vlan_enforcement_enabled

Returns true or false based on if vlan enforcement is enabled or not

=cut

sub is_vlan_enforcement_enabled {

    # cache hit
    return $cache_vlan_enforcement_enabled if (defined($cache_vlan_enforcement_enabled));

    foreach my $interface (@internal_nets) {
        my $device = "interface " . $interface->tag("int");

        if (defined($Config{$device}{'enforcement'}) && $Config{$device}{'enforcement'} eq $IF_ENFORCEMENT_VLAN) {
            # cache the answer for future access
            $cache_vlan_enforcement_enabled = $TRUE;
            return $TRUE;
        }
    }

    # if we haven't exited at this point, it means there are no vlan enforcement
    # cache the answer for future access
    $cache_vlan_enforcement_enabled = $FALSE;
    return $FALSE;
}

=item is_inline_enforcement_enabled

Returns true or false based on if inline enforcement is enabled or not

=cut

sub is_inline_enforcement_enabled {

    # cache hit
    return $cache_inline_enforcement_enabled if (defined($cache_inline_enforcement_enabled));

    foreach my $interface (@internal_nets) {
        my $device = "interface " . $interface->tag("int");

        if (defined($Config{$device}{'enforcement'}) && is_type_inline($Config{$device}{'enforcement'})) {
            # cache the answer for future access
            $cache_inline_enforcement_enabled = $TRUE;
            return $TRUE;
        }
    }

    # if we haven't exited at this point, it means there are no vlan enforcement
    # cache the answer for future access
    $cache_inline_enforcement_enabled = $FALSE;
    return $FALSE;
}

=item is_dns_enforcement_enabled

Returns true or false based on if dns enforcement is enabled or not

=cut

sub is_dns_enforcement_enabled {

    # cache hit
    return $cache_dns_enforcement_enabled if (defined($cache_dns_enforcement_enabled));

    foreach my $interface (@internal_nets) {
        my $device = "interface " . $interface->tag("int");

        if (defined($Config{$device}{'enforcement'}) && $Config{$device}{'enforcement'} eq $IF_ENFORCEMENT_DNS) {
            # cache the answer for future access
            $cache_dns_enforcement_enabled = $TRUE;
            return $TRUE;
        }
    }

    # if we haven't exited at this point, it means there are no vlan enforcement
    # cache the answer for future access
    $cache_dns_enforcement_enabled = $FALSE;
    return $FALSE;
}

=item is_type_inline

=cut

sub is_type_inline {
    my ($type) = @_;
    return exists $NET_INLINE_TYPES{$type};
}

=item get_network_type

Returns the type of a network. The call encapsulate the type configuration changes that we made.

Returns undef on unrecognized types.

=cut

# TODO we can deprecate isolation / registration in 2012
sub get_network_type {
    my ($network) = @_;

    my $type = $ConfigNetworks{$network}{'type'};
    if (!defined($type)) {
        # not defined
        return;
    } elsif ($type =~ /^$NET_TYPE_VLAN_REG/i) {
        # vlan-registration
        return $NET_TYPE_VLAN_REG;

    } elsif ($type =~ /^$NET_TYPE_VLAN_ISOL/i) {
        # vlan-isolation
        return $NET_TYPE_VLAN_ISOL;

    } elsif ( $type =~ /^$NET_TYPE_DNS_ENFORCEMENT/i ) {

        # dns-enforcement
        return $NET_TYPE_DNS_ENFORCEMENT;

    } elsif (is_type_inline($type)) {
        # inline
        return $NET_TYPE_INLINE;

    } elsif ($type =~ /^registration$/i) {
        # deprecated registration
        $logger->warn("networks.conf network type registration is deprecated use vlan-registration instead");
        return $NET_TYPE_VLAN_REG;

    } elsif ($type =~ /^isolation$/i) {
        # deprecated isolation
        $logger->warn("networks.conf network type isolation is deprecated use vlan-isolation instead");
        return $NET_TYPE_VLAN_ISOL;
    }

    $logger->warn("Unknown network type for network $network");
    return;
}

=item is_network_type_vlan_reg

Returns true if given network is of type vlan-registration and false otherwise.

=cut

sub is_network_type_vlan_reg {
    my ($network) = @_;

    my $result = get_network_type($network);
    if (defined($result) && $result eq $NET_TYPE_VLAN_REG) {
        return $TRUE;
    } else {
        return $FALSE;
    }
}

=item is_network_type_dns_enforcement

Returns true if given network is of type dns-enforcement and false otherwise.

=cut

sub is_network_type_dns_enforcement {
    my ($type) = @_;

    my $result = get_network_type($type);
    if ( defined($result) && $result eq $pf::constants::config::NET_TYPE_DNS_ENFORCEMENT ) {
        return $TRUE;
    }
    else {
        return $FALSE;
    }
}

=item is_network_type_vlan_isol

Returns true if given network is of type vlan-isolation and false otherwise.

=cut

sub is_network_type_vlan_isol {
    my ($network) = @_;

    my $result = get_network_type($network);
    if (defined($result) && $result eq $NET_TYPE_VLAN_ISOL) {
        return $TRUE;
    } else {
        return $FALSE;
    }
}

=item is_network_type_inline

Returns true if given network is of type inline and false otherwise.

=cut

sub is_network_type_inline {
    my ($network) = @_;

    my $result = get_network_type($network);
    if (defined($result) && $result eq $NET_TYPE_INLINE) {
        return $TRUE;
    } else {
        return $FALSE;
    }
}

=item configreload

Reload the config

=cut

sub configreload {
    my ($force) = @_;
    require pf::web::filter;
    require pf::CHI;
    my $chi = pf::CHI->new(namespace => 'configfiles');
    $chi->clear;

    # reload pfconfig's config
    require pfconfig::manager;
    my $manager = pfconfig::manager->new;
    $manager->expire_all;
    load_configdata_into_db();
    return ;
}

sub load_configdata_into_db {
    # reload security_events into DB
    require pf::security_event_config;
    pf::security_event_config::loadSecurityEventsIntoDb();

    require pf::SwitchFactory;
    require pf::freeradius;
    pf::freeradius::freeradius_populate_nas_config(\%pf::SwitchFactory::SwitchConfig);

    require pf::nodecategory;
    pf::nodecategory::nodecategory_populate_from_config( \%pf::config::ConfigRoles );

    require pf::Survey;
    pf::Survey::reload_from_config( \%pf::config::ConfigSurvey );
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
