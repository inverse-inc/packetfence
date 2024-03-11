package pf::services::manager::httpd_portal;

=head1 NAME

pf::services::manager::httpd_portal add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::httpd_portal

=cut

use strict;
use warnings;
use Moo;
use List::MoreUtils qw(uniq);
use Clone();
use pf::authentication();
use pf::config qw(
    %Config
    $management_network
    @internal_nets
    @portal_ints
);
use pf::util;
use pf::config::util;
use pf::constants::config;
use pf::web::constants();
use pf::cluster;

extends 'pf::services::manager::httpd';

has '+name' => (default => sub { 'httpd.portal' } );

sub additionalVars {
    my ($self) = @_;
    my $captive_portal = Clone::clone($Config{'captive_portal'});
    foreach my $param (qw(status_only_on_production secure_redirect)){
        $captive_portal->{$param} = isenabled($captive_portal->{$param});
    }
    my %vars = (
        captive_portal => $captive_portal,
        max_clients => $self->get_max_clients,
        vhost_management_network => $self->vhost_management_network,
        vhosts => $self->vhosts,
        logformat => isenabled($cluster_enabled) ? 'loadbalanced_combined' : 'combined',
    );
    return %vars;
}

=head2 vhost_management_network

Get the vhost for the managment network

=cut

sub vhost_management_network {
    my ($self) = @_;
    return "0.0.0.0";
}

=head2 get_max_clients

Get the Max Clients for the server

=cut

sub get_max_clients {
    my ($self) = @_;
    my $memory = pf::services::manager::httpd::get_total_system_memory();
    return pf::services::manager::httpd::calculate_max_clients($memory);
}


=head2 vhosts

Get vhosts

=cut

sub vhosts {
    my ($self) = @_;
    return ["0.0.0.0"];
}

sub apache_version {
    my ($self) = @_;
    #Apache version in the Docker container is 2.4
    return "2.4";
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
