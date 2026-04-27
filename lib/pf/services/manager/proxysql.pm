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
    $tags{'replication'} = $FALSE;
    $tags{'mysql_servers'} = "";
    $tags{'mysql_replication_hostgroups'} = "";
    $tags{'mysql_query_rules'} = "";
    $tags{'mysql_monitor_variables'} = "";
    $tags{'mysql_ssl_p2s_capath'} = "";  # initialized empty; set below only when SSL cacert is configured
    $tags{'database'} = $DB_Config->{db};

    # Standardized hostgroups used everywhere:
    #   HG 10 = writer
    #   HG 30 = reader
    my $writer_hostgroup  = 10;
    my $reader_hostgroup  = 30;
    my $has_reader_split  = 0;  # flag: only generate query rules / replication hostgroups when we actually have a reader HG

    # Monitor and shunning variables — ensure reliable auto-detection of dead servers:
    #   monitor_ping_max_failures=3  → SHUNNED after 3 missed pings (~6 sec with 2s interval)
    #   shun_recovery_time_sec=60    → stays shunned 60s before retry
    #   shun_on_failures=3           → app connection failures before shunning
    #   timeouts raised to 3000ms    → avoids false positives from tight timeouts
    # NOTE: proxysql.conf mysql_variables block does NOT use the 'mysql-' prefix.
    # These variable names are used as-is inside mysql_variables = { } in the template.
    # The [% mysql_monitor_variables %] tag should be placed INSIDE the mysql_variables
    # block in proxysql.conf, alongside [% monitor %] (username/password).
    $tags{'mysql_monitor_variables'} = << "EOT";
    monitor_enabled=1
    monitor_connect_timeout=3000
    monitor_ping_timeout=3000
    monitor_read_only_timeout=2000
    monitor_ping_interval=2000
    monitor_connect_interval=3000
    monitor_read_only_interval=1000
    monitor_ping_max_failures=3
    monitor_read_only_max_timeout_count=3
    shun_on_failures=3
    shun_recovery_time_sec=60
    connect_retries_on_failure=5
    connect_timeout_server=3000
    connect_timeout_server_max=10000
EOT

    $tags{'monitor'} = << "EOT";
    monitor_username="$DB_Config->{user}"
    monitor_password="$DB_Config->{pass}"
EOT

    $tags{'mysql_users'} = << "EOT";
        { username = "$DB_Config->{user}", password = "$DB_Config->{pass}", default_hostgroup = $writer_hostgroup, transaction_persistent = 0, active = 1 },
EOT

    my $i = 100;
    my $database_proxysql = $pf::config::Config{database_proxysql};
    my $port = $database_proxysql->{port} || 3306;

    if (isenabled($database_proxysql->{status})) {
        my $cacert = $database_proxysql->{cacert};
        if ($cacert) {
            $tags{'mysql_ssl_p2s_capath'} = << "EOT";
    mysql-ssl_p2s_capath = "$conf_dir/";
    mysql-ssl_p2s_ca = "$cacert";
EOT
        }

        my $backends_str = $database_proxysql->{backends} || '';
        my @backends = grep { $_ ne '' } map { s/^\s+|\s+$//gr } split(/,/, $backends_str);
        my $ssl = $cacert ? 1 : 0;

        if (scalar(@backends) <= 1) {
            $single_server = 1;
            my $backend = $backends[0] // '';
            # Single server: only HG 10 needed, no reader split
            $tags{mysql_servers} .= << "EOT";
    { address="$backend" , port=$port , hostgroup=$writer_hostgroup, max_connections=1000, weight=100, use_ssl=$ssl },
EOT
        } else {
            $single_server = 0;
            $tags{'replication'} = $TRUE;
            $has_reader_split = 1;

            # First backend = READ/WRITE
            #   → HG 10 (writer) weight=100
            #   → HG 30 (reader) weight=50 as fallback only
            #      (replicas have higher weight and are preferred for reads)
            #   → if all pure readers go down, writer can still serve reads ✅
            my $writer = $backends[0];
            $tags{mysql_servers} .= << "EOT";
    { address="$writer" , port=$port , hostgroup=$writer_hostgroup, max_connections=1000, weight=100, use_ssl=$ssl },
    { address="$writer" , port=$port , hostgroup=$reader_hostgroup, max_connections=1000, weight=50, use_ssl=$ssl },
EOT

            # Remaining backends = READ ONLY → HG 30 only
            # weight=99,98... so first server is preferred for reads
            # On failover: promoted replica sets read_only=0
            # → ProxySQL auto-moves it to HG 10 via mysql_replication_hostgroups
            my $r = 99;
            foreach my $backend (@backends[1..$#backends]) {
                $tags{mysql_servers} .= << "EOT";
    { address="$backend" , port=$port , hostgroup=$reader_hostgroup, max_connections=1000, weight=$r, use_ssl=$ssl },
EOT
                $r--;
            }
        }
    } elsif (pf::cluster::getWriteDB()) {
        $tags{'geoDB'} = $TRUE;
        my @mysql_write_backend = pf::cluster::getWriteDB();
        my @mysql_read_backend = pf::cluster::getReadDB();
        $has_reader_split = 1;

        foreach my $mysql_back (@mysql_write_backend) {
            # Writers go to HG 10 AND HG 30 as fallback if all readers go down
            # weight=50 in HG 30 so readers (weight=100) are always preferred for reads
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=$port , hostgroup=$writer_hostgroup, max_connections=1000, weight=$i },
    { address="$mysql_back" , port=$port , hostgroup=$reader_hostgroup, max_connections=1000, weight=50 },
EOT
            $i--;
        }
        $i = 100;
        # HG 30 (reader)
        foreach my $mysql_back (@mysql_read_backend) {
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=$port , hostgroup=$reader_hostgroup, max_connections=1000, weight=$i },
EOT
            $i--;
        }
    } elsif (($database_proxysql->{scheduler} // '') eq 'default') {
        my @mysql_backend;

        @mysql_backend = map { $_->{management_ip} } pf::cluster::mysql_servers();

        foreach my $mysql_back (@mysql_backend) {
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=$port , hostgroup=$writer_hostgroup, max_connections=1000, weight=$i },
EOT
            $i--;
        }
    } else {
        my @mysql_backend;

        @mysql_backend = map { $_->{management_ip} } pf::cluster::mysql_servers();
        $has_reader_split = 1;

        foreach my $mysql_back (@mysql_backend) {
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=$port , hostgroup=$writer_hostgroup, max_connections=1000, weight=$i },
EOT
            $i--;
        }
        my $j = 101 - @mysql_backend;
        # HG 30 (reader)
        # FIX: was "next if ($j = ...)" which is always true — $j++ was never reached
        foreach my $mysql_back (@mysql_backend) {
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=$port , hostgroup=$reader_hostgroup, max_connections=1000, weight=$j },
EOT
            $j++;
        }
        $i = 100;
        foreach my $mysql_back (@mysql_backend) {
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=$port , hostgroup=810, max_connections=1000, weight=$i },
EOT
            $i--;
        }
        $j = 101 - @mysql_backend;
        foreach my $mysql_back (@mysql_backend) {
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=$port , hostgroup=830, max_connections=1000, weight=$j },
EOT
            $j++;
        }
    }

    $tags{'scheduler'} = $TRUE;
    $tags{'scheduler'} = $FALSE if (($database_proxysql->{scheduler} // '') ne 'default');
    $tags{'scheduler'} = $FALSE if ($tags{'replication'});

    my @mysql_servers = pf::cluster::mysql_servers();

    $tags{'single_server'} = $single_server || (scalar(@mysql_servers) == 1);

    # Generate mysql_replication_hostgroups using standardized HG 10/30
    # read_only=0 → server auto-moved to HG 10 (writer)
    # read_only=1 → server auto-moved to HG 30 (reader)
    # Only generated when we actually have a reader split
    #
    # IMPORTANT: the proxysql.conf template MUST reference [% mysql_replication_hostgroups %]
    # instead of a hardcoded mysql_replication_hostgroups block, otherwise this tag is ignored.
    if ($has_reader_split) {
        # mysql_replication_hostgroups tells ProxySQL to monitor read_only on ALL servers
        # in both writer_hostgroup and reader_hostgroup.
        # Automatic failover works as follows:
        #   - ProxySQL checks read_only every monitor_read_only_interval ms
        #   - If a server in HG 30 becomes read_only=0 (promoted by Cloud SQL or DBA):
        #       → ProxySQL automatically moves it to HG 10 (writer) ✅
        #   - If the current writer becomes read_only=1 (demoted):
        #       → ProxySQL automatically moves it to HG 30 (reader) ✅
        #   - active=1 ensures the monitor thread is running for this hostgroup pair
        $tags{'mysql_replication_hostgroups'} = << "EOT";
mysql_replication_hostgroups =
(
    { writer_hostgroup=$writer_hostgroup, reader_hostgroup=$reader_hostgroup, check_type="read_only", active=1, comment="Replication RW Split - auto failover via read_only check" }
)
EOT
    }

    # Generate mysql_query_rules:
    #   rule 1 — SELECT FOR UPDATE → HG 10 (writer always, locks rows)
    #   rule 2 — SELECT            → HG 30 (readers preferred)
    #            writer is also in HG 30 (weight=50) only as fallback
    #            if all pure readers go down ✅
    #   rule 4 — catch-all                 → HG 10 in normal mode
    #            scheduler rewrites 1,2,4 during degraded mode
    # Only generated when we actually have a reader split
    #
    # IMPORTANT: the proxysql.conf template MUST reference [% mysql_query_rules %]
    # instead of a hardcoded mysql_query_rules block, otherwise this tag is ignored.
    # Also ensure rule_ids here do not conflict with any remaining rules in the template.
    if ($has_reader_split) {
        $tags{'mysql_query_rules'} = << "EOT";
mysql_query_rules =
(
    {
        rule_id=1,
        active=1,
        match_pattern="^SELECT.*FOR UPDATE",
        destination_hostgroup=$writer_hostgroup,
        apply=1,
        comment="SELECT FOR UPDATE goes to writer"
    },
    {
        rule_id=2,
        active=1,
        match_pattern="^SELECT \@\@global.read_only",
        destination_hostgroup=$writer_hostgroup,
        apply=1,
        comment="SELECT global.read_only goes to writer"
    },
    {
        rule_id=3,
        active=1,
        match_pattern="^SELECT",
        destination_hostgroup=$reader_hostgroup,
        apply=1,
        comment="SELECT goes to readers — writer is also in HG $reader_hostgroup as fallback"
    },
    {
        rule_id=4,
        active=1,
        match_pattern=".*",
        destination_hostgroup=$writer_hostgroup,
        apply=1,
        comment="Catch-all traffic goes to writer in normal mode; scheduler rewrites in degraded mode"
    }
)
EOT
    }

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

Copyright (C) 2005-2026 Inverse inc.

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
