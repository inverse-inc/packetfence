package pf::SNMP;

=head1 NAME

pf::SNMP - Object oriented module to access SNMP enabled network switches

=head1 DESCRIPTION

The pf::SNMP module implements an object oriented interface to access
SNMP enabled network switches. This module only contains some basic
functionnality and is meant to be subclassed.

=cut

use strict;
use warnings;

use Carp;
use Data::Dumper;
use Net::SNMP;
use Log::Log4perl;
use Try::Tiny;

our $VERSION = 2.10;

use pf::config;
use pf::locationlog;
use pf::node;
# RADIUS constants (RADIUS:: namespace)
use pf::radius::constants;
use pf::roles::custom $ROLE_API_LEVEL;
# SNMP constants (several standard-based and vendor-based namespaces)
use pf::SNMP::constants;
use pf::util;
use pf::util::radius qw(perform_disconnect);

=head1 SUBROUTINES

=over

=cut

=item supportsFloatingDevice

Returns 1 if switch type supports floating network devices

=cut
sub supportsFloatingDevice {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->error("Floating devices are not supported on switch type " . ref($this));
    return $FALSE;
}

=item supportsWiredMacAuth 

Returns 1 if switch type supports Wired MAC Authentication (Wired Access Authorization through RADIUS)

=cut
sub supportsWiredMacAuth {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->error(
        "Wired MAC Authentication (Wired Access Authorization through RADIUS) "
        . "is not supported on switch type " . ref($this) . ". Please let us know what hardware you are using."
    );
    return $FALSE;
}

=item supportsWiredDot1x - Returns 1 if switch type supports Wired 802.1X

=cut
sub supportsWiredDot1x {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->error(
        "Wired 802.1X is not supported on switch type " . ref($this) . ". "
        . "Please let us know what hardware you are using."
    );
    return $FALSE;
}

=item supportsWirelessMacAuth 

Returns 1 if switch type supports Wireless MAC Authentication (RADIUS Authentication)

=cut
sub supportsWirelessMacAuth {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->error(
        "Wireless MAC Authentication is not supported on switch type " . ref($this) . ". "
        . "Please let us know what hardware you are using."
    );
    return $FALSE;
}

=item supportsWirelessDot1x - Returns 1 if switch type supports Wireless 802.1X (aka WPA-Enterprise)

=cut
sub supportsWirelessDot1x {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->error(
        "Wireless 802.1X (WPA-Enterprise) is not supported on switch type " . ref($this) . ". "
        . "Please let us know what hardware you are using."
    );
    return $FALSE;
}

=item supportsRadiusVoip

=cut
sub supportsRadiusVoip {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->warn(
        "RADIUS Authentication of IP Phones is not supported on switch type " . ref($this) . ". "
        . "Please let us know what hardware you are using."
    );
    return $FALSE;
}

=item supportsRoleBasedEnforcement 

=cut
sub supportsRoleBasedEnforcement {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if (defined($this->{'_roles'}) && %{$this->{'_roles'}}) {
        $logger->warn(
            "Role-based Network Access Control is not supported on network device type " . ref($this) . ". "
        );
    }
    return $FALSE;
}

=item supportsSaveConfig

=cut
sub supportsSaveConfig {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return $FALSE;
}

=item supportsCdp

Does the network device supports Cisco Discovery Protocol (CDP)

=cut
sub supportsCdp {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return $FALSE;
}

=item supportsLldp

Does the network device supports Link-Layer Discovery Protocol (LLDP)

=cut
sub supportsLldp {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return $FALSE;
}

=item supportsRadiusDynamicVlanAssignment

=cut
sub supportsRadiusDynamicVlanAssignment { return $TRUE; }

=item inlineCapabilities

=cut

# inline capabilities
sub inlineCapabilities { return; }


sub new {
    my ( $class, %argv ) = @_;
    my $this = bless {
        '_error'                    => undef,
        '_ip'                       => undef,
        '_macSearchesMaxNb'         => undef,
        '_macSearchesSleepInterval' => undef,
        '_mode'                     => undef,
        '_sessionRead'              => undef,
        '_sessionWrite'             => undef,
        '_sessionControllerWrite'   => undef,
        '_SNMPAuthPasswordRead'     => undef,
        '_SNMPAuthPasswordTrap'     => undef,
        '_SNMPAuthPasswordWrite'    => undef,
        '_SNMPAuthProtocolRead'     => undef,
        '_SNMPAuthProtocolTrap'     => undef,
        '_SNMPAuthProtocolWrite'    => undef,
        '_SNMPCommunityRead'        => undef,
        '_SNMPCommunityTrap'        => undef,
        '_SNMPCommunityWrite'       => undef,
        '_SNMPEngineID'             => undef,
        '_SNMPPrivPasswordRead'     => undef,
        '_SNMPPrivPasswordTrap'     => undef,
        '_SNMPPrivPasswordWrite'    => undef,
        '_SNMPPrivProtocolRead'     => undef,
        '_SNMPPrivProtocolTrap'     => undef,
        '_SNMPPrivProtocolWrite'    => undef,
        '_SNMPUserNameRead'         => undef,
        '_SNMPUserNameTrap'         => undef,
        '_SNMPUserNameWrite'        => undef,
        '_SNMPVersion'              => 1,
        '_SNMPVersionTrap'          => 1,
        '_cliEnablePwd'             => undef,
        '_cliPwd'                   => undef,
        '_cliUser'                  => undef,
        '_cliTransport'             => undef,
        '_wsPwd'                    => undef,
        '_wsUser'                   => undef,
        '_wsTransport'              => undef,
        '_radiusSecret'             => undef,
        '_controllerIp'             => undef,
        '_uplink'                   => undef,
        '_vlans'                    => undef,
        '_VoIPEnabled'              => undef,
        '_roles'                    => undef,
        '_inlineTrigger'            => undef,
        '_deauthMethod'             => undef,
    }, $class;

    foreach ( keys %argv ) {
        if (/^-?SNMPCommunityRead$/i) {
            $this->{_SNMPCommunityRead} = $argv{$_};
        } elsif (/^-?SNMPCommunityTrap$/i) {
            $this->{_SNMPCommunityTrap} = $argv{$_};
        } elsif (/^-?SNMPCommunityWrite$/i) {
            $this->{_SNMPCommunityWrite} = $argv{$_};
        } elsif (/^-?ip$/i) {
            $this->{_ip} = $argv{$_};
        } elsif (/^-?macSearchesMaxNb$/i) {
            $this->{_macSearchesMaxNb} = $argv{$_};
        } elsif (/^-?macSearchesSleepInterval$/i) {
            $this->{_macSearchesSleepInterval} = $argv{$_};
        } elsif (/^-?mode$/i) {
            $this->{_mode} = $argv{$_};
        } elsif (/^-?SNMPAuthPasswordRead$/i) {
            $this->{_SNMPAuthPasswordRead} = $argv{$_};
        } elsif (/^-?SNMPAuthPasswordTrap$/i) {
            $this->{_SNMPAuthPasswordTrap} = $argv{$_};
        } elsif (/^-?SNMPAuthPasswordWrite$/i) {
            $this->{_SNMPAuthPasswordWrite} = $argv{$_};
        } elsif (/^-?SNMPAuthProtocolRead$/i) {
            $this->{_SNMPAuthProtocolRead} = $argv{$_};
        } elsif (/^-?SNMPAuthProtocolTrap$/i) {
            $this->{_SNMPAuthProtocolTrap} = $argv{$_};
        } elsif (/^-?SNMPAuthProtocolWrite$/i) {
            $this->{_SNMPAuthProtocolWrite} = $argv{$_};
        } elsif (/^-?SNMPPrivPasswordRead$/i) {
            $this->{_SNMPPrivPasswordRead} = $argv{$_};
        } elsif (/^-?SNMPPrivPasswordTrap$/i) {
            $this->{_SNMPPrivPasswordTrap} = $argv{$_};
        } elsif (/^-?SNMPPrivPasswordWrite$/i) {
            $this->{_SNMPPrivPasswordWrite} = $argv{$_};
        } elsif (/^-?SNMPPrivProtocolRead$/i) {
            $this->{_SNMPPrivProtocolRead} = $argv{$_};
        } elsif (/^-?SNMPPrivProtocolTrap$/i) {
            $this->{_SNMPPrivProtocolTrap} = $argv{$_};
        } elsif (/^-?SNMPPrivProtocolWrite$/i) {
            $this->{_SNMPPrivProtocolWrite} = $argv{$_};
        } elsif (/^-?SNMPUserNameRead$/i) {
            $this->{_SNMPUserNameRead} = $argv{$_};
        } elsif (/^-?SNMPUserNameTrap$/i) {
            $this->{_SNMPUserNameTrap} = $argv{$_};
        } elsif (/^-?SNMPUserNameWrite$/i) {
            $this->{_SNMPUserNameWrite} = $argv{$_};
        } elsif (/^-?cliEnablePwd$/i) {
            $this->{_cliEnablePwd} = $argv{$_};
        } elsif (/^-?cliPwd$/i) {
            $this->{_cliPwd} = $argv{$_};
        } elsif (/^-?cliUser$/i) {
            $this->{_cliUser} = $argv{$_};
        } elsif (/^-?cliTransport$/i) {
            $this->{_cliTransport} = $argv{$_};
        } elsif (/^-?wsPwd$/i) {
            $this->{_wsPwd} = $argv{$_};
        } elsif (/^-?wsUser$/i) {
            $this->{_wsUser} = $argv{$_};
        } elsif (/^-?wsTransport$/i) {
            $this->{_wsTransport} = lc($argv{$_});
        } elsif (/^-?radiusSecret$/i) {
            $this->{_radiusSecret} = $argv{$_};
        } elsif (/^-?controllerIp$/i) {
            $this->{_controllerIp} = $argv{$_}? lc($argv{$_}) : undef;
        } elsif (/^-?uplink$/i) {
            $this->{_uplink} = $argv{$_};
        } elsif (/^-?SNMPEngineID$/i) {
            $this->{_SNMPEngineID} = $argv{$_};
        } elsif (/^-?SNMPVersion$/i) {
            $this->{_SNMPVersion} = $argv{$_};
        } elsif (/^-?SNMPVersionTrap$/i) {
            $this->{_SNMPVersionTrap} = $argv{$_};
        } elsif (/^-?vlans$/i) {
            $this->{_vlans} = $argv{$_};
        } elsif (/^-?VoIPEnabled$/i) {
            $this->{_VoIPEnabled} = $argv{$_};
        } elsif (/^-?roles$/i) {
            $this->{_roles} = $argv{$_};
        } elsif (/^-?inlineTrigger$/i) {
            $this->{_inlineTrigger} = $argv{$_};
        } elsif (/^-?deauthMethod$/i) {
            $this->{_deauthMethod} = $argv{$_};
        }
        # customVlan members are now dynamically generated. 0 to 99 supported.
        elsif (/^-?(\w+)Vlan$/i) {
            $this->{'_'.$1.'Vlan'} = $argv{$_};
        } 

    }
    return $this;
}

=item isUpLink - determine is a given ifIndex is connected to another switch

=cut 

sub isUpLink {
    my ( $this, $ifIndex ) = @_;
    return (   ( defined( $this->{_uplink} ) )
            && ( grep( { $_ == $ifIndex } @{ $this->{_uplink} } ) == 1 ) );
}

=item connectRead - establish read connection to switch

=cut

sub connectRead {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( defined( $this->{_sessionRead} ) ) {
        return 1;
    }
    $logger->debug( "opening SNMP v"
            . $this->{_SNMPVersion}
            . " read connection to $this->{_ip}" );
    if ( $this->{_SNMPVersion} eq '3' ) {
        ( $this->{_sessionRead}, $this->{_error} ) = Net::SNMP->session(
            -hostname     => $this->{_ip},
            -version      => $this->{_SNMPVersion},
            -username     => $this->{_SNMPUserNameRead},
            -timeout      => 2,
            -retries      => 1,
            -authprotocol => $this->{_SNMPAuthProtocolRead},
            -authpassword => $this->{_SNMPAuthPasswordRead},
            -privprotocol => $this->{_SNMPPrivProtocolRead},
            -privpassword => $this->{_SNMPPrivPasswordRead}
        );
    } else {
        ( $this->{_sessionRead}, $this->{_error} ) = Net::SNMP->session(
            -hostname  => $this->{_ip},
            -version   => $this->{_SNMPVersion},
            -timeout   => 2,
            -retries   => 1,
            -community => $this->{_SNMPCommunityRead}
        );
    }
    if ( !defined( $this->{_sessionRead} ) ) {
        $logger->error( "error creating SNMP v"
                . $this->{_SNMPVersion}
                . " read connection to "
                . $this->{_ip} . ": "
                . $this->{_error} );
        return 0;
    } else {
        my $oid_sysLocation = '1.3.6.1.2.1.1.6.0';
        $logger->trace("SNMP get_request for sysLocation: $oid_sysLocation");
        my $result = $this->{_sessionRead}
            ->get_request( -varbindlist => [$oid_sysLocation] );
        if ( !defined($result) ) {
            $logger->error( "error creating SNMP v"
                    . $this->{_SNMPVersion}
                    . " read connection to "
                    . $this->{_ip} . ": "
                    . $this->{_sessionRead}->error() );
            $this->{_sessionRead} = undef;
            return 0;
        }
    }
    return 1;
}

=item disconnectRead - closing read connection to switch

=cut

sub disconnectRead {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !defined( $this->{_sessionRead} ) ) {
        return 1;
    }
    $logger->debug( "closing SNMP v" . $this->{_SNMPVersion} . " read connection to $this->{_ip}" );
    $this->{_sessionRead}->close;
    return 1;
}

=item connectWriteTo

Establishes an SNMP Write connection to a given IP and installs the session object into this object's sessionKey.
It performs a write test to make sure that the write actually works.

=cut
sub connectWriteTo {
    my ($this, $ip, $sessionKey) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # if connection already exists, no need to connect again
    return 1 if ( defined( $this->{$sessionKey} ) );

    $logger->debug( "opening SNMP v" . $this->{_SNMPVersion} . " write connection to $ip" );
    if ( $this->{_SNMPVersion} eq '3' ) {
        ( $this->{$sessionKey}, $this->{_error} ) = Net::SNMP->session(
            -hostname     => $ip,
            -version      => $this->{_SNMPVersion},
            -timeout      => 2,
            -retries      => 1,
            -username     => $this->{_SNMPUserNameWrite},
            -authprotocol => $this->{_SNMPAuthProtocolWrite},
            -authpassword => $this->{_SNMPAuthPasswordWrite},
            -privprotocol => $this->{_SNMPPrivProtocolWrite},
            -privpassword => $this->{_SNMPPrivPasswordWrite}
        );
    } else {
        ( $this->{$sessionKey}, $this->{_error} ) = Net::SNMP->session(
            -hostname  => $ip,
            -version   => $this->{_SNMPVersion},
            -timeout   => 2,
            -retries   => 1,
            -community => $this->{_SNMPCommunityWrite}
        );
    }

    if ( !defined( $this->{$sessionKey} ) ) {

        $logger->error( "error creating SNMP v" . $this->{_SNMPVersion} . " write connection to $ip: $this->{_error}" );
        return 0;

    } else {
        my $oid_sysLocation = '1.3.6.1.2.1.1.6.0';
        $logger->trace("SNMP get_request for sysLocation: $oid_sysLocation");
        my $result = $this->{$sessionKey}->get_request( -varbindlist => [$oid_sysLocation] );
        if ( !defined($result) ) {
            $logger->error(
                "error creating SNMP v" . $this->{_SNMPVersion} . " write connection to $ip: " 
                . $this->{$sessionKey}->error()
            );
            $this->{$sessionKey} = undef;
            return 0;
        } else {
            my $sysLocation = $result->{$oid_sysLocation} || '';
            $logger->trace(
                "SNMP set_request for sysLocation: $oid_sysLocation to $sysLocation"
            );
            $result = $this->{$sessionKey}->set_request(
                -varbindlist => [
                    "$oid_sysLocation", Net::SNMP::OCTET_STRING,
                    $sysLocation
                ]
            );
            if ( !defined($result) ) {
                $logger->error(
                    "error creating SNMP v" . $this->{_SNMPVersion} . " write connection to $ip: " 
                    . $this->{$sessionKey}->error()
                    . " it looks like you specified a read-only community instead of a read-write one"
                );
                $this->{$sessionKey} = undef;
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
    my $this   = shift;
    return $this->connectWriteTo($this->{_ip}, '_sessionWrite');
}

=item connectWriteToController

Establishes an SNMP write connection to the controller of the network device as defined in controllerIp.

=cut
sub connectWriteToController {
    my $this   = shift;
    return $this->connectWriteTo($this->{_controllerIp}, '_sessionControllerWrite');
}

=item disconnectWriteTo

Closes an SNMP Write connection. Requires sessionKey stored in object (as when calling connectWriteTo).

=cut
sub disconnectWriteTo {
    my ($this, $sessionKey) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    return 1 if ( !defined( $this->{$sessionKey} ) );

    $logger->debug( 
        "closing SNMP v" . $this->{_SNMPVersion} . " write connection to " . $this->{$sessionKey}->hostname()
    );

    $this->{$sessionKey}->close();
    $this->{$sessionKey} = undef;
    return 1;
}

=item disconnectWrite

Closes the default SNMP connection to the network device's IP.

=cut
sub disconnectWrite {
    my $this = shift;

    return $this->disconnectWriteTo('_sessionWrite');
}

=item disconnectWriteToController

Closes the SNMP connection to the network device's controller.

=cut
sub disconnectWriteToController {
    my $this = shift;

    return $this->disconnectWriteTo('_sessionControllerWrite');
}

=item setVlan

Set a port to a VLAN validating some rules first then calling the switch's _setVlan.

=cut

sub setVlan {
    my ($this, $ifIndex, $newVlan, $switch_locker_ref, $presentPCMac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->warn(
            "Should set ifIndex $ifIndex to VLAN $newVlan but the switch is not in production -> Do nothing"
        );
        return 1;
    }

    my $vlan = $this->getVlan($ifIndex);
    my $macDetectionVlan = $this->getVlanByName('macDetection');

    if ( !defined($presentPCMac) && ( $newVlan ne $macDetectionVlan ) ) {
        my @macArray = $this->_getMacAtIfIndex( $ifIndex, $vlan );
        if ( scalar(@macArray) == 1 ) {
            $presentPCMac = $macArray[0];
        }
    }

    #handle some exceptions

    # old VLAN is not a VLAN we manage
    if (!$this->isManagedVlan($vlan)) {
        $logger->warn("old VLAN $vlan is not a managed VLAN -> Do nothing");
        return 1;
    }

    # VLAN -1 handling
    # TODO at some point we should create a new blackhole / blacklist API 
    # it would take advantage of per-switch features
    if ($newVlan == -1) {
        $logger->warn("VLAN -1 is not supported in SNMP-Traps mode. Returning the switch's mac-detection VLAN.");
        $newVlan = $macDetectionVlan;
    }

    # unmanaged VLAN
    if (!$this->isManagedVlan($newVlan)) {   
        $logger->warn(
            "new VLAN $newVlan is not a managed VLAN -> replacing VLAN $newVlan with MAC detection VLAN "
            . $macDetectionVlan
        );
        $newVlan = $macDetectionVlan;
    }

    # VLAN are not defined on the switch
    if ( !$this->isDefinedVlan($newVlan) ) {
        if ( $newVlan == $macDetectionVlan ) {
            $logger->warn(
                "MAC detection VLAN " . $macDetectionVlan
                . " is not defined on switch " . $this->{_ip}
                . " -> Do nothing"
            );
            return 1;
        }
        $logger->warn(
            "new VLAN $newVlan is not defined on switch " . $this->{_ip}
            . " -> replacing VLAN $newVlan with MAC detection VLAN "
            . $macDetectionVlan
        );
        $newVlan = $macDetectionVlan;
        if ( !$this->isDefinedVlan($newVlan) ) {
            $logger->warn(
                "MAC detection VLAN " . $macDetectionVlan
                . " is also not defined on switch " . $this->{_ip}
                . " -> Do nothing"
            );
            return 1;
        }
    }

    #closes old locationlog entries and create a new one if required
    locationlog_synchronize($this->{_ip}, $ifIndex, $newVlan, $presentPCMac, $NO_VOIP, $WIRED_SNMP_TRAPS);

    if ( $vlan == $newVlan ) {
        $logger->info(
            "Should set " . $this->{_ip} . " ifIndex $ifIndex to VLAN $newVlan "
            . "but it is already in this VLAN -> Do nothing"
        );
        return 1;
    }

    #and finally set the VLAN
    $logger->info("setting VLAN at " . $this->{_ip} . " ifIndex $ifIndex from $vlan to $newVlan");
    return $this->_setVlan( $ifIndex, $newVlan, $vlan, $switch_locker_ref );
}

=item setVlanWithName - set the ifIndex VLAN to the VLAN name in the switch instead of vlan number

TODO: not implemented, currently only a nameholder

=cut
sub setVlanWithName {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->warn("not implemented!");
    return;
}

=item _setVlanByOnlyModifyingPvid

=cut

sub _setVlanByOnlyModifyingPvid {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';    # Q-BRIDGE-MIB
    my $result;

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $dot1dBasePort = $this->getDot1dBasePortForThisIfIndex($ifIndex);

    $logger->trace("SNMP set_request for Pvid for new VLAN");
    $result
        = $this->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_dot1qPvid.$dot1dBasePort", Net::SNMP::GAUGE32, $newVlan ]
        );
    if ( !defined($result) ) {
        $logger->error(
            "error setting Pvid: " . $this->{_sessionWrite}->error );
    }
    return ( defined($result) );
}

=item getRoleByName

Get the switch-specific role of a given global role in switches.conf

=cut
sub getRoleByName {
    my ($this, $roleName) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # skip if not defined or empty
    return if (!defined($this->{'_roles'}) || !%{$this->{'_roles'}});

    # return if found
    return $this->{'_roles'}->{$roleName} if (defined($this->{'_roles'}->{$roleName}));

    # otherwise log and return undef
    $logger->warn("Roles are configured but no role found for $roleName");
    return;
}

=item getVlanByName - get the VLAN number of a given name in switches.conf
 
Input: vlan name (as in switches.conf)

=cut                    
sub getVlanByName {
    my ($this, $vlanName) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    if (!defined($this->{'_vlans'}) || !defined($this->{'_vlans'}->{$vlanName})) {
        # VLAN name doesn't exist
        $logger->warn("VLAN $vlanName is not a valid VLAN identifier (something wrong in conf/switches.conf?)");
        return;
    }

    if ($vlanName eq "inline" && length($this->{'_vlans'}->{$vlanName}) == 0) {
        # VLAN empty, return 0 for Inline
        $logger->warn("VLAN $vlanName is empty in switches.conf.  Please ignore if your intentions were to use the native VLAN");
        return 0;
    }
    
    if ($this->{'_vlans'}->{$vlanName} !~ /^\d+$/) {
        # is not resolved to a valid VLAN number
        $logger->warn("VLAN $vlanName is not properly configured in switches.conf, not a vlan number");
        return;
    }   
    return $this->{'_vlans'}->{$vlanName};
}

=item setVlanByName - set the ifIndex VLAN to the VLAN identified by given name in switches.conf

Input: ifIndex, vlan name (as in switches.conf), switch lock

=cut
sub setVlanByName {
    my ($this, $ifIndex, $vlanName, $switch_locker_ref) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    if (!exists($this->{"_".$vlanName})) {
        # VLAN name doesn't exist
        $logger->warn("VLAN $vlanName is not a valid VLAN identifier (see switches.conf)");
        return;
    }

    if ($this->{"_".$vlanName} !~ /^\d+$/) {
        # is not resolved to a valid VLAN number
        $logger->warn("VLAN $vlanName is not properly configured in switches.conf, not a vlan number");
        return;
    }
    return $this->setVlan($ifIndex, $this->{"_".$vlanName}, $switch_locker_ref);
}

=item getIfOperStatus - obtain the ifOperStatus of the specified switch port (1 indicated up, 2 indicates down)

=cut

sub getIfOperStatus {
    my ( $this, $ifIndex ) = @_;
    my $logger           = Log::Log4perl::get_logger( ref($this) );
    my $oid_ifOperStatus = '1.3.6.1.2.1.2.2.1.8';
    if ( !$this->connectRead() ) {
        return 0;
    }
    $logger->trace(
        "SNMP get_request for ifOperStatus: $oid_ifOperStatus.$ifIndex");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$oid_ifOperStatus.$ifIndex"] );
    return $result->{"$oid_ifOperStatus.$ifIndex"};
}

=item setMacDetectionVlan - set the port VLAN to the MAC detection VLAN

=cut 

sub setMacDetectionVlan {
    my ( $this, $ifIndex, $switch_locker_ref,
        $closeAllOpenLocationlogEntries )
        = @_;
    return $this->setVlan( $ifIndex, $this->getVlanByName('macDetection'),
        $switch_locker_ref, undef, $closeAllOpenLocationlogEntries );
}

=item getAlias - get the port description

=cut

sub getAlias {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    my $OID_ifAlias = '1.3.6.1.2.1.31.1.1.1.18';
    $logger->trace("SNMP get_request for ifAlias: $OID_ifAlias.$ifIndex");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_ifAlias.$ifIndex"] );
    return $result->{"$OID_ifAlias.$ifIndex"};
}

=item getSwitchLocation - get the switch location string

=cut

sub getSwitchLocation {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return if ( !$this->connectRead() ); 

    my $OID_sysLocation = '1.3.6.1.2.1.1.6.0';
    $logger->trace("SNMP get_request for sysLocation: $OID_sysLocation");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => ["$OID_sysLocation"] );
    if ( !defined($result) ) {
        $logger->error("couldn't fetch sysLocation on $this->{_ip}: " . $this->{_sessionWrite}->error());
        return;
    }
    if (!defined($result->{"$OID_sysLocation"})) {
        $logger->error("no result for sysLocation on $this->{_ip}");
    }
    return $result->{"$OID_sysLocation"};
}
        

=item setAlias - set the port description

=cut

sub setAlias {
    my ( $this, $ifIndex, $alias ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->info( "setting "
            . $this->{_ip}
            . " ifIndex $ifIndex ifAlias from "
            . $this->getAlias($ifIndex)
            . " to $alias" );
    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't change this port ifAlias");
        return 1;
    }
    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_ifAlias = '1.3.6.1.2.1.31.1.1.1.18';
    $logger->trace(
        "SNMP set_request for ifAlias: $OID_ifAlias.$ifIndex = $alias");
    my $result = $this->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_ifAlias.$ifIndex", Net::SNMP::OCTET_STRING, $alias ] );
    return ( defined($result) );
}

=item getManagedIfIndexes - get the list of ifIndexes which are managed

=cut

sub getManagedIfIndexes {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @managedIfIndexes;
    my @tmp_managedIfIndexes;
    my $ifTypeHashRef;
    my $ifOperStatusHashRef;
    my $vlanHashRef;
    my $OID_ifType       = '1.3.6.1.2.1.2.2.1.3';
    my $OID_ifOperStatus = '1.3.6.1.2.1.2.2.1.8';

    my @UpLinks = $this->getUpLinks();    # fetch the UpLink list
    if ( !$this->connectRead() ) {
        return @managedIfIndexes;
    }

    # fetch all ifType at once
    $logger->trace("SNMP get_request for ifType: $OID_ifType");
    my $result = $this->{_sessionRead}->get_table( -baseoid => $OID_ifType );
    foreach my $key ( keys %{$result} ) {
        $key =~ /^$OID_ifType\.(\d+)$/;
        $ifTypeHashRef->{$1} = $result->{$key};
    }

    # fetch all ifOperStatus at once
    $logger->trace("SNMP get_request for ifOperStatus: $OID_ifOperStatus");
    $result
        = $this->{_sessionRead}->get_table( -baseoid => $OID_ifOperStatus );
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

    $vlanHashRef = $this->getAllVlans(@tmp_managedIfIndexes);
    foreach my $ifIndex (@tmp_managedIfIndexes) {
        my $portVlan = $vlanHashRef->{$ifIndex};
        if ( defined $portVlan ) {    # skip port with no VLAN

            if ( grep( { $_ == $portVlan } values %{ $this->{_vlans} } ) != 0 )
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
    my ($this, $vlan) = @_;

    # can I find $vlan in _vlans ?
    if (grep({$_ == $vlan} values %{$this->{_vlans}}) == 0) {
        #unmanaged VLAN
        return $FALSE;
    }
    return $TRUE;
}

=item getMode - get the mode

=cut

sub getMode {
    my ($this) = @_;
    return $this->{_mode};
}

=item isTestingMode - return True if $switch-E<gt>{_mode} eq 'testing'

=cut

sub isTestingMode {
    my ($this) = @_;
    return ( $this->getMode() eq 'testing' );
}

=item isIgnoreMode - return True if $switch-E<gt>{_mode} eq 'ignore'

=cut

sub isIgnoreMode {
    my ($this) = @_;
    return ( $this->getMode() eq 'ignore' );
}

=item isRegistrationMode - return True if $switch-E<gt>{_mode} eq 'registration'

=cut

sub isRegistrationMode {
    my ($this) = @_;
    return ( $this->getMode() eq 'registration' );
}

=item isProductionMode - return True if $switch-E<gt>{_mode} eq 'production'

=cut

sub isProductionMode {
    my ($this) = @_;
    return ( $this->getMode() eq 'production' );
}

=item isDiscoveryMode - return True if $switch-E<gt>{_mode} eq 'discovery'

=cut

sub isDiscoveryMode {
    my ($this) = @_;
    return ( $this->getMode() eq 'discovery' );
}

=item isVoIPEnabled

Default implementation returns a false value and will log a warning if user 
configured it's switches.conf to do VoIP.

=cut
sub isVoIPEnabled {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # if user set VoIPEnabled to true and we don't support it log a warning
    $logger->warn("VoIP is not supported on this network module") if ($self->{_VoIPEnabled} == $TRUE);

    return $FALSE;
}

=item setVlanAllPort - set the port VLAN for all the non-UpLink ports of a switch

=cut

sub setVlanAllPort {
    my ( $this, $vlan, $switch_locker_ref ) = @_;
    my $oid_ifType = '1.3.6.1.2.1.2.2.1.3';    # MIB: ifTypes
    my @ports;

    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->info("setting all ports of switch $this->{_ip} to VLAN $vlan");
    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't change any port VLAN");
        return 1;
    }

    if ( !$this->connectRead() ) {
        return 0;
    }

    my @managedIfIndexes = $this->getManagedIfIndexes();
    foreach my $ifIndex (@managedIfIndexes) {
        $logger->debug(
            "setting " . $this->{_ip} . " ifIndex $ifIndex to VLAN $vlan" );
        if ($vlan =~ /^\d+$/) {
            # if vlan is an integer, then assume its a vlan number
            $this->setVlan( $ifIndex, $vlan, $switch_locker_ref );
        } else {
            # otherwise its a vlan name
            $this->setVlanByName($ifIndex, $vlan, $switch_locker_ref);
        }
    }
}

=item getMacAtIfIndex - obtain list of MACs at switch ifIndex

=cut

sub getMacAtIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $i      = 0;
    my $start  = time;
    my @macArray;

    # we try to get the MAC macSearchesMaxNb times or for 2 minutes whichever comes first
    do {
        sleep($this->{_macSearchesSleepInterval}) unless ( $i == 0 );
        $logger->debug( "attempt " . ( $i + 1 ) . " to obtain mac at " . $this->{_ip} . " ifIndex $ifIndex" );
        @macArray = $this->_getMacAtIfIndex($ifIndex);
        $i++;
    } while (
        ($i < $this->{_macSearchesMaxNb}) # number of attempts smaller than this parameter
        && ((time-$start) < 120) # total time spent smaller than 120 seconds (TODO extract into parameter)
        && (scalar(@macArray) == 0) # still not found
    );

    if (scalar(@macArray) == 0) {
        if ($i >= $this->{_macSearchesMaxNb}) {
            $logger->warn("Tried to grab MAC address at ifIndex $ifIndex "
                ."on switch ".$this->{_ip}." 30 times and failed");
        } else {
            $logger->warn("Tried to grab MAC address at ifIndex $ifIndex "
                ."on switch ".$this->{_ip}." for 2 minutes and failed");
        }
    }
    return @macArray;
}

=item getSysName - return the administratively-assigned name of the switch. By convention, this is the switch's 
fully-qualified domain name
    
=cut
        
sub getSysName {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_sysName = '1.3.6.1.2.1.1.5';                     # mib-2
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysName: $OID_sysName");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$OID_sysName] );
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
    my ( $this, $ifIndex ) = @_;
    my $logger     = Log::Log4perl::get_logger( ref($this) );
    my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';                     # IF-MIB
    my $oid        = $OID_ifDesc . "." . $ifIndex;
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for ifDesc: $oid");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$oid] );
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
    my ( $this, $ifIndex ) = @_;
    my $logger     = Log::Log4perl::get_logger( ref($this) );
    my $OID_ifName = '1.3.6.1.2.1.31.1.1.1.1';                  # IF-MIB
    my $oid        = $OID_ifName . "." . $ifIndex;
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for ifName: $oid");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$oid] );
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
    my ($this)     = @_;
    my $logger     = Log::Log4perl::get_logger( ref($this) );
    my $OID_ifName = '1.3.6.1.2.1.31.1.1.1.1';                  # IF-MIB
    my %ifNameIfIndexHash;
    if ( !$this->connectRead() ) {
        return %ifNameIfIndexHash;
    }
    $logger->trace("SNMP get_request for ifName: $OID_ifName");
    my $result = $this->{_sessionRead}->get_table( -baseoid => $OID_ifName );
    foreach my $key ( keys %{$result} ) {
        $key =~ /^$OID_ifName\.(\d+)$/;
        $ifNameIfIndexHash{ $result->{$key} } = $1;
    }
    return %ifNameIfIndexHash;
}

=item setAdminStatus - shutdown or enable port

=cut

sub setAdminStatus {
    my ( $this, $ifIndex, $status ) = @_;
    my $logger            = Log::Log4perl::get_logger( ref($this) );
    my $OID_ifAdminStatus = '1.3.6.1.2.1.2.2.1.7';

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port ifAdminStatus");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }
    $logger->trace( "SNMP set_request for ifAdminStatus: $OID_ifAdminStatus.$ifIndex = $status" );
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_ifAdminStatus.$ifIndex", Net::SNMP::INTEGER, $status ]
    );
    return ( defined($result) );
}

=item bouncePort

Performs a shut / no-shut on the port. 
Usually used to force the operating system to do a new DHCP Request after a VLAN change.

=cut
sub bouncePort {
    my ($this, $ifIndex) = @_;

    $this->setAdminStatus( $ifIndex, $SNMP::DOWN );
    sleep($Config{'vlan'}{'bounce_duration'});
    $this->setAdminStatus( $ifIndex, $SNMP::UP );

    return $TRUE;
}

sub isLearntTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub isRemovedTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub isPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    return ( 0 == 1 );
}

=item setPortSecurityEnableByIfIndex

Will disable or enable port-security on a given ifIndex based on the $trueFalse value provided. 
$TRUE will enable, $FALSE will disable.

This version here is a fallback stub, provide your implementation in a switch module.

=cut
sub setPortSecurityEnableByIfIndex {
    my ( $this, $ifIndex, $trueFalse ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->error("Function not implemented for switch type " . ref($this));
    return ( 0 == 1 );
}

sub setPortSecurityMaxSecureMacAddrByIfIndex {
    my ( $this, $ifIndex, $maxSecureMac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->error("Function not implemented for switch type " . ref($this));
    return ( 0 == 1 );
}

sub setPortSecurityViolationActionByIfIndex {
    my ( $this, $ifIndex, $action ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->error("Function not implemented for switch type " . ref($this));
    return ( 0 == 1 );
}

=item enablePortSecurityByIfIndex

Unless you require something more complex, this is usually a wrapper to setPortSecurityEnableByIfIndex($ifIndex, $TRUE)

=cut
sub enablePortSecurityByIfIndex {
    my ( $this, $ifIndex ) = @_;

    return $this->setPortSecurityEnableByIfIndex($ifIndex, $TRUE);
}

=item disablePortSecurityByIfIndex

Unless you require something more complex, this is usually a wrapper to setPortSecurityEnableByIfIndex($ifIndex, $FALSE)

=cut
sub disablePortSecurityByIfIndex {
    my ( $this, $ifIndex ) = @_;

    return $this->setPortSecurityEnableByIfIndex($ifIndex, $FALSE);
}

sub setModeTrunk {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->error("Function not implemented for switch type " . ref($this));
    return ( 0 == 1 );
}   

sub setTaggedVlans {
    my ( $this, $ifIndex, $taggedVlans ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->error("Function not implemented for switch type " . ref($this));
    return ( 0 == 1 );
}   

sub removeAllTaggedVlans {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->error("Function not implemented for switch type " . ref($this));
    return ( 0 == 1 );
}   

sub isTrunkPort {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->debug("Unimplemented. Are you sure you are using the right switch module? Switch type: " . ref($this));
    return ( 0 == 1 );
}

sub isDynamicPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub isStaticPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    return ( 0 == 1 );
}

=item getPhonesDPAtIfIndex

Obtain phones from discovery protocol at ifIndex.

Polls from all supported sources and will filter out duplicates.

=cut
# TODO one day, with Moose roles, the CDP / LLDP role will require the proper
# implementations of getPhonesCDPAtIfIndex / getPhonesLLDPAtIfIndex
sub getPhonesDPAtIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on network device $this->{_ip}: no phones returned" );
        return;
    }

    my @phones = ();
    # CDP
    if ($this->supportsCdp()) {
        push @phones, $this->getPhonesCDPAtIfIndex($ifIndex);
    }

    # LLDP
    if ($this->supportsLldp()) {
        push @phones, $this->getPhonesLLDPAtIfIndex($ifIndex);
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
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch " . $this->{_ip} );
        return 0;
    }

    my @macArray = $this->_getMacAtIfIndex( $ifIndex, $this->getVoiceVlan($ifIndex) );
    foreach my $mac (@macArray) {

        if ($this->isPhoneAtIfIndex($mac, $ifIndex)) {
            return 1;
        }
    }

    $logger->info(
        "determining through discovery protocols if "
        . $this->{_ip} . " ifIndex $ifIndex has VoIP phone connected"
    );
    return ( scalar( $this->getPhonesDPAtIfIndex($ifIndex) ) > 0 );
}

sub isPhoneAtIfIndex {
    my ( $this, $mac, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch " . $this->{_ip} );
        return 0;
    }
    if ( $this->isFakeVoIPMac($mac) ) {
        $logger->debug("MAC $mac is fake VoIP MAC");
        return 1;
    }
    if ( $this->isFakeMac($mac) ) {
        $logger->debug("MAC $mac is fake MAC");
        return 0;
    }
    $logger->trace("determining DHCP fingerprint info for $mac");
    my $node_info = node_attributes_with_fingerprint($mac);

    if (defined($node_info->{'voip'}) && $node_info->{'voip'} eq $VOIP) {
        $logger->debug("This is a VoIP phone according to node.voip");
        return 1;
    }

    if (defined($node_info->{dhcp_fingerprint}) && $node_info->{dhcp_fingerprint} =~ /VoIP Phone/) {
        $logger->debug("DHCP fingerprint for $mac indicates VoIP phone");
        return 1;
    }

    #unknown DHCP fingerprint or no DHCP fingerprint
    if (defined($node_info->{dhcp_fingerprint}) && $node_info->{dhcp_fingerprint} ne ' ') {
        $logger->debug(
            "DHCP fingerprint for $mac indicates " .$node_info->{dhcp_fingerprint}. ". This is not a VoIP phone"
        );
    }

    if (defined($ifIndex)) {
        $logger->debug("determining if $mac is VoIP phone through discovery protocols");
        my @phones = $this->getPhonesDPAtIfIndex($ifIndex);
        return ( grep( { lc($_) eq lc($mac) } @phones ) != 0 );
    } else {
        return 0;
    }
}

sub getMinOSVersion {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return -1;
}

sub getMaxMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return -1;
}

sub getSecureMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $secureMacAddrHashRef = {};
    my $logger               = Log::Log4perl::get_logger( ref($this) );
    return $secureMacAddrHashRef;
}

sub getAllSecureMacAddresses {
    my ($this)               = @_;
    my $logger               = Log::Log4perl::get_logger( ref($this) );
    my $secureMacAddrHashRef = {};
    return $secureMacAddrHashRef;
}

sub authorizeMAC {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return 1;
}

sub _authorizeMAC {
    my ( $this, $ifIndex, $mac, $authorize, $vlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
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
    my ($this, $ifIndex, $newVlan, $oldVlan) = @_;

    return $this->_authorizeCurrentMacWithNewVlan($ifIndex, $newVlan, $oldVlan);
}


=item _authorizeCurrentMacWithNewVlan

Actual implementation of authorizeCurrentMacWithNewVlan

=cut
sub _authorizeCurrentMacWithNewVlan {
    my ($this, $ifIndex, $newVlan, $oldVlan) = @_;

    my $secureTableHashRef = $this->getSecureMacAddresses($ifIndex);

    # hash is valid and has one MAC
    my $valid = (ref($secureTableHashRef) eq 'HASH');
    my $mac_count = scalar(keys %{$secureTableHashRef});
    if ($valid && $mac_count == 1) {

        # normal case
        # grab MAC
        my $mac = (keys %{$secureTableHashRef})[0];
        $this->authorizeMAC($ifIndex, $mac, $mac, $oldVlan, $newVlan);
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
                    $this->authorizeMAC($ifIndex, $mac, $mac, $oldVlan, $newVlan);
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
    my ( $this, @list ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

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
   my ($this, $bitStream, $position) = @_;
   return substr(unpack('B*', $bitStream), $position, 1);
}

=item modifyBitmask

Replaces the specified bit in a packed bitmask and returns the modified bitmask, re-packed

=cut
# TODO move out to a util package
sub modifyBitmask {
    my ( $this, $bitMask, $offset, $replacement ) = @_;
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
    my ( $this, $bitMask, $replacement, @bitsToFlip ) = @_;
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
    my ($this, $position) = @_;
    
    # output zeros up to position -1 and put a 1 in position
    my $numZeros = $position - 1;
    return pack("B*",0 x $numZeros . 1);
}

=item reverseBitmask - reverses all the bits (0 to 1, 1 to 0) from a packed bitmask and returns this new bitmask re-packed

Works on byte blocks since perl's bitewise not operates at the arithmetic level and some hardware have so many ports that I could overflow integers.

=cut
# TODO move out to a util package
sub reverseBitmask {
    my ($this, $bitMask) = @_;

    # reverse byte chunks since we don't know if input will be an int too large
    my $flippedBitMask = "";
    for (my $i = 0; $i < length($bitMask); $i++) {

       # chop string; convert string to byte; bitewise not (arithmetic); convert number to byte (& 255 avoids a warning)
       $flippedBitMask .= pack("C", ~ unpack("C", substr($bitMask,$i,$i+1)) & 255);
    }

    return $flippedBitMask;
}

=item getSysUptime - returns the sysUpTime

=cut

sub getSysUptime {
    my ($this)        = @_;
    my $logger        = Log::Log4perl::get_logger( ref($this) );
    my $oid_sysUptime = '1.3.6.1.2.1.1.3.0';
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysUptime: $oid_sysUptime");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => [$oid_sysUptime] );
    return $result->{$oid_sysUptime};
}

=item getIfType - return the ifType

=cut

sub getIfType {
    my ( $this, $ifIndex ) = @_;
    my $logger     = Log::Log4perl::get_logger( ref($this) );
    my $OID_ifType = '1.3.6.1.2.1.2.2.1.3';                     #IF-MIB
    if ( !$this->connectRead() ) {
        return 0;
    }
    $logger->trace("SNMP get_request for ifType: $OID_ifType.$ifIndex");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_ifType.$ifIndex"] );
    return $result->{"$OID_ifType.$ifIndex"};
}

=item _getMacAtIfIndex - returns the list of MACs

=cut

sub _getMacAtIfIndex {
    my ( $this, $ifIndex, $vlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @macArray;
    if ( !$this->connectRead() ) {
        return @macArray;
    }
    if ( !defined($vlan) ) {
        $vlan = $this->getVlan($ifIndex);
    }
    my %macBridgePortHash = $this->getMacBridgePortHash($vlan);
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
    my ( $this, @ifIndexes ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !@ifIndexes ) {
        @ifIndexes = $this->getManagedIfIndexes();
    }
    my $dot1dBasePortHashRef;
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB
    if ( !$this->connectRead() ) {
        return $dot1dBasePortHashRef;
    }
    $logger->trace(
        "SNMP get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
    my $result = $this->{_sessionRead}
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
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB
    my $dot1dBasePort            = undef;
    if ( !$this->connectRead() ) {
        return $dot1dBasePort;
    }
    $logger->trace(
        "SNMP get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
    my $result = $this->{_sessionRead}
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
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $ifDescHashRef;
    my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';    # IF-MIB

    if ( !$this->connectRead() ) {
        return $ifDescHashRef;
    }

    $logger->trace("SNMP get_table for ifDesc: $OID_ifDesc");
    my $result = $this->{_sessionRead}->get_table( -baseoid => $OID_ifDesc );
    foreach my $key ( keys %{$result} ) {
        my $ifDesc = $result->{$key};
        $key =~ /^$OID_ifDesc\.(\d+)$/;
        my $ifIndex = $1;
        $ifDescHashRef->{$ifIndex} = $ifDesc;
    }
    return $ifDescHashRef;
}

sub getAllIfType {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $ifTypeHashRef;
    my $OID_ifType = '1.3.6.1.2.1.2.2.1.3';

    if ( !$this->connectRead() ) {
        return $ifTypeHashRef;
    }

    $logger->trace("SNMP get_table for ifType: $OID_ifType");
    my $result = $this->{_sessionRead}->get_table( -baseoid => $OID_ifType );
    foreach my $key ( keys %{$result} ) {
        my $ifType = $result->{$key};
        $key =~ /^$OID_ifType\.(\d+)$/;
        my $ifIndex = $1;
        $ifTypeHashRef->{$ifIndex} = $ifType;
    }
    return $ifTypeHashRef;
}

sub getAllVlans {
    my ( $this, @ifIndexes ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $vlanHashRef;
    if ( !@ifIndexes ) {
        @ifIndexes = $this->getManagedIfIndexes();
    }

    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';    # Q-BRIDGE-MIB
    if ( !$this->connectRead() ) {
        return $vlanHashRef;
    }
    my $dot1dBasePortHashRef = $this->getAllDot1dBasePorts(@ifIndexes);

    $logger->trace("SNMP get_request for dot1qPvid: $OID_dot1qPvid");
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $OID_dot1qPvid );
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
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( $this->isVoIPEnabled() ) {
        $logger->error("function is NOT implemented");
        return -1;
    }
    return -1;
}

=item getVlan - returns the port PVID

=cut

sub getVlan {
    my ( $this, $ifIndex ) = @_;
    my $logger        = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';           # Q-BRIDGE-MIB
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $dot1dBasePort = $this->getDot1dBasePortForThisIfIndex($ifIndex);
    if ( !defined($dot1dBasePort) ) {
        return '';
    }

    $logger->trace(
        "SNMP get_request for dot1qPvid: $OID_dot1qPvid.$dot1dBasePort");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_dot1qPvid.$dot1dBasePort"] );
    return $result->{"$OID_dot1qPvid.$dot1dBasePort"};
}

=item getVlans - returns the VLAN ID - name mapping

=cut

sub getVlans {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1qVlanStaticName = '1.3.6.1.2.1.17.7.1.4.3.1.1';  #Q-BRIDGE-MIB
    my $vlans                   = {};
    if ( !$this->connectRead() ) {
        return $vlans;
    }

    $logger->trace(
        "SNMP get_table for dot1qVlanStaticName: $OID_dot1qVlanStaticName");
    my $result = $this->{_sessionRead}
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
    my ( $this, $vlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1qVlanStaticName = '1.3.6.1.2.1.17.7.1.4.3.1.1';  #Q-BRIDGE-MIB
    if ( !$this->connectRead() ) {
        return 0;
    }

    $logger->trace(
        "SNMP get_request for dot1qVlanStaticName: $OID_dot1qVlanStaticName.$vlan"
    );
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_dot1qVlanStaticName.$vlan"] );

    return (
               defined($result)
            && exists( $result->{"$OID_dot1qVlanStaticName.$vlan"} )
            && (
            $result->{"$OID_dot1qVlanStaticName.$vlan"} ne 'noSuchInstance' )
    );
}

sub getMacBridgePortHash {
    my $this   = shift;
    my $vlan   = shift || '';
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1qTpFdbPort = '1.3.6.1.2.1.17.7.1.2.2.1.2';    #Q-BRIDGE-MIB
    my %macBridgePortHash  = ();
    if ( !$this->connectRead() ) {
        return %macBridgePortHash;
    }
    $logger->trace("SNMP get_table for dot1qTpFdbPort: $OID_dot1qTpFdbPort");
    my $result;

    my $vlanFdbId = 0;
    if ( $vlan eq '' ) {
        $result = $this->{_sessionRead}
            ->get_table( -baseoid => $OID_dot1qTpFdbPort );
    } else {
        $vlanFdbId = $this->getVlanFdbId($vlan);
        $result    = $this->{_sessionRead}
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
    my $this              = shift;
    my $logger            = Log::Log4perl::get_logger( ref($this) );
    my @upLinks           = $this->getUpLinks();
    my $hubPorts          = {};
    my %macBridgePortHash = $this->getMacBridgePortHash();
    foreach my $mac ( keys %macBridgePortHash ) {
        my $ifIndex = $macBridgePortHash{$mac};
        if ( $ifIndex != 0 ) {

            # A value of '0' indicates that the port number has not
            # been learned but that the device does have some
            # forwarding/filtering information about this address
            # (e.g. in the dot1qStaticUnicastTable).
            if ( grep( { $_ == $ifIndex } @upLinks ) == 0 ) {

                # the port is not a upLink
                my $portVlan = $this->getVlan($ifIndex);
                if ( grep( { $_ == $portVlan } values %{ $this->{_vlans} } ) != 0 ) {

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
    my ( $this, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_mac = mac2oid($mac);

    if (!defined($oid_mac)) {
        $logger->warn("invalid MAC, not running request");
        return -1;
    }
    if ( !$this->connectRead() ) {
        return -1;
    }

    my $oid_dot1qTpFdbPort = '1.3.6.1.2.1.17.7.1.2.2.1.2'; #Q-BRIDGE-MIB
    foreach my $vlan ( values %{ $this->{_vlans} } ) {
        my $oid = "$oid_dot1qTpFdbPort.$vlan.$oid_mac";
        $logger->trace("SNMP get_request for $oid");
        my $result
            = $this->{_sessionRead}->get_request( -varbindlist => [$oid] );
        if ( ( defined($result) ) && ( !$this->isUpLink( $result->{$oid} ) ) )
        {
            return $result->{$oid};
        }
    }
    return -1;
}

# TODO: unclear method contract
sub getVmVlanType {
    my ( $this, $ifIndex ) = @_;
    return 1;
}

# TODO: unclear method contract
sub setVmVlanType {
    my ( $this, $ifIndex, $type ) = @_;
    return 1;
}

sub getMacAddrVlan {
    my $this    = shift;
    my @upLinks = $this->getUpLinks();
    my %ifIndexMac;
    my %macVlan;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_dot1qTpFdbPort = '1.3.6.1.2.1.17.7.1.2.2.1.2';    #Q-BRIDGE-MIB
    if ( !$this->connectRead() ) {
        return %macVlan;
    }
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $OID_dot1qTpFdbPort );

    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            if ( grep( { $_ == $result->{$key} } @upLinks ) == 0 ) {
                my $portVlan = $this->getVlan( $result->{$key} );
                if ( grep( { $_ == $portVlan } values %{ $this->{_vlans} } ) != 0 )
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
                "ALERT: There is a hub on switch $this->{'_ip'} port $ifIndex. We found $macCount MACs on this port !"
            );
        }
    }
    $logger->debug("Show VLAN and port for every MACs (dumper):");
    $logger->debug( Dumper(%macVlan) );

    return %macVlan;
}

sub getAllMacs {
    my ( $this, @ifIndexes ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !@ifIndexes ) {
        @ifIndexes = $this->getManagedIfIndexes();
    }
    my $ifIndexVlanMacHashRef;

    my $OID_dot1qTpFdbPort = '1.3.6.1.2.1.17.7.1.2.2.1.2';    #Q-BRIDGE-MIB
    if ( !$this->connectRead() ) {
        return $ifIndexVlanMacHashRef;
    }
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $OID_dot1qTpFdbPort );

    my @vlansToConsider = values %{ $this->{_vlans} };
    if ( $this->isVoIPEnabled() ) {
        my $voiceVlan = $this->getVlanByName('voice');
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
    my ( $this, @ifIndexes ) = @_;
    my $logger          = Log::Log4perl::get_logger( ref($this) );
    my $oid_ifInOctets  = '1.3.6.1.2.1.2.2.1.10';
    my $oid_ifOutOctets = '1.3.6.1.2.1.2.2.1.16';
    my $ifOctetsHashRef;
    if ( !$this->connectRead() ) {
        return $ifOctetsHashRef;
    }
    if ( !@ifIndexes ) {
        @ifIndexes = $this->getManagedIfIndexes();
    }

    $logger->trace("SNMP get_table for ifInOctets $oid_ifInOctets");
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $oid_ifInOctets );
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
        = $this->{_sessionRead}->get_table( -baseoid => $oid_ifOutOctets );
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
    my ( $this, $versionToCompareToString ) = @_;
    my $currentVersion          = $this->getVersion();
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
    my ($this, $is_voice_vlan, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

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
    my ( $this, $mac ) = @_;
    return ( $mac =~ /^02:00:00/ );
}

# TODO move out to a util package
sub isFakeVoIPMac {
    my ( $this, $mac ) = @_;
    return ( $mac =~ /^02:00:01/ );
}

=item  getUpLinks - get the list of port marked as uplink in configuration

Returns an array of port ifIndex or -1 on failure

=cut

sub getUpLinks {
    my ($this) = @_;
    my @upLinks;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( lc(@{ $this->{_uplink} }[0]) eq 'dynamic' ) {
        $logger->warn( "Warning: for switch "
                . $this->{_ip}
                . ", 'uplink = Dynamic' in config file but this is not supported !"
        );
        return -1;
    } else {
        @upLinks = @{ $this->{_uplink} };
    }
    return @upLinks;
}

# TODO: what the hell is this supposed to do?
sub getVlanFdbId {
    my ( $this, $vlan ) = @_;
    my $OID_dot1qVlanFdbId = '1.3.6.1.2.1.17.7.1.4.2.1.3.0';    #Q-BRIDGE-MIB
    my $logger = Log::Log4perl::get_logger( ref($this) );

    return $vlan;
}

sub isIfLinkUpDownTrapEnable { 
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_ifLinkUpDownTrapEnable = '1.3.6.1.2.1.31.1.1.1.14'; # from IF-MIB
    $logger->trace("SNMP get_request for ifLinkUpDownTrapEnable: $OID_ifLinkUpDownTrapEnable"); 
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [ "$OID_ifLinkUpDownTrapEnable.$ifIndex" ] );
    return ( exists( $result->{"$OID_ifLinkUpDownTrapEnable.$ifIndex"} )
                && ( $result->{"$OID_ifLinkUpDownTrapEnable.$ifIndex"} ne 'noSuchInstance' )
                && ( $result->{"$OID_ifLinkUpDownTrapEnable.$ifIndex"} == 1 ) );
}       

sub setIfLinkUpDownTrapEnable {
    my ( $this, $ifIndex, $enable ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port ifLinkUpDownTrapEnable");
        return 1;
    }   

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $OID_ifLinkUpDownTrapEnable = '1.3.6.1.2.1.31.1.1.1.14'; # from IF-MIB
    my $truthValue = $enable ? $SNMP::TRUE : $SNMP::FALSE;

    $logger->trace("SNMP set_request for ifLinkUpDownTrapEnable: $OID_ifLinkUpDownTrapEnable");
    my $result = $this->{_sessionWrite}->set_request( -varbindlist => [ 
        "$OID_ifLinkUpDownTrapEnable.$ifIndex", Net::SNMP::INTEGER, $truthValue
    ]);

    return ( defined($result) );
}

=item disableIfLinkUpDownTraps

Disables LinkUp / LinkDown SNMP traps on a given ifIndex

=cut
sub disableIfLinkUpDownTraps {
    my ($this, $ifIndex) = @_;

    return $this->setIfLinkUpDownTrapEnable($ifIndex, $FALSE);
}

=item enableIfLinkUpDownTraps

Enables LinkUp / LinkDown SNMP traps on a given ifIndex

=cut
sub enableIfLinkUpDownTraps {
    my ($this, $ifIndex) = @_;

    return $this->setIfLinkUpDownTrapEnable($ifIndex, $TRUE);
}

=item deauthenticateMac - performs wireless deauthentication

mac - mac address to deauthenticate

is_dot1x - set to 1 if special dot1x de-authentication is required

=cut
sub deauthenticateMac {
    my ($this, $mac, $is_dot1x) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    my ($switchdeauthMethod, $deauthTechniques) = $this->deauthTechniques($this->{_deauthMethod});
    $deauthTechniques->($this,$mac);
}

=item dot1xPortReauthenticate

Forces 802.1x re-authentication of a given ifIndex

ifIndex - ifIndex to force re-authentication on

=cut
sub dot1xPortReauthenticate {
    my ($this, $ifIndex) = @_;

    return $this->_dot1xPortReauthenticate($ifIndex);
}

=item _dot1xPortReauthenticate

Actual implementation. 
Allows callers to refer to this implementation even though someone along the way override the above call.

=cut
sub _dot1xPortReauthenticate {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    $logger->info("Trying generic MIB to force 802.1x port re-authentication. Your mileage may vary. "
        . "If it doesn't work open a bug report with your hardware type.");
 
    my $oid_dot1xPaePortReauthenticate = "1.0.8802.1.1.1.1.1.2.1.5"; # from IEEE8021-PAE-MIB

    if (!$this->connectWrite()) {
        return 0;
    }

    $logger->trace("SNMP set_request force dot1xPaePortReauthenticate on ifIndex: $ifIndex");
    my $result = $this->{_sessionWrite}->set_request(-varbindlist => [
        "$oid_dot1xPaePortReauthenticate.$ifIndex", Net::SNMP::INTEGER, 1
    ]);

    if (!defined($result)) {
        $logger->error("got an SNMP error trying to force 802.1x re-authentication: ".$this->{_sessionWrite}->error);
    }

    return (defined($result));
}

=item NasPortToIfIndex 

Translate RADIUS NAS-Port into the physical port ifIndex

Default fallback implementation: we just return the NAS-Port as ifIndex.

=cut
sub NasPortToIfIndex {
    my ($this, $nas_port) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    $logger->trace("Fallback implementation. Returning NAS-Port as ifIndex: $nas_port");
    return $nas_port;
}

=item handleReAssignVlanTrapForWiredMacAuth

Called when a ReAssignVlan trap is received for a switch-port in Wired MAC Authentication.

Default behavior is to bounce the port 

=cut
sub handleReAssignVlanTrapForWiredMacAuth {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # TODO extract that behavior in a method call in pf::vlan so it can be overridden easily

    $logger->warn("Until CoA is implemented we will bounce the port on VLAN re-assignment traps for MAC-Auth");

    # TODO perform CoA instead (when implemented)
    # actually once CoA will be implemented, we should consider offering the same option to users
    # as we currently do with port-security and VoIP which is bounce or not bounce and suffer consequences
    # this should be a choice exposed in configuration and not hidden in code
    $this->bouncePort($ifIndex);
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
    my ($this, $radius_request) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

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
        "Unable to extract SSID for module " . ref($this) . ". SSID-based VLAN assignments won't work. "
        . "Please let us know so we can add support for it."
    );
    return;
}


=item getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut
sub getVoipVsa {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    $logger->warn(
        "No RADIUS Vendor Specific Attributes (VSA) for module " . ref($this) . ". "
        . "Phone will not be allowed on the correct untagged VLAN."
    );
    return;
}

=item enablePortConfigAsTrunk - sets port as multi-Vlan port

=cut
sub enablePortConfigAsTrunk {
    my ($this, $mac, $switch_port, $switch_locker_ref, $taggedVlans)  = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # switchport mode trunk
    $logger->info("Setting port $switch_port as trunk.");
    if (! $this->setModeTrunk($switch_port, $TRUE)) {
        $logger->error("An error occured while enabling port $switch_port as multi-vlan (trunk)");
    }

    # switchport trunk allowed vlan x,y,z
    $logger->info("Allowing tagged Vlans on port $switch_port");
    if (! $this->setTaggedVlans($switch_port, $switch_locker_ref, split(",", $taggedVlans)) ) {
        $logger->error("An error occured while allowing tagged Vlans on trunk port $switch_port");
    }

    return 1;
}

=item disablePortConfigAsTrunk - sets port as non multi-Vlan port

=cut
sub disablePortConfigAsTrunk {
    my ($this, $switch_port, $switch_locker_ref) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # switchport mode access
    $logger->info("Setting port $switch_port as non trunk.");
    if (! $this->setModeTrunk($switch_port, $FALSE)) {
        $logger->error("An error occured while disabling port $switch_port as multi-vlan (trunk)");
    }

    # no switchport trunk allowed vlan
    # this setting is not necessary but we thought it would ease the reading of the port configuration if we remove
    # all the tagged vlan when they are not in use (port no longer trunk)
    $logger->info("Disabling tagged Vlans on port $switch_port");
    if (! $this->removeAllTaggedVlans($switch_port, $switch_locker_ref)) {
        $logger->warn("An minor issue occured while disabling tagged Vlans on trunk port $switch_port " .
                      "but the port should work.");
    }

    return 1;
}

=item getDeauthSnmpConnectionKey

Handles if deauthentication should be performed against controller or actual network device. 
Performs the actual SNMP Write connection and returns sessionWrite hash key to use.

See L<pf::SNMP::Dlink::DWS_3026> for a usage example.

=cut
sub getDeauthSnmpConnectionKey {
    my $this = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if (defined($this->{_controllerIp}) && $this->{_controllerIp} ne '') {

        $logger->info("controllerIp is set, we will use controller $this->{_controllerIp} to perform deauth");
        return if ( !$this->connectWriteToController() );
        return '_sessionControllerWrite';
    } else {
        return if ( !$this->connectWrite() );
        return '_sessionWrite';
    }
}

=item radiusDisconnect

Sends a RADIUS Disconnect-Request to the NAS with the MAC as the Calling-Station-Id to disconnect.

Optionally you can provide other attributes as an hashref.

Uses L<pf::util::radius> for the low-level RADIUS stuff.

=cut
# TODO consider whether we should handle retries or not?
sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS Disconnect-Request on $self->{'_ip'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating $mac");

    # Where should we send the RADIUS Disconnect-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'} 
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'}, 
            LocalAddr => $management_network->tag('vip'),
        };

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

    return $TRUE if ($response->{'Code'} eq 'Disconnect-ACK');
    
    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Default implementation.

=cut
sub returnRadiusAccessAccept {
    my ($self, $vlan, $mac, $port, $connection_type, $user_name, $ssid, $wasInline) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # Inline Vs. VLAN enforcement
    my $radius_reply_ref = {};

    if (!$wasInline || ($wasInline && $vlan != 0)) {
        $radius_reply_ref = {
            'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
            'Tunnel-Type' => $RADIUS::VLAN,
            'Tunnel-Private-Group-ID' => $vlan,
        };
    }

    # TODO this is experimental
    try {
        if ($self->supportsRoleBasedEnforcement()) {
            $logger->debug("network device supports roles. Evaluating role to be returned");
            my $roleResolver = pf::roles::custom->instance();
            my $role = $roleResolver->getRoleForNode($mac, $self);
            if (defined($role)) {
                $radius_reply_ref->{$self->returnRoleAttribute()} = $role;
                $logger->info(
                    "Added role $role to the returned RADIUS Access-Accept under attribute " . $self->returnRoleAttribute()
                );
            }
            else {
                $logger->debug("received undefined role. No Role added to RADIUS Access-Accept");
            }
        }
    }
    catch {
        chomp($_);
        $logger->debug(
            "Exception when trying to resolve a Role for the node. No Role added to RADIUS Access-Accept. "
            . "Exception: $_"
        );
    };

    $logger->info("Returning ACCEPT with VLAN: $vlan");
    return [$RADIUS::RLM_MODULE_OK, %$radius_reply_ref];
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($this, $method) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $default = $SNMP::DEFAULT;
    my %tech = (
        $SNMP::DEFAULT => \&deauthenticateMacDefault,
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
    my ( $this ) = @_;

    my %tech = (
        'Default' => \&$this->deauthenticateMacDefault,
    );
    return %tech;
}

=item deauthenticateMacDefault

return Default Deauthentication Default technique

=cut
sub deauthenticateMacDefault {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->warn("Unimplemented! First, make sure your configuration is ok. "
        . "If it is then we don't support your hardware. Open a bug report with your hardware type.");
    return $FALSE;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
