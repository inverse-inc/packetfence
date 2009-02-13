#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::config;

use strict;
use warnings;
use Config::IniFiles;
use File::Spec;
use Net::Netmask;
use Date::Parse;
use Log::Log4perl;
use File::Basename qw(basename);
use threads;

our (
    $install_dir,              $bin_dir,
    $conf_dir,                 $lib_dir,
    $log_dir,                  %Default_Config,
    %Config,                   @listen_ints,
    @internal_nets,            @routed_isolation_nets,
    @routed_registration_nets, $blackholemac,
    @managed_nets,             @external_nets,
    @dhcplistener_ints,        $monitor_int,
    $unreg_mark,               $reg_mark,
    $black_mark,               $portscan_sid,
    $default_config_file,      $config_file,
    $network_config_file,      $dhcp_fingerprints_file,
    $node_categories_file,     $default_pid,
    $fqdn,                     $oui_url,
    $dhcp_fingerprints_url,    $oui_file,
    @valid_trigger_types,      $thread
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT
        = qw($install_dir $bin_dir $conf_dir $lib_dir %Default_Config %Config @listen_ints @internal_nets @routed_isolation_nets @routed_registration_nets
        $blackholemac @managed_nets @external_nets @dhcplistener_ints $monitor_int $unreg_mark $reg_mark $black_mark $portscan_sid
        $default_config_file $config_file $network_config_file $dhcp_fingerprints_file $node_categories_file $default_pid $fqdn $oui_url $dhcp_fingerprints_url
        $oui_file @valid_trigger_types $thread);
}

$thread = 0;

$install_dir = '/usr/local/pf';
$bin_dir     = File::Spec->catdir( $install_dir, "bin" );
$conf_dir    = File::Spec->catdir( $install_dir, "conf" );
$lib_dir     = File::Spec->catdir( $install_dir, "lib" );
$log_dir     = File::Spec->catdir( $install_dir, "logs" );

Log::Log4perl->init("$conf_dir/log.conf");
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  threads->self->tid() );

my $logger = Log::Log4perl->get_logger('pf::config');

$config_file            = $conf_dir . "/pf.conf";
$default_config_file    = $conf_dir . "/pf.conf.defaults";
$network_config_file    = $conf_dir . "/networks.conf";
$dhcp_fingerprints_file = $conf_dir . "/dhcp_fingerprints.conf";
$oui_file               = $conf_dir . "/oui.txt";
$node_categories_file   = $conf_dir . "/node_categories.conf";

$oui_url               = 'http://standards.ieee.org/regauth/oui/oui.txt';
$dhcp_fingerprints_url = 'http://www.packetfence.org/dhcp_fingerprints.conf';

@valid_trigger_types = ( "scan", "detect", "internal", "os" );

$portscan_sid = 1200003;
$default_pid  = 1;

# to shut up strict warnings
$ENV{PATH} = '/sbin:/bin:/usr/bin:/usr/sbin';

# Ip mash marks
$unreg_mark = "0";
$reg_mark   = "1";
$black_mark = "2";

# this is broken NIC on Dave's desk - it better be unique!
$blackholemac = "00:60:8c:83:d7:34";

# read & load in configuration file
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
    $logger->logdie( join( "\n", @errors ) );
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
    "registration.expire_window", "registration.expire_session"
    )
{
    my ( $group, $item ) = split( /\./, $val );
    $Config{$group}{$item} = normalize_time( $Config{$group}{$item} );
}
foreach
    my $val ( "registration.skip_deadline", "registration.expire_deadline" )
{
    my ( $group, $item ) = split( /\./, $val );
    $Config{$group}{$item} = str2time( $Config{$group}{$item} );
}

#determine absolute paths
foreach my $val ("alerting.log") {
    my ( $group, $item ) = split( /\./, $val );
    if ( !File::Spec->file_name_is_absolute( $Config{$group}{$item} ) ) {
        $Config{$group}{$item}
            = File::Spec->catfile( $log_dir, $Config{$group}{$item} );
    }
}
foreach my $val ("vlan.adjustswitchportvlanscript") {
    my ( $group, $item ) = split( /\./, $val );
    if ( !File::Spec->file_name_is_absolute( $Config{$group}{$item} ) ) {
        $Config{$group}{$item}
            = File::Spec->catfile( $bin_dir, $Config{$group}{$item} );
    }
}

$fqdn = $Config{'general'}{'hostname'} . "." . $Config{'general'}{'domain'};

# read & load in network configuration file
my %ConfigNetworks;
tie %ConfigNetworks, 'Config::IniFiles',
    ( -file => $network_config_file, -allowempty => 1 );
@errors = @Config::IniFiles::errors;
if ( scalar(@errors) ) {
    $logger->logdie( join( "\n", @errors ) );
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
            my $isolation_obj = new Net::Netmask( $section,
                $ConfigNetworks{$section}{'netmask'} );
            push @routed_isolation_nets, $isolation_obj;
        } elsif ( lc($ConfigNetworks{$section}{'type'}) eq 'registration' ) {
            my $registration_obj = new Net::Netmask( $section,
                $ConfigNetworks{$section}{'netmask'} );
            push @routed_registration_nets, $registration_obj;
        }
    }
}

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

1;
