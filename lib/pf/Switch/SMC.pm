package pf::Switch::SMC;

=head1 NAME

pf::Switch::SMC - Object oriented module to access SNMP enabled SMC switches

=head1 STATUS

This modules holds functions common to the SMC switches but details and documentation are in each sub-module.
Refer to them for more information.

=head1 BUGS AND LIMITATIONS

This modules holds functions common to the SMC switches but details and documentation are in each sub-module.
Refer to them for more information.

=cut

use strict;
use warnings;

use POSIX;

use base ('pf::Switch');

# importing switch constants
use pf::Switch::constants;
use pf::util;

# FIXME: add to admin guide instruction to cut up/down traps and get rid of the 02:00... traps

=head1 SUBROUTINES

=over

=cut

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;

    #link up/down
    if ( $trapString =~ /BEGIN VARIABLEBINDINGS [^|]+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])\|.1.3.6.1.2.1.2.2.1.1.([0-9]+)/) {
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;

    # Old link status trap form
    } elsif ( $trapString =~ /BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = /) {
        $trapHashRef->{'trapType'} = ( ( $1 == 2 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;

    } elsif ( $trapString =~ m/BEGIN VARIABLEBINDINGS .+ OID: \.1\.3\.6\.1\.4\.1\.202\.20\.[0-9]+\.2\.1\.0\.36\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.[0-9]+ = INTEGER: ([0-9]+)\|\.1\.3\.6\.1\.4\.1\.202\.20\.[0-9]+\.1\.14\.2\.29\.0 = $SNMP::MAC_ADDRESS_FORMAT/ ) {

        $trapHashRef->{'trapType'} = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1;
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($2);
        $trapHashRef->{'trapVlan'} = $self->getVlan( $trapHashRef->{'trapIfIndex'} );

    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';                    # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticUntaggedPorts = '1.3.6.1.2.1.17.7.1.4.3.1.4'; # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticEgressPorts = '1.3.6.1.2.1.17.7.1.4.3.1.2';   # Q-BRIDGE-MIB
    my $result;

    # get current egress and untagged ports
    $self->{_sessionRead}->translate(0);
    $logger->trace("SNMP get_request for dot1qVlanStaticUntaggedPorts and dot1qVlanStaticEgressPorts");
    $result = $self->{_sessionRead}->get_request( -varbindlist => [
            "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
            "$OID_dot1qVlanStaticEgressPorts.$newVlan",
            "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
            "$OID_dot1qVlanStaticUntaggedPorts.$newVlan" ] );
    $self->{_sessionRead}->translate(1);

    my $dot1dBasePort = $self->getDot1dBasePortForThisIfIndex($ifIndex);
    if ( !defined($dot1dBasePort) ) {
        return 0;
    }

    # calculate new settings
    my $egressPortsOldVlan = $self->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticEgressPorts.$oldVlan"}, $dot1dBasePort - 1, 0 );
    my $egressPortsVlan = $self->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"}, $dot1dBasePort - 1, 1 );
    my $untaggedPortsOldVlan = $self->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticUntaggedPorts.$oldVlan"}, $dot1dBasePort - 1, 0 );
    my $untaggedPortsVlan = $self->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticUntaggedPorts.$newVlan"}, $dot1dBasePort - 1, 1 );

    # set all values
    if ( !$self->connectWrite() ) {
        return 0;
    }

    $logger->trace("SNMP set_request for egressPorts and untaggedPorts for old and new VLAN ");

    #add port to new VLAN untagged & egress
    $result = $self->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_dot1qVlanStaticEgressPorts.$newVlan", Net::SNMP::OCTET_STRING, $egressPortsVlan,
            "$OID_dot1qVlanStaticUntaggedPorts.$newVlan", Net::SNMP::OCTET_STRING, $untaggedPortsVlan ] );

    if ( !defined($result) ) {
        $logger->error( "error setting egressPorts and untaggedPorts for old and new vlan: "
            . $self->{_sessionWrite}->error );
    }

    #change port PVID
    $result = $self->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_dot1qPvid.$ifIndex", Net::SNMP::GAUGE32, $newVlan ] );

    if ( !defined($result) ) {
        $logger->error( "error setting egressPorts and untaggedPorts for old and new vlan: "
                . $self->{_sessionWrite}->error );
    }

    #remove port from old VLAN untagged & egress
    $result = $self->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan", Net::SNMP::OCTET_STRING, $untaggedPortsOldVlan,
            "$OID_dot1qVlanStaticEgressPorts.$oldVlan", Net::SNMP::OCTET_STRING, $egressPortsOldVlan ]);

    if ( !defined($result) ) {
        $logger->error("error setting egressPorts and untaggedPorts for old and new vlan: "
                . $self->{_sessionWrite}->error );
    }

    # if we are in port security mode we need to authorize the MAC in the new VLAN (and deauthorize the old stuff)
    # because this switch's port-security secure MAC address table is VLAN aware
    # Same behaviour/code as for Foundry switches
    if ($self->isPortSecurityEnabled($ifIndex)) {

        my $auth_result = $self->authorizeCurrentMacWithNewVlan($ifIndex, $newVlan, $oldVlan);
        if (!defined($auth_result) || $auth_result != 1) {
            $logger->warn("couldn't authorize MAC for new VLAN: no secure mac");
        }
    }

    return ( defined($result) );
}

sub getDot1dBasePortForThisIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return 0;
    }

    #get Physical port amount
    my $OID_dot1dBaseNumPort = '1.3.6.1.2.1.17.1.2.0';    #from BRIDGE-MIB

    $logger->trace("SNMP get_request for dot1dBaseNumPort : $OID_dot1dBaseNumPort");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => ["$OID_dot1dBaseNumPort"] );

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

=item getAllSecureMacAddresses - return all MAC addresses in security table and their VLAN

Returns an hashref with MAC => ifIndex => Array(VLANs)



=cut

sub getAllSecureMacAddresses {
    my ($self) = @_;
    my $logger = $self->logger;

    # from Q-BRIDGE MIB
    my $OID_dot1qStaticUnicastAllowedToGoTo = '1.3.6.1.2.1.17.7.1.3.1.1.3';

    my $secureMacAddrHashRef = {};
    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    $self->{_sessionRead}->translate(0);
    $logger->trace("SNMP get_table for dot1qStaticUnicastAllowedToGoTo: $OID_dot1qStaticUnicastAllowedToGoTo");
    my $result = $self->{_sessionRead}->get_table( -baseoid => "$OID_dot1qStaticUnicastAllowedToGoTo" );
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
        # iterate through all ports enabled for that entry
        while($port_list =~ /1/g) {
            my $ifIndex = pos($port_list);

            if ($oid_including_mac =~
                /^$OID_dot1qStaticUnicastAllowedToGoTo\.               # oid
                ([0-9]+)\.                                             # vlan
                ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.     # mac in oid format
                [0-9]+                                                 # unknown
                /x) {

                my $vlan = $1;
                my $mac = oid2mac($2);
                push @{ $secureMacAddrHashRef->{$mac}->{$ifIndex} }, $vlan;
            }
        }
    }
    return $secureMacAddrHashRef;
}

=item getSecureMacAddresses - return all MAC addresses in security table and their VLAN for a given ifIndex

Returns an hashref with MAC => Array(VLANs)

This method here has to handle different PortList sizes.
TigerStack 8xxx has a 480bit length port list and the 6xxx a 64bit length one.
Have that in mind when doing maintenance.

=cut

sub getSecureMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $OID_dot1qStaticUnicastAllowedToGoTo = '1.3.6.1.2.1.17.7.1.3.1.1.3';

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
                /^$OID_dot1qStaticUnicastAllowedToGoTo\.                               # query OID
                ([0-9]+)\.                                                             # <vlan>.
                ([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)   # MAC in OID format
                /x) {

                my $vlan = $1;
                my $mac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x", $2, $3, $4, $5, $6, $7 );
                push @{$secureMacAddrHashRef->{$mac}}, $vlan;
            }
        }
    }
    return $secureMacAddrHashRef;
}

sub authorizeMAC {
    my ( $self, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = $self->logger;

    # from Q-BRIDGE-MIB (RFC4363)
    my $OID_dot1qStaticUnicastStatus = '1.3.6.1.2.1.17.7.1.3.1.1.4';
    my $OID_dot1qStaticUnicastAllowedToGoTo = '1.3.6.1.2.1.17.7.1.3.1.1.3';

    # Add a static entry for 00-00-00-00-00-0F on ethernet 1/5 in VLAN 1
    # snmpset ... 1.3.6.1.2.1.17.7.1.3.1.1.4.1.0.0.0.0.0.255.0 i 3
    #               dot1qStaticUnicastStatus.x.y.y.y.y.y.y.0     3: permanent
    #                                index = x.y.y.y.y.y.y       x = VLAN     y = MAC-address entry
    # snmpset ... 1.3.6.1.2.1.17.7.1.3.1.1.3.1.0.0.0.0.0.255.0 x 080000
    #        dot1qStaticUnicastAllowedToGoTo.x.y.y.y.y.y.y.0     080000 = 0000 1000 0000 0000 0000 0000  means int 1/5
    #
    # Remove static entry 00-00-00-00-00-0F
    # snmpset ... 1.3.6.1.2.1.17.7.1.3.1.1.4.4.2.0.0.0.0.0.255.0 i 2
    #               dot1qStaticUnicastStatus.x.y.y.y.y.y.y.0       2: deletepermanent

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't add or delete a static entry in the MAC address table");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    if ($deauthMac && !$self->isFakeMac($deauthMac)) {

        my $mac_oid = mac2oid($deauthMac);

        $logger->trace("SNMP set_request for OID_dot1qStaticUnicastStatus");
        my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_dot1qStaticUnicastStatus.$deauthVlan.$mac_oid.0", Net::SNMP::INTEGER, $SNMP::Q_BRIDGE::INVALID
        ]);
        $logger->info("Deauthorizing $deauthMac ($mac_oid) on ifIndex $ifIndex, vlan $deauthVlan");
    }

    if ($authMac && !$self->isFakeMac($authMac)) {

        my $mac_oid = mac2oid($authMac);

        $logger->trace("SNMP set_request for OID_dot1qStaticUnicastStatus");

        my $portList = $self->createPortListWithOneItem($ifIndex);

        # Warning: this may seem counter-intuitive but I'm authorizing the new MAC on the old VLAN
        # because the switch won't accept it for a VLAN that doesn't exist on that port.
        # When changed by _setVlan later, the MAC will be re-authorized on the right VLAN
        my $vlan = $self->getVlan($ifIndex);

        $logger->trace("SNMP set_request for OID_dot1qStaticUnicastAllowedToGoTo");
        my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_dot1qStaticUnicastStatus.$vlan.$mac_oid.0", Net::SNMP::INTEGER, $SNMP::Q_BRIDGE::PERMANENT,
            "$OID_dot1qStaticUnicastAllowedToGoTo.$vlan.$mac_oid.0", Net::SNMP::OCTET_STRING, $portList
        ]);
        $logger->info("Authorizing $authMac ($mac_oid) on ifIndex $ifIndex, vlan $vlan "
            . "(don't worry if VLAN is not ok, it'll be re-assigned later)");
    }
    return 1;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Mr. Chinasee BOONYATANG <chinasee.b@psu.ac.th>

  Prince of Songkla University, Thailand
  http://netserv.cc.psu.ac.th

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENCE

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
