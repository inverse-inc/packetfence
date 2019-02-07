package pf::Switch::Cisco::Catalyst_3560;
=head1 NAME

pf::Switch::Cisco::Catalyst_3560

=head1 DESCRIPTION

Object oriented module to access and configure Cisco Catalyst 3560 switches

This module is currently only a placeholder, see pf::Switch::Cisco::Catalyst_2960.

=head1 SUPPORT STATUS

=over

=item port-security

12.2(50)SE1 has been reported to work fine

12.2(25)SEC1 has issues

=item port-security + Voice over IP (VoIP)

Recommended IOS is 12.2(55)SE4.

=item MAC-Authentication / 802.1X

The hardware should support it.

802.1X support was never tested by Inverse.

=back

=head1 BUGS AND LIMITATIONS

Because a lot of code is shared with the 2950 make sure to check the BUGS AND LIMITATIONS section of
L<pf::Switch::Cisco::Catalyst_2950> also.

=over

=item port-security + Voice over IP (VoIP)

=over

=item IOS 12.2(25r) disappearing config

For some reason when securing a MAC address the switch loses an important portion of its config.
This is a Cisco bug, nothing much we can do. Don't use this IOS for VoIP.
See issue #1020 for details.

=item IOS 12.2(55)SE1 voice VLAN issues

For some reason this IOS doesn't put VoIP devices in the voice VLAN correctly.
This is a Cisco bug, nothing much we can do. Don't use this IOS for VoIP.
12.2(55)SE4 is working fine.

=back

=back

=cut

use strict;
use warnings;

use Net::SNMP;

use pf::config qw(
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);

use base ('pf::Switch::Cisco::Catalyst_2960');

sub description { 'Cisco Catalyst 3560' }

# CAPABILITIES
# inherited from 2960

sub setModeTrunk {
    my ( $self, $ifIndex, $enable ) = @_;
    my $logger = $self->logger;
    my $OID_vlanTrunkPortDynamicState = "1.3.6.1.4.1.9.9.46.1.6.1.1.13";    #CISCO-VTP-MIB
    my $OID_vlanTrunkEncapsulation = "1.3.6.1.4.1.9.9.46.1.6.1.1.3";

    # $mode = 1 -> switchport mode trunk
    # $mode = 2 -> switchport mode access

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port vlanTrunkPortDynamicState");
        return 1;
    }
    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $truthValue = $enable ? $SNMP::TRUE : $SNMP::FALSE;
    my $trunkMode = $enable ? $CISCO::TRUNK_DOT1Q : $CISCO::TRUNK_AUTO;
    $logger->trace("SNMP set_request for vlanTrunkEncapsulation: $OID_vlanTrunkEncapsulation");
    my $result = $self->{_sessionWrite}->set_request( -varbindlist => [ "$OID_vlanTrunkEncapsulation.$ifIndex",
        Net::SNMP::INTEGER, $trunkMode ] );
    $logger->trace("SNMP set_request for vlanTrunkPortDynamicState: $OID_vlanTrunkPortDynamicState");
    $result = $self->{_sessionWrite}->set_request( -varbindlist => [ "$OID_vlanTrunkPortDynamicState.$ifIndex",
        Net::SNMP::INTEGER, $truthValue ] );

    return ( defined($result) );
}

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
