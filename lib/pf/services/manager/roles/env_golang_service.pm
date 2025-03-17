package pf::services::manager::roles::env_golang_service;
=head1 NAME

pf::services::manager::roles::env_golang_service

=cut

=head1 DESCRIPTION

pf::services::manager::roles::env_golang_service

=cut

use strict;
use warnings;

use Moo::Role;
use pf::config qw(%Config $management_network);
use pfconfig::config;

before generateConfig => sub {
    my $self = shift;
    my $tt = Template->new(ABSOLUTE => 1);
    my $pfconfig_config = $pfconfig::config::INI_CONFIG;
    my $service_env = $self->env_golang_service_service_env();
    my $vars = {
       env_dict => {
           %$service_env,
           LOG_OUTPUT => 'stdout',
           PFCONFIG_PROTO => $pfconfig_config->section("general")->{proto},
           PFCONFIG_TCP_HOST => $pfconfig_config->section("general")->{tcp_host},
           PFCONFIG_TCP_PORT => $pfconfig_config->section("general")->{tcp_port},
           PF_SERVICES_URL_PFPKI => $Config{services_url}{pfpki},
           PF_SERVICES_URL_PFIPSET => $Config{services_url}{pfipset},
           PF_SERVICES_URL_PFDHCP => $Config{services_url}{pfdhcp},
           PF_SERVICES_URL_PFPERL_API => $Config{services_url}{'pfperl-api'},
           PF_SERVICES_URL_PFDNS_DOH => $Config{services_url}{'pfdns-doh'},
           PF_SERVICES_URL_PFSSO => $Config{services_url}{pfsso},
           PF_SERVICES_URL_PFLDAPEXPLORER => $Config{services_url}{pfldapexplorer},
           PF_SERVICES_URL_PFCONNECTOR_SERVER => $Config{services_url}{'pfconnector-server'},
           PF_SERVICES_URL_NETDATA =>  $Config{services_url}{netdata},
           STATSD_ADDRESS => $Config{advanced}{statsd_listen_host}.":".$Config{advanced}{statsd_listen_port},
           PFCONNECTOR_SERVER_DYN_REVERSE_HOST => $management_network ? $management_network->{Tip} : '',
       },
    };
    $tt->process("/usr/local/pf/containers/environment.template", $vars, "/usr/local/pf/var/conf/".$self->name.".env") or die $tt->error();
};

=head2 env_golang_service_service_env

Allows pf::services::manager classes to define additional environment variables that will be configured in the env file

=cut

sub env_golang_service_service_env { {} }

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

