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


extends 'pf::services::manager::haproxy';

has '+name' => (default => sub { 'haproxy-db' } );

has '+haproxy_config_template' => (default => sub { "$conf_dir/haproxy-db.conf" });

sub generateConfig {
    my ($self,$quick) = @_;
    my $logger = get_logger();
    my ($package, $filename, $line) = caller();

    my %tags;
    $tags{'template'} = $self->haproxy_config_template;
    $tags{'http'} = '';
    $tags{'mysql_backend'} = '';
    $tags{'var_dir'} = $var_dir;
    $tags{'conf_dir'} = $var_dir.'/conf';
    if ($OS eq 'debian') {
        $tags{'os_path'} = '/etc/haproxy/errors/';
    } else {
         $tags{'os_path'} = '/usr/share/haproxy/';
    }
    
    my $i = 0;
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
    
    $tags{'active_active_ip'} = pf::cluster::management_cluster_ip();
    $tags{'management_ip'}
        = defined( $management_network->tag('vip') )
        ? $management_network->tag('vip')
        : $management_network->tag('ip');


    $tags{captiveportal_templates_path} = $captiveportal_templates_path;
    parse_template( \%tags, $self->haproxy_config_template, "$generated_conf_dir/".$self->name.".conf" );

    return 1;
}

sub isManaged {
    my ($self) = @_;
    my $name = $self->name;
    if (isenabled($pf::config::Config{'services'}{$name})) {
        return $cluster_enabled;
    } else {
        return 0;
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>



=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
