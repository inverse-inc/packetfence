package pf::UnifiedApi::Controller::Config::RoutedNetworks;

=head1 NAME

pf::UnifiedApi::Controller::Config::RoutedNetworks - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::RoutedNetworks



=cut

use strict;
use warnings;


use Mojo::Base qw(pf::UnifiedApi::Controller::Config);

has 'config_store_class' => 'pf::ConfigStore::RoutedNetwork';
has 'form_class' => 'pfappserver::Form::Config::Network::Routed';
has 'primary_key' => 'network_id';

use pf::ConfigStore::RoutedNetwork;
use pfappserver::Form::Config::Network::Routed;

=head2 get_json

Override parent method to set the id to the network value as it is required for validation in pf::UnifiedApi::Controller::Config

=cut

sub get_json {
    my ($self) = @_;
    my ($error, $data) = $self->SUPER::get_json();
    if (defined $error) {
        return ($error, $data);
    }
    if(my $id = $self->stash('network_id')) {
        $data->{network} = $id;
    }
    return ($error, $data);
}

=head2 form

Override to add the network ID in the form args if its defined

=cut

sub form {
    my ($self, $item, @args) = @_;
    if(my $id = $self->stash('network_id')) {
        push @args, network => $id;
    }
    return $self->SUPER::form($item, @args);
}

=head2 cleanup_item

Override to remove the network key from the items in favor of id

=cut

sub cleanup_item {
    my ($self, $item) = @_;
    $item = $self->SUPER::cleanup_item($item);
    $item->{id} = delete $item->{network};
    return $item;
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

