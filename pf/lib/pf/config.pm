package pf::config;

=head1 NAME

pf::config - PacketFence configuration

=cut

=head1 DESCRIPTION

pf::config contains the code necessary to read and manipulate the 
PacketFence configuration files.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following configuration files: F<log.conf>, F<pf.conf>, 
F<pf.conf.defaults>, F<networks.conf>, F<dhcp_fingerprints.conf>, F<oui.txt>, F<floating_network_device.conf>.

=cut

use strict;
use warnings;
use Config::IniFiles;
use File::Spec;
use Net::Netmask;
use Date::Parse;
use Log::Log4perl;
use File::Basename qw(basename);
use threads;
use Readonly;

# Categorized by feature, pay attention when modifying
our (
    $install_dir, $bin_dir, $conf_dir, $lib_dir, $log_dir, 
    @listen_ints, @internal_nets, @routed_isolation_nets, @routed_registration_nets, @managed_nets, @external_nets,
    @dhcplistener_ints, $monitor_int,
    $unreg_mark, $reg_mark, $black_mark,
    $default_config_file, %Default_Config, 
    $config_file, %Config, 
    $network_config_file, 
    $dhcp_fingerprints_file, $dhcp_fingerprints_url,
    $oui_file, $oui_url,
    $floating_devices_file, %ConfigFloatingDevices,
    %connection_type, %connection_type_to_str, %connection_type_explained,
    $blackholemac, $portscan_sid, @valid_trigger_types, $thread, $default_pid, $fqdn
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # Categorized by feature, pay attention when modifying
    @EXPORT = qw(
        $install_dir $bin_dir $conf_dir $lib_dir 
        @listen_ints @internal_nets @routed_isolation_nets @routed_registration_nets @managed_nets @external_nets 
        @dhcplistener_ints $monitor_int 
        $unreg_mark $reg_mark $black_mark 
        $default_config_file %Default_Config
        $config_file %Config
        $network_config_file 
        $dhcp_fingerprints_file $dhcp_fingerprints_url 
        $oui_file $oui_url
        $floating_devices_file %ConfigFloatingDevices
        $blackholemac $portscan_sid @valid_trigger_types $thread $default_pid $fqdn
        $FALSE $TRUE
        WIRELESS_802_1X WIRELESS_MAC_AUTH WIRED_802_1X WIRED_MAC_AUTH WIRED_SNMP_TRAPS WIRELESS WIRED EAP
        VOIP NO_VOIP
        LOOPBACK_IPV4
        %connection_type %connection_type_to_str %connection_type_explained
    );
}

$thread = 0;

# TODO bug#920 all application config data should use Readonly to avoid accidental post-startup alterration
$install_dir = '/usr/local/pf';
$bin_dir     = File::Spec->catdir( $install_dir, "bin" );
$conf_dir    = File::Spec->catdir( $install_dir, "conf" );
$lib_dir     = File::Spec->catdir( $install_dir, "lib" );
$log_dir     = File::Spec->catdir( $install_dir, "logs" );

Log::Log4perl->init("$conf_dir/log.conf");
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  threads->self->tid() );

my $logger = Log::Log4perl->get_logger('pf::config');

# some global constants
Readonly::Scalar our $FALSE => 0;
Readonly::Scalar our $TRUE => 1;

$config_file            = $conf_dir . "/pf.conf";
$default_config_file    = $conf_dir . "/pf.conf.defaults";
$network_config_file    = $conf_dir . "/networks.conf";
$dhcp_fingerprints_file = $conf_dir . "/dhcp_fingerprints.conf";
$oui_file               = $conf_dir . "/oui.txt";
$floating_devices_file  = $conf_dir . "/floating_network_device.conf";

$oui_url               = 'http://standards.ieee.org/regauth/oui/oui.txt';
$dhcp_fingerprints_url = 'http://www.packetfence.org/dhcp_fingerprints.conf';

@valid_trigger_types = ( "scan", "detect", "internal", "os", "vendormac", "useragent" );

$portscan_sid = 1200003;
$default_pid  = 1;

# connection type constants
use constant WIRELESS_802_1X => 0b11000001;
use constant WIRELESS_MAC_AUTH => 0b10000010;
use constant WIRED_802_1X => 0b01100100;
use constant WIRED_MAC_AUTH => 0b00101000;
use constant WIRED_SNMP_TRAPS => 0b00110000;
# masks to be used on connection types
use constant WIRELESS => 0b10000000;
use constant WIRED => 0b00100000;
use constant EAP => 0b01000000;

# TODO we should build a connection data class with these hashes and related constants
# String to constant hash
%connection_type = (
    'Wireless-802.11-EAP'   => WIRELESS_802_1X,
    'Wireless-802.11-NoEAP' => WIRELESS_MAC_AUTH,
    'Ethernet-EAP'          => WIRED_802_1X,
    'Ethernet-NoEAP'        => WIRED_MAC_AUTH,
    'SNMP-Traps'            => WIRED_SNMP_TRAPS,
);

# Note that the () in the hashes below is a trick to prevent bareword quoting so I can store 
# my constant values as keys of the hashes. See CAVEATS section of perldoc constant.
# Their string equivalent for database storage
%connection_type_to_str = (
    WIRELESS_802_1X() => 'Wireless-802.11-EAP',
    WIRELESS_MAC_AUTH() => 'Wireless-802.11-NoEAP',
    WIRED_802_1X() => 'Ethernet-EAP',
    WIRED_MAC_AUTH() => 'Ethernet-NoEAP',
    WIRED_SNMP_TRAPS() => 'SNMP-Traps',
);

# String to constant hash
# these duplicated in html/admin/common.php for web admin display
# changes here should be reflected there
%connection_type_explained = (
    WIRELESS_802_1X() => 'Secure Wireless (802.1x + WPA2 Enterprise)',
    WIRELESS_MAC_AUTH() => 'Open Wireless (mac-authentication)',
    WIRED_802_1X() => 'Wired 802.1x',
    WIRED_MAC_AUTH() => 'Wired MAC Authentication',
    WIRED_SNMP_TRAPS() => 'Wired (discovered by SNMP-Traps)',
);

# VoIP constants
use constant VOIP    => 'yes';
use constant NO_VOIP => 'no';

# to shut up strict warnings
$ENV{PATH} = '/sbin:/bin:/usr/bin:/usr/sbin';

# Ip mash marks
$unreg_mark = "0";
$reg_mark   = "1";
$black_mark = "2";

# this is broken NIC on Dave's desk - it better be unique!
$blackholemac = "00:60:8c:83:d7:34";
use constant LOOPBACK_IPV4 => '127.0.0.1';

readPfConfigFiles();

readNetworkConfigFile();

readFloatingNetworkDeviceFile();


=over

=item readPfConfigFiles -  pf.conf.defaults & pf.conf

=cut
sub readPfConfigFiles {

    if ( -e $default_config_file ) {
        tie %Config, 'Config::IniFiles',
            (
            -file   => $config_file,
            -import => Config::IniFiles->new( -file => $default_config_file )
            );
    } else {
        tie %Config, 'Config::IniFiles', ( -file => $config_file );
    }
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->logcroak( join( "\n", @errors ) );
    }

    #remove trailing spaces..
    foreach my $section ( tied(%Config)->Sections ) {
        foreach my $key ( keys %{ $Config{$section} } ) {
            $Config{$section}{$key} =~ s/\s+$//;
        }
    }

    #normalize time
    #tie %documentation, 'Config::IniFiles', ( -file => $conf_dir."/documentation.conf" );
    #foreach my $section (sort tied(%documentation)->Sections) {
    #   my($group,$item) = split(/\./, $section);
    #   my $type = $documentation{$section}{'type'};
    #   $Config{$group}{$item}=normalize_time($Config{$group}{$item}) if ($type eq "time");
    #}

    #normalize time
    foreach my $val (
        "expire.iplog",               "expire.traplog",
        "expire.locationlog",         "expire.node",
        "arp.interval",               "arp.gw_timeout",
        "arp.timeout",                "arp.dhcp_timeout",
        "arp.heartbeat",              "trapping.redirtimer",
        "registration.skip_window",   "registration.skip_reminder",
        "registration.expire_window", "registration.expire_session",
        "general.maintenance_interval", "scan.duration",
        "dhcp.isolation_lease",       "dhcp.registered_lease",
        "dhcp.unregistered_lease"
        )
    {
        my ( $group, $item ) = split( /\./, $val );
        $Config{$group}{$item} = normalize_time( $Config{$group}{$item} );
    }
    foreach my $val ( "registration.skip_deadline", "registration.expire_deadline" )
    {
        my ( $group, $item ) = split( /\./, $val );
        $Config{$group}{$item} = str2time( $Config{$group}{$item} );
    }

    #determine absolute paths
    foreach my $val ("alerting.log") {
        my ( $group, $item ) = split( /\./, $val );
        if ( !File::Spec->file_name_is_absolute( $Config{$group}{$item} ) ) {
            $Config{$group}{$item} = File::Spec->catfile( $log_dir, $Config{$group}{$item} );
        }
    }
    foreach my $val ("vlan.adjustswitchportvlanscript") {
        my ( $group, $item ) = split( /\./, $val );
        if ( !File::Spec->file_name_is_absolute( $Config{$group}{$item} ) ) {
            $Config{$group}{$item} = File::Spec->catfile( $bin_dir, $Config{$group}{$item} );
        }
    }

    $fqdn = $Config{'general'}{'hostname'} . "." . $Config{'general'}{'domain'};

    foreach my $interface ( tied(%Config)->GroupMembers("interface") ) {
        my $int_obj;
        my $int = $interface;
        $int =~ s/interface //;

        my $ip             = $Config{$interface}{'ip'};
        my $mask           = $Config{$interface}{'mask'};
        my $gateway        = $Config{$interface}{'gateway'};
        my $type           = $Config{$interface}{'type'};
        my $authorized_ips = $Config{$interface}{'authorizedips'} || '';

        if ( defined($ip) && defined($mask) ) {
            $ip   =~ s/ //g;
            $mask =~ s/ //g;
            $int_obj = new Net::Netmask( $ip, $mask );
            $int_obj->tag( "gw",      $gateway );
            $int_obj->tag( "ip",      $ip );
            $int_obj->tag( "int",     $int );
            $int_obj->tag( "authips", $authorized_ips );
        }
        foreach my $type ( split( /\s*,\s*/, $type ) ) {
            if ( $type eq 'internal' ) {
                push @internal_nets, $int_obj;
                push @listen_ints, $int if ( $int !~ /:\d+$/ );
            } elsif ( $type eq 'managed' ) {
                push @managed_nets, $int_obj;
            } elsif ( $type eq 'external' ) {
                push @external_nets, $int_obj;
            } elsif ( $type eq 'monitor' ) {
                $monitor_int = $int;
            } elsif ( $type eq 'dhcplistener' ) {
                push @dhcplistener_ints, $int;
            }
        }
    }

    @listen_ints = split( /\s*,\s*/, $Config{'arp'}{'listendevice'} )
        if ( defined $Config{'arp'}{'listendevice'} );
}

=item readNetworkConfigFiles - networks.conf

=cut
sub readNetworkConfigFile {

    my %ConfigNetworks;
    tie %ConfigNetworks, 'Config::IniFiles', ( -file => $network_config_file, -allowempty => 1 );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->logcroak( join( "\n", @errors ) );
    }   

    #remove trailing spaces..
    foreach my $section ( tied(%ConfigNetworks)->Sections ) {
        foreach my $key ( keys %{ $ConfigNetworks{$section} } ) {
            $ConfigNetworks{$section}{$key} =~ s/\s+$//;
        }
    }

    foreach my $section ( tied(%ConfigNetworks)->Sections ) {
        if ( exists( $ConfigNetworks{$section}{'type'} ) ) {
            if ( lc($ConfigNetworks{$section}{'type'}) eq 'isolation' ) {
                my $isolation_obj = new Net::Netmask( $section, $ConfigNetworks{$section}{'netmask'} );
                push @routed_isolation_nets, $isolation_obj;
            } elsif ( lc($ConfigNetworks{$section}{'type'}) eq 'registration' ) {
                my $registration_obj = new Net::Netmask( $section, $ConfigNetworks{$section}{'netmask'} );
                push @routed_registration_nets, $registration_obj;
            }
        }
    }   
}

=item readFloatingNetworkDeviceFile - floating_network_device.conf

=cut
sub readFloatingNetworkDeviceFile {

    tie %ConfigFloatingDevices, 'Config::IniFiles', ( -file => $floating_devices_file, -allowempty => 1 );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->logcroak( join( "\n", @errors ) );
    }

    #remove trailing spaces..
    foreach my $section ( tied(%ConfigFloatingDevices)->Sections ) {   
        foreach my $key ( keys %{ $ConfigFloatingDevices{$section} } ) {
            if ($key eq 'trunkPort') {
                if ($ConfigFloatingDevices{$section}{$key} =~ /^\s*(y|yes|true|enabled|1)\s*$/i) {
                    $ConfigFloatingDevices{$section}{$key} = '1';
                } else {
                    $ConfigFloatingDevices{$section}{$key} = '0';
                }
            } else {
                $ConfigFloatingDevices{$section}{$key} =~ s/\s+$//;
            }
        }
    }
}

=item normalize_time - formats date

=cut
sub normalize_time {
    my ($date) = @_;
    if ( $date =~ /^\d+$/ ) {
        return ($date);
    } else {
        my ( $num, $modifier ) = $date =~ /^(\d+)([smhdwy])$/i;
        $modifier = lc($modifier);
        if ( $modifier eq "s" ) {
            return ($num);
        } elsif ( $modifier eq "m" ) {
            return ( $num * 60 );
        } elsif ( $modifier eq "h" ) {
            return ( $num * 3600 );
        } elsif ( $modifier eq "d" ) {
            return ( $num * 86400 );
        } elsif ( $modifier eq "w" ) {
            return ( $num * 604800 );
        } elsif ( $modifier eq "y" ) {
            return ( $num * 31449600 );
        } else {
            return (0);
        }
    }
}

=back

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Olivier Bilodeau <obilodeau@inverse.ca>

Regis Balzard <rbalzard@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2009,2010 Inverse, inc.

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
