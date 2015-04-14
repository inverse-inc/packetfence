package pf::services::manager::haproxy;
=head1 NAME

pf::services::manager::haproxy add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::haproxy

=cut

use strict;
use warnings;
use Moo;
use IPC::Cmd qw[can_run run];
use List::MoreUtils qw(uniq);
use POSIX;
use pf::config;
use pf::log;
use pf::util;
use pf::cluster;

extends 'pf::services::manager';

has '+name' => (default => sub { 'haproxy' } );

has '+launcher' => (default => sub { "sudo %1\$s -f $generated_conf_dir/haproxy.conf -D -p $var_dir/run/haproxy.pid" } );

has '+shouldCheckup' => ( default => sub { 0 }  );

sub executable {
    my ($self) = @_;
    my $service = ( $Config{'services'}{"haproxy_binary"} || "$install_dir/sbin/haproxy" );
    return $service;
}

sub generateConfig {
    my ($self,$quick) = @_;
    my $logger = get_logger();
    my ($package, $filename, $line) = caller();

    my %tags;
    $tags{'template'} = "$conf_dir/haproxy.conf";
    $tags{'http'} = '';
    $tags{'mysql_backend'} = '';
    if ($OS eq 'debian') {
        $tags{'os_path'} = '/etc/haproxy/errors/';
    } else {
         $tags{'os_path'} = '/usr/share/haproxy/';
    }
    my @ints = uniq(@listen_ints,@dhcplistener_ints);
    foreach my $interface ( @ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        my $i = 0;
        if ($interface eq $management_network->tag('int')) {
            $tags{'active_active_ip'} = pf::cluster::management_cluster_ip();
            my @mysql_backend = map { $_->{management_ip} } pf::cluster::mysql_servers();
            foreach my $mysql_back (@mysql_backend) {
                # the second server (the one without the VIP) will be the prefered MySQL server
                if ($i == 0) {
                $tags{'mysql_backend'} .= <<"EOT";
        server MySQL$i $mysql_back:3306 check
EOT
                } else {
                $tags{'mysql_backend'} .= <<"EOT";
        server MySQL$i $mysql_back:3306 check backup
EOT
                }
            $i++;
            }
            my $cluster_ip = pf::cluster::cluster_ip($interface);
            my @backend_ip = values %{pf::cluster::members_ips($interface)};
            my $backend_ip_config = '';
            foreach my $back_ip ( @backend_ip ) {

                $backend_ip_config .= <<"EOT";
        server $back_ip $back_ip:80 check
EOT
            }

            $tags{'http'} .= <<"EOT";
frontend portal-http-mgmt
        bind $cluster_ip:80
        reqadd X-Forwarded-Proto:\\ http
        default_backend portal-mgmt-backend

frontend portal-https-mgmt
        bind $cluster_ip:443 ssl crt /usr/local/pf/conf/ssl/server.pem
        reqadd X-Forwarded-Proto:\\ https
        default_backend portal-mgmt-backend

backend portal-mgmt-backend
        balance source
        option httpclose
        option forwardfor
$backend_ip_config

EOT
        }
        if ($cfg->{'type'} eq 'internal') {
            my $cluster_ip = pf::cluster::cluster_ip($interface);
            my @backend_ip = values %{pf::cluster::members_ips($interface)};
            my $backend_ip_config = '';
            foreach my $back_ip ( @backend_ip ) {

                $backend_ip_config .= <<"EOT";
        server $back_ip $back_ip:80 check
EOT
            }
 
            $tags{'http'} .= <<"EOT";
frontend portal-http-$cluster_ip
        bind $cluster_ip:80
        reqadd X-Forwarded-Proto:\\ http
        default_backend $cluster_ip-backend

frontend portal-https-$cluster_ip
        bind $cluster_ip:443 ssl crt /usr/local/pf/conf/ssl/server.pem
        reqadd X-Forwarded-Proto:\\ https
        default_backend $cluster_ip-backend

backend $cluster_ip-backend
        balance source
        option httpclose
        option forwardfor
$backend_ip_config

EOT

        }
    }

    parse_template( \%tags, "$conf_dir/haproxy.conf", "$generated_conf_dir/haproxy.conf" );
    return 1;
}

sub preStartSetup {
    my ($self,$quick) = @_;
    $self->SUPER::preStartSetup($quick);
    return 1;
}

sub stop {
    my ($self,$quick) = @_;
    my $result = $self->SUPER::stop($quick);
    return $result;
}

sub isManaged {
    my ($self) = @_;
    return $cluster_enabled;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>



=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
