package pf::Switch::Cisco::Catalyst_3750G;

=head1 NAME

pf::Switch::Cisco::Catalyst_3750G

=head1 DESCRIPTION

Object oriented module to access and configure Cisco Catalyst 3750G switches

This module implements a few things but for the most part refer to L<pf::Switch::Cisco::Catalyst_2960>.

=head1 STATUS

Should work in:

=over

=item port-security

=item MAC-Authentication / 802.1X

We've got reports of it working with 12.2(55)SE.
Stacked switches should also work.

=back

The minimum required firmware version is 12.2(25)SEE2.

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;

use Net::SNMP;

use pf::Switch::constants;

use base ('pf::Switch::Cisco::Catalyst_3750');

sub description { 'Cisco Catalyst 3750G' }

# CAPABILITIES
# inherited from 3750

=head1 SUBROUTINES

=over

=item NasPortToIfIndex

Translate RADIUS NAS-Port into switch's ifIndex.

=cut

sub NasPortToIfIndex {
    my ($self, $NAS_port) = @_;
    my $logger = $self->logger;

    # NAS-Port bumps by +100 between stacks while ifIndex bumps by +500
    # some examples values for stacked switches are available in t/network-devices/cisco.t
    # This could work with other Cisco switches but we couldn't test so we implemented it only for the 3750.
    if (my ($stack_idx, $port) = $NAS_port =~ /^50(\d)(\d\d)$/) {
        return ( ($stack_idx - 1) * $CISCO::IFINDEX_PER_STACK ) + $port + $CISCO::IFINDEX_GIG_OFFSET;
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
