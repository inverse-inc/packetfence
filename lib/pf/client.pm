package pf::client;
=head1 NAME

pf::client 

=cut

=head1 DESCRIPTION

pf::client managing which api client should be used

=cut

use strict;
use warnings;
use pf::config;
use List::MoreUtils qw(any);
use Module::Pluggable
  search_path => 'pf::api',
  sub_name    => 'modules',
  inner       => 0,
  require     => 1;
use pf::cluster;
use pf::constants::api;

my @MODULES = __PACKAGE__->modules;

our $CURRENT_CLIENT = $pf::constants::api::DEFAULT_CLIENT;

=head2 setClient

sets the global client to use

=cut

sub setClient {
    my ($clienttype) = @_;
    return unless any { $_ eq $clienttype } @MODULES; 
    $CURRENT_CLIENT= $clienttype;
}

=head2 getClient

gets the currently configured client

=cut

sub getClient {
    $CURRENT_CLIENT ||= $pf::constants::api::DEFAULT_CLIENT;
    $CURRENT_CLIENT->new;
}

sub getManagementClient {
    if($cluster_enabled) {
        return $pf::constants::api::DEFAULT_CLIENT->new(proto => 'https', host => pf::cluster::management_cluster_ip());
    }
    else {
        return getClient();
    }
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

