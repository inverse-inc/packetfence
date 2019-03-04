package pf::cmd::pf::generatemariadbconfig;
=head1 NAME

pf::cmd::pf::generatemariadbconfig

=head1 SYNOPSIS

 pfcmd generatemariadbconfig

generates the OS configuration for the domain binding

=head1 DESCRIPTION

pf::cmd::pf::generatemariadbconfig

=cut

use strict;
use warnings;

use base qw(pf::cmd);

use Template;
use pf::file_paths qw(
    $conf_dir
    $install_dir
);
use pf::cluster;
use pf::constants::exit_code qw($EXIT_SUCCESS);
use pf::config qw(
    %Config
    $management_network
    $DISTRIB
);
use pf::util;

sub _run {
    my ($self) = @_;
    my $tt = Template->new(ABSOLUTE => 1);

    my %vars = (
        key_buffer_size => $Config{database_advanced}{key_buffer_size},
        innodb_buffer_pool_size => $Config{database_advanced}{innodb_buffer_pool_size},
        innodb_additional_mem_pool_size => $Config{database_advanced}{innodb_additional_mem_pool_size},
        query_cache_size => $Config{database_advanced}{query_cache_size},
        thread_concurrency => $Config{database_advanced}{thread_concurrency},
        max_connections => $Config{database_advanced}{max_connections},
        table_cache => $Config{database_advanced}{table_cache},
        max_allowed_packet => $Config{database_advanced}{max_allowed_packet},
        thread_cache_size => $Config{database_advanced}{thread_cache_size},
        server_ip => $management_network ? $management_network->{Tvip} // $management_network->{Tip} : "",
    );

    # Only generate cluster configuration if there is more than 1 enabled host in the cluster
    if(isenabled($Config{active_active}{galera_replication}) && $cluster_enabled && scalar(pf::cluster::db_enabled_hosts()) > 1) {
        %vars = (
            %vars,

            cluster_enabled => $cluster_enabled,

            server_ip => pf::cluster::current_server()->{management_ip},
            servers_ip => [(map { $_->{management_ip} } pf::cluster::mysql_servers())],

            # TODO: have real configurable user
            replication_user => $Config{active_active}{galera_replication_username},
            replication_password => $Config{active_active}{galera_replication_password},

            hostname => $host_id,
            server_id => (pf::cluster::cluster_index() + 1),

            db_config => $Config{database},
        );
        if ($DISTRIB eq 'debian') {
            $vars{'libgalera'} = '/usr/lib/galera/libgalera_smm.so';
        } else {
            $vars{'libgalera'} = '/usr/lib64/galera/libgalera_smm.so';
        }
    }

    my $maria_conf = "$install_dir/var/conf/mariadb.conf";
    $tt->process("$conf_dir/mariadb/mariadb.conf.tt", \%vars, $maria_conf) or die $tt->error();
    chmod 0644, $maria_conf;
    
    my $db_update_path = "$install_dir/var/run/db-update";
    $tt->process("$conf_dir/mariadb/db-update.tt", \%vars, $db_update_path) or die $tt->error();
    chmod 0744, $db_update_path;
    user_chown("mysql", $db_update_path);

    my $db_check_path = "$install_dir/var/run/db-check";
    $tt->process("$conf_dir/mariadb/db-check.tt", \%vars, $db_check_path) or die $tt->error();
    chmod 0744, $db_check_path;
    pf_chown($db_check_path);

    return $EXIT_SUCCESS; 
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

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


