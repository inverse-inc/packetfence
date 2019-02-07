package pf::Switch::Cisco::Catalyst_2960G;
=head1 NAME

pf::Switch::Cisco::Catalyst_2960G

=head1 DESCRIPTION

Object oriented module to access and configure Cisco Catalyst 2960G switches

=head1 STATUS

This module is currently only a placeholder, see L<pf::Switch::Cisco::Cisco_2960> for relevant support items.

This module implement support for a different ifIndex translation for the 2960G.

=head1 BUGS AND LIMITATIONS

Most of the code is shared with the 2960 make sure to check the BUGS AND
LIMITATIONS section of L<pf::Switch::Cisco::Catalyst_2960>.

=cut

use strict;
use warnings;

use pf::log;
use Net::SNMP;

use base ('pf::Switch::Cisco::Catalyst_2960');

sub description { 'Cisco Catalyst 2960G' }

# CAPABILITIES
# inherited from 2960

=head1 METHODS

=over

=item NasPortToIfIndex

Translate RADIUS NAS-Port into switch's ifIndex.

=cut

sub NasPortToIfIndex {
    my ($self, $NAS_port) = @_;
    my $logger = get_logger();

    # ex: 50023 is ifIndex 10123
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
