package pf::cmd::pf::generatemariadbconfig;

=head1 NAME

pf::cmd::pf::generatemariadbconfig

=head1 SYNOPSIS

 pfcmd generatemariadbconfig [--force]

generates the OS configuration for the domain binding

=head1 DESCRIPTION

pf::cmd::pf::generatemariadbconfig

=cut

use strict;
use warnings;

use base qw(pf::cmd);

use Template;
use pf::version;
use List::MoreUtils qw(uniq any);
use pf::file_paths qw(
    $conf_dir
    $install_dir
    $mariadb_pf_udf_file
    $pf_config_file
    $pf_default_file
);
use Sys::Hostname;
use pf::cluster;
use pf::constants qw(
    $TRUE
    $FALSE
);
use pf::constants::exit_code qw($EXIT_SUCCESS);
use pfconfig::cached_hash;
use pf::config qw(
    $management_network
    $OS
    %Config
);
use pf::constants::eventLogger;

use pf::dal::admin_api_audit_log;
use pf::dal::auth_log;
use pf::dal::dhcp_option82;
use pf::dal::dns_audit_log;
use pf::dal::radius_audit_log;
use pfconfig::namespaces::config::EventLoggers;

my %EventLoggers = %{pfconfig::namespaces::config::EventLoggers->new->build()};

use pf::util;

my $pf_conf = pf::IniFiles->new(-file => $pf_config_file, -import => pf::IniFiles->new(-file => $pf_default_file, -envsubst => 1), -envsubst => 1);
our $FORCE = $FALSE;

=head2 _pf_config_val

Read a section parameter from the %Config variable but if its uninitialized (like when there is a problem with pfconfig, then fallback to getting the value from pf.conf.defaults

=cut

sub _pf_config_val {
    my ($section, $param) = @_;
    return $pf_conf->val($section, $param)
}

sub parseArgs {
    my ($self) = @_;

    if(scalar($self->args) > 0 && [$self->args]->[0] eq "--force") {
        $FORCE = $TRUE;
    }
    return 1;
}

sub _run {
    my ($self) = @_;
    my $tt = Template->new(ABSOLUTE => 1);

    if(!$FORCE && !tied(%Config)->get_socket) {
        print STDERR "pfconfig is down, cannot rely on it to generate the MariaDB configuration. Add --force to this command to force it to regenerate the configuration as best as it can. The right fix is to get packetfence-config (pfconfig) to start";
        return;
    }

    my %vars = (
        key_buffer_size => _pf_config_val("database_advanced", "key_buffer_size"),
        innodb_buffer_pool_size => _pf_config_val("database_advanced", "innodb_buffer_pool_size"),
        query_cache_size => _pf_config_val("database_advanced", "query_cache_size"),
        thread_concurrency => _pf_config_val("database_advanced", "thread_concurrency"),
        max_connections => _pf_config_val("database_advanced", "max_connections"),
        table_cache => _pf_config_val("database_advanced", "table_cache"),
        max_allowed_packet => _pf_config_val("database_advanced", "max_allowed_packet"),
        thread_cache_size => _pf_config_val("database_advanced", "thread_cache_size"),
        server_ip => $management_network ? ($management_network->{Tvip} // $management_network->{Tip}) : "",
        performance_schema => _pf_config_val("database_advanced", "performance_schema"),
        max_connect_errors => _pf_config_val("database_advanced", "max_connect_errors"),
        net_read_timeout => normalize_time(_pf_config_val("database_advanced", "net_read_timeout")),
        net_write_timeout => normalize_time(_pf_config_val("database_advanced", "net_write_timeout")),
        masterslave => _pf_config_val("database_advanced", "masterslave"),
    );

    # Only generate cluster configuration if there is more than 1 enabled host in the cluster
    if(isenabled($Config{active_active}{galera_replication}) && $cluster_enabled && scalar(pf::cluster::db_enabled_hosts()) > 1) {
        %vars = (
            %vars,

            cluster_enabled => $cluster_enabled,

            server_ip => pf::cluster::current_server()->{management_ip},

            masterslavemode => (defined($ConfigCluster{CLUSTER}{masterslavemode}) ? "SLAVE" : "MASTER"),

            slave_server_id => (unpack 'N', pack 'C4', split '\.', pf::cluster::current_server()->{management_ip}),

            gtid_domain_id => (unpack 'N', pack 'C4', split '\.', pf::cluster::current_server()->{management_ip}) + (pf::cluster::cluster_index() + 1),

            servers_ip => [uniq(split(',', $Config{database_advanced}{other_members})), (map { $_->{management_ip} } pf::cluster::mysql_servers())],

            replication_user => $Config{active_active}{galera_replication_username},
            replication_password => $Config{active_active}{galera_replication_password},

            hostname => $host_id,
            server_id => (pf::cluster::cluster_index() + 1),

            db_config => $Config{database},
        );
    } elsif ($Config{database_advanced}{other_members} ne "" && $Config{database_advanced}{masterslave} eq "OFF") {
        %vars = (
            %vars,

            cluster_enabled => 1,

            server_ip => defined( $management_network->tag('vip') ) ? $management_network->tag('vip') : $management_network->tag('ip'),
            servers_ip => [sort (uniq(split(',', $Config{database_advanced}{other_members}), (defined( $management_network->tag('vip') ) ? $management_network->tag('vip') : $management_network->tag('ip'))))],

            replication_user => $Config{active_active}{galera_replication_username},
            replication_password => $Config{active_active}{galera_replication_password},

            hostname => $host_id,
            server_id => (unpack 'N', pack 'C4', split '\.', $vars{'server_ip'}),

            db_config => $Config{database},
        );
    }

    if ($OS eq 'debian') {
        $vars{'libgalera'} = '/usr/lib/galera/libgalera_smm.so';
    } else {
        $vars{'libgalera'} = '/usr/lib64/galera-4/libgalera_smm.so';
    }

    my $maria_conf = "$install_dir/var/conf/mariadb.conf";
    $tt->process("$conf_dir/mariadb/mariadb.conf.tt", \%vars, $maria_conf) or die $tt->error();
    chmod 0644, $maria_conf;
    
    my $db_update_path = "$install_dir/var/run/db-update";
    $tt->process("$conf_dir/mariadb/db-update.tt", \%vars, $db_update_path) or die $tt->error();
    chmod 0744, $db_update_path;
    user_chown("mysql", $db_update_path);

    update_udf_config($mariadb_pf_udf_file, \%EventLoggers);
    update_init_file($tt, "$conf_dir/mariadb/mariadb.sql.tt", "$install_dir/var/conf/mariadb.sql", make_init_file_vars());
    chmod 0644, "$install_dir/var/conf/mariadb.sql";

    return $EXIT_SUCCESS; 
}


sub make_init_file_vars {
    my $dbConfig = $Config{database};
    my $namespaces = make_namespaces_var();
    return {
        db => $dbConfig->{db},
        namespaces => $namespaces,
        pf_logger  => any { defined $_->{trigger} } @$namespaces
    };
}

sub make_namespaces_var {
    return [ map { make_namespace($_) } @pf::constants::eventLogger::Namespaces],
}

sub make_namespace {
    my ($n) = @_;
    return {
        name => $_,
        trigger => make_trigger($_),
    }
}

sub make_trigger {
    my ($n) = @_;
    if (exists $EventLoggers{$n}) {
        return "pf::dal::$n"->event_log_trigger();
    }

    return undef;
}

sub update_init_file {
    my ($tt, $template, $outfile, $vars) = @_;
    $tt->process($template, $vars, $outfile) or die $tt->error();
}

sub update_udf_config {
    my ($filename, $event_logger) = @_;
    my $fh;
    if (!open($fh,">", $filename)) {
        print "Cannot open $filename\n";
    }
    my $hostname = hostname();
    my %hosts;
    my $pf_version = pf::version::version_get_current();
    while (my ($k, $v) = each %$event_logger) {
        for my $logger (@$v) {
            print $fh "type=$logger->{type} facility=$logger->{facility} priority=$logger->{priority} app_syslog=packetfence port=$logger->{port} host=$logger->{host} version_pf=$pf_version host_syslog=$hostname namespaces=$k\n";
        }
    }

    close($fh);
    chmod 0644, $filename;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

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
