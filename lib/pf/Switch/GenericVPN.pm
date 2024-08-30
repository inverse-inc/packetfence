package pf::Switch::GenericVPN;

=head1 NAME

pf::Switch::GenericVPN - Object oriented module to manage generic VPN

=head1 SYNOPSIS

The pf::Switch::GenericVPN  module implements an object oriented interface to interact with a generic VPN

=head1 STATUS



=cut

use strict;
use warnings;
use pf::util;
use pf::log;
use pf::constants;
use pf::config qw ($VIRTUAL_VPN);
use Readonly;

use base ('pf::Switch');

=head1 METHODS

=cut

sub description { 'GenericVPN' }

use pf::SwitchSupports qw(
    VPN
);

=item getIfIndexByNasPortId

Return constant sice there is no ifindex

=cut

sub getIfIndexByNasPortId {
   return 'external';
}


sub getVersion {
    my ($self) = @_;
    return 0;
}

=item identifyConnectionType

Force VPN since it does only that

=cut


sub identifyConnectionType {
    my ( $self, $connection, $radius_request ) = @_;
    my $logger = $self->logger;

    $connection->isVPN($TRUE);
    $connection->isCLI($FALSE);
}


=item returnAuthorizeVPN

Return radius attributes to allow VPN access

=cut

sub returnAuthorizeVPN {
    my ($self, $args) = @_;
    my $logger = $self->logger;


    my $radius_reply_ref = {};
    my $status;
    # should this node be kicked out?
    my $kick = $self->handleRadiusDeny($args);
    return $kick if (defined($kick));

    my $node = $args->{'node_info'};
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    $logger->info("Returning ACCEPT");
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=item parseVPNRequest

Redefinition of pf::Switch::parseVPNRequest due to specific attribute being used

=cut

sub parseVPNRequest {
    my ( $self, $radius_request ) = @_;
    my $logger = $self->logger;

    my $mac;
    my $client_ip       = $radius_request->{'Calling-Station-Id'};
    $mac                = '02:00:' . join(':', map { sprintf("%02x", $_) } split /\./, $radius_request->{'Calling-Station-Id'}) if (exists $radius_request->{'Calling-Station-Id'});
    my $user_name       = $self->parseRequestUsername($radius_request);
    my $nas_port_type   = $radius_request->{'NAS-Port-Type'};
    my $port            = $radius_request->{'NAS-Port'};
    my $eap_type        = ( exists($radius_request->{'EAP-Type'}) ? $radius_request->{'EAP-Type'} : 0 );
    my $nas_port_id     = ( defined($radius_request->{'NAS-Port-Id'}) ? $radius_request->{'NAS-Port-Id'} : undef );

    return ($nas_port_type, $eap_type, $mac, $port, $user_name, $nas_port_id, undef, $nas_port_id);
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
