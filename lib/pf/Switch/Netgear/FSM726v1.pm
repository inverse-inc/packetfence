package pf::Switch::Netgear::FSM726v1;

=head1 NAME

pf::Switch::Netgear::FSM726v1 - Object oriented module to access and configure enabled Netgear FSM726/FSM726S v1 switches.

=head1 STATUS

=over

=item Port-security

- Developped and tested on a FSM726v1 using firmware (Software version) 2.6.5 (6035)

- VoIP configuration not tested

=item Link up/down

- Can't work in this mode since up/down traps are parts of the port-security process

=back

=head1 BUGS AND LIMITATIONS

=over

=item forceDeauthOnLinkDown

The MAC address needs to be unauthorized from the port otherwise this MAC will stay authorized on the VLAN and no
more traps will show up.

=item setAdminStatus

A port shutdown on this switch doesn't physically shuts the port. The port just stop forwarding packet without really
shutting down. A workaround to this is to change the auto negotiation status that will create a shutdown behavior
on the client device.

=back

=cut

use strict;
use warnings;

use POSIX;
use Net::SNMP;

use pf::Switch::constants;
use pf::constants;
use pf::util;

use base ('pf::Switch::Netgear');

sub description { 'Netgear FSM726v1' }

=head1 METHODS

=over

=item authorizeMAC

=cut

sub authorizeMAC {
    my ( $self, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = $self->logger;

    my $OID_trustedMacStatus = '1.3.6.1.4.1.4526.1.1.15.1.1.3';    # NETGEAR-MIB

    if ( !$self->isProductionMode() ) {
        $logger->info(
                "The switch isn't in production mode (Do nothing): " .
                "Should deauthorize MAC $deauthMac on ifIndex $ifIndex " .
                "and authorize MAC $authMac on ifIndex $ifIndex"
        );
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    # Deauthorize MAC address from old location
    if ( $deauthMac ) {
        my $mac_oid = mac2oid($deauthMac);

        $logger->trace(
                "SNMP set_request for OID_trustedMacStatus: " .
                "( $OID_trustedMacStatus.$ifIndex.$mac_oid i $SNMP::DESTROY )"
        );
        my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
                "$OID_trustedMacStatus.$ifIndex.$mac_oid", Net::SNMP::INTEGER, $SNMP::DESTROY
        ] );
        if ( !defined($result) ) {
            $logger->error(
                    "Error deauthorizing $deauthMac ( $mac_oid ) on ifIndex $ifIndex: " .
                    $self->{_sessionWrite}->error
            );
        } else {
            $logger->info(
                    "Deauthorizing $deauthMac ($mac_oid) on ifIndex $ifIndex"
            );
        }
    }

    # Authorize MAC address at new location
    if ( $authMac ) {
        my $mac_oid = mac2oid($authMac);

        $logger->trace(
                "SNMP set_request for OID_trustedMacStatus: " .
                "( $OID_trustedMacStatus.$ifIndex.$mac_oid i $SNMP::CREATE_AND_GO )"
        );
        my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
                "$OID_trustedMacStatus.$ifIndex.$mac_oid", Net::SNMP::INTEGER, $SNMP::CREATE_AND_GO
        ] );
        if ( !defined($result) ) {
            $logger->error(
                    "Error authorizing $authMac ( $mac_oid ) on ifIndex $ifIndex: " .
                    $self->{_sessionWrite}->error
            );
            return 0;
        } else {
            $logger->info(
                    "Authorizing $authMac ( $mac_oid ) on ifIndex $ifIndex"
            );
        }
    }

    return 1;
}

=item forceDeauthOnLinkDown

Force a MAC address deauthorization from the port sending the linkdown trap.

See bugs and limitations.

=cut

sub forceDeauthOnLinkDown {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    # here we actively ignore uplinks because this is called from the parsing threads which don't
    # check for uplinks (yet).
    # This hack is to work-around "Netgear's not sending traps under certain circumstances" "feature"
    my @uplinks = $self->getUpLinks();

    if ( @uplinks && $uplinks[0] == -1 ) {
        $logger->warn("Can't determine uplinks for the switch -> do nothing");
    } else {
        if ( grep( { $_ == $ifIndex } @uplinks ) == 0 ) {
            my $trustedMacHash = $self->getSecureMacAddresses($ifIndex);
            my $deauthMac = (keys %{$trustedMacHash})[0];
            my $authMac = $self->generateFakeMac($FALSE, $ifIndex);
            $self->authorizeMAC($ifIndex, $deauthMac, $authMac);
        }
    }

    return 1;
}

=item getAllSecureMacAddresses

=cut

sub getAllSecureMacAddresses {
    my ( $self ) = @_;
    my $logger = $self->logger;

    my $OID_trustedMacAddress = '1.3.6.1.4.1.4526.1.1.15.1.1.2';
    my $secureMacAddrHashRef = {};

    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    $self->{_sessionRead}->translate(0);
    $logger->trace("SNMP get_table for trustedMacAddress: $OID_trustedMacAddress");
    my $result = $self->{_sessionRead}->get_table( -baseoid => "$OID_trustedMacAddress" );
    $self->{_sessionRead}->translate(1);

    while ( my $oid_including_mac = each( %{$result} ) ) {
        if ($oid_including_mac =~
                /^$OID_trustedMacAddress\.                                   # query OID
                ([0-9]+)\.                                                   # ifIndex
                ([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)   # MAC in OID format
                /x) {

            my $ifIndex = $1;
            my $mac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x", $2, $3, $4, $5, $6, $7 );
            my $vlan = $self->getVlan($ifIndex);

            push @{$secureMacAddrHashRef->{$mac}->{$ifIndex}}, $vlan;
        }
    }

    return $secureMacAddrHashRef;
}

=item getSecureMacAddresses

=cut

sub getSecureMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    my $OID_trustedMacAddress = '1.3.6.1.4.1.4526.1.1.15.1.1.2';
    my $secureMacAddrHashRef = {};

    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    $self->{_sessionRead}->translate(0);
    $logger->trace("SNMP get_table for trustedMacAddress: $OID_trustedMacAddress");
    my $result = $self->{_sessionRead}->get_table( -baseoid => "$OID_trustedMacAddress.$ifIndex" );
    $self->{_sessionRead}->translate(1);

    while ( my $oid_including_mac = each( %{$result} ) ) {

            if ($oid_including_mac =~
                /^$OID_trustedMacAddress\.                                    # query OID
                [0-9]+\.                                                      # ifIndex
                ([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)    # MAC in OID format
                /x) {

                my $mac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x", $1, $2, $3, $4, $5, $6 );
                my $vlan = $self->getVlan($ifIndex);

                push @{$secureMacAddrHashRef->{$mac}}, $vlan;
            }
    }
    return $secureMacAddrHashRef;
}

=item getVlan

=cut

sub getVlan {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    my $OID_configPortDefaultVlanId = '1.3.6.1.4.1.4526.1.1.11.6.1.12';    # NETGEAR-MIB

    if ( !$self->connectRead() ) {
        return 0;
    }

    $logger->trace(
            "SNMP get_request for OID_configPortDefaultVlanId: " .
            "( $OID_configPortDefaultVlanId.$ifIndex )"
    );
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [
            "$OID_configPortDefaultVlanId.$ifIndex"
    ] );
    if ( !defined($result) ) {
        $logger->error(
                "Error getting PVID on ifIndex $ifIndex: " .
                $self->{_sessionRead}->error
        );
    } else {
        $logger->info(
                "Getting PVID on ifIndex $ifIndex"
        );
    }

    return $result->{"$OID_configPortDefaultVlanId.$ifIndex"};
}

=item isPortSecurityEnabled

Since port security on this switch is called Trusted MAC, there's no check possible to see if
port security is enabled.

Always returns true because switch doesn't work except in port-security.

=cut

sub isPortSecurityEnabled { return $TRUE; }

=item parseTrap

=cut

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $logger = $self->logger();

    my $trapHashRef;

    # link up/down traps
    if ( $trapString =~
            /BEGIN\ TYPE\ ([23])\ END\ TYPE\ BEGIN\ SUBTYPE\ 0\ END\ SUBTYPE\
            BEGIN\ VARIABLEBINDINGS\ \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+)
            /x ) {
        $trapHashRef->{'trapType'}      = ( ( $1 == 3 ) ? "up" : "down" );
        $trapHashRef->{'trapIfIndex'}   = $2;

        if ( $1 == 2 ) { $self->forceDeauthOnLinkDown($2) };
    }
    # secure MAC address violation traps
    elsif ( $trapString =~
            /BEGIN\ VARIABLEBINDINGS\ \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.[0-9]+\
            =\ INTEGER:\ ([0-9]+)\|\.1\.3\.6\.1\.4\.1\.4526\.1\.2\.16\.1\.
            [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\ =\ $SNMP::MAC_ADDRESS_FORMAT
            /x ) {
        $trapHashRef->{'trapType'}      = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'}   = $1;
        $trapHashRef->{'trapMac'}       = parse_mac_from_trap($2);
        $trapHashRef->{'trapVlan'}      = $self->getVlan( $trapHashRef->{'trapIfIndex'} );
    }
    # unhandled traps
    else {
        $logger->debug("trap currently no handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }

    return $trapHashRef;
}

=item setAdminStatus

Use the auto negotiation setting to force the port to shuts because the admin status doesn't do the trick.

See bugs and limitations.

=cut

sub setAdminStatus {
    my ( $self, $ifIndex, $status ) = @_;
    my $logger = $self->logger;

    my $OID_configPortAutoNegotiation = '1.3.6.1.4.1.4526.1.1.11.6.1.14';    # NETGEAR-MIB

    if ( !$self->isProductionMode() ) {
        $logger->info(
                "The switch isn't in production mode (Do nothing): " .
                "Should trigger auto negotiation status to shut the ifIndex $ifIndex"
        );
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    $logger->trace(
            "SNMP set_request for OID_configPortAutoNegotiation: " .
            "( $OID_configPortAutoNegotiation.$ifIndex i $status )"
    );
    my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_configPortAutoNegotiation.$ifIndex", Net::SNMP::INTEGER, $status
    ] );
    if ( !defined($result) ) {
        $logger->error(
                "Error setting auto negotiation status on ifIndex $ifIndex: " .
                $self->{_sessionWrite}->error
        );

        return 0;
    } else {
        $logger->info(
                "Setting auto negotiation status on ifIndex $ifIndex"
        );

        return $result;
    }
}

=item _setVlan

=cut

sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;

    my $OID_vlanPortStatus = '1.3.6.1.4.1.4526.1.1.13.2.1.3';            # NETGEAR-MIB
    my $OID_configPortDefaultVlanId = '1.3.6.1.4.1.4526.1.1.11.6.1.12';  # NETGEAR-MIB

    my $result;

    if ( !$self->isProductionMode() ) {
        $logger->info(
                "The switch isn't in production mode (Do nothing): " .
                "Should set ifIndex $ifIndex to VLAN $newVlan"
        );
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    $self->forceDeauthOnLinkDown($ifIndex);

    # Change port PVID
    $logger->trace(
            "SNMP set_request for OID_configPortDefaultVlanId: " .
            "( $OID_configPortDefaultVlanId.$ifIndex i $newVlan )"
    );
    $result = $self->{_sessionWrite}->set_request( -varbindlist =>[
            "$OID_configPortDefaultVlanId.$ifIndex", Net::SNMP::INTEGER, $newVlan
    ] );
    if ( !defined($result) ) {
        $logger->error(
                "Error setting PVID $newVlan on ifIndex $ifIndex: " .
                $self->{_sessionWrite}->error
        );
    } else {
        $logger->info(
                "Setting PVID $newVlan on ifIndex $ifIndex"
        );
    }

    # Destroy the old port / vlan association
    $logger->trace(
            "SNMP set_request for OID_vlanPortStatus: " .
            "( $OID_vlanPortStatus.$ifIndex.$oldVlan i $SNMP::DESTROY )"
    );
    $result = $self->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_vlanPortStatus.$ifIndex.$oldVlan", Net::SNMP::INTEGER, $SNMP::DESTROY
    ] );
    if ( !defined($result) ) {
        $logger->error(
                "Error removing old vlan $oldVlan from ifIndex $ifIndex: " .
                $self->{_sessionWrite}->error
        );
    } else {
        $logger->info(
                "Removing old vlan $oldVlan from ifIndex $ifIndex"
        );
    }

    # Create a new port / vlan association
    $logger->trace(
            "SNMP set_request for OID_vlanPortStatus: " .
            "( $OID_vlanPortStatus.$ifIndex.$newVlan i $SNMP::CREATE_AND_GO )"
    );
    $result = $self->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_vlanPortStatus.$ifIndex.$newVlan", Net::SNMP::INTEGER, $SNMP::CREATE_AND_GO
    ] );
    if ( !defined($result) ) {
        $logger->error(
                "Error setting new vlan $newVlan on ifIndex $ifIndex: " .
                $self->{_sessionWrite}->error
        );
    } else {
        $logger->info(
                "Setting new vlan $newVlan on ifIndex $ifIndex"
        );
    }

    return ( defined($result) );
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
