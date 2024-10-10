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

use base ('pf::Switch::Cisco::Cisco_IOS_15_0');
use pf::util qw(clean_mac);
use pf::log;
use pf::SwitchSupports qw(
    -DownloadableListBasedEnforcement
);

sub description { 'Cisco SG300' }

=head1 SUBROUTINES

=cut

# CAPABILITIES
# access technology supported
# inherited from Cisco_IOS_15_0
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

=head2 parseRequest

=cut

sub parseRequest {
    my ( $self, $radius_request ) = @_;

    my $client_mac      = ref($radius_request->{'Calling-Station-Id'}) eq 'ARRAY'
                           ? clean_mac($radius_request->{'Calling-Station-Id'}[0])
                           : clean_mac($radius_request->{'Calling-Station-Id'});
    my $user_name       = $self->parseRequestUsername($radius_request);
    my $nas_port_type   = ( defined($radius_request->{'NAS-Port-Type'}) ? $radius_request->{'NAS-Port-Type'} : "virtual" );
    my $port            = $radius_request->{'NAS-Port'};
    my $eap_type        = ( exists($radius_request->{'EAP-Type'}) ? $radius_request->{'EAP-Type'} : 0 );
    my $nas_port_id     = ( defined($radius_request->{'NAS-Port-Id'}) ? $radius_request->{'NAS-Port-Id'} : undef );

    return ($nas_port_type, $eap_type, $client_mac, $port, $user_name, $nas_port_id, undef, $nas_port_id);
}

=head2 returnAuthorizeRead

Return radius attributes to allow read access

=cut

sub returnAuthorizeRead {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    my $radius_reply_ref;
    my $status;
    $radius_reply_ref->{'Cisco-AVPair'} = 'shell:priv-lvl=1';
    $radius_reply_ref->{'Reply-Message'} = "Switch read access granted by PacketFence";
    $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with read access");
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeRead', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
