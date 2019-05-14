package pf::ConfigStore::RoutedNetwork;

=head1 NAME

pf::ConfigStore::RoutedNetwork

=head1 DESCRIPTION

ConfigStore for routed networks in networks.conf

=cut

use Moo;
use namespace::autoclean;
use pf::log;
use pf::config qw(%ConfigNetworks %Config);
use pf::util qw(isenabled);
use pf::file_paths qw($network_config_file);

extends 'pf::ConfigStore::Network';
with 'pf::ConfigStore::Filtered';

=head1 METHODS

=cut

=head2 filter

Filter the sections of this ConfigStore

=cut

sub filter { 
    my ($self, $section) = @_;
    return $self->cachedConfig->exists($section, "next_hop");
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
