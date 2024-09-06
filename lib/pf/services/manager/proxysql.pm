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

has 'pxc_scheduler_handler_template' => (is => "rw" ,default => sub { "$conf_dir/config.toml" });

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
    my $single_server = 0;
    $tags{'template'} = $self->proxysql_config_template;
    $tags{'geoDB'} = $FALSE;
    $tags{'mysql_servers'} = "";
    $tags{'database'} = $DB_Config->{db};

    $tags{'monitor'} = << "EOT";
    monitor_username="$DB_Config->{user}"
    monitor_password="$DB_Config->{pass}"
EOT

    $tags{'mysql_users'} = << "EOT";
        { username = "$DB_Config->{user}", password = "$DB_Config->{pass}", default_hostgroup = 10, transaction_persistent = 0, active = 1 },
EOT

    my $i = 100;
    my $database_proxysql = $pf::config::Config{database_proxysql};

    if (isenabled($database_proxysql->{status})) {
        my $cacert = $database_proxysql->{cacert};
        if ($cacert) {
            $tags{'mysql_ssl_p2s_capath'} = << "EOT";
    mysql-ssl_p2s_capath = "$cacert";
EOT
        }

        $single_server = 1;
        my $backend = $database_proxysql->{backend};
        my $ssl = $cacert ? 1 : 0;
        $tags{mysql_servers} .= << "EOT";
    { address="$backend" , port=3306 , hostgroup=10, max_connections=1000, weight=$i, use_ssl=$ssl },
EOT
    } elsif (pf::cluster::getWriteDB()) {
        $tags{'geoDB'} = $TRUE;
        my @mysql_write_backend = pf::cluster::getWriteDB();
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
    } elsif ($database_proxysql->{scheduler} eq 'default') {
        my @mysql_backend;

        @mysql_backend = map { $_->{management_ip} } pf::cluster::mysql_servers();

        foreach my $mysql_back (@mysql_backend) {
        $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=3306 , hostgroup=10, max_connections=1000, weight=$i },
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
        my $j = 101 - @mysql_backend;
        foreach my $mysql_back (@mysql_backend) {
        $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=3306 , hostgroup=30, max_connections=1000, weight=$j },
EOT
        next if ($j = (102 - @mysql_backend));
        $j++;
        }
        $i = 100;
        foreach my $mysql_back (@mysql_backend) {
        $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=3306 , hostgroup=810, max_connections=1000, weight=$i },
EOT
        $i--;
        }
        $j = 101 - @mysql_backend;
        foreach my $mysql_back (@mysql_backend) {
        $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=3306 , hostgroup=830, max_connections=1000, weight=$j },
EOT
        $j++;
        }
    }
    $tags{'scheduler'} = $TRUE;
    $tags{'scheduler'} = $FALSE if ($database_proxysql->{scheduler} ne 'default');

    my @mysql_servers = pf::cluster::mysql_servers();

    $tags{'single_server'} = $single_server || (scalar(@mysql_servers) == 1);

    $tags{'mysql_pf_user'} = $DB_Config->{user};
    $tags{'mysql_pf_user'} =~ s/"/\\"/g;
    $tags{'mysql_pf_pass'} = $DB_Config->{pass};
    $tags{'mysql_pf_pass'} =~ s/"/\\"/g;
    $tt->process($self->proxysql_config_template, \%tags, "$generated_conf_dir/".$self->name.".conf") or die $tt->error();
    $tt->process($self->pxc_scheduler_handler_template, \%tags, "$generated_conf_dir/config.toml") or die $tt->error();

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
