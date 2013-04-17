package pfappserver::Model::Config::Cached::Network;

=head1 NAME

pfappserver::Model::Config::Cached::Network add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Cached::Switch;

=cut

use Moose;
use namespace::autoclean;
use pf::config;
use pf::error qw(is_error is_success);

extends 'pfappserver::Base::Model::Config::Cached';

has '+idKey' => (default => 'network');

=head2 METHODS

=over

=head2 _buildCachedConfig

=cut

sub _buildCachedConfig { $pf::config::cached_network_config }

=head2 getRoutedNetworks

Return the routed networks for the specified network and mask.

=cut

sub getRoutedNetworks {
    my ($self, $network, $netmask) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my @networks;
    foreach my $section ( keys %ConfigNetworks ) {
        next if ($section eq $network);
        my $next_hop = $ConfigNetworks{$section}{next_hop};
        if ($next_hop && $self->getNetworkAddress($next_hop, $netmask) eq $network) {
            push @networks, $section;
        }
    }

    if (scalar @networks > 0) {
        @networks = sort @networks;
        return ($STATUS::OK, \@networks);
    } else {
        return ($STATUS::NOT_FOUND, "No routes for $network/$netmask found");
    }
}

=head2 getType

=cut

sub getType {
    my ($self, $network) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status, $type) = ($STATUS::NOT_FOUND, "");
    # skip if we don't have a network address set
    if (defined($network) && exists $ConfigNetworks{$network} && exists $ConfigNetworks{$network}{type}) {
        ($status, $type) = ($STATUS::OK, $ConfigNetworks{$network}{type});
    }

    return ($status, $type);
}

=head2 getNetworkAddress

Calculate the network address for the provided ipaddress/network combination

Returns undef on undef IP / Mask

=cut

sub getNetworkAddress {
    my ($self, $ipaddress, $netmask) = @_;

    return if ( !defined($ipaddress) || !defined($netmask) );
    return Net::Netmask->new($ipaddress, $netmask)->base();
}

=head2 cleanupNetworks

=cut

sub cleanupNetworks {
    my ($self, $interfaces) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $networks = $self->readAllIds();
    my %unused = map { $_ => 1 } @$networks;

    foreach my $interface (@$interfaces) {

        # Only check interface with an IP address
        next unless $interface->{ipaddress};

        # Check default network
        my $network = $self->getNetworkAddress($interface->{ipaddress}, $interface->{netmask});
        delete $unused{$network} if exists $unused{$network};

        # Check routed networks
        my ($status, $return) = $self->getRoutedNetworks($network, $interface->{netmask});
        if (is_success($status)) {
            foreach (@$return) {
                delete $unused{$_} if exists $unused{$_};
            }
        }

    }

    foreach my $network (keys %unused) {
        $logger->warn("Remmoving unused network $network");
        $self->remove($network);
    }

    return (scalar %unused);
}

=head2 cleanupBeforeCommit

Set default values before update or creating

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $network) = @_;

    # Set default values
    $network->{named} = 'enabled' unless ($network->{named});
    $network->{dhcpd} = 'enabled' unless ($network->{dhcpd});
}

__PACKAGE__->meta->make_immutable;

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

