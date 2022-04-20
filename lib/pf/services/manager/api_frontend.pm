package pf::services::manager::api_frontend;

=head1 NAME

pf::services::manager::api_frontend - The service manager for the api_frontend  service

=cut

=head1 DESCRIPTION

pf::services::manager::api_frontend

=cut

use strict;
use warnings;
use Moo;
use pf::config qw(%Config);

extends 'pf::services::manager';

has '+name' => ( default => sub { 'api-frontend' } );

sub generateConfig {
    my ($self) = @_;
    my $tt = Template->new(ABSOLUTE => 1);
    my $vars = {
       env_dict => {
           LOG_OUTPUT => 'stdout',
           PFCONFIG_PROTO => 'tcp',
           PFCONFIG_TCP_HOST => 'host.docker.internal',
           PF_SERVICES_URL_PFPKI => $Config{services_url}{pfpki},
           PF_SERVICES_URL_PFIPSET => $Config{services_url}{pfipset},
           PF_SERVICES_URL_PFDHCP => $Config{services_url}{pfdhcp},
           PF_SERVICES_URL_PFPERL_API => $Config{services_url}{'pfperl-api'},
           PF_SERVICES_URL_PFDNS_DOH => $Config{services_url}{'pfdns-doh'},
           PF_SERVICES_URL_PFSSO => $Config{services_url}{pfsso},
           STATSD_ADDRESS => $Config{advanced}{statsd_listen_host}.":".$Config{advanced}{statsd_listen_port},
       }, 
    };
    $tt->process("/usr/local/pf/docker/caddy-environment.template", $vars, "/usr/local/pf/var/conf/api-frontend.env") or die $tt->error();
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
