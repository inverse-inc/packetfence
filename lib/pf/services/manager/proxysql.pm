package pf::services::manager::proxysql;

=head1 NAME

pf::services::manager::proxysql add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::proxysql

=cut

use strict;
use warnings;
use Moo;

use List::MoreUtils qw(uniq);

use pf::log;
use pf::util;
use pf::cluster;
use pf::constants qw($TRUE $FALSE);
use pf::config qw(
    %Config
    $management_network
);
use pf::file_paths qw(
    $generated_conf_dir
    $conf_dir
);

use Template;

use Moo;
extends 'pf::services::manager';

has '+name' => (default => sub { 'proxysql' } );

has '+shouldCheckup' => ( default => sub { 0 }  );

has 'proxysql_config_template' => (is => "rw" ,default => sub { "$conf_dir/proxysql.conf" });

our $host_id = $pf::config::cluster::host_id;

tie our %clusters_hostname_map, 'pfconfig::cached_hash', 'resource::clusters_hostname_map';

our $DB_Config;

tie %$DB_Config, 'pfconfig::cached_hash', 'resource::Database';

sub generateConfig {
    my ($self,$quick) = @_;
    my $tt = Template->new(ABSOLUTE => 1);

    my $logger = get_logger();
    my ($package, $filename, $line) = caller();

    my %tags;
    $tags{'template'} = $self->proxysql_config_template;
    $tags{'geoDB'} = $FALSE;
    $tags{'mysql_servers'} = "";

    $tags{'monitor'} = << "EOT";
    monitor_username="$DB_Config->{user}"
    monitor_password="$DB_Config->{pass}"
EOT

    $tags{'mysql_users'} = << "EOT";
        { username = "$DB_Config->{user}", password = "$DB_Config->{pass}", default_hostgroup = 10, transaction_persistent = 0, active = 1 },
EOT

    my $i = 100;
    if (pf::cluster::getMasterDB()) {
        $tags{'geoDB'} = $TRUE unless $db_stack eq "galera";
        my @mysql_write_backend = pf::cluster::getMasterDB();
        my @mysql_read_backend = pf::cluster::getReadDB();

	foreach my $mysql_back (@mysql_write_backend) {
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=3306 , hostgroup=10, max_connections=1000, weight=$i },

EOT
        $i--;
        }
        $i = 100;
        foreach my $mysql_back (@mysql_read_backend) {
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=3306 , hostgroup=30, max_connections=1000, weight=$i },

EOT
        $i--;
        }
    } else {
        my @mysql_backend;

        @mysql_backend = map { $_->{management_ip} } pf::cluster::mysql_servers();

        foreach my $mysql_back (@mysql_backend) {
        $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=3306 , hostgroup=10, max_connections=1000, weight=$i },
EOT
        $i--;
        }
    }
    $tt->process($self->proxysql_config_template, \%tags, "$generated_conf_dir/".$self->name.".conf") or die $tt->error();

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

=head1 AUTHOR

Inverse inc. <info@inverse.ca>



=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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
