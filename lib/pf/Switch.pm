package pf::Switch;

=head1 NAME

pf::Switch - Object oriented module to access SNMP enabled network switches

=head1 DESCRIPTION

The pf::Switch module implements an object oriented interface to access
SNMP enabled network switches. This module only contains some basic
functionnality and is meant to be subclassed.

=cut

use strict;
use warnings;

use Carp;
use Data::Dumper;
use Net::IP;
use Net::SNMP;
use pf::log;
use Try::Tiny;

our $VERSION = 2.10;

use pf::CHI;
use pf::constants;
use pf::constants::role qw($VOICE_ROLE $REGISTRATION_ROLE $REJECT_ROLE);
use pf::config qw(
    $ROLES_API_LEVEL
    $management_network
    %Config
    $WIRED_SNMP_TRAPS
    $VOIP
    $WIRED_802_1X
    $WIRED_MAC_AUTH
    $NO_VOIP
);
use Errno qw(EINTR);
use pf::file_paths qw(
    $control_dir
);
use pf::dal;
use pf::locationlog;
use pf::node;
use pf::cluster;
# RADIUS constants (RADIUS:: namespace)
use pf::radius::constants;
use pf::roles::custom $ROLES_API_LEVEL;
# SNMP constants (several standard-based and vendor-based namespaces)
use pf::Switch::constants;
use pf::util;
use pf::util::radius qw(perform_disconnect);
use List::MoreUtils qw(any all);
use List::Util qw(first);
use Scalar::Util qw(looks_like_number);
use pf::StatsD;
use pf::util::statsd qw(called);
use Time::HiRes;
use pf::access_filter::radius;
use File::Spec::Functions;
use File::FcntlLock;
use JSON::MaybeXS;

our $DEFAULT_COA_PORT = 1700;
our $DEFAULT_DISCONNECT_PORT = 3799;

#
# %TRAP_NORMALIZERS
# A hash of cisco trap normalizers
# Use the following convention when adding a normalizer
# <nameOfTrapNotificationType>TrapNormalizer
#
our %TRAP_NORMALIZERS = (
    '.1.3.6.1.6.3.1.1.5.3' => 'linkDownTrapNormalizer',
    '.1.3.6.1.6.3.1.1.5.4' => 'linkUpTrapNormalizer',
    '.1.2.840.10036.1.6.0.2' => 'dot11DeauthenticateTrapNormalizer',
);

=head1 SUBROUTINES

=over

=cut

=item supportsFloatingDevice

Returns 1 if switch type supports floating network devices

=cut

sub supportsFloatingDevice {
    my ( $self ) = @_;
    my $logger = $self->logger;

    $logger->error("Floating devices are not supported on switch type " . ref($self));
    return $FALSE;
}

=item supportsExternalPortal

Returns 1 if switch type supports external captive portal

=cut

sub supportsExternalPortal {
    my ( $self ) = @_;
    my $logger = $self->logger;

    $logger->debug("External captive portal is not supported on switch type " . ref($self));
    return $FALSE;
}

=item supportsWebFormRegistration

Returns 1 if switch type supports web form registration (for release of the external captive portal)

=cut

sub supportsWebFormRegistration {
    my ( $self ) = @_;
    my $logger = $self->logger;

    $logger->debug("Web form registration is not supported on switch type " . ref($self));
    return $FALSE;
}

=item supportsWiredMacAuth

Returns 1 if switch type supports Wired MAC Authentication (Wired Access Authorization through RADIUS)

=cut

sub supportsWiredMacAuth {
    my ( $self ) = @_;
    my $logger = $self->logger;

    $logger->error(
        "Wired MAC Authentication (Wired Access Authorization through RADIUS) "
        . "is not supported on switch type " . ref($self) . ". Please let us know what hardware you are using."
    );
    return $FALSE;
}

=item supportsWiredDot1x - Returns 1 if switch type supports Wired 802.1X

=cut

sub supportsWiredDot1x {
    my ( $self ) = @_;
    my $logger = $self->logger;

    $logger->error(
        "Wired 802.1X is not supported on switch type " . ref($self) . ". "
        . "Please let us know what hardware you are using."
    );
    return $FALSE;
}

=item supportsWirelessMacAuth

Returns 1 if switch type supports Wireless MAC Authentication (RADIUS Authentication)

=cut

sub supportsWirelessMacAuth {
    my ( $self ) = @_;
    my $logger = $self->logger;

    $logger->error(
        "Wireless MAC Authentication is not supported on switch type " . ref($self) . ". "
        . "Please let us know what hardware you are using."
    );
    return $FALSE;
}

=item supportsWirelessDot1x - Returns 1 if switch type supports Wireless 802.1X (aka WPA-Enterprise)

=cut

sub supportsWirelessDot1x {
    my ( $self ) = @_;
    my $logger = $self->logger;

    $logger->error(
        "Wireless 802.1X (WPA-Enterprise) is not supported on switch type " . ref($self) . ". "
        . "Please let us know what hardware you are using."
    );
    return $FALSE;
}

=item supportsRadiusVoip

=cut

sub supportsRadiusVoip {
    my ( $self ) = @_;
    my $logger = $self->logger;

    $logger->warn(
        "RADIUS Authentication of IP Phones is not supported on switch type " . ref($self) . ". "
        . "Please let us know what hardware you are using."
    );
    return $FALSE;
}

=item supportsRoleBasedEnforcement

=cut

sub supportsRoleBasedEnforcement {
    my ( $self ) = @_;
    my $logger = $self->logger;

    if (defined($self->{'_roles'}) && %{$self->{'_roles'}}) {
        $logger->trace(
            "Role-based Network Access Control is not supported on network device type " . ref($self) . ". "
        );
    }
    return $FALSE;
}

sub supportsAccessListBasedEnforcement {
    my ( $self ) = @_;
    my $logger = $self->logger;
    $logger->trace("Access list based enforcement is not supported on network device type " . ref($self) . ". ");
    return $FALSE;
}


=item supportsRoamingAccounting

=cut

sub supportsRoamingAccounting {
    my ( $self ) = @_;
    my $logger = $self->logger;
    $logger->trace("Update of the locationlog based on accounting data is not supported on network device type " . ref($self) . ". ");
    return $FALSE;
}

=item supportsSaveConfig

=cut

sub supportsSaveConfig {
    my ( $self ) = @_;
    my $logger = $self->logger;
    return $FALSE;
}

=item supportsCdp

Does the network device supports Cisco Discovery Protocol (CDP)

=cut

sub supportsCdp {
    my ( $self ) = @_;
    my $logger = $self->logger;
    return $FALSE;
}

=item supportsLldp

Does the network device supports Link-Layer Discovery Protocol (LLDP)

=cut

sub supportsLldp {
    my ( $self ) = @_;
    my $logger = $self->logger;
    return $FALSE;
}

=item supportsRadiusDynamicVlanAssignment

=cut

sub supportsRadiusDynamicVlanAssignment { return $TRUE; }

=item inlineCapabilities

=cut

# inline capabilities
sub inlineCapabilities { return; }

sub supportsMABFloatingDevices {
    my ( $self ) = @_;
    my $logger = $self->logger;
    return $FALSE;
}

=item supportsVPN

=cut

sub supportsVPN { return $FALSE; }

sub vpnAttributes { return $FALSE; }

sub new {
    my ($class, $argv) = @_;
    my $self = bless {
        '_error'                        => undef,
        '_id'                           => undef,
        '_macSearchesMaxNb'             => undef,
        '_macSearchesSleepInterval'     => undef,
        '_mode'                         => undef,
        '_sessionRead'                  => undef,
        '_sessionWrite'                 => undef,
        '_sessionControllerWrite'       => undef,
        '_SNMPAuthPasswordRead'         => undef,
        '_SNMPAuthPasswordTrap'         => undef,
        '_SNMPAuthPasswordWrite'        => undef,
        '_SNMPAuthProtocolRead'         => undef,
        '_SNMPAuthProtocolTrap'         => undef,
        '_SNMPAuthProtocolWrite'        => undef,
        '_SNMPCommunityRead'            => undef,
        '_SNMPCommunityTrap'            => undef,
        '_SNMPCommunityWrite'           => undef,
        '_SNMPEngineID'                 => undef,
        '_SNMPPrivPasswordRead'         => undef,
        '_SNMPPrivPasswordTrap'         => undef,
        '_SNMPPrivPasswordWrite'        => undef,
        '_SNMPPrivProtocolRead'         => undef,
        '_SNMPPrivProtocolTrap'         => undef,
        '_SNMPPrivProtocolWrite'        => undef,
        '_SNMPUserNameRead'             => undef,
        '_SNMPUserNameTrap'             => undef,
        '_SNMPUserNameWrite'            => undef,
        '_SNMPVersion'                  => 1,
        '_SNMPVersionTrap'              => 1,
        '_cliEnablePwd'                 => undef,
        '_cliPwd'                       => undef,
        '_cliUser'                      => undef,
        '_cliTransport'                 => undef,
        '_wsPwd'                        => undef,
        '_wsUser'                       => undef,
        '_wsTransport'                  => undef,
        '_radiusSecret'                 => undef,
        '_controllerIp'                 => undef,
        '_disconnectPort'               => undef,
        '_coaPort'                      => undef,
        '_uplink'                       => undef,
        '_vlans'                        => undef,
        '_ExternalPortalEnforcement'    => 'disabled',    
        '_VoIPEnabled'                  => undef,
        '_roles'                        => undef,
        '_inlineTrigger'                => undef,
        '_deauthMethod'                 => undef,
        '_useCoA'                       => 'enabled',
        '_switchIp'                     => undef,
        '_ip'                           => undef,
        '_switchMac'                    => undef,
        '_VlanMap'                      => 'enabled',
        '_RoleMap'                      => 'enabled',
        '_UrlMap'                       => 'enabled',
        '_TenantId'                     => $DEFAULT_TENANT_ID,
        map { "_".$_ => $argv->{$_} } keys %$argv,
    }, $class;
    return $self;
}

=item isUpLink - determine is a given ifIndex is connected to another switch

=cut

sub isUpLink {
    my ( $self, $ifIndex ) = @_;
    return (   ( defined( $self->{_uplink} ) )
            && ( grep( { $_ == $ifIndex } @{ $self->{_uplink} } ) == 1 ) );
}

=item connectRead - establish read connection to switch

=cut

sub connectRead {
    my $self   = shift;
    my $logger = $self->logger;
    if ( defined( $self->{_sessionRead} ) ) {
        return 1;
    }
    $logger->debug( "opening SNMP v"
            . $self->{_SNMPVersion}
            . " read connection to $self->{_id}" );
    if ( $self->{_SNMPVersion} eq '3' ) {
        ( $self->{_sessionRead}, $self->{_error} ) = Net::SNMP->session(
            -hostname     => $self->{_ip},
            -version      => $self->{_SNMPVersion},
            -username     => $self->{_SNMPUserNameRead},
            -timeout      => 2,
            -retries      => 1,
            -authprotocol => $self->{_SNMPAuthProtocolRead},
            -authpassword => $self->{_SNMPAuthPasswordRead},
            -privprotocol => $self->{_SNMPPrivProtocolRead},
            -privpassword => $self->{_SNMPPrivPasswordRead},
            -maxmsgsize => 4096
        );
    } else {
        ( $self->{_sessionRead}, $self->{_error} ) = Net::SNMP->session(
            -hostname  => $self->{_ip},
            -version   => $self->{_SNMPVersion},
            -timeout   => 2,
            -retries   => 1,
            -community => $self->{_SNMPCommunityRead},
            -maxmsgsize => 4096,
        );
    }
    if ( !defined( $self->{_sessionRead} ) ) {
        $logger->error( "error creating SNMP v"
                . $self->{_SNMPVersion}
                . " read connection to "
                . $self->{_id} . ": "
                . $self->{_error} );
        return 0;
    } else {
        my $oid_sysLocation = '1.3.6.1.2.1.1.6.0';
        $logger->trace("SNMP get_request for sysLocation: $oid_sysLocation");
        my $result = $self->cachedSNMPRequest([-varbindlist => [$oid_sysLocation]], {expires_in => '10m'});
        if ( !defined($result) ) {
            $logger->error( "error creating SNMP v"
                    . $self->{_SNMPVersion}
                    . " read connection to "
                    . $self->{_id} . ": "
                    . $self->{_sessionRead}->error() );
            $self->{_sessionRead} = undef;
            return 0;
        }
    }
    return 1;
}

=item cachedSNMPTable

Get a cached SNMP request using the default cache expiration

    $self->cachedSNMPTable([-base_oid => ['1.3.6.1.2.1.1.6.0']]);

Get a cached SNMP request using a provided expiration

    $self->cachedSNMPTable([-base_oid => ['1.3.6.1.2.1.1.6.0']], {expires_in => '10m'});

=cut

sub cachedSNMPTable {
    my ($self, $args, $options) = @_;
    my $session = $self->{_sessionRead};
    if(!defined $session) {
        $self->logger->error("Trying read to from a undefined session");
        return undef;
    }
    $options //= {};
    return $self->cache_distributed->compute($self->{'_id'} . "-"  . encode_json($args), $options, sub {$self->{_sessionRead}->get_table(@$args)});
}

=item cachedSNMPRequest

Get a cached SNMP request using the default cache expiration

    $self->cachedSNMPRequest([-varbindlist => ['1.3.6.1.2.1.1.6.0']]);

Get a cached SNMP request using a provided expiration

    $self->cachedSNMPRequest([-varbindlist => ['1.3.6.1.2.1.1.6.0']], {expires_in => '10m'});

=cut

sub cachedSNMPRequest {
    my ($self, $args, $options) = @_;
    my $session = $self->{_sessionRead};
    if(!defined $session) {
        $self->logger->error("Trying read to from a undefined session");
        return undef;
    }
    $options //= {};
    return $self->cache_distributed->compute($self->{'_id'} . "-"  . encode_json($args), $options, sub {$self->{_sessionRead}->get_request(@$args)});
}

=item disconnectRead - closing read connection to switch

=cut

sub disconnectRead {
    my $self   = shift;
    my $logger = $self->logger;
    if ( !defined( $self->{_sessionRead} ) ) {
        return 1;
    }
    $logger->debug( "closing SNMP v" . $self->{_SNMPVersion} . " read connection to $self->{_id}" );
    $self->{_sessionRead}->close;
    return 1;
}

=item connectWriteTo

Establishes an SNMP Write connection to a given IP and installs the session object into this object's sessionKey.
It performs a write test to make sure that the write actually works.

=cut

sub connectWriteTo {
    my ($self, $ip, $sessionKey,$port) = @_;
    my $logger = $self->logger;

    # if connection already exists, no need to connect again
    return 1 if ( defined( $self->{$sessionKey} ) );
    $port ||= 161;

    $logger->debug( "opening SNMP v" . $self->{_SNMPVersion} . " write connection to $ip" );
    if ( $self->{_SNMPVersion} eq '3' ) {
        ( $self->{$sessionKey}, $self->{_error} ) = Net::SNMP->session(
            -hostname     => $ip,
            -port         => $port,
            -version      => $self->{_SNMPVersion},
            -timeout      => 2,
            -retries      => 1,
            -username     => $self->{_SNMPUserNameWrite},
            -authprotocol => $self->{_SNMPAuthProtocolWrite},
            -authpassword => $self->{_SNMPAuthPasswordWrite},
            -privprotocol => $self->{_SNMPPrivProtocolWrite},
            -privpassword => $self->{_SNMPPrivPasswordWrite},
            -maxmsgsize => 4096,
        );
    } else {
        ( $self->{$sessionKey}, $self->{_error} ) = Net::SNMP->session(
            -hostname  => $ip,
            -port      => $port,
            -version   => $self->{_SNMPVersion},
            -timeout   => 2,
            -retries   => 1,
            -community => $self->{_SNMPCommunityWrite},
            -maxmsgsize => 4096,
        );
    }

    if ( !defined( $self->{$sessionKey} ) ) {

        $logger->error( "error creating SNMP v" . $self->{_SNMPVersion} . " write connection to $ip: $self->{_error}" );
        return 0;

    } else {
        my $oid_sysLocation = '1.3.6.1.2.1.1.6.0';
        $logger->trace("SNMP get_request for sysLocation: $oid_sysLocation");
        my $result = $self->{$sessionKey}->get_request( -varbindlist => [$oid_sysLocation] );
        if ( !defined($result) ) {
            $logger->error(
                "error creating SNMP v" . $self->{_SNMPVersion} . " write connection to $ip: "
                . $self->{$sessionKey}->error()
            );
            $self->{$sessionKey} = undef;
            return 0;
        } else {
            my $sysLocation = $result->{$oid_sysLocation} || '';
            $logger->trace(
                "SNMP set_request for sysLocation: $oid_sysLocation to $sysLocation"
            );
            $result = $self->{$sessionKey}->set_request(
                -varbindlist => [
                    "$oid_sysLocation", Net::SNMP::OCTET_STRING,
                    $sysLocation
                ]
            );
            if ( !defined($result) ) {
                $logger->error(
                    "error creating SNMP v" . $self->{_SNMPVersion} . " write connection to $ip: "
                    . $self->{$sessionKey}->error()
                    . " it looks like you specified a read-only community instead of a read-write one"
                );
                $self->{$sessionKey} = undef;
                return 0;
            }
        }
    }
    return 1;
}

=item connectWrite

Establishes a default SNMP Write connection to the network device.
Uses connectWriteTo with IP from configuration internally.

=cut

sub connectWrite {
    my $self   = shift;
    return $self->connectWriteTo( $self->{_ip}, '_sessionWrite');
}

=item connectWriteToController

Establishes an SNMP write connection to the controller of the network device as defined in controllerIp.

=cut

sub connectWriteToController {
    my $self   = shift;
    return $self->connectWriteTo($self->{_controllerIp}, '_sessionControllerWrite',$self->{_disconnectPort});
}

=item disconnectWriteTo

Closes an SNMP Write connection. Requires sessionKey stored in object (as when calling connectWriteTo).

=cut

sub disconnectWriteTo {
    my ($self, $sessionKey) = @_;
    my $logger = $self->logger;

    return 1 if ( !defined( $self->{$sessionKey} ) );

    $logger->debug(
        "closing SNMP v" . $self->{_SNMPVersion} . " write connection to " . $self->{$sessionKey}->hostname()
    );

    $self->{$sessionKey}->close();
    $self->{$sessionKey} = undef;
    return 1;
}

=item disconnectWrite

Closes the default SNMP connection to the network device's IP.

=cut

sub disconnectWrite {
    my $self = shift;

    return $self->disconnectWriteTo('_sessionWrite');
}

=item disconnectWriteToController

Closes the SNMP connection to the network device's controller.

=cut

sub disconnectWriteToController {
    my $self = shift;

    return $self->disconnectWriteTo('_sessionControllerWrite');
}

=item setVlan

Set a port to a VLAN validating some rules first then calling the switch's _setVlan.

=cut

sub setVlan {
    my ($self, $ifIndex, $newVlan, $switch_locker_ref, $presentPCMac) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->warn(
            "Should set ifIndex $ifIndex to VLAN $newVlan but the switch is not in production -> Do nothing"
        );
        return 1;
    }

    my $vlan = $self->getVlan($ifIndex);
    my $registrationVlan = $self->getVlanByName($REGISTRATION_ROLE);

    if ( !defined($presentPCMac) ) {
        my @macArray = $self->_getMacAtIfIndex( $ifIndex, $vlan );
        if ( scalar(@macArray) == 1 ) {
            $presentPCMac = $macArray[0];
        }
    }

    #handle some exceptions

    # VLAN -1 handling
    # TODO at some point we should create a new blackhole / blacklist API
    # it would take advantage of per-switch features
    if ( $newVlan eq "-1") {
        $logger->warn("VLAN -1 is not supported in SNMP-Traps mode. Returning the switch's registration VLAN.");
        $newVlan = $registrationVlan;
    }

    # VLAN are not defined on the switch
    if ( !$self->isDefinedVlan($newVlan) ) {
        if ( $newVlan eq $registrationVlan ) {
            $logger->warn(
                "Registration VLAN " . $registrationVlan
                . " is not defined on switch " . $self->{_id}
                . " -> Do nothing"
            );
            return 1;
        }
        $logger->warn(
            "new VLAN $newVlan is not defined on switch " . $self->{_id}
            . " -> replacing VLAN $newVlan with Registration VLAN "
            . $registrationVlan
        );
        $newVlan = $registrationVlan;
        if ( !$self->isDefinedVlan($newVlan) ) {
            $logger->warn(
                "Registration VLAN " . $registrationVlan
                . " is also not defined on switch " . $self->{_id}
                . " -> Do nothing"
            );
            return 1;
        }
    }

    #closes old locationlog entries and create a new one if required
    $self->synchronize_locationlog($ifIndex, $newVlan, $presentPCMac, $NO_VOIP, $WIRED_SNMP_TRAPS);

    if ( $vlan == $newVlan ) {
        $logger->info(
            "Should set " . $self->{_id} . " ifIndex $ifIndex to VLAN $newVlan "
            . "but it is already in this VLAN -> Do nothing"
        );
        return 1;
    }

    #and finally set the VLAN
    $logger->info("setting VLAN at " . $self->{_id} . " ifIndex $ifIndex from $vlan to $newVlan");
    return $self->_setVlan( $ifIndex, $newVlan, $vlan, $switch_locker_ref );
}

=item setVlanWithName - set the ifIndex VLAN to the VLAN name in the switch instead of vlan number

TODO: not implemented, currently only a nameholder

=cut

sub setVlanWithName {
    my ($self) = @_;
    my $logger = $self->logger;
    $logger->warn("not implemented!");
    return;
}

=item _setVlanByOnlyModifyingPvid

=cut

sub _setVlanByOnlyModifyingPvid {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';    # Q-BRIDGE-MIB
    my $result;

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $dot1dBasePort = $self->getDot1dBasePortForThisIfIndex($ifIndex);

    $logger->trace("SNMP set_request for Pvid for new VLAN");
    $result
        = $self->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_dot1qPvid.$dot1dBasePort", Net::SNMP::GAUGE32, $newVlan ]
        );
    if ( !defined($result) ) {
        $logger->error(
            "error setting Pvid: " . $self->{_sessionWrite}->error );
    }
    return ( defined($result) );
}

=item getRoleByName

Get the switch-specific role of a given global role in switches.conf

=cut

sub getRoleByName {
    my ($self, $roleName) = @_;
    my $logger = $self->logger;

    # skip if not defined or empty
    return if (!defined($self->{'_roles'}) || !%{$self->{'_roles'}});

    # return if found
    return $self->{'_roles'}->{$roleName} if (defined($self->{'_roles'}->{$roleName}));

    # otherwise log and return undef
    $logger->trace("(".$self->{_id}.") No parameter ${roleName}Role found in conf/switches.conf");
    return;
}

=item getVlanByName - get the VLAN number of a given name in switches.conf

Input: VLAN name (as in switches.conf)

=cut

sub getVlanByName {
    my ($self, $vlanName) = @_;
    my $logger = $self->logger;

    if (!defined($self->{'_vlans'}) || !defined($self->{'_vlans'}->{$vlanName})) {
        # VLAN name doesn't exist
        $pf::StatsD::statsd->increment(called() . ".error" );
        $logger->warn("No parameter ${vlanName}Vlan found in conf/switches.conf for the switch " . $self->{_id});
        return undef;
    }

    if ($vlanName eq "inline" && length($self->{'_vlans'}->{$vlanName}) == 0) {
        # VLAN empty, return 0 for Inline
        $logger->trace("No parameter ${vlanName}Vlan found in conf/switches.conf for the switch " . $self->{_id} .
                      ". Please ignore if your intentions were to use the native VLAN");
        return 0;
    }

    if (length $self->{'_vlans'}->{$vlanName} < 1 ) {
        # is not resolved to a valid VLAN identifier
        $logger->warn("VLAN $vlanName is not properly configured in switches.conf for the switch " . $self->{_id} .
                      ", not a VLAN identifier");
        $pf::StatsD::statsd->increment(called() . ".error" );
        return;
    }
    return $self->{'_vlans'}->{$vlanName};
}

sub getAccessListByName {
    my ($self, $access_list_name) = @_;
    my $logger = $self->logger;

    # skip if not defined or empty
    return if (!defined($self->{'_access_lists'}) || !%{$self->{'_access_lists'}});

    # return if found
    return $self->{'_access_lists'}->{$access_list_name} if (defined($self->{'_access_lists'}->{$access_list_name}));

    # otherwise log and return undef
    $logger->trace("No parameter ${access_list_name}AccessList found in conf/switches.conf for the switch " . $self->{_id});
    return;

}

=item getUrlByName

Get the switch-specific url of a given global role in switches.conf

=cut

sub getUrlByName {
    my ($self, $roleName) = @_;
    my $logger = $self->logger;

    # skip if not defined or empty
    return if (!defined($self->{'_urls'}) || !%{$self->{'_urls'}});

    # return if found
    return $self->{'_urls'}->{$roleName} if (defined($self->{'_urls'}->{$roleName}));

    # otherwise log and return undef
    $logger->trace("(".$self->{_id}.") No parameter ${roleName}Url found in conf/switches.conf");
    return;
}

=item setVlanByName - set the ifIndex VLAN to the VLAN identified by given name in switches.conf

Input: ifIndex, VLAN name (as in switches.conf), switch lock

=cut

sub setVlanByName {
    my ($self, $ifIndex, $vlanName, $switch_locker_ref) = @_;
    my $logger = $self->logger;

    if (!exists($self->{"_".$vlanName})) {
        # VLAN name doesn't exist
        $logger->warn("VLAN $vlanName is not a valid VLAN identifier (see switches.conf)");
        return;
    }

    if ($self->{"_".$vlanName} !~ /^\w+$/) {
        # is not resolved to a valid VLAN identifier
        $logger->warn("VLAN $vlanName is not properly configured in switches.conf, not a VLAN identifier");
        return;
    }
    return $self->setVlan($ifIndex, $self->{"_".$vlanName}, $switch_locker_ref);
}

=item getIfOperStatus - obtain the ifOperStatus of the specified switch port (1 indicated up, 2 indicates down)

=cut

sub getIfOperStatus {
    my ( $self, $ifIndex ) = @_;
    my $logger           = $self->logger;
    my $oid_ifOperStatus = '1.3.6.1.2.1.2.2.1.8';
    if ( !$self->connectRead() ) {
        return 0;
    }
    $logger->trace(
        "SNMP get_request for ifOperStatus: $oid_ifOperStatus.$ifIndex");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$oid_ifOperStatus.$ifIndex"] );
    return $result->{"$oid_ifOperStatus.$ifIndex"};
}

=item getAlias - get the port description

=cut

sub getAlias {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    my $OID_ifAlias = '1.3.6.1.2.1.31.1.1.1.18';
    $logger->trace("SNMP get_request for ifAlias: $OID_ifAlias.$ifIndex");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_ifAlias.$ifIndex"] );
    return $result->{"$OID_ifAlias.$ifIndex"};
}

=item getSwitchLocation - get the switch location string

=cut

sub getSwitchLocation {
    my ( $self ) = @_;
    my $logger = $self->logger;
    return if ( !$self->connectRead() );

    my $OID_sysLocation = '1.3.6.1.2.1.1.6.0';
    $logger->trace("SNMP get_request for sysLocation: $OID_sysLocation");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => ["$OID_sysLocation"] );
    if ( !defined($result) ) {
        $logger->error("couldn't fetch sysLocation on $self->{_id}: " . $self->{_sessionWrite}->error());
        return;
    }
    if (!defined($result->{"$OID_sysLocation"})) {
        $logger->error("no result for sysLocation on $self->{_id}");
    }
    return $result->{"$OID_sysLocation"};
}

=item setAlias - set the port description

=cut

sub setAlias {
    my ( $self, $ifIndex, $alias ) = @_;
    my $logger = $self->logger;
    $logger->info( "setting "
            . $self->{_id}
            . " ifIndex $ifIndex ifAlias from "
            . $self->getAlias($ifIndex)
            . " to $alias" );
    if ( !$self->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't change this port ifAlias");
        return 1;
    }
    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_ifAlias = '1.3.6.1.2.1.31.1.1.1.18';
    $logger->trace(
        "SNMP set_request for ifAlias: $OID_ifAlias.$ifIndex = $alias");
    my $result = $self->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_ifAlias.$ifIndex", Net::SNMP::OCTET_STRING, $alias ] );
    return ( defined($result) );
}

=item getManagedIfIndexes - get the list of ifIndexes which are managed

=cut

sub getManagedIfIndexes {
    my $self   = shift;
    my $logger = $self->logger;
    my @managedIfIndexes;
    my @tmp_managedIfIndexes;
    my $ifTypeHashRef;
    my $ifOperStatusHashRef;
    my $vlanHashRef;
    my $OID_ifType       = '1.3.6.1.2.1.2.2.1.3';
    my $OID_ifOperStatus = '1.3.6.1.2.1.2.2.1.8';

    my @UpLinks = $self->getUpLinks();    # fetch the UpLink list
    if ( !$self->connectRead() ) {
        return @managedIfIndexes;
    }

    # fetch all ifType at once
    $logger->trace("SNMP get_request for ifType: $OID_ifType");
    my $result = $self->{_sessionRead}->get_table( -baseoid => $OID_ifType );
    foreach my $key ( keys %{$result} ) {
        $key =~ /^$OID_ifType\.(\d+)$/;
        $ifTypeHashRef->{$1} = $result->{$key};
    }

    # fetch all ifOperStatus at once
    $logger->trace("SNMP get_request for ifOperStatus: $OID_ifOperStatus");
    $result
        = $self->{_sessionRead}->get_table( -baseoid => $OID_ifOperStatus );
    foreach my $key ( keys %{$result} ) {
        $key =~ /^$OID_ifOperStatus\.(\d+)$/;
        $ifOperStatusHashRef->{$1} = $result->{$key};
    }

    foreach my $ifIndex ( keys %{$ifTypeHashRef} ) {

        # skip non ethernetCsmacd port type
        if ( $ifTypeHashRef->{$ifIndex} == $SNMP::ETHERNET_CSMACD ) {

            # skip UpLinks
            if ( grep( { $_ == $ifIndex } @UpLinks ) == 0 ) {
                my $ifOperStatus = $ifOperStatusHashRef->{$ifIndex};

                # skip ports with ifOperStatus not present
                if (   ( defined $ifOperStatus )
                    && ( $ifOperStatusHashRef->{$ifIndex} != $SNMP::NOT_PRESENT ) )
                {
                    push @tmp_managedIfIndexes, $ifIndex;
                } else {
                    $logger->debug(
                        "ifIndex $ifIndex excluded from managed ifIndexes since its ifOperstatus is 6 (notPresent)"
                    );
                }
            } else {
                $logger->debug(
                    "ifIndex $ifIndex excluded from managed ifIndexes since it's an uplink"
                );
            }
        } else {
            $logger->debug(
                "ifIndex $ifIndex excluded from managed ifIndexes since it's not an ethernetCsmacd port"
            );
        }
    }

    $vlanHashRef = $self->getAllVlans(@tmp_managedIfIndexes);
    foreach my $ifIndex (@tmp_managedIfIndexes) {
        my $portVlan = $vlanHashRef->{$ifIndex};
        if ( defined $portVlan ) {    # skip port with no VLAN

            if ( $self->isManagedVlan($portVlan))
            {                         # skip port in a non-managed VLAN
                push @managedIfIndexes, $ifIndex;
            } else {
                $logger->debug(
                    "ifIndex $ifIndex excluded from managed ifIndexes since it's not in a managed VLAN"
                );
            }
        } else {
            $logger->debug(
                "ifIndex $ifIndex excluded from managed ifIndexes since no VLAN could be determined"
            );
        }
    }
    return @managedIfIndexes;
}

=item isManagedVlan - is the VLAN in the list of VLANs managed by the switch?

=cut

sub isManagedVlan {
    my ($self, $vlan) = @_;
    my $vlans = $self->{_vlans};
    return ( (all {defined $_ } $vlan,$vlans) && looks_like_number($vlan) && any {$_ == $vlan} values %$vlans) ? $TRUE : $FALSE;
}

=item getMode - get the mode

=cut

sub getMode {
    my ($self) = @_;
    return $self->{_mode};
}

=item isTestingMode - return True if $switch-E<gt>{_mode} eq 'testing'

=cut

sub isTestingMode {
    my ($self) = @_;
    return ( $self->getMode() eq 'testing' );
}

=item isIgnoreMode - return True if $switch-E<gt>{_mode} eq 'ignore'

=cut

sub isIgnoreMode {
    my ($self) = @_;
    return ( $self->getMode() eq 'ignore' );
}

=item isRegistrationMode - return True if $switch-E<gt>{_mode} eq 'registration'

=cut

sub isRegistrationMode {
    my ($self) = @_;
    return ( $self->getMode() eq 'registration' );
}

=item isProductionMode - return True if $switch-E<gt>{_mode} eq 'production'

=cut

sub isProductionMode {
    my ($self) = @_;
    return ( $self->getMode() eq 'production' );
}

=item isDiscoveryMode - return True if $switch-E<gt>{_mode} eq 'discovery'

=cut

sub isDiscoveryMode {
    my ($self) = @_;
    return ( $self->getMode() eq 'discovery' );
}

=item isVoIPEnabled

Default implementation returns a false value and will log a warning if user
configured it's switches.conf to do VoIP.

=cut

sub isVoIPEnabled {
    my ($self) = @_;
    my $logger = $self->logger();

    # if user set VoIPEnabled to true and we don't support it log a warning
    $logger->warn("VoIP is not supported on this network module") if ($self->{_VoIPEnabled} == $TRUE);

    return $FALSE;
}

=item setVlanAllPort - set the port VLAN for all the non-UpLink ports of a switch

=cut

sub setVlanAllPort {
    my ( $self, $vlan, $switch_locker_ref ) = @_;
    my $oid_ifType = '1.3.6.1.2.1.2.2.1.3';    # MIB: ifTypes
    my @ports;

    my $logger = $self->logger;
    $logger->info("setting all ports of switch $self->{_id} to VLAN $vlan");
    if ( !$self->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't change any port VLAN");
        return 1;
    }

    if ( !$self->connectRead() ) {
        return 0;
    }

    my @managedIfIndexes = $self->getManagedIfIndexes();
    foreach my $ifIndex (@managedIfIndexes) {
        $logger->debug(
            "setting " . $self->{_id} . " ifIndex $ifIndex to VLAN $vlan" );
        if ($vlan =~ /^\d+$/) {
            # if vlan is an integer, then assume its a vlan number
            $self->setVlan( $ifIndex, $vlan, $switch_locker_ref );
        } else {
            # otherwise its a vlan name
            $self->setVlanByName($ifIndex, $vlan, $switch_locker_ref);
        }
    }
}

=item getMacAtIfIndex - obtain list of MACs at switch ifIndex

=cut

sub getMacAtIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $i      = 0;
    my $start  = time;
    my @macArray;

    # we try to get the MAC macSearchesMaxNb times or for 2 minutes whichever comes first
    do {
        sleep($self->{_macSearchesSleepInterval}) unless ( $i == 0 );
        $logger->debug( "attempt " . ( $i + 1 ) . " to obtain mac at " . $self->{_id} . " ifIndex $ifIndex" );
        @macArray = $self->_getMacAtIfIndex($ifIndex);
        $i++;
    } while (
        ($i < $self->{_macSearchesMaxNb}) # number of attempts smaller than this parameter
        && ((time-$start) < 120) # total time spent smaller than 120 seconds (TODO extract into parameter)
        && (scalar(@macArray) == 0) # still not found
    );

    if (scalar(@macArray) == 0) {
        if ($i >= $self->{_macSearchesMaxNb}) {
            $logger->warn("Tried to grab MAC address at ifIndex $ifIndex "
                ."on switch ".$self->{_id}." 30 times and failed");
        } else {
            $logger->warn("Tried to grab MAC address at ifIndex $ifIndex "
                ."on switch ".$self->{_id}." for 2 minutes and failed");
        }
    }
    return @macArray;
}

=item getSysName - return the administratively-assigned name of the switch. By convention, this is the switch's
fully-qualified domain name

=cut

sub getSysName {
    my ($self) = @_;
    my $logger = $self->logger;
    my $OID_sysName = '1.3.6.1.2.1.1.5';                     # mib-2
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysName: $OID_sysName");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$OID_sysName] );
    if ( exists( $result->{$OID_sysName} )
        && ( $result->{$OID_sysName} ne 'noSuchInstance' ) )
    {
        return $result->{$OID_sysName};
    }
    return '';
}

=item getIfDesc - return ifDesc given ifIndex

=cut

sub getIfDesc {
    my ( $self, $ifIndex ) = @_;
    my $logger     = $self->logger;
    my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';                     # IF-MIB
    my $oid        = $OID_ifDesc . "." . $ifIndex;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for ifDesc: $oid");
    my $result = $self->cachedSNMPRequest([-varbindlist => [$oid]]);
    if ( exists( $result->{$oid} )
        && ( $result->{$oid} ne 'noSuchInstance' ) )
    {
        return $result->{$oid};
    }
    return '';
}

=item getIfName - return ifName given ifIndex

=cut

sub getIfName {
    my ( $self, $ifIndex ) = @_;
    my $logger     = $self->logger;
    my $OID_ifName = '1.3.6.1.2.1.31.1.1.1.1';                  # IF-MIB
    my $oid        = $OID_ifName . "." . $ifIndex;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for ifName: $oid");
    my $result = $self->cachedSNMPRequest([-varbindlist => [$oid]]);
    if ( exists( $result->{$oid} )
        && ( $result->{$oid} ne 'noSuchInstance' ) )
    {
        return $result->{$oid};
    }
    return '';
}

=item getIfNameIfIndexHash - return ifName =E<gt> ifIndex hash

=cut

sub getIfNameIfIndexHash {
    my ($self)     = @_;
    my $logger     = $self->logger;
    my $OID_ifName = '1.3.6.1.2.1.31.1.1.1.1';                  # IF-MIB
    my %ifNameIfIndexHash;
    if ( !$self->connectRead() ) {
        return %ifNameIfIndexHash;
    }
    $logger->trace("SNMP get_request for ifName: $OID_ifName");
    my $result = $self->{_sessionRead}->get_table( -baseoid => $OID_ifName );
    foreach my $key ( keys %{$result} ) {
        $key =~ /^$OID_ifName\.(\d+)$/;
        $ifNameIfIndexHash{ $result->{$key} } = $1;
    }
    return %ifNameIfIndexHash;
}

=item setAdminStatus - shutdown or enable port

=cut

sub setAdminStatus {
    my ( $self, $ifIndex, $status ) = @_;
    my $logger            = $self->logger;
    my $OID_ifAdminStatus = '1.3.6.1.2.1.2.2.1.7';

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port ifAdminStatus");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }
    $logger->trace( "SNMP set_request for ifAdminStatus: $OID_ifAdminStatus.$ifIndex = $status" );
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_ifAdminStatus.$ifIndex", Net::SNMP::INTEGER, $status ]
    );
    return ( defined($result) );
}

=item bouncePort

Performs a shut / no-shut on the port.
Usually used to force the operating system to do a new DHCP Request after a VLAN change.

=cut

sub bouncePort {
    my ($self, $ifIndex) = @_;

    $self->setAdminStatus( $ifIndex, $SNMP::DOWN );
    sleep($Config{'snmp_traps'}{'bounce_duration'});
    $self->setAdminStatus( $ifIndex, $SNMP::UP );

    return $TRUE;
}

sub isLearntTrapsEnabled {
    my ( $self, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub isRemovedTrapsEnabled {
    my ( $self, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub isPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    return ( 0 == 1 );
}

=item setPortSecurityEnableByIfIndex

Will disable or enable port-security on a given ifIndex based on the $trueFalse value provided.
$TRUE will enable, $FALSE will disable.

This version here is a fallback stub, provide your implementation in a switch module.

=cut

sub setPortSecurityEnableByIfIndex {
    my ( $self, $ifIndex, $trueFalse ) = @_;
    my $logger = $self->logger;

    $logger->error("Function not implemented for switch type " . ref($self));
    return ( 0 == 1 );
}

sub setPortSecurityMaxSecureMacAddrByIfIndex {
    my ( $self, $ifIndex, $maxSecureMac ) = @_;
    my $logger = $self->logger;

    $logger->error("Function not implemented for switch type " . ref($self));
    return ( 0 == 1 );
}

sub setPortSecurityViolationActionByIfIndex {
    my ( $self, $ifIndex, $action ) = @_;
    my $logger = $self->logger;

    $logger->error("Function not implemented for switch type " . ref($self));
    return ( 0 == 1 );
}

=item enablePortSecurityByIfIndex

Unless you require something more complex, this is usually a wrapper to setPortSecurityEnableByIfIndex($ifIndex, $TRUE)

=cut

sub enablePortSecurityByIfIndex {
    my ( $self, $ifIndex ) = @_;

    return $self->setPortSecurityEnableByIfIndex($ifIndex, $TRUE);
}

=item disablePortSecurityByIfIndex

Unless you require something more complex, this is usually a wrapper to setPortSecurityEnableByIfIndex($ifIndex, $FALSE)

=cut

sub disablePortSecurityByIfIndex {
    my ( $self, $ifIndex ) = @_;

    return $self->setPortSecurityEnableByIfIndex($ifIndex, $FALSE);
}

sub setModeTrunk {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    $logger->error("Function not implemented for switch type " . ref($self));
    return ( 0 == 1 );
}

sub setTaggedVlans {
    my ( $self, $ifIndex, $taggedVlans ) = @_;
    my $logger = $self->logger;

    $logger->error("Function not implemented for switch type " . ref($self));
    return ( 0 == 1 );
}

sub removeAllTaggedVlans {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    $logger->error("Function not implemented for switch type " . ref($self));
    return ( 0 == 1 );
}

sub isTrunkPort {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    $logger->debug("Unimplemented. Are you sure you are using the right switch module? Switch type: " . ref($self));
    return ( 0 == 1 );
}

sub isDynamicPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub isStaticPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    return ( 0 == 1 );
}

=item enableMABFloatingDevice

Connects to the switch and configures the specified port to be RADIUS floating device ready

=cut

sub enableMABFloatingDevice {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;
    $logger->warn("Cannot enable floating device on $self->{ip} on $ifIndex because this function is not implemented");
}

=item disableMABFloatingDevice

Connects to the switch and removes the RADIUS floating device configuration

=cut

sub disableMABFloatingDevice {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;
    $logger->warn("Cannot disable floating device on $self->{ip} on $ifIndex because this function is not implemented");
}

=item getPhonesDPAtIfIndex

Obtain phones from discovery protocol at ifIndex.

Polls from all supported sources and will filter out duplicates.

=cut

# TODO one day, with Moose roles, the CDP / LLDP role will require the proper
# implementations of getPhonesCDPAtIfIndex / getPhonesLLDPAtIfIndex
sub getPhonesDPAtIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    if ( !$self->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on network device $self->{_id}: no phones returned" );
        return;
    }

    my @phones = ();
    # CDP
    if ($self->supportsCdp()) {
        if (!defined($self->{_VoIPCDPDetect}) || isenabled($self->{_VoIPCDPDetect}) ) {
            push @phones, $self->getPhonesCDPAtIfIndex($ifIndex);
        }
    }

    # LLDP
    if ($self->supportsLldp()) {
        if (!defined($self->{_VoIPLLDPDetect}) || isenabled($self->{_VoIPLLDPDetect}) ) {
            push @phones, $self->getPhonesLLDPAtIfIndex($ifIndex);
        }
    }

    # filtering duplicates w/ hashmap (key collisions handles it)
    my %phones = map { $_ => $TRUE } @phones;

    # Log
    if (%phones) {
        $logger->info("We found an IP phone through discovery protocols for ifIndex $ifIndex");
    } else {
        $logger->info("Could not find any IP phones through discovery protocols for ifIndex $ifIndex");
    }
    return keys %phones;
}

=item hasPhoneAtIfIndex

Is there at least one IP Phone on the given ifIndex.

=cut

sub hasPhoneAtIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    if ( !$self->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch " . $self->{_id} );
        return 0;
    }

    my @macArray = $self->_getMacAtIfIndex( $ifIndex, $self->getVoiceVlan($ifIndex) );
    foreach my $mac (@macArray) {

        if ($self->isPhoneAtIfIndex($mac, $ifIndex)) {
            return 1;
        }
    }

    $logger->info(
        "determining through discovery protocols if "
        . $self->{_id} . " ifIndex $ifIndex has VoIP phone connected"
    );
    return ( scalar( $self->getPhonesDPAtIfIndex($ifIndex) ) > 0 );
}

sub isPhoneAtIfIndex {
    my ( $self, $mac, $ifIndex ) = @_;
    my $logger = $self->logger;

    if ( $self->isFakeVoIPMac($mac) ) {
        $logger->debug("MAC $mac is fake VoIP MAC");
        return 1;
    }
    if ( $self->isFakeMac($mac) ) {
        $logger->debug("MAC $mac is fake MAC");
        return 0;
    }
    $logger->trace("determining DHCP fingerprint info for $mac");
    my $node_info = node_attributes_with_fingerprint($mac);

    if (defined($node_info->{'voip'}) && $node_info->{'voip'} eq $VOIP) {
        $logger->debug("This is a VoIP phone according to node.voip");
        return 1;
    }

    if (!defined($self->{_VoIPDHCPDetect}) || isenabled($self->{_VoIPDHCPDetect}) ) {
        if (defined($node_info->{device_class}) && $node_info->{device_class} =~ /VoIP Device/) {
            $logger->debug("DHCP fingerprint for $mac indicates VoIP phone");
            return 1;
        }

        #unknown DHCP fingerprint or no DHCP fingerprint
        if (defined($node_info->{dhcp_fingerprint}) && $node_info->{dhcp_fingerprint} ne ' ') {
            $logger->debug(
                "DHCP fingerprint for $mac indicates " .$node_info->{dhcp_fingerprint}. ". This is not a VoIP phone"
            );
        }
    }

    if (defined($ifIndex)) {
        return $self->cache_distributed->compute($self->{_id} . "-SNMP-isPhoneAtIfIndex-$ifIndex-$mac", sub {
            $logger->debug("determining if $mac is VoIP phone through discovery protocols");
            my @phones = $self->getPhonesDPAtIfIndex($ifIndex);
            return ( grep( { lc($_) eq lc($mac) } @phones ) != 0 );
        });
    } else {
        return 0;
    }
}

sub getMinOSVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    $logger->error("function is NOT implemented");
    return -1;
}

sub getMaxMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    $logger->error("function is NOT implemented");
    return -1;
}

sub getSecureMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $secureMacAddrHashRef = {};
    my $logger               = $self->logger;
    return $secureMacAddrHashRef;
}

sub getAllSecureMacAddresses {
    my ($self)               = @_;
    my $logger               = $self->logger;
    my $secureMacAddrHashRef = {};
    return $secureMacAddrHashRef;
}

sub authorizeMAC {
    my ($self) = @_;
    my $logger = $self->logger;
    $logger->error("function is NOT implemented");
    return 1;
}

sub _authorizeMAC {
    my ( $self, $ifIndex, $mac, $authorize, $vlan ) = @_;
    my $logger = $self->logger;
    $logger->error("function is NOT implemented");
    return 1;
}

=item authorizeCurrentMacWithNewVlan

Authorize MAC already in secure table on the new VLAN (and deauth from old VLAN).
This is meant to be called in _setVlan on switches which have a VLAN aware port-security table.
This is because _setVlan changes the underlying VLAN but doesn't authorize the MAC on the new VLAN.

This method was in the Foundry module first then duplicated in SMC.
When the third implementation came that needed this feature I decided to extract it and have it sit here since
it's quite generic.

=cut

sub authorizeCurrentMacWithNewVlan {
    my ($self, $ifIndex, $newVlan, $oldVlan) = @_;

    return $self->_authorizeCurrentMacWithNewVlan($ifIndex, $newVlan, $oldVlan);
}

=item _authorizeCurrentMacWithNewVlan

Actual implementation of authorizeCurrentMacWithNewVlan

=cut

sub _authorizeCurrentMacWithNewVlan {
    my ($self, $ifIndex, $newVlan, $oldVlan) = @_;

    my $secureTableHashRef = $self->getSecureMacAddresses($ifIndex);

    # hash is valid and has one MAC
    my $valid = (ref($secureTableHashRef) eq 'HASH');
    my $mac_count = scalar(keys %{$secureTableHashRef});
    if ($valid && $mac_count == 1) {

        # normal case
        # grab MAC
        my $mac = (keys %{$secureTableHashRef})[0];
        $self->authorizeMAC($ifIndex, $mac, $mac, $oldVlan, $newVlan);
        return 1;
    } elsif ($valid && $mac_count > 1) {

        # VoIP case
        # check every MAC
        foreach my $mac (keys %{$secureTableHashRef}) {

            # for every MAC check every VLAN
            foreach my $vlan (@{$secureTableHashRef->{$mac}}) {
                # is VLAN equals to old VLAN
                if ($vlan == $oldVlan) {
                    # then we need to remove that MAC from that VLAN
                    $self->authorizeMAC($ifIndex, $mac, $mac, $oldVlan, $newVlan);
                }
            }
        }
        return 1;
    }
    return;
}

=item getRegExpFromList - analyze a list and determine a regexp pattern from this list (used for show mac-address-table)

=cut

sub getRegExpFromList {
    my ( $self, @list ) = @_;
    my $logger = $self->logger;

    my %decompHash;
    foreach my $item (@list) {
        $item =~ /^(.+\/)(\d+)$/;
        if ( $2 < 10 ) {
            push @{ $decompHash{$1}{0} }, $2;
        } else {
            push @{ $decompHash{$1}{ substr( $2, 0, length($2) - 1 ) } },
                substr( $2, length($2) - 1 );
        }
    }

    my $regexp         = '(';
    my @portDescStarts = sort keys %decompHash;
    for ( my $i = 0; $i < scalar(@portDescStarts); $i++ ) {
        if ( $i > 0 ) {
            $regexp .= '|';
        }
        $regexp .= "($portDescStarts[$i](";
        my @portNbStarts = sort keys %{ $decompHash{ $portDescStarts[$i] } };
        for ( my $j = 0; $j < scalar(@portNbStarts); $j++ ) {
            if ( $j > 0 ) {
                $regexp .= '|';
            }
            if ( $portNbStarts[$j] == 0 ) {
                $regexp .= "["
                    . join(
                    '',
                    sort( @{$decompHash{ $portDescStarts[$i] }
                                { $portNbStarts[$j] }
                            } )
                    ) . "]";
            } else {
                $regexp
                    .= '('
                    . $portNbStarts[$j] . "["
                    . join(
                    '',
                    sort( @{$decompHash{ $portDescStarts[$i] }
                                { $portNbStarts[$j] }
                            } )
                    ) . "])";
            }
        }
        $regexp .= '))';
    }
    $regexp .= ')[^0-9]*$';
    return $regexp;
}

=item getBitAtPosition - returns the bit at the position specified

The input must be the untranslated raw result of an snmp get_table

=cut

# TODO move out to a util package


sub getBitAtPosition {
   my ($self, $bitStream, $position) = @_;
   #Expect the hex stream
   if ($bitStream =~ /^0x/) {
       $bitStream =~ s/^0x//i;
       my $bin = join('',map { unpack("B4",pack("H",$_)) } (split //, $bitStream));
       return substr($bin, $position, 1);
   } else {
       return substr(unpack('B*', $bitStream), $position, 1);
   }
}

=item modifyBitmask

Replaces the specified bit in a packed bitmask and returns the modified bitmask, re-packed

=cut

# TODO move out to a util package
sub modifyBitmask {
    my ( $self, $bitMask, $offset, $replacement ) = @_;
    my $bitMaskString = unpack( 'B*', $bitMask );
    substr( $bitMaskString, $offset, 1, $replacement );
    return pack( 'B*', $bitMaskString );
}

=item flipBits

Replaces the specified bits in a packed bitmask and returns the modified bitmask, re-packed

It's a multi flip version of modifyBitmask

=cut

# TODO move out to a util package
sub flipBits {
    my ( $self, $bitMask, $replacement, @bitsToFlip ) = @_;
    my $bitMaskString = unpack( 'B*', $bitMask );
    foreach my $bitPos (@bitsToFlip) {
        substr( $bitMaskString, $bitPos, 1, $replacement );
    }
    return pack( 'B*', $bitMaskString );
}

=item createPortListWithOneItem - generate a PortList (Bitmask) with one bit turned on at the specified index value

The output is a packed binary representation useful to snmp::set_request

=cut

# TODO move out to a util package
sub createPortListWithOneItem {
    my ($self, $position) = @_;

    # output zeros up to position -1 and put a 1 in position
    my $numZeros = $position - 1;
    return pack("B*",0 x $numZeros . 1);
}

=item reverseBitmask - reverses all the bits (0 to 1, 1 to 0) from a packed bitmask and returns this new bitmask re-packed

Works on byte blocks since perl's bitewise not operates at the arithmetic level and some hardware have so many ports that I could overflow integers.

=cut

# TODO move out to a util package
sub reverseBitmask {
    my ($self, $bitMask) = @_;

    # reverse byte chunks since we don't know if input will be an int too large
    my $flippedBitMask = "";
    for (my $i = 0; $i < length($bitMask); $i++) {

       # chop string; convert string to byte; bitewise not (arithmetic); convert number to byte (& 255 avoids a warning)
       $flippedBitMask .= pack("C", ~ unpack("C", substr($bitMask,$i,$i+1)) & 255);
    }

    return $flippedBitMask;
}

=item getIfType - return the ifType

=cut

sub getIfType {
    my ( $self, $ifIndex ) = @_;
    my $logger     = $self->logger;
    my $OID_ifType = '1.3.6.1.2.1.2.2.1.3';                     #IF-MIB
    if ( !$self->connectRead() ) {
        return 0;
    }
    $logger->trace("SNMP get_request for ifType: $OID_ifType.$ifIndex");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_ifType.$ifIndex"] );
    return $result->{"$OID_ifType.$ifIndex"};
}

=item _getMacAtIfIndex - returns the list of MACs

=cut

sub _getMacAtIfIndex {
    my ( $self, $ifIndex, $vlan ) = @_;
    my $logger = $self->logger;
    my @macArray;
    if ( !$self->connectRead() ) {
        return @macArray;
    }
    if ( !defined($vlan) ) {
        $vlan = $self->getVlan($ifIndex);
    }
    my %macBridgePortHash = $self->getMacBridgePortHash($vlan);
    foreach my $_mac ( keys %macBridgePortHash ) {
        if ( $macBridgePortHash{$_mac} eq $ifIndex ) {
            push @macArray, $_mac;
        }
    }
    if (!@macArray) {
        $logger->warn("couldn't get MAC at ifIndex $ifIndex. This is a problem.");
    }
    return @macArray;
}

sub getAllDot1dBasePorts {
    my ( $self, @ifIndexes ) = @_;
    my $logger = $self->logger;
    if ( !@ifIndexes ) {
        @ifIndexes = $self->getManagedIfIndexes();
    }
    my $dot1dBasePortHashRef;
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB
    if ( !$self->connectRead() ) {
        return $dot1dBasePortHashRef;
    }
    $logger->trace(
        "SNMP get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => $OID_dot1dBasePortIfIndex );
    my $dot1dBasePort = undef;
    foreach my $key ( keys %{$result} ) {
        my $ifIndex = $result->{$key};
        if ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) {
            $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
            $dot1dBasePort = $1;
            $logger->debug(
                "dot1dBasePort corresponding to ifIndex $ifIndex is $dot1dBasePort"
            );
            $dot1dBasePortHashRef->{$dot1dBasePort} = $ifIndex;
        }
    }
    return $dot1dBasePortHashRef;
}

=item getDot1dBasePortForThisIfIndex - returns the dot1dBasePort for a given ifIndex

=cut

sub getDot1dBasePortForThisIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB
    my $dot1dBasePort            = undef;
    if ( !$self->connectRead() ) {
        return $dot1dBasePort;
    }
    $logger->trace(
        "SNMP get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => $OID_dot1dBasePortIfIndex );
    foreach my $key ( keys %{$result} ) {
        if ( $result->{$key} == $ifIndex ) {
            $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
            $dot1dBasePort = $1;
            $logger->debug(
                "dot1dBasePort corresponding to ifIndex $ifIndex is $dot1dBasePort"
            );
        }
    }
    return $dot1dBasePort;
}

sub getAllIfDesc {
    my ($self) = @_;
    my $logger = $self->logger;
    my $ifDescHashRef;
    my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';    # IF-MIB

    if ( !$self->connectRead() ) {
        return $ifDescHashRef;
    }

    $logger->trace("SNMP get_table for ifDesc: $OID_ifDesc");
    my $result = $self->{_sessionRead}->get_table( -baseoid => $OID_ifDesc );
    foreach my $key ( keys %{$result} ) {
        my $ifDesc = $result->{$key};
        $key =~ /^$OID_ifDesc\.(\d+)$/;
        my $ifIndex = $1;
        $ifDescHashRef->{$ifIndex} = $ifDesc;
    }
    return $ifDescHashRef;
}

sub getAllIfType {
    my ($self) = @_;
    my $logger = $self->logger;
    my $ifTypeHashRef;
    my $OID_ifType = '1.3.6.1.2.1.2.2.1.3';

    if ( !$self->connectRead() ) {
        return $ifTypeHashRef;
    }

    $logger->trace("SNMP get_table for ifType: $OID_ifType");
    my $result = $self->{_sessionRead}->get_table( -baseoid => $OID_ifType );
    foreach my $key ( keys %{$result} ) {
        my $ifType = $result->{$key};
        $key =~ /^$OID_ifType\.(\d+)$/;
        my $ifIndex = $1;
        $ifTypeHashRef->{$ifIndex} = $ifType;
    }
    return $ifTypeHashRef;
}

sub getAllVlans {
    my ( $self, @ifIndexes ) = @_;
    my $logger = $self->logger;
    my $vlanHashRef;
    if ( !@ifIndexes ) {
        @ifIndexes = $self->getManagedIfIndexes();
    }

    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';    # Q-BRIDGE-MIB
    if ( !$self->connectRead() ) {
        return $vlanHashRef;
    }
    my $dot1dBasePortHashRef = $self->getAllDot1dBasePorts(@ifIndexes);

    $logger->trace("SNMP get_request for dot1qPvid: $OID_dot1qPvid");
    my $result
        = $self->{_sessionRead}->get_table( -baseoid => $OID_dot1qPvid );
    foreach my $key ( keys %{$result} ) {
        my $vlan = $result->{$key};
        $key =~ /^$OID_dot1qPvid\.(\d+)$/;
        my $dot1dBasePort = $1;
        if ( defined( $dot1dBasePortHashRef->{$dot1dBasePort} ) ) {
            $vlanHashRef->{ $dot1dBasePortHashRef->{$dot1dBasePort} } = $vlan;
        }
    }
    return $vlanHashRef;
}

=item getVoiceVlan - returns the port voice VLAN ID

=cut

sub getVoiceVlan {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( $self->isVoIPEnabled() ) {
        $logger->error("function is NOT implemented");
        return -1;
    }
    return -1;
}

=item getVlan - returns the port PVID

=cut

sub getVlan {
    my ( $self, $ifIndex ) = @_;
    my $logger        = $self->logger;
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';           # Q-BRIDGE-MIB
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $dot1dBasePort = $self->getDot1dBasePortForThisIfIndex($ifIndex);
    if ( !defined($dot1dBasePort) ) {
        return '';
    }

    $logger->trace(
        "SNMP get_request for dot1qPvid: $OID_dot1qPvid.$dot1dBasePort");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_dot1qPvid.$dot1dBasePort"] );
    return $result->{"$OID_dot1qPvid.$dot1dBasePort"};
}

=item getVlans - returns the VLAN ID - name mapping

=cut

sub getVlans {
    my $self   = shift;
    my $logger = $self->logger;
    my $OID_dot1qVlanStaticName = '1.3.6.1.2.1.17.7.1.4.3.1.1';  #Q-BRIDGE-MIB
    my $vlans                   = {};
    if ( !$self->connectRead() ) {
        return $vlans;
    }

    $logger->trace(
        "SNMP get_table for dot1qVlanStaticName: $OID_dot1qVlanStaticName");
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => $OID_dot1qVlanStaticName );

    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            $key =~ /^$OID_dot1qVlanStaticName\.(\d+)$/;
            $vlans->{$1} = $result->{$key};
        }
    }

    return $vlans;
}

=item isDefinedVlan - determines if the VLAN is defined on the switch

=cut

sub isDefinedVlan {
    my ( $self, $vlan ) = @_;
    my $logger = $self->logger;
    my $OID_dot1qVlanStaticName = '1.3.6.1.2.1.17.7.1.4.3.1.1';  #Q-BRIDGE-MIB
    if ( !$self->connectRead() ) {
        return 0;
    }

    $logger->trace(
        "SNMP get_request for dot1qVlanStaticName: $OID_dot1qVlanStaticName.$vlan"
    );
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_dot1qVlanStaticName.$vlan"] );

    return (
               defined($result)
            && exists( $result->{"$OID_dot1qVlanStaticName.$vlan"} )
            && (
            $result->{"$OID_dot1qVlanStaticName.$vlan"} ne 'noSuchInstance' )
    );
}

sub getMacBridgePortHash {
    my $self   = shift;
    my $vlan   = shift || '';
    my $logger = $self->logger;
    my $OID_dot1qTpFdbPort = '1.3.6.1.2.1.17.7.1.2.2.1.2';    #Q-BRIDGE-MIB
    my %macBridgePortHash  = ();
    if ( !$self->connectRead() ) {
        return %macBridgePortHash;
    }
    $logger->trace("SNMP get_table for dot1qTpFdbPort: $OID_dot1qTpFdbPort");
    my $result;

    my $vlanFdbId = 0;
    if ( $vlan eq '' ) {
        $result = $self->{_sessionRead}
            ->get_table( -baseoid => $OID_dot1qTpFdbPort );
    } else {
        $vlanFdbId = $self->getVlanFdbId($vlan);
        $result    = $self->{_sessionRead}
            ->get_table( -baseoid => "$OID_dot1qTpFdbPort.$vlanFdbId" );
    }

    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            $key
                =~ /^$OID_dot1qTpFdbPort\.(\d+)\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
            if ( ( $vlanFdbId == 0 ) || ( $1 eq $vlanFdbId ) ) {
                my $mac = sprintf( "%02X:%02X:%02X:%02X:%02X:%02X",
                    $2, $3, $4, $5, $6, $7 );
                $macBridgePortHash{$mac} = $result->{$key};
            }
        }
    }
    return %macBridgePortHash;
}

sub getHubs {
    my $self              = shift;
    my $logger            = $self->logger;
    my @upLinks           = $self->getUpLinks();
    my $hubPorts          = {};
    my %macBridgePortHash = $self->getMacBridgePortHash();
    foreach my $mac ( keys %macBridgePortHash ) {
        my $ifIndex = $macBridgePortHash{$mac};
        if ( $ifIndex != 0 ) {

            # A value of '0' indicates that the port number has not
            # been learned but that the device does have some
            # forwarding/filtering information about this address
            # (e.g. in the dot1qStaticUnicastTable).
            if ( grep( { $_ == $ifIndex } @upLinks ) == 0 ) {

                # the port is not a upLink
                my $portVlan = $self->getVlan($ifIndex);
                if ( $self->isManagedVlan($portVlan) ) {

                    # the port is in a VLAN we manage
                    push @{ $hubPorts->{$ifIndex} }, $mac;
                }
            }
        }
    }
    foreach my $ifIndex ( keys %$hubPorts ) {
        if ( scalar( @{ $hubPorts->{$ifIndex} } ) == 1 ) {
            delete( $hubPorts->{$ifIndex} );
        }
    }
    return $hubPorts;
}

sub getIfIndexForThisMac {
    my ( $self, $mac ) = @_;
    my $logger = $self->logger;
    my $oid_mac = mac2oid($mac);

    if (!defined($oid_mac)) {
        $logger->warn("invalid MAC, not running request");
        return -1;
    }
    if ( !$self->connectRead() ) {
        return -1;
    }

    my $oid_dot1qTpFdbPort = '1.3.6.1.2.1.17.7.1.2.2.1.2'; #Q-BRIDGE-MIB
    foreach my $vlan ( values %{ $self->{_vlans} } ) {
        my $oid = "$oid_dot1qTpFdbPort.$vlan.$oid_mac";
        $logger->trace("SNMP get_request for $oid");
        my $result
            = $self->{_sessionRead}->get_request( -varbindlist => [$oid] );
        if ( ( defined($result) ) && ( !$self->isUpLink( $result->{$oid} ) ) )
        {
            return $result->{$oid};
        }
    }
    return -1;
}

# TODO: unclear method contract
sub getVmVlanType {
    my ( $self, $ifIndex ) = @_;
    return 1;
}

# TODO: unclear method contract
sub setVmVlanType {
    my ( $self, $ifIndex, $type ) = @_;
    return 1;
}

sub getMacAddrVlan {
    my $self    = shift;
    my @upLinks = $self->getUpLinks();
    my %ifIndexMac;
    my %macVlan;
    my $logger = $self->logger;

    my $OID_dot1qTpFdbPort = '1.3.6.1.2.1.17.7.1.2.2.1.2';    #Q-BRIDGE-MIB
    if ( !$self->connectRead() ) {
        return %macVlan;
    }
    my $result
        = $self->{_sessionRead}->get_table( -baseoid => $OID_dot1qTpFdbPort );

    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            if ( grep( { $_ == $result->{$key} } @upLinks ) == 0 ) {
                my $portVlan = $self->getVlan( $result->{$key} );
                if ( $self->isManagedVlan($portVlan) )
                {    # the port is in a VLAN we manage
                    push @{ $ifIndexMac{ $result->{$key} } }, $key;
                }
            }
        }
    }
    $logger->debug("List of MACS for every non-upLink ports (Dumper):");
    $logger->debug( Dumper(%ifIndexMac) );

    foreach my $ifIndex ( keys %ifIndexMac ) {
        my $macCount = scalar( @{ $ifIndexMac{$ifIndex} } );
        $logger->debug("port: $ifIndex; number of MACs: $macCount");
        if ( $macCount == 1 ) {
            $ifIndexMac{$ifIndex}[0]
                =~ /^$OID_dot1qTpFdbPort\.(\d+)\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
            my $mac = sprintf( "%02X:%02X:%02X:%02X:%02X:%02X",
                $2, $3, $4, $5, $6, $7 );
            $macVlan{$mac}{'vlan'}    = $1;
            $macVlan{$mac}{'ifIndex'} = $ifIndex;
        } elsif ( $macCount > 1 ) {
            $logger->warn(
                "ALERT: There is a hub on switch $self->{'_id'} port $ifIndex. We found $macCount MACs on this port !"
            );
        }
    }
    $logger->debug("Show VLAN and port for every MACs (dumper):");
    $logger->debug( Dumper(%macVlan) );

    return %macVlan;
}

sub getAllMacs {
    my ( $self, @ifIndexes ) = @_;
    my $logger = $self->logger;
    if ( !@ifIndexes ) {
        @ifIndexes = $self->getManagedIfIndexes();
    }
    my $ifIndexVlanMacHashRef;

    my $OID_dot1qTpFdbPort = '1.3.6.1.2.1.17.7.1.2.2.1.2';    #Q-BRIDGE-MIB
    if ( !$self->connectRead() ) {
        return $ifIndexVlanMacHashRef;
    }
    my $result
        = $self->{_sessionRead}->get_table( -baseoid => $OID_dot1qTpFdbPort );

    my @vlansToConsider = values %{ $self->{_vlans} };
    if ( $self->isVoIPEnabled() ) {
        my $voiceVlan = $self->getVlanByName($VOICE_ROLE);
        if ( defined( $voiceVlan ) ) {
            if ( grep( { $_ == $voiceVlan } @vlansToConsider ) == 0 ) {
                push @vlansToConsider, $voiceVlan;
            }
        }
    }
    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            my $ifIndex = $result->{$key};
            if ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) {
                $key
                    =~ /^$OID_dot1qTpFdbPort\.(\d+)\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
                my $vlan = $1;
                if ( grep( { $_ == $vlan } @vlansToConsider ) > 0 ) {
                    my $mac = sprintf( "%02X:%02X:%02X:%02X:%02X:%02X",
                        $2, $3, $4, $5, $6, $7 );
                    push @{ $ifIndexVlanMacHashRef->{$ifIndex}->{$vlan} },
                        $mac;
                }
            }
        }
    }

    return $ifIndexVlanMacHashRef;
}

sub getAllIfOctets {
    my ( $self, @ifIndexes ) = @_;
    my $logger          = $self->logger;
    my $oid_ifInOctets  = '1.3.6.1.2.1.2.2.1.10';
    my $oid_ifOutOctets = '1.3.6.1.2.1.2.2.1.16';
    my $ifOctetsHashRef;
    if ( !$self->connectRead() ) {
        return $ifOctetsHashRef;
    }
    if ( !@ifIndexes ) {
        @ifIndexes = $self->getManagedIfIndexes();
    }

    $logger->trace("SNMP get_table for ifInOctets $oid_ifInOctets");
    my $result
        = $self->{_sessionRead}->get_table( -baseoid => $oid_ifInOctets );
    foreach my $key ( sort keys %$result ) {
        if ( $key =~ /^$oid_ifInOctets\.(\d+)$/ ) {
            my $ifIndex = $1;
            if ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) {
                $ifOctetsHashRef->{$ifIndex}->{'in'} = $result->{$key};
            }
        } else {
            $logger->warn("error key $key");
        }
    }
    $logger->trace("SNMP get_table for ifOutOctets $oid_ifOutOctets");
    $result
        = $self->{_sessionRead}->get_table( -baseoid => $oid_ifOutOctets );
    foreach my $key ( sort keys %$result ) {
        if ( $key =~ /^$oid_ifOutOctets\.(\d+)$/ ) {
            my $ifIndex = $1;
            if ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) {
                $ifOctetsHashRef->{$ifIndex}->{'out'} = $result->{$key};
            }
        } else {
            $logger->warn("error key $key");
        }
    }
    return $ifOctetsHashRef;
}

sub isNewerVersionThan {
    my ( $self, $versionToCompareToString ) = @_;
    my $currentVersion          = $self->getVersion();
    my @detectedOSVersionArray  = split( /\./, $currentVersion );
    my @versionToCompareToArray = split( /\./, $versionToCompareToString );
    my $i                       = 0;
    while ( $i < scalar(@detectedOSVersionArray) ) {
        if ( $detectedOSVersionArray[$i] > $versionToCompareToArray[$i] ) {
            return 1;
        }
        $i++;
    }
    return 0;
}

# TODO move out to a util package
sub generateFakeMac {
    my ($self, $is_voice_vlan, $ifIndex) = @_;
    my $logger = $self->logger;

    # generating a fixed 6 digit string with ifIndex (zero filled)
    my $zero_filled_ifIndex = sprintf('%06d', $ifIndex);
    my $mac_suffix;
    if ($zero_filled_ifIndex !~ /^\d{6}$/) {
         $logger->warn("Unexpected ifIndex to generate a fake MAC for. "
             . "This could cause port-security problems. ifIndex: $zero_filled_ifIndex");
         $mac_suffix = "99:99:99";
    } else {
         $zero_filled_ifIndex =~ /(\d{2})(\d{2})(\d{2})/;
         $mac_suffix = "$1:$2:$3";
    }

    # VoIP will be different than non-VoIP
    return "02:00:" . ( ($is_voice_vlan) ? "01" : "00" ) . ":" . $mac_suffix;
}

# TODO move out to a util package
sub isFakeMac {
    my ( $self, $mac ) = @_;
    return ( $mac =~ /^02:00:00/ );
}

# TODO move out to a util package
sub isFakeVoIPMac {
    my ( $self, $mac ) = @_;
    return ( $mac =~ /^02:00:01/ );
}

=item  getUpLinks - get the list of port marked as uplink in configuration

Returns an array of port ifIndex or -1 on failure

=cut

sub getUpLinks {
    my ($self) = @_;
    my @upLinks;
    my $logger = $self->logger;

    if ( lc(@{ $self->{_uplink} }[0]) eq 'dynamic' ) {
        $logger->warn( "Warning: for switch "
                . $self->{_id}
                . ", 'uplink = Dynamic' in config file but this is not supported !"
        );
        return -1;
    } else {
        @upLinks = @{ $self->{_uplink} };
    }
    return @upLinks;
}

# TODO: what the hell is this supposed to do?
sub getVlanFdbId {
    my ( $self, $vlan ) = @_;
    my $OID_dot1qVlanFdbId = '1.3.6.1.2.1.17.7.1.4.2.1.3.0';    #Q-BRIDGE-MIB
    my $logger = $self->logger;

    return $vlan;
}

sub isIfLinkUpDownTrapEnable {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_ifLinkUpDownTrapEnable = '1.3.6.1.2.1.31.1.1.1.14'; # from IF-MIB
    $logger->trace("SNMP get_request for ifLinkUpDownTrapEnable: $OID_ifLinkUpDownTrapEnable");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [ "$OID_ifLinkUpDownTrapEnable.$ifIndex" ] );
    return ( exists( $result->{"$OID_ifLinkUpDownTrapEnable.$ifIndex"} )
                && ( $result->{"$OID_ifLinkUpDownTrapEnable.$ifIndex"} ne 'noSuchInstance' )
                && ( $result->{"$OID_ifLinkUpDownTrapEnable.$ifIndex"} == 1 ) );
}

sub setIfLinkUpDownTrapEnable {
    my ( $self, $ifIndex, $enable ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port ifLinkUpDownTrapEnable");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $OID_ifLinkUpDownTrapEnable = '1.3.6.1.2.1.31.1.1.1.14'; # from IF-MIB
    my $truthValue = $enable ? $SNMP::TRUE : $SNMP::FALSE;

    $logger->trace("SNMP set_request for ifLinkUpDownTrapEnable: $OID_ifLinkUpDownTrapEnable");
    my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
        "$OID_ifLinkUpDownTrapEnable.$ifIndex", Net::SNMP::INTEGER, $truthValue
    ]);

    return ( defined($result) );
}

=item disableIfLinkUpDownTraps

Disables LinkUp / LinkDown SNMP traps on a given ifIndex

=cut

sub disableIfLinkUpDownTraps {
    my ($self, $ifIndex) = @_;

    return $self->setIfLinkUpDownTrapEnable($ifIndex, $FALSE);
}

=item enableIfLinkUpDownTraps

Enables LinkUp / LinkDown SNMP traps on a given ifIndex

=cut

sub enableIfLinkUpDownTraps {
    my ($self, $ifIndex) = @_;

    return $self->setIfLinkUpDownTrapEnable($ifIndex, $TRUE);
}

=item deauthenticateMac - performs wireless deauthentication

mac - mac address to deauthenticate

is_dot1x - set to 1 if special dot1x de-authentication is required

=cut

sub deauthenticateMac {
    my ($self, $mac, $is_dot1x) = @_;
    my $logger = $self->logger;
    my ($switchdeauthMethod, $deauthTechniques) = $self->deauthTechniques($self->{_deauthMethod});
    $self->$deauthTechniques($mac);
}

=item dot1xPortReauthenticate

Forces 802.1x re-authentication of a given ifIndex

ifIndex - ifIndex to force re-authentication on

=cut

sub dot1xPortReauthenticate {
    my ($self, $ifIndex, $mac) = @_;

    return $self->_dot1xPortReauthenticate($ifIndex);
}

=item _dot1xPortReauthenticate

Actual implementation.
Allows callers to refer to this implementation even though someone along the way override the above call.

=cut

sub _dot1xPortReauthenticate {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;

    $logger->info("Trying generic MIB to force 802.1x port re-authentication. Your mileage may vary. "
        . "If it doesn't work open a bug report with your hardware type.");

    my $oid_dot1xPaePortReauthenticate = "1.0.8802.1.1.1.1.1.2.1.5"; # from IEEE8021-PAE-MIB

    if (!$self->connectWrite()) {
        return 0;
    }

    $logger->trace("SNMP set_request force dot1xPaePortReauthenticate on ifIndex: $ifIndex");
    my $result = $self->{_sessionWrite}->set_request(-varbindlist => [
        "$oid_dot1xPaePortReauthenticate.$ifIndex", Net::SNMP::INTEGER, 1
    ]);

    if (!defined($result)) {
        $logger->error("got an SNMP error trying to force 802.1x re-authentication: ".$self->{_sessionWrite}->error);
    }

    return (defined($result));
}

=item NasPortToIfIndex

Translate RADIUS NAS-Port into the physical port ifIndex

Default fallback implementation: we just return the NAS-Port as ifIndex.

=cut

sub NasPortToIfIndex {
    my ($self, $nas_port) = @_;
    my $logger = $self->logger;

    $logger->trace("Fallback implementation. Returning NAS-Port as ifIndex: $nas_port");
    return $nas_port;
}

=item handleReAssignVlanTrapForWiredMacAuth

Called when a ReAssignVlan trap is received for a switch-port in Wired MAC Authentication.

Default behavior is to bounce the port

=cut

sub handleReAssignVlanTrapForWiredMacAuth {
    my ($self, $ifIndex, $mac) = @_;
    my $logger = $self->logger;

    # TODO extract that behavior in a method call in pf::role so it can be overridden easily

    $logger->warn("Until CoA is implemented we will bounce the port on VLAN re-assignment traps for MAC-Auth");

    # TODO perform CoA instead (when implemented)
    # actually once CoA will be implemented, we should consider offering the same option to users
    # as we currently do with port-security and VoIP which is bounce or not bounce and suffer consequences
    # this should be a choice exposed in configuration and not hidden in code
    $self->bouncePort($ifIndex);
}

=item extractSsid

Find RADIUS SSID parameter out of RADIUS REQUEST parameters

SSID are not provided by a standardized parameter name so we encapsulate that complexity here.
If your AP is not supported look in /usr/share/freeradius/dictionary* for vendor specific attributes (VSA).

Most standard way we encountered is in Called-Station-Id in the format: "xx-xx-xx-xx-xx-xx:SSID".

We support also:

  "xx:xx:xx:xx:xx:xx:SSID"
  "xxxxxxxxxxxx:SSID"

=cut

sub extractSsid {
    my ($self, $radius_request) = @_;
    my $logger = $self->logger;

    # it's put in Called-Station-Id
    # ie: Called-Station-Id = "aa-bb-cc-dd-ee-ff:Secure SSID" or "aa:bb:cc:dd:ee:ff:Secure SSID"
    if (defined($radius_request->{'Called-Station-Id'})) {
        if ($radius_request->{'Called-Station-Id'} =~ /^
            # below is MAC Address with supported separators: :, - or nothing
            [a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}[-:]?[a-f0-9]{2}
            :                                                                                           # : delimiter
            (.*)                                                                                        # SSID
        $/ix) {
            return $1;
        } else {
            $logger->info("Unable to extract SSID of Called-Station-Id: ".$radius_request->{'Called-Station-Id'});
        }
    }

    $logger->warn(
        "Unable to extract SSID for module " . ref($self) . ". SSID-based VLAN assignments won't work. "
        . "Please let us know so we can add support for it."
    );
    return;
}

=item getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut

sub getVoipVsa {
    my ($self) = @_;
    my $logger = $self->logger;

    $logger->warn(
        "No RADIUS Vendor Specific Attributes (VSA) for module " . ref($self) . ". "
        . "Phone will not be allowed on the correct untagged VLAN."
    );
    return;
}



=item enablePortConfigAsTrunk - sets port as multi-Vlan port

=cut

sub enablePortConfigAsTrunk {
    my ($self, $mac, $switch_port, $switch_locker_ref, $taggedVlans)  = @_;
    my $logger = $self->logger;

    # switchport mode trunk
    $logger->info("Setting port $switch_port as trunk.");
    if (! $self->setModeTrunk($switch_port, $TRUE)) {
        $logger->error("An error occured while enabling port $switch_port as multi-vlan (trunk)");
    }

    # switchport trunk allowed vlan x,y,z
    $logger->info("Allowing tagged Vlans on port $switch_port");
    if (! $self->setTaggedVlans($switch_port, $switch_locker_ref, split(",", $taggedVlans)) ) {
        $logger->error("An error occured while allowing tagged Vlans on trunk port $switch_port");
    }

    return 1;
}

=item disablePortConfigAsTrunk - sets port as non multi-Vlan port

=cut

sub disablePortConfigAsTrunk {
    my ($self, $switch_port, $switch_locker_ref) = @_;
    my $logger = $self->logger;

    # switchport mode access
    $logger->info("Setting port $switch_port as non trunk.");
    if (! $self->setModeTrunk($switch_port, $FALSE)) {
        $logger->error("An error occured while disabling port $switch_port as multi-vlan (trunk)");
    }

    # no switchport trunk allowed vlan
    # this setting is not necessary but we thought it would ease the reading of the port configuration if we remove
    # all the tagged vlan when they are not in use (port no longer trunk)
    $logger->info("Disabling tagged Vlans on port $switch_port");
    if (! $self->removeAllTaggedVlans($switch_port, $switch_locker_ref)) {
        $logger->warn("An minor issue occured while disabling tagged Vlans on trunk port $switch_port " .
                      "but the port should work.");
    }

    return 1;
}

=item getDeauthSnmpConnectionKey

Handles if deauthentication should be performed against controller or actual network device.
Performs the actual SNMP Write connection and returns sessionWrite hash key to use.

See L<pf::Switch::Dlink::DWS_3026> for a usage example.

=cut

sub getDeauthSnmpConnectionKey {
    my $self = shift;
    my $logger = $self->logger;

    if (defined($self->{_controllerIp}) && $self->{_controllerIp} ne '') {

        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        return if ( !$self->connectWriteToController() );
        return '_sessionControllerWrite';
    } else {
        return if ( !$self->connectWrite() );
        return '_sessionWrite';
    }
}

#sub ip { my $self = shift; return $self->{_controllerIp} || $self->{_ip}; }

=item radiusDisconnect

Sends a RADIUS Disconnect-Request to the NAS with the MAC as the Calling-Station-Id to disconnect.

Optionally you can provide other attributes as an hashref.

Uses L<pf::util::radius> for the low-level RADIUS stuff.

=cut

# TODO consider whether we should handle retries or not?
sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = $self->logger();

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS Disconnect-Request on $self->{'_id'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating");

    # Where should we send the RADIUS Disconnect-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    my $nas_ip_address = $self->{_switchIp};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }
    # allowing client code to override where we connect with NAS-IP-Address
    if ( defined($add_attributes_ref->{'NAS-IP-Address'}) && $add_attributes_ref->{'NAS-IP-Address'} ne '' ) {
        $logger->info("'NAS-IP-Address' additionnal attribute is set. Using it '" . $add_attributes_ref->{'NAS-IP-Address'} . "' to perform deauth");
        $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'};
    }

    my $response;
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip($send_disconnect_to),
        };

        if (defined($self->{'_disconnectPort'}) && $self->{'_disconnectPort'} ne '') {
            $connection_info->{'nas_port'} = $self->{'_disconnectPort'};
        }

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        $response = perform_disconnect($connection_info, $attributes_ref);
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS Disconnect-Request: $_");
        $logger->error("Wrong RADIUS secret or unreachable network device...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ( ($response->{'Code'} eq 'Disconnect-ACK') || ($response->{'Code'} eq 'CoA-ACK') );

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept response for the network device.

Default implementation.

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger();

    my $radius_reply_ref = {};

    # should this node be kicked out?
    my $kick = $self->handleRadiusDeny($args);
    return $kick if (defined($kick));

    # Inline Vs. VLAN enforcement
    my $role = "";
    if ( (!$args->{'wasInline'} || ($args->{'wasInline'} && $args->{'vlan'} != 0) ) && isenabled($self->{_VlanMap})) {
        if(defined($args->{'vlan'}) && $args->{'vlan'} ne "" && $args->{'vlan'} ne 0){
            $logger->info("(".$self->{'_id'}.") Added VLAN $args->{'vlan'} to the returned RADIUS Access-Accept");
            $radius_reply_ref = {
                'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
                'Tunnel-Type' => $RADIUS::VLAN,
                'Tunnel-Private-Group-ID' => $args->{'vlan'} . "",
            };
        }
        else {
            $logger->debug("(".$self->{'_id'}.") Received undefined VLAN. No VLAN added to RADIUS Access-Accept");
        }
    }

    if ( isenabled($self->{_RoleMap}) && $self->supportsRoleBasedEnforcement()) {
        $logger->debug("Network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned");
        if ( defined($args->{'user_role'}) && $args->{'user_role'} ne "" ) {
            $role = $self->getRoleByName($args->{'user_role'});
        }
        if ( defined($role) && $role ne "" ) {
            $radius_reply_ref = {
                %$radius_reply_ref,
                $self->returnRoleAttributes($role),
            };
            $logger->info(
                "(".$self->{'_id'}.") Added role $role to the returned RADIUS Access-Accept"
            );
        }
        else {
            $logger->debug("(".$self->{'_id'}.") Received undefined role. No Role added to RADIUS Access-Accept");
        }
    }

    my $status = $RADIUS::RLM_MODULE_OK;
    if (!isenabled($args->{'unfiltered'})) {
        my $filter = pf::access_filter::radius->new;
        my $rule = $filter->test('returnRadiusAccessAccept', $args);
        ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    }

    return [$status, %$radius_reply_ref];
}

=item returnRoleAttributes

Return the specific role attribute of the switch.

=cut

sub returnRoleAttributes {
    my ($self, $role) = @_;
    return ($self->returnRoleAttribute() => $role);
}

=item handleRadiusDeny

Return RLM_MODULE_USERLOCK if the vlan id is -1

=cut

sub handleRadiusDeny {
    my ($self, $args) =@_;
    my $logger = $self->logger();

    if (( defined($args->{'vlan'}) && $args->{'vlan'} eq "-1" ) || ( defined($args->{'user_role'}) && $args->{'user_role'} eq $REJECT_ROLE )) {
        $logger->info("According to rules in fetchRoleForNode this node must be kicked out. Returning USERLOCK");
        $self->disconnectRead();
        $self->disconnectWrite();
        return [ $RADIUS::RLM_MODULE_USERLOCK, ('Reply-Message' => "This node is not allowed to use this service") ];
    }
    return undef;
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::SNMP;
    my %tech = (
        $SNMP::SNMP => 'deauthenticateMacDefault',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=item supporteddeauthTechniques

return Default Deauthentication Method

=cut

sub supporteddeauthTechniques {
    my ( $self ) = @_;

    my %tech = (
        'Default' => 'deauthenticateMacDefault',
    );
    return %tech;
}

=item deauthenticateMacDefault

return Default Deauthentication Default technique

=cut

sub deauthenticateMacDefault {
    my ( $self ) = @_;
    my $logger = $self->logger;

    $logger->warn("Unimplemented! First, make sure your configuration is ok. "
        . "If it is then we don't support your hardware. Open a bug report with your hardware type.");
    return $FALSE;
}

=item GetIfIndexByNasPortId

return IfIndexByNasPortId

=cut

sub getIfIndexByNasPortId {
    my ($self ) = @_;
    return $FALSE;
}

=item wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::SNMP;
        my %tech = (
            $SNMP::SNMP => 'dot1xPortReauthenticate',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    if ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::SNMP;
        my %tech = (
            $SNMP::SNMP => 'handleReAssignVlanTrapForWiredMacAuth',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
}

sub synchronize_locationlog {
    my ( $self, $ifIndex, $vlan, $mac, $voip_status, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role, $ifDesc) = @_;
    locationlog_synchronize($self->{_id},$self->{_ip},$self->{_switchMac}, $ifIndex, $vlan, $mac, $voip_status, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role, $ifDesc);
}


=item extractVLAN

Extract VLAN from the radius attributes.

=cut

sub extractVLAN {
    my ($self, $radius_request) = @_;
    my $logger = $self->logger();
    $logger->warn("Not implemented");
    return;
}

=item parseRequest

Takes FreeRADIUS' RAD_REQUEST hash and process it to return
NAS Port type (Ethernet, Wireless, etc.)
Network Device IP
EAP
MAC
NAS-Port (port)
User-Name

=cut

sub parseRequest {
    my ( $self, $radius_request ) = @_;

    my $client_mac      = ref($radius_request->{'Calling-Station-Id'}) eq 'ARRAY'
                           ? clean_mac($radius_request->{'Calling-Station-Id'}[0])
                           : clean_mac($radius_request->{'Calling-Station-Id'});
    my $user_name       = $self->parseRequestUsername($radius_request);
    my $nas_port_type   = ( defined($radius_request->{'NAS-Port-Type'}) ? $radius_request->{'NAS-Port-Type'} : ( defined($radius_request->{'Called-Station-SSID'}) ? "Wireless-802.11" : undef ) );
    my $port            = $radius_request->{'NAS-Port'};
    my $eap_type        = ( exists($radius_request->{'EAP-Type'}) ? $radius_request->{'EAP-Type'} : 0 );
    my $nas_port_id     = ( defined($radius_request->{'NAS-Port-Id'}) ? $radius_request->{'NAS-Port-Id'} : undef );

    return ($nas_port_type, $eap_type, $client_mac, $port, $user_name, $nas_port_id, undef, $nas_port_id);
}

=item parseRequestUsername

Parse the username from the RADIUS request

=cut

sub parseRequestUsername {
    my ($self, $radius_request) = @_;
    if (isenabled($Config{radius_configuration}{normalize_radius_machine_auth_username})) {
        if ($radius_request->{'User-Name'} =~ /^host\//) {
            if (exists($radius_request->{'TLS-Client-Cert-Common-Name'})) {
                return $radius_request->{'User-Name'};
            }
        }
    }
    foreach my $attribute (@{$Config{radius_configuration}{username_attributes}}) {
        if(exists($radius_request->{$attribute})) {
            my $user_name = $radius_request->{$attribute};
            get_logger->debug("Extracting username '$user_name' from RADIUS attribute $attribute");
            return $user_name;
        }
    }
}


=item parseVPNRequest

Takes FreeRADIUS' RAD_REQUEST hash and process it to return
NAS Port type
Network Device IP
EAP
NAS-Port (port)
User-Name

=cut

sub parseVPNRequest {
    my ( $self, $radius_request ) = @_;
    my $logger = $self->logger;

    my $client_ip       = ref($radius_request->{'Calling-Station-Id'}) eq 'ARRAY'
                           ? clean_ip($radius_request->{'Calling-Station-Id'}[0])
                           : clean_ip($radius_request->{'Calling-Station-Id'});

    my $user_name       = $self->parseRequestUsername($radius_request);
    my $nas_port_type   = $radius_request->{'NAS-Port-Type'};
    my $port            = $radius_request->{'NAS-Port'};
    my $eap_type        = ( exists($radius_request->{'EAP-Type'}) ? $radius_request->{'EAP-Type'} : 0 );
    my $nas_port_id     = ( defined($radius_request->{'NAS-Port-Id'}) ? $radius_request->{'NAS-Port-Id'} : undef );

    return ($nas_port_type, $eap_type, undef, $port, $user_name, $nas_port_id, undef, $nas_port_id);
}

=item getAcceptForm

Get the accept form that will trigger the device registration on the switch

=cut

sub getAcceptForm {
    my ( $self, $mac, $destination_url, $portalSession ) = @_;
    my $logger = $self->logger();
    $logger->error("This function is not implemented.");
    return;
}

=item parseExternalPortalRequest

Parse external portal request using URI and it's parameters then return an hash reference with the appropriate parameters

See L<pf::web::externalportal::handle>

=cut

sub parseExternalPortalRequest {
    my ( $self, $r, $req ) = @_;
    my $logger = $self->logger;
    $logger->error("This function is not implemented.");
    return;
}

=item parseTrap

Unimplemented base method meant to be overriden in switches that support SNMP trap based methods.

=cut

sub parseTrap {
    my $self   = shift;
    my $logger = $self->logger();
    $logger->warn("SNMP trap handling not implemented for this type of switch.");
    my $trapHashRef;
    $trapHashRef->{'trapType'} = 'unknown';
    return $trapHashRef;
}

=item identifyConnectionType

Used to override L<pf::Connection::identifyType> behavior if needed on a per switch module basis.

=cut

sub identifyConnectionType {
    my ( $self, $radius_request ) = @_;
    my $logger = get_logger();

    return;
}

=item disableMABByIfIndex

Disables mac authentication bypass on the specified port

=cut

sub disableMABByIfIndex {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger();
    $logger->error("This function is unimplemented.");
    return 0;
}

=item enableMABByIfIndex

Enables mac authentication bypass on the specified port

=cut

sub enableMABByIfIndex {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger();
    $logger->error("This function is unimplemented.");
    return 0;
}

=item deauth_source_ip

Computes which IP should be used as source IP address for the deauthentication

Takes into account the active/active clustering and centralized deauth

=cut

sub deauth_source_ip {
    my ($self,$dst_ip) = @_;
    my $logger = $self->logger();
    my $chi = pf::CHI->new(namespace => 'route_int');
    my $int = $chi->compute($dst_ip, sub {
                                         my @interface_src = split(" ", pf_run("sudo ip route get $dst_ip"));
                                         if ($interface_src[1] eq 'via') {
                                             return $interface_src[4];
                                         } else {
                                             return $interface_src[2];
                                         }
                                      }
                           );
    if (defined($Config{ 'interface ' . $int })) {
        if($cluster_enabled){
            return isenabled($Config{active_active}{centralized_deauth}) ? pf::cluster::cluster_ip($int) : pf::cluster::current_server->{"interface $int"}->{ip};
        }
        else {
            return $Config{ 'interface ' . $int }{'vip'} || $Config{ 'interface ' . $int }{'ip'}
        }
    } else {
        $logger->warn("Interface $int has not been found in the configuration, using the management interface");
        if($cluster_enabled){
            return isenabled($Config{active_active}{centralized_deauth}) ? pf::cluster::management_cluster_ip() : pf::cluster::current_server->{management_ip};
        }
        else {
            return $management_network->tag('vip') || $management_network->tag('ip');
        }
    }
}

=item logger

Return the current logger for the switch

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
}

=item cache

Return the cache for the namespace switch

=cut

sub cache {
   my ($self) = @_;
   return pf::CHI->new( namespace => 'switch' );
}

=item cache_distributed

Returns the distributed cache for the switch namespace

=cut

sub cache_distributed {
    my ( $self ) = @_;
    return pf::CHI->new( namespace => 'switch_distributed' );
}

=item returnAuthorizeWrite

Return radius attributes to allow write access

=cut

sub returnAuthorizeWrite {
    my ($self, $args) = @_;
    my $radius_reply_ref = {};
    my $status = $RADIUS::RLM_MODULE_FAIL;
    my $msg = "PacketFence does not support this switch for read/write access login";
    $self->logger->info($msg);
    $radius_reply_ref->{'Reply-Message'} = $msg;
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeWrite', $args);
    if (defined($rule)) {
        ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    }
    return [$status, %$radius_reply_ref];

}

=item returnAuthorizeRead

Return radius attributes to allow read access

=cut

sub returnAuthorizeRead {
    my ($self, $args) = @_;
    my $radius_reply_ref ={};
    my $status = $RADIUS::RLM_MODULE_FAIL;
    my $msg = "PacketFence does not support this switch for read access login";
    $self->logger->info($msg);
    $radius_reply_ref->{'Reply-Message'} = $msg;
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeRead', $args);
    if (defined($rule)) {
        ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    }
    return [$status, %$radius_reply_ref];
}

=item setSession

Create a session id and save in in the locationlog.

=cut

sub setSession {
    my($self, $args) = @_;
    my $mac = $args->{'mac'};
    my $session_id = generate_session_id(6);
    my $chi = pf::CHI->new(namespace => 'httpd.portal');
    $chi->set($session_id,{
        client_mac => $mac,
        wlan => $args->{'ssid'},
        switch_id => $args->{'switch'}->{'_id'},
    });
    pf::locationlog::locationlog_set_session($mac, $session_id);
    return $session_id;
}

=item shouldUseCoA

Check if switch should use CoA

=cut

sub shouldUseCoA {
    my ($self, $args) = @_;
    # Roles are configured and the user should have one
    return (defined($args->{role}) && isenabled($self->{_RoleMap}) && isenabled($self->{_useCoA}));
}

=item getRelayAgentInfoOptRemoteIdSub

Return the RelayAgentInfoOptRemoteIdSub to match with switch mac in dhcp option 82.
In this case this is not supported on this switch and we return undef

=cut

sub getRelayAgentInfoOptRemoteIdSub {
    my($self) = @_;
    return undef;
}

=item externalPortalEnforcement

Evaluate wheter or not external portal enforcement is available on requested network equipment

=cut

sub externalPortalEnforcement {
    my ( $self ) = @_;
    my $logger = pf::log::get_logger;

    return $TRUE if ( $self->supportsExternalPortal && isenabled($self->{_ExternalPortalEnforcement}) );

    $logger->info("External portal enforcement either not supported '" . $self->supportsExternalPortal . "' or not configured '" . $self->{_ExternalPortalEnforcement} . "' on network equipment '" . $self->{_id} . "'");
    return $FALSE;
}

=item handleTrap

Trap handling logic

=back

=head1 Methods for trap handling

=over

=item normalizeTrap

Normalize a trap to the packetfence internal format.

Example

  {
    trapType => 'up',
    trapIfIndex => 1,
  }

The minimum information needed for the normalized trap data is the trapType
If a trap cannot be normalized then trapType will be set to 'unknown'

=cut

sub normalizeTrap {
    my ($self, $trapInfo) = @_;
    my $normalizer = $self->findTrapNormalizer($trapInfo);
    if ($normalizer) {
        return $self->$normalizer($trapInfo);
    }
    return {trapType => 'unknown'};
}

=item findTrapNormalizer

find the method to be used for normalizing a trap

=cut

sub findTrapNormalizer {
    my ($self, $trapInfo) = @_;
    my ($pdu, $variables) = @$trapInfo;
    my $snmpTrapOID =  $self->findTrapOID($variables);
    return undef unless $snmpTrapOID;
    if (exists $TRAP_NORMALIZERS{$snmpTrapOID}) {
        return $TRAP_NORMALIZERS{$snmpTrapOID};
    }
    return $self->_findTrapNormalizer($snmpTrapOID, $pdu, $variables);
}

=item _findTrapNormalizer

The method for a pf::Switch subclass to override in order to find the trap normalizer method

=cut

sub _findTrapNormalizer {
    return undef;
}

=item linkDownTrapNormalizer

The trap normalizer for the linkDown trap

=cut

sub linkDownTrapNormalizer {
    my ($self, $trapInfo) = @_;
    return {
        trapType => 'down',
        trapIfIndex => $self->getIfIndexFromTrap($trapInfo->[1]),
    };
}

=item linkUpTrapNormalizer

The trap normalizer for the linkUp trap

=cut

sub linkUpTrapNormalizer {
    my ($self, $trapInfo) = @_;
    return {
        trapType => 'up',
        trapIfIndex => $self->getIfIndexFromTrap($trapInfo->[1]),
    };
}

=item dot11DeauthenticateTrapNormalizer

The trap normalizer for the dot11Deauthenticate trap

=cut

sub dot11DeauthenticateTrapNormalizer {
    my ($self, $trapInfo) = @_;
    return {
        trapType => 'dot11Deauthentication',
        trapMac => $self->getMacFromTrapVariablesForOIDBase($trapInfo->[1], '.1.2.840.10036.1.1.1.18.')
    };
}

=item findTrapVarWithBase

find the trap variables that start with an OID

=cut

sub findTrapVarWithBase {
    my ($self, $variables, $base) = @_;
    return grep { $_->[0] =~ /^\Q$base\E/ } @$variables;
}

=item getIfIndexFromTrap

get the IfIndex from a trap

=cut

sub getIfIndexFromTrap {
    my ($self, $variables) = @_;
    my @indexes = $self->findTrapVarWithBase($variables,".1.3.6.1.2.1.2.2.1.1");
    return undef unless @indexes;
    return undef unless $indexes[0][1] =~ /(INTEGER|Gauge32): (\d+)/;
    return $2;
}

=item findTrapOID

find the traps notification type OID

=cut

sub findTrapOID {
    my ($self, $variables) = @_;
    my $variable = first { $_->[0] eq '.1.3.6.1.6.3.1.1.4.1.0'} @$variables;
    return undef unless $variable;
    $variable->[1] =~ /OID: (.*)/;
    return $1;
}

=item getMacFromTrapVariablesForOIDBase

Get a mac from a trap variable based of it's OID

=cut

sub getMacFromTrapVariablesForOIDBase {
    my ($self, $variables, $base) = @_;
    my ($variable) = $self->findTrapVarWithBase($variables, $base);
    return undef unless $variable;
    return $self->extractMacFromVariable($variable);
}

=item extractMacFromVariable

extract the mac address from a trap variable

=cut

sub extractMacFromVariable {
    my ($self, $variable) = @_;
    return undef unless $variable->[1] =~ /$SNMP::MAC_ADDRESS_FORMAT/;
    return parse_mac_from_trap($1);
}

=item TO_JSON

TO_JSON

=cut

sub TO_JSON {
    my ($self) = @_;
    my %data = %$self;
    delete @data{qw(_sessionRead _sessionWrite _sessionControllerWrite)};
    return \%data;
}

=item handleTrap

A hook for switch specific trap handling
If a true value is returned then the trap will be handled using the default logic.

=cut

sub handleTrap { 1 }


=item getExclusiveLock

Get an exclusive lock for the switch

=cut

sub getExclusiveLock {
    my ($self, $nonblock) = @_;
    return $self->getExclusiveLockForScope('', $nonblock);
}

=item getExclusiveLockForScope

Get an exclusive lock for the switch for a particular scope

=cut

sub getExclusiveLockForScope {
    my ($self, $scope, $nonblock) = @_;
    my $fh;
    my $filename = "$control_dir/switch:$self->{_id}:$scope";
    unless (open($fh, ">", $filename)) {
        $self->logger("Cannot open $filename: $!");
        return undef;
    }
    my $fs = File::FcntlLock->new(
        l_type   => F_WRLCK,
        l_whence => SEEK_SET,
        l_start => 0,
        l_len => 0,
    );
    my $type = $nonblock ? F_SETLK : F_SETLKW;
    my $result;
    1 while(!defined($result = $fs->lock($fh, $type)) && $! == EINTR);
    unless (defined $result) {
        $self->logger("Error getting lock on $filename: $!");
        return undef;
    }
    return $fh;
}

=item getLldpLocPortDesc

Query the switch for lldpLocPortDesc table and cache the result

=cut

sub getLldpLocPortDesc {
    my ( $self ) = @_;
    my $logger = $self->logger;

    # if can't SNMP read abort
    return if ( !$self->connectRead() );

    my $oid_lldpLocPortDesc = '1.0.8802.1.1.2.1.3.7.1.4'; # from LLDP-MIB
    $logger->trace("SNMP get_table for lldpLocPortDesc: $oid_lldpLocPortDesc");
    my $cache = $self->cache_distributed;
    my $result = $cache->compute($self->{'_id'} . "-" . $oid_lldpLocPortDesc, sub { $self->{_sessionRead}->get_table( -baseoid => $oid_lldpLocPortDesc, -maxrepetitions  => 1 ) } );
    # here's what we are getting here. Looking for the last element of the OID: lldpRemLocalPortNum
    # iso.0.8802.1.1.2.1.3.7.1.4.10 = STRING: "FastEthernet1/0/8"
    # iso.0.8802.1.1.2.1.3.7.1.4.11 = STRING: "FastEthernet1/0/9"
    # iso.0.8802.1.1.2.1.3.7.1.4.12 = STRING: "FastEthernet1/0/10"
    # iso.0.8802.1.1.2.1.3.7.1.4.13 = STRING: "FastEthernet1/0/11"
    # NOTE: We set the maxrepetitions to '1' to use 'get-next-requests' instead of 'get-bulk-requests' which tend to return empty results if response is to big

    return $result;
}

=item ifIndexToLldpLocalPort

Translate an ifIndex into an LLDP Local Port number.

We use ifDescr to lookup the lldpRemLocalPortNum in the lldpLocPortDesc table.

=cut

sub ifIndexToLldpLocalPort {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    # if can't SNMP read abort
    return if ( !$self->connectRead() );

    my $ifDescr = $self->getIfDesc($ifIndex);
    return if (!defined($ifDescr) || $ifDescr eq '');

    # Get lldpLocPortDesc
    my $oid_lldpLocPortDesc = '1.0.8802.1.1.2.1.3.7.1.4'; # from LLDP-MIB
    my $result = $self->getLldpLocPortDesc();

    foreach my $entry ( keys %{$result} ) {
        if ( $result->{$entry} eq $ifDescr ) {
            if ( $entry =~ /^$oid_lldpLocPortDesc\.([0-9]+)$/ ) {
                return $1;
            }
        }
    }

    # nothing found
    return;
}

=item invalidate_distributed_cache

Invalidate the distributed cache for a given switch object

=cut

sub invalidate_distributed_cache {
    my ( $self ) = @_;
    my $logger = $self->logger;

    $logger->info("Invalidating distributed switch cache for switch '" . $self->{_id} . "'");

    if ( $self->{_id} =~ /\// ) {
        $logger->info("Processing switch range '" . $self->{_id} . "'");
        my $ip = new Net::IP($self->{_id});
        do {
            $logger->info("Invalidating distributed switch cache for switch '" . $ip->ip() . "' part of switch range '" . $self->{_id} . "'");
            $self->remove_switch_from_cache($ip->ip());
        } while (++$ip);
    } else {
        $self->remove_switch_from_cache($self->{_id});
    }
}

=item remove_switch_from_cache

Remove all switch distributed cache keys for a given switch

=cut

sub remove_switch_from_cache {
    my ( $self, $key ) = @_;
    my $logger = $self->logger;

    my $cache = $self->cache_distributed;
    my %cache_content = $cache->get_keys();

    foreach ( keys %cache_content ) {
        $cache->remove($_) if $_ =~ /^$key-/;
    }
}

=item isMacInAddressTableAtIfIndex

isMacInAddressTableAtIfIndex

=cut

sub isMacInAddressTableAtIfIndex {
    my ($self) = @_;
    my $logger = $self->logger;
    $logger->warn("isMacInAddressTableAtIfIndex is not supported or implemented for this switch");

    return 0;
}

=item setCurrentTenant

Set the current tenant in the DAL based on the tenant ID configured in the switch

=cut

sub setCurrentTenant {
    my ($self) = @_;
    pf::dal->set_tenant($self->{_TenantId});
}

=head2 getCiscoAvPairAttribute

getCiscoAvPairAttribute

=cut

sub getCiscoAvPairAttribute {
    my ($self, $radius_request, $attr) = @_;
    my $logger = $self->logger;
    my $avpair = listify($radius_request->{'Cisco-AVPair'} // []);
    foreach my $ciscoAVPair (@{$avpair}) {
        $logger->trace("Cisco-AVPair: $ciscoAVPair $attr");
        if ($ciscoAVPair =~ /^\Q$attr\E=(.*)$/ig) {
            return $1;
        } else {
            $logger->info("Unable to extract $attr of Cisco-AVPair: $ciscoAVPair");
        }
    }

    $logger->warn(
        "Unable to extract $attr for module " . ref($self) . ". SSID-based VLAN assignments won't work. "
        . "Make sure you enable Vendor Specific Attributes (VSA) on the AP if you want them to work."
    );

    return ;
}

sub coaPort {
    my ($self) = @_;
    return $self->{'_coaPort'} || $DEFAULT_COA_PORT;
}

sub disconnectPort {
    my ($self) = @_;
    return $self->{'_disconnectPort'} || $DEFAULT_DISCONNECT_PORT;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
