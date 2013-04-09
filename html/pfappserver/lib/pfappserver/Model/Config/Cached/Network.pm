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

extends 'pfappserver::Base::Model::Config::Cached';


has '+idKey' => (default => 'network');

=head2 Methods

=over

=item _buildCachedConfig

=cut

sub _buildCachedConfig { $pf::config::cached_network_config }

=item getRoutedNetworks

Return the routed networks for the specified network and mask.

=cut

sub getRoutedNetworks {
    my ( $self, $network, $netmask ) = @_;
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
        return ($STATUS::NOT_FOUND,"No routes for $network/$netmask found");
    }
}

=item getType

=cut

sub getType {
    my ( $self, $network ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status, $type) = ($STATUS::NOT_FOUND,"");
    # skip if we don't have a network address set
    if (defined($network) && exists $ConfigNetworks{$network} && exists $ConfigNetworks{$network}{type}) {
        ($status, $type) = ($STATUS::OK,$ConfigNetworks{$network}{type});
    }

    return ($status, $type);
}

=item getNetworkAddress

Calculate the network address for the provided ipaddress/network combination

Returns undef on undef IP / Mask

=cut

sub getNetworkAddress {
    my ( $self, $ipaddress, $netmask ) = @_;

    return if ( !defined($ipaddress) || !defined($netmask) );
    return Net::Netmask->new($ipaddress, $netmask)->base();
}

__PACKAGE__->meta->make_immutable;


=back

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

