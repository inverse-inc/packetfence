package pf::Switch::LG;

=head1 NAME

pf::Switch::LG - Object oriented module to access and configure enabled LG-Ericsson switches.

=head1 STATUS

=over

=item Link UP / DOWN

- Supported using operating code version 1.2.3.2 with links UP/DOWN traps enabled.

=item Port-security

- Supported using operating code version 1.2.3.2 with authentication traps enabled.

- VoIP configuration not tested.

=item MAC-Authentication / 802.1X

- The hardware support it.

=back

=head1 BUGS AND LIMITATIONS

=over

=item Link UP / DOWN

- Seems to have a firmware bug that doesn't send traps on interfaces down.

=item Port-security

- The three port security statements (port security, port security max-mac-count, port security action)
are required on each port security enabled ports for the switch to correctly handle the feature. Make sure that
the "port security" statement is correctly enabled using the recommandation in the "Network devices guide". If not
correctly enabled, the method isPortSecurityEnabled can't return a good value and the switch sets the device MAC address
to learn rather than static.

=item Stack

- Stack configuration not tested.

=back

=cut

use strict;
use warnings;

use base ('pf::Switch');

use POSIX;
use Net::SNMP;

use pf::constants;
use pf::config qw(
    $MAC
    $PORT
);
use pf::Switch::constants;
use pf::util;

# CAPABILITIES
# access technology supported
sub supportsSnmpTraps { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
sub supportsWiredMacAuth { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }

=head1 SUBROUTINES

This list is incomplete.

=over

=cut


sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;

    # link up/down
    if ( $trapString =~
            /BEGIN\ VARIABLEBINDINGS\ [^|]+[|]\.
            1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0               # SNMP notification
            \ =\ OID:\ \.
            1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])             # link UP(4) DOWN(3) trap
            \|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.([0-9]+)    # ifIndex
            /x ) {
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;

    # secure MAC violation
    } elsif ( $trapString =~
            /BEGIN\ VARIABLEBINDINGS\ [^|]+[|]\.
            1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0                               # SNMP notification
            \ =\ OID:\
            \.1\.3\.6\.1\.4\.1\.572\.17389\.14500\.2\.1\.0\.36            # secure MAC violation trap
            \|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.[0-9]+\ =\
            INTEGER:\ ([0-9]+)                                            # ifIndex
            \|\.1\.3\.6\.1\.4\.1\.572\.17389\.14500\.1\.14\.2\.29\.0\ =\
            $SNMP::MAC_ADDRESS_FORMAT                                     # MAC Address
            /x ) {
        $trapHashRef -> {'trapType'} = 'secureMacAddrViolation';
        $trapHashRef -> {'trapIfIndex'} = $1;
        $trapHashRef -> {'trapMac'} = parse_mac_from_trap($2);
        $trapHashRef -> {'trapVlan'} = $self->getVlan( $trapHashRef->{'trapIfIndex'} );

    # unhandled traps
    } else {
        $logger->debug("trap currently no handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }

    return $trapHashRef;
}


sub getVersion {
    my ( $self ) = @_;
    my $logger = $self->logger;

    my $OID_swProdVersion = '1.3.6.1.4.1.572.17389.14500.1.1.5.4.0';    # iPECS_ES-4500G MIB

    if ( !$self->connectRead() ) {
        return '';
    }

    # Get switch firmware version
    $logger->trace(
        "SNMP get_request for OID_swProdVersion: $OID_swProdVersion"
    );
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$OID_swProdVersion] );

    return ( $result->{$OID_swProdVersion} || '' );
}


sub isPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    my $OID_portSecPortStatus = '1.3.6.1.4.1.572.17389.14500.1.17.2.1.1.2';    # iPECS_ES-4500G MIB

    if ( !$self->connectRead() ) {
        return 0;
    }

    $logger->trace("SNMP get_request for OID_portSecPortStatus: $OID_portSecPortStatus.$ifIndex");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [ "$OID_portSecPortStatus.$ifIndex" ] );
    return ( exists(
             $result->{"$OID_portSecPortStatus.$ifIndex"} )
        && ( $result->{"$OID_portSecPortStatus.$ifIndex"} ne 'noSuchInstance' )
        && ( $result->{"$OID_portSecPortStatus.$ifIndex"} ne 'noSuchObject' )
        && ( $result->{"$OID_portSecPortStatus.$ifIndex"} == 1 ) );
}


sub authorizeMAC {
    my ( $self, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = $self->logger;

    my $OID_dot1qStaticUnicastStatus = '1.3.6.1.2.1.17.7.1.3.1.1.4';           # Q-BRIDGE MIB
    my $OID_dot1qStaticUnicastAllowedToGoTo = '1.3.6.1.2.1.17.7.1.3.1.1.3';    # Q-BRIDGE MIB

    if ( !$self->isProductionMode() ) {
        $logger->info(
                "The switch isn't in production mode (Do nothing): " .
                "Should deauthorize MAC $deauthMac on ifIndex $ifIndex, VLAN $deauthVlan " .
                "and authorize MAC $authMac on ifIndex $ifIndex, VLAN $authVlan."
        );
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    # Deauthorize MAC address from old location
    if ( $deauthMac && !$self->isFakeMac($deauthMac) ) {

        my $mac_oid = mac2oid($deauthMac);

        $logger->trace(
            "SNMP set_request for OID_dot1qStaticUnicastStatus: " .
            "( $OID_dot1qStaticUnicastStatus.$deauthVlan.$mac_oid.0 i $SNMP::Q_BRIDGE::INVALID )"
        );
        my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_dot1qStaticUnicastStatus.$deauthVlan.$mac_oid.0", Net::SNMP::INTEGER, $SNMP::Q_BRIDGE::INVALID
        ] );
        if ( !defined($result) ) {
            $logger->error(
                    "Error deauthorizing $deauthMac ( $mac_oid ) on ifIndex $ifIndex, vlan $deauthVlan: " .
                    $self->{_sessionWrite}->error );
        } else {
            $logger->info( "Deauthorizing $deauthMac ( $mac_oid ) on ifIndex $ifIndex, vlan $deauthVlan" );
        }
    }

    # Authorize MAC address at new location
    if ( $authMac && !$self->isFakeMac($authMac) ) {

        my $mac_oid = mac2oid($authMac);
        my $portList = $self->createPortListWithOneItem($ifIndex);

        $logger->trace(
            "SNMP set_request for OID_dot1qStaticUnicastStatus: " .
            "( $OID_dot1qStaticUnicastStatus.$authVlan.$mac_oid.0 i $SNMP::Q_BRIDGE::PERMANENT )"
        );
        $logger->trace(
            "SNMP set_request for OID_dot1qStaticUnicastAllowedToGoTo: " .
            "( $OID_dot1qStaticUnicastAllowedToGoTo.$authVlan.$mac_oid.0 s $portList )"
        );
        my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_dot1qStaticUnicastStatus.$authVlan.$mac_oid.0", Net::SNMP::INTEGER, $SNMP::Q_BRIDGE::PERMANENT,
            "$OID_dot1qStaticUnicastAllowedToGoTo.$authVlan.$mac_oid.0", Net::SNMP::OCTET_STRING, $portList
        ] );
        if ( !defined($result) ) {
            $logger->error(
                    "Error authorizing $authMac ( $mac_oid ) on ifIndex $ifIndex, vlan $authVlan: " .
                    $self->{_sessionWrite}->error );
        } else {
            $logger->info( "Authorizing $authMac ( $mac_oid ) on ifIndex $ifIndex, vlan $authVlan" );
        }
    }

    return 1;
}


sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;

    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';                       # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticUntaggedPorts = '1.3.6.1.2.1.17.7.1.4.3.1.4';    # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticEgressPorts = '1.3.6.1.2.1.17.7.1.4.3.1.2';      # Q-BRIDGE-MIB

    if ( !$self->isProductionMode() ) {
        $logger->info(
                "The switch isn't in production mode (Do nothing): " .
                "Should set ifIndex $ifIndex to VLAN $newVlan" );
        return 1;
    }

    my $result;

    my $dot1dBasePort = $self->getDot1dBasePortForThisIfIndex($ifIndex);
    if ( !defined($dot1dBasePort) ) {
        return 0;
    }

    if ( !$self->connectRead() ) {
        return 0;
    }

    {
        my $lock = $self->getExclusiveLock();

        # Get current egress and untagged ports
        $logger->trace(
                "SNMP get_request for dot1qVlanStaticEgressPorts: " .
                "( $OID_dot1qVlanStaticEgressPorts.$oldVlan )" );
        $logger->trace(
                "SNMP get_request for dot1qVlanStaticEgressPorts: " .
                "( $OID_dot1qVlanStaticEgressPorts.$newVlan )" );
        $logger->trace(
                "SNMP get_request for dot1qVlanStaticUntaggedPorts: " .
                "( $OID_dot1qVlanStaticUntaggedPorts.$oldVlan )" );
        $logger->trace(
                "SNMP get_request for dot1qVlanStaticUntaggedPorts: " .
                "( $OID_dot1qVlanStaticUntaggedPorts.$newVlan )" );
        $self->{_sessionRead}->translate(0);
        $result = $self->{_sessionRead}->get_request( -varbindlist => [
                "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
                "$OID_dot1qVlanStaticEgressPorts.$newVlan",
                "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
                "$OID_dot1qVlanStaticUntaggedPorts.$newVlan" ] );
        $self->{_sessionRead}->translate(1);

        # Calculate new settings
        my $egressPortsOldVlan = $self->modifyBitmask(
                $result->{"$OID_dot1qVlanStaticEgressPorts.$oldVlan"}, $dot1dBasePort - 1, 0 );
        my $egressPortsVlan = $self->modifyBitmask(
                $result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"}, $dot1dBasePort - 1, 1 );
        my $untaggedPortsOldVlan = $self->modifyBitmask(
                $result->{"$OID_dot1qVlanStaticUntaggedPorts.$oldVlan"}, $dot1dBasePort - 1, 0 );
        my $untaggedPortsVlan = $self->modifyBitmask(
                $result->{"$OID_dot1qVlanStaticUntaggedPorts.$newVlan"}, $dot1dBasePort - 1, 1 );

        if ( !$self->connectWrite() ) {
            return 0;
        }

        # Setting egressPorts and untaggedPorts for new vlan
        $logger->trace(
            "SNMP set_request for OID_dot1qVlanStaticUntaggedPorts: " .
            "( $OID_dot1qVlanStaticUntaggedPorts.$newVlan s portList )"
        );
        $logger->trace(
            "SNMP set_request for OID_dot1qVlanStaticEgressPorts: " .
            "( $OID_dot1qVlanStaticEgressPorts.$newVlan s portList )"
        );
        # This switch is sensitive about the order in which we set untagged vs egress parameters.
        # This combination worked, don't touch it unless you know what you are doing!
        $result = $self->{_sessionWrite}->set_request( -varbindlist => [
                "$OID_dot1qVlanStaticUntaggedPorts.$newVlan", Net::SNMP::OCTET_STRING, $untaggedPortsVlan,
                "$OID_dot1qVlanStaticEgressPorts.$newVlan", Net::SNMP::OCTET_STRING, $egressPortsVlan ] );
        if ( !defined($result) ) {
            $logger->error(
                    "Error setting untaggedPorts and egressPorts for new vlan $newVlan: " .  $self->{_sessionWrite}->error
            );
        } else {
            $logger->info( "Changed untaggedPorts and egressPorts for new vlan $newVlan" );
        }

        # Changing port PVID for new vlan
        $logger->trace(
                "SNMP set_request for OID_dot1qPvid: " .
                "( $OID_dot1qPvid.$ifIndex u $newVlan )" );
        $result = $self->{_sessionWrite}->set_request( -varbindlist => [
                "$OID_dot1qPvid.$ifIndex", Net::SNMP::GAUGE32, $newVlan ] );
        if ( !defined($result) ) {
            $logger->error(
                    "Error changing port PVID for new vlan $newVlan: " .  $self->{_sessionWrite}->error
            );
        } else {
            $logger->info( "Changed port PVID for new vlan $newVlan" );
        }

        # Setting egressPorts and untaggedPorts for old vlan
        $logger->trace(
                "SNMP set_request for OID_dot1qVlanStaticUntaggedPorts: " .
                "( $OID_dot1qVlanStaticUntaggedPorts.$oldVlan s portList )" );
        $logger->trace(
                "SNMP set_request for OID_dot1qVlanStaticEgressPorts: " .
                "( $OID_dot1qVlanStaticEgressPorts.$oldVlan s portList )" );
        $result = $self->{_sessionWrite}->set_request( -varbindlist => [
                "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan", Net::SNMP::OCTET_STRING, $untaggedPortsOldVlan,
                "$OID_dot1qVlanStaticEgressPorts.$oldVlan", Net::SNMP::OCTET_STRING, $egressPortsOldVlan ] );
        if ( !defined($result) ) {
            $logger->error(
                    "Error setting untaggedPorts and egressPorts for old vlan: " .
                    $self->{_sessionWrite}->error );
        } else {
            $logger->info( "Changed untaggedPorts and egressPorts for old vlan $oldVlan" );
        }

     }

    # if we are in port security mode we need to authorize the MAC in the new VLAN (and deauthorize the old stuff)
    # because this switch's port-security secure MAC address table is VLAN aware
    # Same behaviour/code as for Foundry switches
    if ( $self->isPortSecurityEnabled($ifIndex) ) {
        my $auth_result = $self->authorizeCurrentMacWithNewVlan($ifIndex, $newVlan, $oldVlan);

        if ( ( !defined($auth_result) ) || ( $auth_result != 1 ) ) {
            $logger->error("Couldn't authorize MAC for new VLAN: no secure mac");
        }
    }

    return ( defined($result) );
}


=item getSecureMacAddresses

Return all MAC addresses in security table and their VLAN for a given ifIndex

Returns an hashref with MAC => Array(VLANs)

=cut

sub getSecureMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    my $OID_dot1qStaticUnicastAllowedToGoTo = '1.3.6.1.2.1.17.7.1.3.1.1.3';    # Q-BRIDGE MIB

    my $secureMacAddrHashRef = {};
    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    $self->{_sessionRead}->translate(0);
    $logger->trace("SNMP get_table for dot1qStaticUnicastAllowedToGoTo: $OID_dot1qStaticUnicastAllowedToGoTo");
    my $result = $self->{_sessionRead}->get_table( -baseoid => "$OID_dot1qStaticUnicastAllowedToGoTo" );
    $self->{_sessionRead}->translate(1);

    while ( my $oid_including_mac = each( %{$result} ) ) {

        # if bit at ifIndex position is On, this MAC is on the ifIndex we are looking for, store it
        if ($self->getBitAtPosition($result->{$oid_including_mac}, $ifIndex-1)) {
            if ($oid_including_mac =~
                /^$OID_dot1qStaticUnicastAllowedToGoTo\.             # query OID
                ([0-9]+)\.                                           # <vlan>.
                ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)     # MAC in OID format
                \.[0-9]+                                             # Unknown field (stack index?)
                /x) {

                my $vlan = $1;
                my $mac = oid2mac($2);
                push @{$secureMacAddrHashRef->{$mac}}, $vlan;
            }
        }
    }
    return $secureMacAddrHashRef;
}


=item getAllSecureMacAddresses

Return all MAC addresses in security table and their VLAN

Returns an hashref with MAC => ifIndex => Array(VLANs)

=cut

sub getAllSecureMacAddresses {
    my ( $self ) = @_;
    my $logger = $self->logger;

    my $OID_dot1qStaticUnicastAllowedToGoTo = '1.3.6.1.2.1.17.7.1.3.1.1.3';    # Q-BRIDGE MIB

    my $secureMacAddrHashRef = {};

    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    # Get secure MAC address list
    $logger->trace(
        "SNMP get_table for dot1qStaticUnicastAllowedToGoTo: " .
        "( $OID_dot1qStaticUnicastAllowedToGoTo )"
    );
    $self->{_sessionRead}->translate(0);
    my $result = $self->{_sessionRead}->get_table( -baseoid =>
        "$OID_dot1qStaticUnicastAllowedToGoTo" );
    $self->{_sessionRead}->translate(1);

    while ( my $oid_including_mac = each( %{$result} ) ) {

        # here is an example for port ethernet 1/16
        # result is HEX and $y is bits
        #
        # the length of result varies based on SMC model, 480 bits on 8xxx and 64 bits on 6xxx
        # in hex: result = 0x0001000000000000000000...
        # in bit port_list: $port_list = 0000 0000 0000 0001 0000 0000 ....
        # in this example then $ifIndex = 16

        my $port_list = unpack("B*", $result->{$oid_including_mac});

        # Iterate through all ports enabled for that entry
        while( $port_list =~ /1/g ) {
            my $ifIndex = pos($port_list);

            if ( $oid_including_mac =~
                    /^$OID_dot1qStaticUnicastAllowedToGoTo\.              # oid
                    ([0-9]+)\.                                            # vlan
                    ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.    # mac in oid format
                    [0-9]+                                                # unknown
                    /x ) {

                my $vlan = $1;
                my $mac = oid2mac($2);
                push @{ $secureMacAddrHashRef->{$mac}->{$ifIndex} }, $vlan;
            }
        }
    }

    return $secureMacAddrHashRef;
}


sub getDot1dBasePortForThisIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    my $OID_dot1dBaseNumPort = '1.3.6.1.2.1.17.1.2.0';    # BRIDGE MIB

   if ( !$self->connectRead() ) {
        return 0;
    }

    # Get physical port amount
    $logger->trace(
            "SNMP get_request for dot1dBaseNumPort: " .
            "( $OID_dot1dBaseNumPort )" );
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [
            "$OID_dot1dBaseNumPort"
    ] );
    if ( !( exists( $result->{"$OID_dot1dBaseNumPort"} ) ) ) {
        return 0;
    }

    my $dot1dBaseNumPort = $result->{$OID_dot1dBaseNumPort};

    my $dot1dBasePort = 0;

    if ( ( $ifIndex > 0 ) && ( $ifIndex <= $dot1dBaseNumPort ) ) {
        $dot1dBasePort = $ifIndex;
    }

    return $dot1dBasePort;
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
