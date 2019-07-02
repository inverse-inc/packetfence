package pf::Switch::Cisco::SG300;

=head1 NAME

pf::Switch::Cisco::SG300

=head1 SYNOPSIS

The pf::Switch::Cisco::SG300 module implements an object oriented interface to
manage Cisco SG300 switches

=head1 STATUS

Developed and tested on SG300 running 1.1.2.0

=over

=item Supports

=over

=item RADIUS MAC authentication bypass

=item VoIP with MAC authentication

=back

=back

=cut

use strict;
use warnings;

use base ('pf::Switch::Cisco::Catalyst_2960');
use pf::log;

sub description { 'Cisco SG300' }

=head1 SUBROUTINES

=cut

# CAPABILITIES
# access technology supported
# inherited from cisco 2960
#

=head2 getVoipVsa

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).
For now it returns the voiceVlan untagged since Cisco supports multiple untagged VLAN in the same interface

=cut

sub getVoipVsa {
    my ($self) = @_;
    my $logger = $self->logger;

    return (
        'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
        'Tunnel-Type' => $RADIUS::VLAN,
        'Tunnel-Private-Group-ID' => $self->{_voiceVlan} . "",
    );
}


=head2 getIfIndexByNasPortId

Returns 0 since this needs to be skipped as the info is in the NAS port

=cut

sub getIfIndexByNasPortId {
    return 0;
}

=head2 NasPortToIfIndex

Translate RADIUS NAS-Port into the physical port ifIndex
Just returns the NAS-Port

=cut

sub NasPortToIfIndex {
    my ($self, $NAS_port) = @_;
    my $logger = $self->logger;

    $logger->debug("Found $NAS_port for ifindex");

    return $NAS_port;
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
