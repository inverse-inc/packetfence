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

sub _run {
    my ($self) = @_;
    my $tt = Template->new(ABSOLUTE => 1);

    my %vars = (
        # TODO: migrate those to pf.conf.defaults
        key_buffer_size => $Config{database}{key_buffer_size},
        innodb_buffer_pool_size => $Config{database}{innodb_buffer_pool_size},
        innodb_additional_mem_pool_size => $Config{database}{innodb_additional_mem_pool_size},
        query_cache_size => $Config{database}{query_cache_size},
        thread_concurrency => $Config{database}{thread_concurrency},
        max_connections => $Config{database}{max_connections},
        table_cache => $Config{database}{table_cache},

    );

    if($cluster_enabled) {
        %vars = (
            %vars,

            cluster_enabled => $cluster_enabled,

            server_ip => pf::cluster::current_server()->{management_ip},
            servers_ip => [(map { $_->{management_ip} } @cluster_servers)],

            # TODO: have real configurable user
            replication_user => "zammit",
            replication_password => "isnotadog",

            server_id => (pf::cluster::cluster_index() + 1),
        );
    }

    $tt->process("$conf_dir/mariadb.conf.tt", \%vars, "$install_dir/var/conf/mariadb.conf") or die $tt->error();
    return $EXIT_SUCCESS; 
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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


