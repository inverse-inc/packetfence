package pf::Switch::Meraki::MS220_8;

=head1 NAME

pf::Switch::Meraki::MS220_8

=head1 SYNOPSIS

The pf::Switch::Meraki::MS220_8 module implements an object oriented interface to
manage the connection with MS220_8 switch model.

=head1 STATUS

Developed and tested on a MS220_8P (P standing for PoE) switch

=head1 BUGS AND LIMITATIONS

=head2 Cannot detect VoIP devices

VoIP devices cannot be detected via CDP/LLDP via an SNMP lookup.

=cut

use strict;
use warnings;

use base ('pf::Switch::Meraki');

use pf::config qw(
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);
use pf::constants;
use pf::util;
use pf::node;
use pf::util::radius qw(perform_coa);
use Try::Tiny;
use pf::Switch::Meraki::MR_v2;

=head1 SUBROUTINES

=cut

# CAPABILITIES
# access technology supported
sub description { 'Meraki switch MS220_8' }
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
sub supportsRadiusVoip { return $TRUE; }

sub isVoIPEnabled {
    my ($self) = @_;
    return isenabled($self->{_VoIPEnabled});
}

=head2 getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut

sub getVoipVsa {
    my ($self) = @_;
    my $logger = $self->logger;

    return ('Cisco-AVPair' => "device-traffic-class=voice");
}

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
    my $user_name       = $radius_request->{'PacketFence-UserNameAttribute'} || $radius_request->{'TLS-Client-Cert-Subject-Alt-Name-Upn'} || $radius_request->{'TLS-Client-Cert-Common-Name'} || $radius_request->{'User-Name'};
    my $nas_port_type   = $radius_request->{'NAS-Port-Type'};
    my $port            = $radius_request->{'NAS-Port'};
    my $eap_type        = ( exists($radius_request->{'EAP-Type'}) ? $radius_request->{'EAP-Type'} : 0 );
    my $nas_port_id     = ( defined($radius_request->{'NAS-Port-Id'}) ? $radius_request->{'NAS-Port-Id'} : undef );
    my $session_id = $self->getCiscoAvPairAttribute($radius_request, "audit-session-id");
    return ($nas_port_type, $eap_type, $client_mac, $port, $user_name, $nas_port_id, $session_id, $nas_port_id);
}

=head2 wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques {
   my ($self, $method, $connection_type) = @_;
   my $logger = $self->logger;

    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    elsif ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );
        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    else{
        $logger->error("This authentication mode is not supported");
    }

}

=head2 deauthenticateMacRadius

Method to deauth a wired node with RADIUS Disconnect.

=cut

sub deauthenticateMacRadius {
    my ($self, $ifIndex,$mac) = @_;
    my $logger = $self->logger;

    $self->radiusDisconnect($mac );
}

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = $self->logger;
    # Use the same disconnect method as the Meraki MR v2
    pf::Switch::Meraki::MR_v2::radiusDisconnect(@_);
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
