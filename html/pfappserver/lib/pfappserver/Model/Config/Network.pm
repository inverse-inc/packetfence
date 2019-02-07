package pfappserver::Model::Config::Network;

=head1 NAME

pfappserver::Model::Config::Network add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Network

=cut

use Moose;
use namespace::autoclean;
use pf::config;
use pf::error qw(is_error is_success);
use pf::util qw(sort_ip);
use pf::ConfigStore::Network;

extends 'pfappserver::Base::Model::Config';

has '+idKey' => (default => 'network');

=head1 METHODS

=head2 _buildCachedConfig

=cut

sub _buildConfigStore { pf::ConfigStore::Network->new }

=head2 getRoutedNetworks

Return the routed networks for the specified network and mask.

=cut

sub getRoutedNetworks {
    my ($self, $network, $netmask) = @_;
    my @networks = @{$self->configStore->getRoutedNetworks($network,$netmask)};
    if (scalar @networks > 0) {
        @networks = sort_ip @networks;
        return ($STATUS::OK, \@networks);
    } else {
        return ($STATUS::NOT_FOUND, "No routes for [_1]/[_2] found",$network,$netmask);
    }
}

=head2 getType

=cut

sub getType {
    my ($self, $network) = @_;
    my $type = $self->configStore->getType($network);
    my $status;
    if($type) {
    # skip if we don't have a network address set
        $status = $STATUS::OK;
    }
    else {
        $status = $STATUS::NOT_FOUND;
        $type = "";
    }
    return ($status, $type);
}

=head2 getTypes

Returns an hashref with

    $interface => $type

For example

    eth0 => vlan-isolation

=cut

sub getTypes {
    my ( $self, $interfaces_ref ) = @_;
    return ($STATUS::OK, $self->configStore->getTypes($interfaces_ref));
}

=head2 getNetworkAddress

Calculate the network address for the provided ipaddress/network combination

Returns undef on undef IP / Mask

=cut

sub getNetworkAddress {
    my ($self, $ipaddress, $netmask) = @_;
    return $self->configStore->getNetworkAddress($ipaddress, $netmask);
}

=head2 cleanupNetworks

=cut

sub cleanupNetworks {
    my ($self, $interfaces) = @_;
    return $self->configStore->cleanupNetworks($interfaces);
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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

