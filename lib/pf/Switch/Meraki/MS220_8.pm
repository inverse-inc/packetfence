package pf::Switch::Meraki::MS220_8;

=head1 NAME

pf::Switch::Meraki::MS220_8

=head1 SYNOPSIS

The pf::Switch::Meraki::MS220_8 module implements an object oriented interface to
manage the connection with MS220_8 switch model.

=head1 STATUS

Developed and tested on a MS220_8P (P standing for PoE) switch

=head1 BUGS AND LIMITATIONS

The firmware allow only for VLAN enforcement at the moment. We cannot push the predefined policies from PacketFence.

=head2 Cannot reevaluate the access

There is currently no way to reevaluate the access of the device.
There is neither an API access or a RADIUS disconnect that can be sent either to the switch.

=cut

use strict;
use warnings;

use base ('pf::Switch::Meraki');

use pf::constants;
use pf::config;
use pf::util;
use pf::node;

=head1 SUBROUTINES

=cut

# CAPABILITIES
# access technology supported
sub description { 'Meraki switch MS220_8' }
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }

=head2 getVersion 

obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    $logger->info("we don't know how to determine the version through SNMP !");
    return '1';
}

=head2 parseRequest

Redefinition of pf::Switch::parseRequest due to specific attribute being used by Meraki

=cut

sub parseRequest {
    my ( $self, $radius_request ) = @_;
    my $client_mac      = ref($radius_request->{'Calling-Station-Id'}) eq 'ARRAY'
                           ? clean_mac($radius_request->{'Calling-Station-Id'}[0])
                           : clean_mac($radius_request->{'Calling-Station-Id'});
    my $user_name       = $radius_request->{'TLS-Client-Cert-Common-Name'} || $radius_request->{'User-Name'};
    my $nas_port_type   = $radius_request->{'NAS-Port-Type'};
    my $port            = $radius_request->{'NAS-Port'};
    my $eap_type        = ( exists($radius_request->{'EAP-Type'}) ? $radius_request->{'EAP-Type'} : 0 );
    my $nas_port_id     = ( defined($radius_request->{'NAS-Port-Id'}) ? $radius_request->{'NAS-Port-Id'} : undef );

    my $session_id;
    if (defined($radius_request->{'Cisco-AVPair'})) {
        if ($radius_request->{'Cisco-AVPair'} =~ /audit-session-id=(.*)/ig ) {
            $session_id =$1;
        }
    }
    return ($nas_port_type, $eap_type, $client_mac, $port, $user_name, $nas_port_id, $session_id);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
