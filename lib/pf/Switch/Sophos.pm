package pf::Switch::Sophos;

=head1 NAME

pf::Switch::Shophos - Object oriented module to Sophos

=head1 SYNOPSIS

The pf::Switch::Shophos  module implements an object oriented interface to interact with the Shophos

=head1 STATUS



=cut

use strict;
use warnings;
use List::Util qw/shuffle/;

use base ('pf::OpenVPN');

=head1 METHODS

=cut

sub description { 'ShophosVPN' }

use pf::SwitchSupports qw(
    VPN
);

=item parseVPNRequest

Redefinition of pf::Switch::parseVPNRequest due to specific attribute being used

=cut

sub parseVPNRequest {
    my ( $self, $radius_request ) = @_;
    my $logger = $self->logger;
    # Generate a fake mac address
    my $mac = join "", shuffle split //, $radius_request->{'User-Name'};
    $mac = substr $sorted, 0, 6;
    $mac = =~ s/(.)/sprintf '%02x', ord $1/seg;

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

Copyright (C) 2005-2022 Inverse inc.

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
