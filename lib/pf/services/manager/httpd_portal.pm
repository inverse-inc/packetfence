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

=head2 startDependsOnServices

services that the httpd.portal depends on

=cut

around startDependsOnServices => sub {
    my ($orig, $self) = (shift, shift);
    my $startDependsOnServices = $self->$orig(@_);
    push @$startDependsOnServices,'redis_queue';
    return $startDependsOnServices;
};

sub additionalVars {
    my ($self) = @_;
    my $captive_portal = Clone::clone($Config{'captive_portal'});
    foreach my $param (qw(httpd_mod_qos httpd_mod_evasive status_only_on_production httpd_mod_evasive)){
        $captive_portal->{$param} = isenabled($captive_portal->{$param});
    }
    my %vars = (
        captive_portal => $captive_portal,
        max_clients => $self->get_max_clients,
        routedNets => $self->routedNets,
        loadbalancersIp => $self->loadbalancersIp($captive_portal),
        vhost_management_network => $self->vhost_management_network,
        dos_system_cmd => $self->dos_system_cmd($captive_portal),
        vhosts => $self->vhosts,
        logformat => isenabled($cluster_enabled) ? 'loadbalanced_combined' : 'combined',
    );
    $vars{qos} = $vars{max_clients} * 0.7;
    return %vars;
}

=head2 dos_system_cmd

Get the final DOS system command

=cut

sub dos_system_cmd {
    my ($self, $captive_portal) = @_;
    my $cmd = $captive_portal->{httpd_mod_evasive_system_command};
    if (defined $cmd && $cmd ne '') {
        $cmd =~ s/\%t/$captive_portal->{httpd_mod_evasive_blocking_period}/;
    }
    return $cmd;
}

=head2 vhost_management_network

Get the vhost for the managment network

=cut

sub vhost_management_network {
    my ($self) = @_;
    my $vhost;
    if (defined($management_network->{'Tip'}) && $management_network->{'Tip'} ne '') {
        # Handling virtual IP
        if (defined($management_network->{'Tvip'}) && $management_network->{'Tvip'} ne '') {
            $vhost = $management_network->{'Tvip'};
        }
        else {
            $vhost = $management_network->{'Tip'};
        }
    }
    return $vhost;
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
    return [
        map {
            defined $_->{'Tvip'} && $_->{'Tvip'} ne '' ? $_->{'Tvip'} : $_->{'Tip'}
        } uniq @internal_nets, @portal_ints
    ];
}

=head2 routedNets

Get the routed nets

=cut

sub routedNets {
    my ($self) = @_;
    return join(" ", pf::config::util::get_routed_isolation_nets(), pf::config::util::get_routed_registration_nets() , pf::config::util::get_inline_nets());
}

=head2 loadbalancersIp

Get the load balancers IP address

=cut

sub loadbalancersIp {
    my ($self, $captive_portal) = @_;
    return join(" ", split(/\n/, $captive_portal->{'loadbalancers_ip'}));
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
