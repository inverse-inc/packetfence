package pf::Switch::H3C::Comware_v7;

=head1 NAME

pf::Switch::H3C::Comware_v7 - Object oriented module to access and configure enabled H3C S5120 switches.

=head1 STATUS

This module is currently only a placeholder, see L<pf::Switch::H3C>.

=cut

use strict;
use warnings;

use base ('pf::Switch::H3C::Comware_v5');


sub description { 'Comware v7' }

=head1 SUBROUTINES

=over

=item NasPortToIfIndex

Translate RADIUS NAS-Port into switch's ifIndex.

=cut

sub NasPortToIfIndex {
    my ($self, $nas_port) = @_;
    my $logger = $self->logger;

    # 4096 NAS-Port slots are reserved per physical ports,
    # I'm assuming that each client will get a +1 so I translate all of them into the same ifIndex
    # Also there's a large offset (16781312), 4096 * (4096 + 1)
    # VLAN ID are last 3 nibbles ────────────────┐
    # Port is next 2 nibbles    ────────────┐    │
    # Subslot is next 1 nibble ──────────┐  │    │
    # Slot is next 2 nibbles  ───────┐   │  │    │
    # Example: 33575422 --to hex--> (02)(0)(05)(1FE)
    my $nas_port_no_vlan = floor($nas_port / $THREECOM::NAS_PORTS_PER_PORT_RANGE);
    my $slot = floor($nas_port_no_vlan / $THREECOM::NAS_PORTS_PER_PORT_RANGE);
    my $port = $nas_port_no_vlan - $THREECOM::NAS_PORTS_PER_PORT_RANGE * $slot;
    my $ifIndex = $port + $THREECOM::IFINDEX_OFFSET_PER_SLOT * ($slot - 1);
    if ($ifIndex > 0) {

        # TODO we should think about caching or pre-computation here
        $ifIndex = $self->getIfIndexForThisDot1dBasePort($ifIndex);

        # return if defined and an int
        return $ifIndex if (defined($ifIndex) && $ifIndex =~ /^\d+$/);
    }

    # error reporting
    $logger->warn(
        "Unknown NAS-Port format. ifIndex translation could have failed. "
        . "VLAN re-assignment and switch/port accounting will be affected."
    );
    return $nas_port;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
