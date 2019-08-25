package pf::Switch::Cisco::Catalyst_6500;

=head1 NAME

pf::Switch::Cisco::Catalyst_6500

=head1 DESCRIPTION

Object oriented module to access and configure Cisco Catalyst 6500 switches

=head1 STATUS

Supports port-security.
VoIP not tested.

Known to work on IOS 12.2(18)SXF17b.

=head1 BUGS AND LIMITATIONS

Because a lot of code is shared with the 2960 make sure to check the BUGS AND LIMITATIONS section of 
L<pf::Switch::Cisco::Catalyst_2960> also.

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;

use Net::SNMP;

use pf::Switch::constants;
use pf::util;

use base ('pf::Switch::Cisco::Catalyst_2960');

sub description { 'Cisco Catalyst 6500 Series' }

=head1 SUBROUTINES

=over

=item _setVlan

Here we override Cisco's setVlan because of the behavior of the security table on the 6500's.
The 6500's security table is per port per Vlan as opposed to per port (as most other Cisco's are).

=cut

sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $result;
    if ( $self->isTrunkPort($ifIndex) ) {

        $result = $self->setTrunkPortNativeVlan($ifIndex, $newVlan);

        #expirer manuellement la mac-address-table
        $self->clearMacAddressTable( $ifIndex, $oldVlan );

    } else {
        my $OID_vmVlan = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB
        $logger->trace("SNMP set_request for vmVlan: $OID_vmVlan");
        $result = $self->{_sessionWrite}->set_request( -varbindlist =>[ 
            "$OID_vmVlan.$ifIndex", Net::SNMP::INTEGER, $newVlan ] );
    }
    if ( !defined($result) ) {
        $logger->error("Error changing VLAN on ifIndex $ifIndex: " . $self->{_sessionWrite}->error);
    }
    my $returnValue = ( defined($result) );

    # if we are in port security mode we need to authorize the MAC in the new VLAN (and deauthorize the old stuff)
    # because this switch's port-security secure MAC address table is VLAN aware
    if ($self->isPortSecurityEnabled($ifIndex)) {

        my $auth_result = $self->authorizeCurrentMacWithNewVlan($ifIndex, $newVlan, $oldVlan);
        if (!defined($auth_result) || $auth_result != 1) {
            $logger->warn("couldn't authorize MAC for new VLAN: no secure mac");
        }
    }

    return $returnValue;
}

=item authorizeMAC

Override because VLAN is important in this switch' security table.
Changed authVlan's deauthVlan to authVlan.

=cut

sub authorizeMAC {
    my ( $self, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = $self->logger;
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';

    if ( !$self->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't add an entry to the SecureMacAddrTable"
        );
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    # We will assemble the SNMP set request in this array and do it all in one pass
    my @oid_value;
    if ($deauthMac) {
        $logger->trace("Adding a cpsIfVlanSecureMacAddrRowStatus DESTROY to the set request");
        my $oid = "$oid_cpsIfVlanSecureMacAddrRowStatus.$ifIndex." . mac2oid($deauthMac) . ".$deauthVlan";
        push @oid_value, ($oid, Net::SNMP::INTEGER, $SNMP::DESTROY);
    }
    if ($authMac) {
        $logger->trace("Adding a cpsIfVlanSecureMacAddrRowStatus CREATE_AND_GO to the set request");
        # Warning: placing in deauthVlan instead of authVlan because authorization happens before VLAN change
        my $oid = "$oid_cpsIfVlanSecureMacAddrRowStatus.$ifIndex." . mac2oid($authMac) . ".$authVlan";
        push @oid_value, ($oid, Net::SNMP::INTEGER, $SNMP::CREATE_AND_GO);
    }
    if (@oid_value) {
        $logger->trace("SNMP set_request for cpsIfVlanSecureMacAddrRowStatus");
        my $result = $self->{_sessionWrite}->set_request(-varbindlist => \@oid_value);
        if (!defined($result)) {
            $logger->warn(
                "SNMP error tyring to remove or add secure rows to ifIndex $ifIndex in port-security table. "
                . "This could be normal. Error message: ".$self->{_sessionWrite}->error()
            );
            return 0;
        }
    }

    return 1;
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
