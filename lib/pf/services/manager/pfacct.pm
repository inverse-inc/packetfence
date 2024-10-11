package pf::services::manager::pfacct;

=head1 NAME

pf::services::manager::pfacct -

=head1 DESCRIPTION

pf::services::manager::pfacct

=cut

use strict;
use warnings;
use pf::util;
use Moo;
use Template;
use pf::log;
use pf::cluster;
use pf::config qw(
    $management_network
    %Config
    @radius_ints
);
use List::MoreUtils qw(any uniq);

extends 'pf::services::manager';
with 'pf::services::manager::roles::env_golang_service';

has '+name' => ( default => sub { 'pfacct' } );

=head2 generateConfig

Generate the configuration for pfacct

=cut

sub generateConfig {
    my ($self, $quick) = @_;

    $self->_generateConfig();
    return 1;
}

=head2 _generateConfig

Generate the configuration files for pfacct processes

=cut

sub _generateConfig {
    my ($self,$quick) = @_;
    my $tt = Template->new(ABSOLUTE => 1);
    $self->generate_container_environments($tt);
}

=head2 generate_container_environments

Generate the environment variables for running the container

=cut

sub generate_container_environments {
    my ($self, $tt) = @_;
    my $logger = get_logger();
    my @listen_ips;

    my $port = '-p 1813:1813/udp';
    my $port_save;
    my $listeningIp = "";
    if ($cluster_enabled || isenabled($Config{services}{radiusd_acct})) {
        my $management_ip = $management_network->tag('ip');
        $port = "-p $management_ip:1823:1813/udp";
        $port_save = "1823"
    }
    if ($cluster_enabled && isenabled($Config{services}{radiusd_acct})) {
        $port = "-p 1833:1813/udp";
        $port_save = "1833";
    }
    my $listen = $port;
    if (isenabled($Config{services}{radiusd_acct})) {
        $listeningIp = '127.0.0.1';
        $listen = "-p $listeningIp:$port_save:1813/udp";
    } else {
         if (!$cluster_enabled) {
            foreach my $interface ( uniq(@radius_ints) ) {
                push @listen_ips, $interface->tag('ip');
            }
            my @interfaces = map { $_.":1813:1813/udp" } @listen_ips;
            $listen = "-p " . join " -p ",@interfaces;
         }
    }
    my $vars = {
       env_dict => {
           PFACCT_ADDRESS=> "$listen",
       },
    };
    $tt->process("/usr/local/pf/containers/environment.template", $vars, "/usr/local/pf/var/conf/acct.env") or die $tt->error();
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
