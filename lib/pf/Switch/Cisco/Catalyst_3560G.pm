package pf::Switch::Cisco::Catalyst_3560G;
=head1 NAME

pf::Switch::Cisco::Catalyst_3560G

=head1 DESCRIPTION

Object oriented module to access and configure Cisco Catalyst 3560G switches

=head1 SUPPORT STATUS

=over

=item port-security

12.2(50)SE1 has been reported to work fine

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

=over

=cut

use strict;
use warnings;

use Net::SNMP;

use base ('pf::Switch::Cisco::Catalyst_3560');

sub description { 'Cisco Catalyst 3560G' }

# CAPABILITIES
# inherited from 3560

=item NasPortToIfIndex

Translate RADIUS NAS-Port into switch's ifIndex.

=cut

sub NasPortToIfIndex {
    my ($self, $NAS_port) = @_;
    my $logger = $self->logger;

    # ex: 50023 is ifIndex 10023
    if ($NAS_port =~ s/^500/101/) {
        return $NAS_port;
    } else {
        $logger->warn("Unknown NAS-Port format. ifIndex translation could have failed. "
            ."VLAN re-assignment and switch/port accounting will be affected.");
    }
    return $NAS_port;
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
