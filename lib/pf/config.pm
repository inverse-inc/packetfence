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
use pf::config::cached;
use pf::file_paths;
use Date::Parse;
use File::Basename qw(basename);
use File::Spec;
use Net::Interface;
use Net::Netmask;
use POSIX;
use Readonly;
use threads;
use Try::Tiny;
use File::Which;
use Socket;
use List::MoreUtils qw(any);
use Time::Local;

# Categorized by feature, pay attention when modifying
our (
    @listen_ints, @dhcplistener_ints, @ha_ints, $monitor_int,
    @internal_nets, @routed_isolation_nets, @routed_registration_nets, @inline_nets, @external_nets,
    @inline_enforcement_nets, @vlan_enforcement_nets, $management_network,
#pf.conf.default variables
    %Default_Config, $cached_pf_default_config,
#pf.conf variables
    %Config, $cached_pf_config,
#network.conf variables
    %ConfigNetworks, $cached_network_config,
#oauth2 variables
    %ConfigOAuth,
#documentation.conf variables
    %Doc_Config, $cached_pf_doc_config,
#floating_network_device.conf variables
    %ConfigFloatingDevices, $cached_floating_device_config,
#apache_filters_config.conf
    %ConfigApacheFilters, $cached_apache_filters_config,
#profiles.conf variables
    %Profile_Filters, %Profiles_Config, $cached_profiles_config,

    %connection_type, %connection_type_to_str, %connection_type_explained,
    %connection_group, %connection_group_to_str,
    %mark_type_to_str, %mark_type,
    $thread, $default_pid, $fqdn,
    %CAPTIVE_PORTAL,

);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # Categorized by feature, pay attention when modifying
    @EXPORT = qw(
        @listen_ints @dhcplistener_ints @ha_ints $monitor_int
        @internal_nets @routed_isolation_nets @routed_registration_nets @inline_nets $management_network @external_nets
        @inline_enforcement_nets @vlan_enforcement_nets
        $IPTABLES_MARK_UNREG $IPTABLES_MARK_REG $IPTABLES_MARK_ISOLATION
        $IPSET_VERSION %mark_type_to_str %mark_type
        $MAC $PORT $SSID $ALWAYS
        %Default_Config
        %Config
        %ConfigNetworks %ConfigOAuth
        %ConfigFloatingDevices
        $TRIGGER_TYPE_ACCOUNTING $TRIGGER_TYPE_DETECT $TRIGGER_TYPE_INTERNAL $TRIGGER_TYPE_MAC $TRIGGER_TYPE_NESSUS $TRIGGER_TYPE_OPENVAS $TRIGGER_TYPE_OS $TRIGGER_TYPE_SOH $TRIGGER_TYPE_USERAGENT $TRIGGER_TYPE_VENDORMAC @VALID_TRIGGER_TYPES
        $ACCOUNTING_POLICY_TIME $ACCOUNTING_POLICY_BANDWIDTH
        $WIPS_VID $thread $default_pid $fqdn
        $FALSE $TRUE $YES $NO
        $IF_INTERNAL $IF_ENFORCEMENT_VLAN $IF_ENFORCEMENT_INLINE
        $WIRELESS_802_1X $WIRELESS_MAC_AUTH $WIRED_802_1X $WIRED_MAC_AUTH $WIRED_SNMP_TRAPS $UNKNOWN $INLINE
        $NET_TYPE_INLINE $NET_TYPE_INLINE_L2 $NET_TYPE_INLINE_L3
        $WIRELESS $WIRED $EAP
        $WEB_ADMIN_NONE $WEB_ADMIN_ALL
        $VOIP $NO_VOIP $NO_PORT $NO_VLAN
        %connection_type %connection_type_to_str %connection_type_explained
        %connection_group %connection_group_to_str
        $RADIUS_API_LEVEL $VLAN_API_LEVEL $INLINE_API_LEVEL $AUTHENTICATION_API_LEVEL $SOH_API_LEVEL $BILLING_API_LEVEL
        $ROLE_API_LEVEL
        $SELFREG_MODE_EMAIL $SELFREG_MODE_SMS $SELFREG_MODE_SPONSOR $SELFREG_MODE_GOOGLE $SELFREG_MODE_FACEBOOK $SELFREG_MODE_GITHUB $SELFREG_MODE_NULL
        %CAPTIVE_PORTAL
        $HTTP $HTTPS
        normalize_time $TIME_MODIFIER_RE $ACCT_TIME_MODIFIER_RE $DEADLINE_UNIT access_duration
        $BANDWIDTH_DIRECTION_RE $BANDWIDTH_UNITS_RE
        is_vlan_enforcement_enabled is_inline_enforcement_enabled is_type_inline
        is_in_list
        $LOG4PERL_RELOAD_TIMER
        init_config
        %Profile_Filters %Profiles_Config $cached_profiles_config
        $cached_pf_config $cached_network_config $cached_floating_device_config
        %ConfigApacheFilters $cached_apache_filters_config
        $cached_pf_default_config $cached_pf_doc_config @stored_config_files
        $OS
        %Doc_Config
    );
}

sub import {
    pf::config->export_to_level(1,@_);
    pf::file_paths->export_to_level(1);
}

use pf::util::apache qw(url_parser);

$thread = 0;

my $logger = Log::Log4perl->get_logger('pf::config');

# some global constants
Readonly::Scalar our $FALSE => 0;
Readonly::Scalar our $TRUE => 1;
Readonly::Scalar our $YES => 'yes';
Readonly::Scalar our $NO => 'no';

# Violation trigger types
Readonly::Scalar our $TRIGGER_TYPE_ACCOUNTING => 'accounting';
Readonly::Scalar our $TRIGGER_TYPE_DETECT => 'detect';
Readonly::Scalar our $TRIGGER_TYPE_INTERNAL => 'internal';
Readonly::Scalar our $TRIGGER_TYPE_MAC => 'mac';
Readonly::Scalar our $TRIGGER_TYPE_NESSUS => 'nessus';
Readonly::Scalar our $TRIGGER_TYPE_OPENVAS => 'openvas';
Readonly::Scalar our $TRIGGER_TYPE_OS => 'os';
Readonly::Scalar our $TRIGGER_TYPE_SOH => 'soh';
Readonly::Scalar our $TRIGGER_TYPE_USERAGENT => 'useragent';
Readonly::Scalar our $TRIGGER_TYPE_VENDORMAC => 'vendormac';

Readonly our @VALID_TRIGGER_TYPES =>
  (
   $TRIGGER_TYPE_ACCOUNTING,
   $TRIGGER_TYPE_DETECT,
   $TRIGGER_TYPE_INTERNAL,
   $TRIGGER_TYPE_MAC,
   $TRIGGER_TYPE_NESSUS,
   $TRIGGER_TYPE_OPENVAS,
   $TRIGGER_TYPE_OS,
   $TRIGGER_TYPE_SOH,
   $TRIGGER_TYPE_USERAGENT,
   $TRIGGER_TYPE_VENDORMAC
  );

# Accounting trigger policies
Readonly::Scalar our $ACCOUNTING_POLICY_TIME => 'TimeExpired';
Readonly::Scalar our $ACCOUNTING_POLICY_BANDWIDTH => 'BandwidthExpired';


$default_pid  = "admin";

Readonly our $WIPS_VID => '1100020';

# OS Specific
Readonly::Scalar our $OS => os_detection();

# Interface types
Readonly our $IF_INTERNAL => 'internal';

# Interface enforcement techniques
Readonly our $IF_ENFORCEMENT_VLAN => 'vlan';
Readonly our $IF_ENFORCEMENT_INLINE => 'inline';
Readonly our $IF_ENFORCEMENT_INLINE_L2 => 'inlinel2';
Readonly our $IF_ENFORCEMENT_INLINE_L3 => 'inlinel3';

# Network configuration parameters.
Readonly our $NET_TYPE_VLAN_REG => 'vlan-registration';
Readonly our $NET_TYPE_VLAN_ISOL => 'vlan-isolation';
Readonly our $NET_TYPE_INLINE => 'inline';
Readonly our $NET_TYPE_INLINE_L2 => 'inlinel2';
Readonly our $NET_TYPE_INLINE_L3 => 'inlinel3';
Readonly our %NET_INLINE_TYPES =>  (
    $NET_TYPE_INLINE    => undef,
    $NET_TYPE_INLINE_L2 => undef,
    $NET_TYPE_INLINE_L3 => undef,
);

# connection type constants
Readonly our $WIRELESS_802_1X   => 0b110000001;
Readonly our $WIRELESS_MAC_AUTH => 0b100000010;
Readonly our $WIRED_802_1X      => 0b011000100;
Readonly our $WIRED_MAC_AUTH    => 0b001001000;
Readonly our $WIRED_SNMP_TRAPS  => 0b001010000;
Readonly our $INLINE            => 0b000100000;
Readonly our $UNKNOWN           => 0b000000000;
# masks to be used on connection types
Readonly our $WIRELESS => 0b100000000;
Readonly our $WIRED    => 0b001000000;
Readonly our $EAP      => 0b010000000;

# Catalyst-based access level constants
Readonly::Scalar our $ADMIN_USERNAME => 'admin';
Readonly our $WEB_ADMIN_NONE => 0;
Readonly our $WEB_ADMIN_ALL => 4294967295;

# TODO we should build a connection data class with these hashes and related constants
# String to constant hash
%connection_type = (
    'Wireless-802.11-EAP'   => $WIRELESS_802_1X,
    'Wireless-802.11-NoEAP' => $WIRELESS_MAC_AUTH,
    'Ethernet-EAP'          => $WIRED_802_1X,
    'Ethernet-NoEAP'        => $WIRED_MAC_AUTH,
    'SNMP-Traps'            => $WIRED_SNMP_TRAPS,
    'Inline'                => $INLINE,
    'WIRED_MAC_AUTH'        => $WIRED_MAC_AUTH,
);
%connection_group = (
    'Wireless'              => $WIRELESS,
    'Ethernet'              => $WIRED,
    'EAP'                   => $EAP,
);

# Their string equivalent for database storage
%connection_type_to_str = (
    $WIRELESS_802_1X => 'Wireless-802.11-EAP',
    $WIRELESS_MAC_AUTH => 'Wireless-802.11-NoEAP',
    $WIRED_802_1X => 'Ethernet-EAP',
    $WIRED_MAC_AUTH => 'WIRED_MAC_AUTH',
    $WIRED_SNMP_TRAPS => 'SNMP-Traps',
    $INLINE => 'Inline',
    $UNKNOWN => '',
);
%connection_group_to_str = (
    $WIRELESS => 'Wireless',
    $WIRED => 'Ethernet',
    $EAP => 'EAP',
);

# String to constant hash
# these duplicated in html/admin/common.php for web admin display
# changes here should be reflected there
%connection_type_explained = (
    $WIRELESS_802_1X => 'WiFi 802.1X',
    $WIRELESS_MAC_AUTH => 'WiFi MAC Auth',
    $WIRED_802_1X => 'Wired 802.1x',
    $WIRED_MAC_AUTH => 'Wired MAC Auth',
    $WIRED_SNMP_TRAPS => 'Wired SNMP',
    $INLINE => 'Inline',
    $UNKNOWN => 'Unknown',
);

# VoIP constants
Readonly our $VOIP    => 'yes';
Readonly our $NO_VOIP => 'no';

# HTTP constants
Readonly our $HTTP => 'http';
Readonly our $HTTPS => 'https';

# API version constants
Readonly::Scalar our $RADIUS_API_LEVEL => 1.02;
Readonly::Scalar our $VLAN_API_LEVEL => 1.04;
Readonly::Scalar our $INLINE_API_LEVEL => 1.01;
Readonly::Scalar our $AUTHENTICATION_API_LEVEL => 1.11;
Readonly::Scalar our $SOH_API_LEVEL => 1.00;
Readonly::Scalar our $BILLING_API_LEVEL => 1.00;
Readonly::Scalar our $ROLE_API_LEVEL => 0.90;

# to shut up strict warnings
$ENV{PATH} = '/sbin:/bin:/usr/bin:/usr/sbin';

# Inline related
# Ip mash marks
# Warning: make sure to verify conf/iptables.conf for hard-coded marks if you change the marks here.
Readonly::Scalar our $IPTABLES_MARK_REG => "1";
Readonly::Scalar our $IPTABLES_MARK_ISOLATION => "2";
Readonly::Scalar our $IPTABLES_MARK_UNREG => "3";
Readonly::Scalar our $IPSET_VERSION => ipset_version();

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

# Guest related
# The values matches the external authentication sources types
Readonly our $SELFREG_MODE_EMAIL => 'email';
Readonly our $SELFREG_MODE_SMS => 'sms';
Readonly our $SELFREG_MODE_SPONSOR => 'sponsoremail';
Readonly our $SELFREG_MODE_GOOGLE => 'google';
Readonly our $SELFREG_MODE_FACEBOOK => 'facebook';
Readonly our $SELFREG_MODE_GITHUB => 'github';
Readonly our $SELFREG_MODE_NULL   => 'null';

# SoH filters
Readonly our $SOH_ACTION_ACCEPT => 'accept';
Readonly our $SOH_ACTION_REJECT => 'reject';
Readonly our $SOH_ACTION_VIOLATION => 'violation';

Readonly::Array our @SOH_ACTIONS =>
  (
   $SOH_ACTION_ACCEPT,
   $SOH_ACTION_REJECT,
   $SOH_ACTION_VIOLATION
  );

Readonly our $SOH_CLASS_FIREWALL => 'firewall';
Readonly our $SOH_CLASS_ANTIVIRUS => 'antivirus';
Readonly our $SOH_CLASS_ANTISPYWARE => 'antispyware';
Readonly our $SOH_CLASS_AUTO_UPDATES => 'auto-updates';
Readonly our $SOH_CLASS_SECURITY_UPDATES => 'security-updates';

Readonly::Array our @SOH_CLASSES =>
  (
   $SOH_CLASS_FIREWALL,
   $SOH_CLASS_ANTIVIRUS,
   $SOH_CLASS_ANTISPYWARE,
   $SOH_CLASS_AUTO_UPDATES,
   $SOH_CLASS_SECURITY_UPDATES
  );

Readonly our $SOH_STATUS_OK => 'ok';
Readonly our $SOH_STATUS_INSTALLED => 'installed';
Readonly our $SOH_STATUS_ENABLED => 'enabled';
Readonly our $SOH_STATUS_DISABLED => 'disabled';
Readonly our $SOH_STATUS_UP2DATE => 'up2date';
Readonly our $SOH_STATUS_MICROSOFT => 'microsoft';

Readonly::Array our @SOH_STATUS =>
  (
   $SOH_STATUS_OK,
   $SOH_STATUS_INSTALLED,
   $SOH_STATUS_ENABLED,
   $SOH_STATUS_DISABLED,
   $SOH_STATUS_UP2DATE,
   $SOH_STATUS_MICROSOFT
  );

# Log Reload Timer in seconds
Readonly our $LOG4PERL_RELOAD_TIMER => 5 * 60;

# simple cache for faster config lookup
my $cache_vlan_enforcement_enabled;
my $cache_inline_enforcement_enabled;

# Accepted time modifier values
our $TIME_MODIFIER_RE = qr/[smhDWMY]/;
our $ACCT_TIME_MODIFIER_RE = qr/[DWMY]/;
our $DEADLINE_UNIT = qr/[RF]/;

# Bandwdith accounting values
our $BANDWIDTH_DIRECTION_RE = qr/IN|OUT|TOT/;
our $BANDWIDTH_UNITS_RE = qr/B|KB|MB|GB|TB/;


# constants are done, let's load the configuration
try {
    init_config();
} catch {
    chomp($_);
    $logger->logdie("Fatal error preventing configuration to load. Please review your configuration. Error: $_");
};

=head1 SUBROUTINES

=over

=item init_config

Load configuration. Can be used to reload it too.

WARNING: This has been recently introduced and was not tested with our
multi-threaded daemons.

=cut

sub init_config {
    readPfDocConfigFiles();
    readPfConfigFiles();
    readProfileConfigFile();
    readNetworkConfigFile();
    readFloatingNetworkDeviceFile();
    readApacheFiltersFile();
}

=item ipset_version -  check the ipset version on the system

=cut

sub ipset_version {
    my $logger = Log::Log4perl::get_logger('pf::config');
    my $exe_path = which('ipset');
    if (defined($exe_path)) {
        # TODO: once we can import pf::util in here, we should run this through pf_run instead of backticks
        my $cmd = "sudo ".$exe_path." --version";
        my $out = `$cmd`;
        my ($ipset_version) = $out =~ m/^ipset\s+v?([\d+])/ims;
        return $ipset_version;
    }
    else {
        return 0;
    }
}

=item os_detection -  check the os system

=cut

sub os_detection {
    my $logger = Log::Log4perl::get_logger('pf::config');
    if (-e '/etc/debian_version') {
        return "debian";
    }elsif (-e '/etc/redhat-release') {
        return "rhel";
    }
}

=item readPfDocConfigFiles

=cut

sub readPfDocConfigFiles {
    $cached_pf_doc_config = pf::config::cached->new(
        -file => $pf_doc_file,
        -allowempty => 1,
        -onreload => [ 'reload_pf_doc_config' =>  sub {
            my ($config,$name) = @_;
            $config->toHash(\%Doc_Config);
            $config->cleanupWhitespace(\%Doc_Config);
            foreach my $doc_data (values %Doc_Config) {
                if (exists $doc_data->{options} && defined $doc_data->{options}) {
                    my $options = $doc_data->{options};
                    $doc_data->{options} = [split(/\|/, $options)] if defined $options;
                } else {
                    $doc_data->{options} = [];
                }
                if (exists $doc_data->{description} && defined $doc_data->{description}) {
                    # Limited formatting from text to html
                    my $description = $doc_data->{description};
                    $description =~ s/</&lt;/g; # convert < to HTML entity
                    $description =~ s/>/&gt;/g; # convert > to HTML entity
                    $description =~ s/(\S*(&lt;|&gt;)\S*)(?=[\s,\.])/<code>$1<\/code>/g; # enclose strings that contain < or >
                    $description =~ s/(\S+\.(html|tt|pm|pl|txt))\b(?!<\/code>)/<code>$1<\/code>/g; # enclose strings that ends with .html, .tt, etc
                    $description =~ s/^ \* (.+?)$/<li>$1<\/li>/mg; # create list elements for lines beginning with " * "
                    $description =~ s/(<li>.*<\/li>)/<ul>$1<\/ul>/s; # create lists from preceding substitution
                    $description =~ s/\"([^\"]+)\"/<i>$1<\/i>/mg; # enclose strings surrounded by double quotes
                    $description =~ s/\[(\S+)\]/<strong>$1<\/strong>/mg; # enclose strings surrounded by brakets
                    $description =~ s/(https?:\/\/\S+)/<a href="$1">$1<\/a>/g; # make links clickable
                    $doc_data->{description} = $description;
                }
            }
        }]
    );
}

=item readPfConfigFiles -  pf.conf.defaults & pf.conf

=cut

sub readPfConfigFiles {

    # load default and override by local config (most common case)
    $cached_pf_default_config = pf::config::cached->new(
                -file => $default_config_file,
                -onfilereload => [
                    onfile_pf_defaults_reload => sub {
                        my ( $config, $name ) = @_;
                        $config->toHash(\%Default_Config);
                        $config->cleanupWhitespace(\%Default_Config);
                        $config->cacheForData->set( "Default_Config", \%Default_Config );
                    },
                ],
                -oncachereload => [
                    oncache_pf_defaults_reload => sub {
                        my ( $config, $name ) = @_;
                        my $data = $config->fromCacheForDataUntainted("Default_Config");
                        if($data) {
                            %Default_Config = %$data;
                        } else {
                            $config->_callFileReloadCallbacks();
                        }
                    },
                ],
    );

    if ( -e $default_config_file || -e $config_file ) {
        $cached_pf_config = pf::config::cached->new(
            -file   => $config_file,
            -import => $cached_pf_default_config,
            -allowempty => 1,
            -onfilereload => [
                onfile_pf_reload => sub {
                    my ( $config, $name ) = @_;
                    $config->toHash(\%Config);
                    $config->cleanupWhitespace(\%Config);
                    $config->cacheForData->set( "Config", \%Config );
                },
            ],
            -oncachereload => [
                oncache_pf_defaults_reload => sub {
                    my ( $config, $name ) = @_;
                    my $data = $config->fromCacheForDataUntainted("Config");
                    if($data) {
                        %Config = %$data;
                    } else {
                        $config->_callFileReloadCallbacks();
                    }
                },
            ],
            -onpostreload => [ 'reload_pf_config' =>  sub {
                my ($config) = @_;
                #clearing older interfaces infor
                $monitor_int = $management_network = '';
                @listen_ints = @dhcplistener_ints = @ha_ints =
                  @internal_nets = @external_nets =
                  @inline_enforcement_nets = @vlan_enforcement_nets = ();

                my @time_values = grep { my $t = $Doc_Config{$_}{type}; defined $t && $t eq 'time' } keys %Doc_Config;

                # normalize time
                foreach my $val (@time_values ) {
                    my ( $group, $item ) = split( /\./, $val );
                    $Config{$group}{$item} = normalize_time($Config{$group}{$item}) if ($Config{$group}{$item});
                }

                # determine absolute paths
                foreach my $val ("alerting.log") {
                    my ( $group, $item ) = split( /\./, $val );
                    if ( !File::Spec->file_name_is_absolute( $Config{$group}{$item} ) ) {
                        $Config{$group}{$item} = File::Spec->catfile( $log_dir, $Config{$group}{$item} );
                    }
                }

                $fqdn = sprintf("%s.%s",
                                $Config{'general'}{'hostname'} || $Default_Config{'general'}{'hostname'},
                                $Config{'general'}{'domain'} || $Default_Config{'general'}{'domain'});

                foreach my $interface ( $config->GroupMembers("interface") ) {
                    my $int_obj;
                    my $int = $interface;
                    $int =~ s/interface //;

                    my $ip             = $Config{$interface}{'ip'};
                    my $mask           = $Config{$interface}{'mask'};
                    my $type           = $Config{$interface}{'type'};

                    if ( defined($ip) && defined($mask) ) {
                        $ip   =~ s/ //g;
                        $mask =~ s/ //g;
                        $int_obj = new Net::Netmask( $ip, $mask );
                        $int_obj->tag( "ip",      $ip );
                        $int_obj->tag( "int",     $int );
                    }

                    if (!defined($type)) {
                        $logger->warn("$int: interface type not defined");
                        # setting type to empty to avoid warnings on split below
                        $type = '';
                    }

                    die "Missing mandatory element ip or netmask on interface $int"
                        if ($type =~ /internal|managed|management|external/ && !defined($int_obj));

                    foreach my $type ( split( /\s*,\s*/, $type ) ) {
                        if ( $type eq 'internal' ) {
                            push @internal_nets, $int_obj;
                            if ($Config{$interface}{'enforcement'} eq $IF_ENFORCEMENT_VLAN) {
                                push @vlan_enforcement_nets, $int_obj;
                            } elsif (is_type_inline($Config{$interface}{'enforcement'})) {
                                push @inline_enforcement_nets, $int_obj;
                            }
                            if ($int =~ m/(\w+):\d+/) {
                                $int = $1;
                            }
                            push @listen_ints, $int if ( $int !~ /:\d+$/ );
                        } elsif ( $type eq 'managed' || $type eq 'management' ) {
                            $int_obj->tag("vip", _fetch_virtual_ip($int, $interface));
                            $management_network = $int_obj;
                            # adding management to dhcp listeners by default (if it's not already there)
                            push @dhcplistener_ints, $int if ( not scalar grep({ $_ eq $int } @dhcplistener_ints) );

                        } elsif ( $type eq 'external' ) {
                            push @external_nets, $int_obj;
                        } elsif ( $type eq 'monitor' ) {
                            $monitor_int = $int;
                        } elsif ( $type =~ /^dhcp-?listener$/i ) {
                            push @dhcplistener_ints, $int;
                        } elsif ( $type eq 'high-availability' ) {
                            push @ha_ints, $int;
                        }
                    }
                }
                $Config{trapping}{passthroughs} = [split(/\s*,\s*/,$Config{trapping}{passthroughs} || '') ];
                if (isenabled($Config{'trapping'}{'passthrough'})) {
                    $Config{trapping}{proxy_passthroughs} = [
                        split(/\s*,\s*/,$Config{trapping}{proxy_passthroughs} || ''),
                        qw(
                            crl.geotrust.com ocsp.geotrust.com crl.thawte.com ocsp.thawte.com
                            crl.comodoca.com ocsp.comodoca.com crl.incommon.org ocsp.incommon.org
                            crl.usertrust.com ocsp.usertrust.com mscrl.microsoft.com crl.microsoft.com
                            ocsp.apple.com ocsp.digicert.com ocsp.entrust.com srvintl-crl.verisign.com
                            ocsp.verisign.com ctldl.windowsupdate.com crl.globalsign.net pki.google.com
                            www.microsoft.com
                        )
                    ];
                } else {
                    $Config{trapping}{proxy_passthroughs} = [
                        qw(
                            crl.geotrust.com ocsp.geotrust.com crl.thawte.com ocsp.thawte.com
                            crl.comodoca.com ocsp.comodoca.com crl.incommon.org ocsp.incommon.org
                            crl.usertrust.com ocsp.usertrust.com mscrl.microsoft.com crl.microsoft.com
                            ocsp.apple.com ocsp.digicert.com ocsp.entrust.com srvintl-crl.verisign.com
                            ocsp.verisign.com ctldl.windowsupdate.com crl.globalsign.net pki.google.com
                            www.microsoft.com
                        )
                    ];
                }

                _load_captive_portal();
            }]
        );
    } else {
        die ("No configuration files present.");
    }

    if ( @Config::IniFiles::errors) {
        $logger->logcroak( join( "\n", @Config::IniFiles::errors ) );
    }

}

sub readProfileConfigFile {
    $cached_profiles_config = pf::config::cached->new(
            -file => $profiles_config_file,
            -allowempty => 1,
            -default => 'default',
            -onreload => [ 'reload_profile_config' => sub {
                my ($config,$name) = @_;
                $config->toHash(\%Profiles_Config);
                $config->cleanupWhitespace(\%Profiles_Config);
                my $default_description = $Profiles_Config{'default'}{'description'};
                while (my ($profile_id, $profile) = each %Profiles_Config) {
                    $profile->{'description'} = '' if $profile_id ne 'default' && $profile->{'description'} eq $default_description;
                    foreach my $field (qw(locale mandatory_fields sources filter) ) {
                        $profile->{$field} = [split(/\s*,\s*/, $profile->{$field} || '')];
                    }
                    foreach my $filter (@{$profile->{'filter'}}) {
                        $Profile_Filters{$filter} = $profile_id;
                    }
                }
            }]
    );
}

=item readNetworkConfigFiles - networks.conf

=cut

sub readNetworkConfigFile {
    $cached_network_config = pf::config::cached->new(
        -file => $network_config_file,
        -allowempty => 1,
        -onreload => [ reload_network_config =>  sub {
            my ($config) = @_;
            $config->toHash(\%ConfigNetworks);
            $config->cleanupWhitespace(\%ConfigNetworks);
            @routed_isolation_nets = @routed_registration_nets = @inline_nets = ();
            foreach my $network ( $config->Sections ) {

                # populate routed nets variables
                if ( is_network_type_vlan_isol($network) ) {
                    my $isolation_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
                    push @routed_isolation_nets, $isolation_obj;
                } elsif ( is_network_type_vlan_reg($network) ) {
                    my $registration_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
                    push @routed_registration_nets, $registration_obj;
                } elsif ( is_network_type_inline($network) ) {
                    my $inline_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
                    push @inline_nets, $inline_obj;
                }

                # transition pf_gateway to next_hop
                # TODO we can deprecate pf_gateway in 2012
                if ( defined($ConfigNetworks{$network}{'pf_gateway'}) && !defined($ConfigNetworks{$network}{'next_hop'}) ) {
                    # carry over the parameter so that things still work
                    $ConfigNetworks{$network}{'next_hop'} = $ConfigNetworks{$network}{'pf_gateway'};
                }
            }
        }]
    );
    if(@Config::IniFiles::errors) {
        $logger->logcroak( join( "\n", @Config::IniFiles::errors ) );
    }
}

=item readFloatingNetworkDeviceFile - floating_network_device.conf

=cut

sub readFloatingNetworkDeviceFile {
    $cached_floating_device_config = pf::config::cached->new(
        -file => $floating_devices_file,
        -allowempty => 1,
        -onreload => [ reload_floating_network_device_config => sub {
            my ($config) = @_;
            $config->toHash(\%ConfigFloatingDevices);
            $config->cleanupWhitespace(\%ConfigFloatingDevices);
            foreach my $section ( keys %ConfigFloatingDevices) {
                if (defined($ConfigFloatingDevices{$section}{"trunkPort"}) && $ConfigFloatingDevices{$section}{"trunkPort"} =~ /^\s*(y|yes|true|enabled|1)\s*$/i) {
                    $ConfigFloatingDevices{$section}{"trunkPort"} = '1';
                } else {
                    $ConfigFloatingDevices{$section}{"trunkPort"} = '0';
                }
            }
        }]
    );
    if(@Config::IniFiles::errors) {
        $logger->logcroak( join( "\n", @Config::IniFiles::errors ) );
    }
}

=item readApacheFiltersFile - apache_filters_config.conf

=cut

sub readApacheFiltersFile {
    $cached_apache_filters_config = pf::config::cached->new(
        -file => $apache_filters_config_file,
        -allowempty => 1,
        -onreload => [ reload_apache_filters_config => sub {
            my ($config) = @_;
            $config->toHash(\%ConfigApacheFilters);
            $config->cleanupWhitespace(\%ConfigApacheFilters);
        }]
    );
    if(@Config::IniFiles::errors) {
        $logger->logcroak( join( "\n", @Config::IniFiles::errors ) );
    }
}

=item normalize_time - formats date

Returns the number of seconds represented by the time period.

Months and years are approximate. Do not use for anything serious about time.

=cut

sub normalize_time {
    my ($date) = @_;
    if ( $date =~ /^\d+$/ ) {
        return ($date);

    } else {
        my ( $num, $modifier ) = $date =~ /^(\d+)($TIME_MODIFIER_RE)/ or return (0);

        if ( $modifier eq "s" ) { return ($num);
        } elsif ( $modifier eq "m" ) { return ( $num * 60 );
        } elsif ( $modifier eq "h" ) { return ( $num * 60 * 60 );
        } elsif ( $modifier eq "D" ) { return ( $num * 24 * 60 * 60 );
        } elsif ( $modifier eq "W" ) { return ( $num * 7 * 24 * 60 * 60 );
        } elsif ( $modifier eq "M" ) { return ( $num * 30 * 24 * 60 * 60 );
        } elsif ( $modifier eq "Y" ) { return ( $num * 365 * 24 * 60 * 60 );
        }
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
    elsif ($trigger =~ /^(\d+)($TIME_MODIFIER_RE)($DEADLINE_UNIT)([-+])(\d+)($TIME_MODIFIER_RE)$/) {
        # we match the beginning of the period
        my ($tvalue,$modifier,$advance_type,$sign,$delta_value,$delta_type) = ($1,$2,$3,$4,$5,$6);
        my $delta = normalize_time($delta_value.$delta_type);
        if ($sign eq "-") {
            $delta *= -1;
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
            return POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime( ($refdate + normalize_time($tvalue.$modifier)) - $today_sec + $delta ));
        }
        else {
            return $FALSE;
        }
    }
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

=item is_type_inline

=cut

sub is_type_inline {
    my ($type) = @_;
    return exists $NET_INLINE_TYPES{$type};
}

=item get_newtork_type

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
    } elsif ($type =~ /^$NET_TYPE_VLAN_REG$/i) {
        # vlan-registration
        return $NET_TYPE_VLAN_REG;

    } elsif ($type =~ /^$NET_TYPE_VLAN_ISOL$/i) {
        # vlan-isolation
        return $NET_TYPE_VLAN_ISOL;

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

=item is_in_list

Searches for an item in a comma separated list of elements (like we do in our configuration files).

Returns true or false values based on if item was found or not.

=cut

sub is_in_list {
    my ($item, $list) = @_;
    my @list = (ref($list) eq 'ARRAY') ? @$list : split( /\s*,\s*/, $list );
    return $TRUE if any { $_ eq $item } @list;
    return $FALSE;
}

=item _fetch_virtual_ip

Returns the virtual IP (vip) on a given interface.

First, if there's a vip parameter defined on the interface, we return that.

Othwerise, we assume that the vip has a /32 netmask and that's how we fetch it.

We return the first vip that matches the above criteria in decimal dotted notation (ex: 192.168.1.1).
Undef if nothing is found.

=cut

# TODO IPv6 support
sub _fetch_virtual_ip {
    my ($interface, $config_section) = @_;

    # [interface $int].vip= ... always wins
    return $Config{$config_section}{'vip'} if defined($Config{$config_section}{'vip'});

    my $if = Net::Interface->new($interface);
    return if (!defined($if));

    # these array are ordered the same way, that's why we can assume the following
    my @masks = $if->netmask(AF_INET());
    my @addresses = $if->address(AF_INET());

    for my $i (0 .. $#masks) {
        return inet_ntoa($addresses[$i]) if (inet_ntoa($masks[$i]) eq '255.255.255.255');
    }
    return;
}

=item _load_captive_portal

Populate captive portal related configuration and constants.

=cut

sub _load_captive_portal {

    # CAPTIVE-PORTAL RELATED
    # Captive Portal constants
    %CAPTIVE_PORTAL = (
        "NET_DETECT_INITIAL_DELAY" => floor($Config{'trapping'}{'redirtimer'} / 4),
        "NET_DETECT_RETRY_DELAY" => 2,
        "NET_DETECT_PENDING_INITIAL_DELAY" => 2 * 60,
        "NET_DETECT_PENDING_RETRY_DELAY" => 30,
        "TEMPLATE_DIR" => "$install_dir/html/captive-portal/templates",
        "PROFILE_TEMPLATE_DIR" => "$install_dir/html/captive-portal/profile-templates",
        "ADMIN_TEMPLATE_DIR" => "$install_dir/html/admin/templates",
    );

    # process pf.conf's parameter into an IP => 1 hash
    %{$CAPTIVE_PORTAL{'loadbalancers_ip'}} =
        map { $_ => $TRUE } split(/\s*,\s*/, $Config{'captive_portal'}{'loadbalancers_ip'})
    ;
}

=item isenabled

Is the given configuration parameter considered enabled? y, yes, true, enable
and enabled are all positive values for PacketFence.

=cut

sub isenabled {
    my ($enabled) = @_;
    if ( $enabled && $enabled =~ /^\s*(y|yes|true|enable|enabled|1)\s*$/i ) {
        return (1);
    } else {
        return (0);
    }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
