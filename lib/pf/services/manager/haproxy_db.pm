package pf::services::manager::haproxy_db;
=head1 NAME

pf::services::manager::haproxy_db add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::haproxy_db

=cut

use strict;
use warnings;
use Moo;

use List::MoreUtils qw(uniq);

use pf::log;
use pf::util;
use pf::cluster;
use pf::config qw(
    %Config
    $OS
    @listen_ints
    @dhcplistener_ints
    $management_network
    @portal_ints
);
use pf::file_paths qw(
    $generated_conf_dir
    $install_dir
    $conf_dir
    $var_dir
    $captiveportal_templates_path
);

use pf::constants qw($TRUE $FALSE);

extends 'pf::services::manager::haproxy';

has '+name' => (default => sub { 'haproxy-db' } );

has '+haproxy_config_template' => (default => sub { "$conf_dir/haproxy-db.conf" });

our $host_id = $pf::config::cluster::host_id;
tie our %clusters_hostname_map, 'pfconfig::cached_hash', 'resource::clusters_hostname_map';

sub generateConfig {
    my ($self,$quick) = @_;
    my $logger = get_logger();
    my ($package, $filename, $line) = caller();

    my %tags;
    $tags{'template'} = $self->haproxy_config_template;
    $tags{'http'} = '';
    $tags{'mysql_backend'} = '';
    $tags{'mysql_probe'} = '';
    $tags{'var_dir'} = $var_dir;
    $tags{'conf_dir'} = $var_dir.'/conf';
    $tags{'timeout'} = $Config{'database_advanced'}{'net_write_timeout'} * 1000;
    $tags{'management_ip_frontend'} = '';
    if ($OS eq 'debian') {
        $tags{'os_path'} = '/etc/haproxy/errors/';
    } else {
         $tags{'os_path'} = '/usr/share/haproxy/';
    }
    
    $tags{'management_ip'}
        = defined( $management_network->tag('vip') )
        ? $management_network->tag('vip')
        : $management_network->tag('ip');

    my $i = 0;
    my @mysql_backend;

    if ($cluster_enabled) {
        if (isenabled($Config{active_active}{probe_mysql_from_haproxy_db}) && isenabled($Config{'services'}{'mysql-probe'})){
            $tags{'mysql_probe'} = <<"EOT";
    option httpchk
    default-server port 3307 inter 2s downinter 5s rise 3 fall 2 slowstart 60s maxconn 64 maxqueue 128 weight 100
EOT
        }
        my $management_ip = pf::cluster::management_cluster_ip();
        if (pf::cluster::isSlaveMode()) {
            if (pf::cluster::getDBMaster()) {
                 push(@mysql_backend, pf::cluster::getDBMaster());
            }
            push(@mysql_backend, $tags{'management_ip'});
        } else {
            @mysql_backend = map { $_->{management_ip} } pf::cluster::mysql_servers();
        }
        $tags{'management_ip_frontend'} = <<"EOT";
frontend  management_ip
    bind $management_ip:3306
    mode tcp
    option tcplog
    default_backend             mysql
EOT
    } else {
        @mysql_backend = split(',', $Config{database_advanced}{other_members});
        push(@mysql_backend, $tags{'management_ip'});
        @mysql_backend = sort @mysql_backend;
        $tags{'management_ip_frontend'} = '';
    }
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
    
    $tags{captiveportal_templates_path} = $captiveportal_templates_path;
    parse_template( \%tags, $self->haproxy_config_template, "$generated_conf_dir/".$self->name.".conf" );

    return 1;
}

sub isManaged {
    my ($self) = @_;
    my $name = $self->name;
    if (isenabled($pf::config::Config{'services'}{$name})) {
        if ($cluster_enabled && pf::cluster::isSlaveMode()) {
            return $TRUE;
        }
        return $cluster_enabled;
    } else {
        return 0;
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>



=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
