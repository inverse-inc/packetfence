package pf::services::manager::netdata;

=head1 NAME

pf::services::manager::netdata add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::netdata

=cut

use strict;
use warnings;
use pf::file_paths qw(
    $generated_conf_dir
    $conf_dir
);

use pf::log;
use pf::util;
use pf::cluster;
use pf::constants;
use NetAddr::IP;

use pf::config qw(
    $management_network
    %Config
);
use pfconfig::cached_array;

use Moo;
extends 'pf::services::manager';

has '+name' => (default => sub { 'netdata' } );
has '+optional' => ( default => sub {'1'} );

tie our @authentication_sources_monitored, 'pfconfig::cached_array', "resource::authentication_sources_monitored";

my $host_id = $pf::config::cluster::host_id;

tie our %NetworkConfig, 'pfconfig::cached_hash', "resource::network_config($host_id)";

=head2 postStartCleanup

Stub method to be implemented in services if needed.

=cut

sub postStartCleanup {
    my ($self,$quick) = @_;
    my $logger = get_logger();
    sleep 40;
    unless ($self->pid) {
        $logger->error("$self->name died or has failed to start");
        return $FALSE;
    }
    return $TRUE;
}

sub generateConfig {
    my ($self,$quick) = @_;
    my $logger = get_logger();
    my %tags;

    $tags{'members'} = '';
    if ($cluster_enabled) {
        my $int = $management_network->tag('int');
        $tags{'members'} = join(" ", grep( {$_ ne $management_network->tag('ip')} values %{pf::cluster::members_ips($int)}));
    }


    foreach my $source  (@authentication_sources_monitored) {
        if ($source->{'host'}) {
            my @members = split(",", $source->{'host'});
            foreach my $member (@members) {
                $tags{'members'} .= " $member";
            }
        }
        if ($source->{'server1_address'}) {
            $tags{'members'} .= " $source->{'server1_address'}";
        }
        if ($source->{'server2_address'}) {
            $tags{'members'} .= " $source->{'server2_address'}";
        }
        my $type = $source->{'type'};

        if ($type eq 'Eduroam') {

            $tags{'alerts'} .= <<"EOT";
template: eduroam1__source_available
families: *
      on: statsd_gauge.source.$type.Eduroam1
   every: 10s
    crit: \$gauge != 1
   units: ok/failed
    info: Source eduroam1 unavailable
   delay: down 5m multiplier 1.5 max 1h
      to: sysadmin

template: eduroam2_source_available
families: *
      on: statsd_gauge.source.$type.Eduroam2
   every: 10s
    crit: \$gauge != 1
   units: ok/failed
    info: Source eduroam2 unavailable
   delay: down 5m multiplier 1.5 max 1h
      to: sysadmin

EOT
        } else {
            my @number = split(',',$source->{'host'});
            for my $source_id (@number) {
              $tags{'alerts'} .= <<"EOT";
template: $source->{'id'}_source_available
families: *
      on: statsd_gauge.source.$type.$source->{'id'}.$source_id
   every: 10s
    crit: \$gauge != 1
   units: ok/failed
    info: Source $source->{'id'}.$source_id unavailable
   delay: down 5m multiplier 1.5 max 1h
      to: sysadmin

EOT
            }
        }
    }

    foreach my $network ( keys %NetworkConfig ) {
        my $dev = $NetworkConfig{$network}{'interface'}{'int'};
        next if !defined $dev;
        next if isdisabled($NetworkConfig{$network}{'dhcpd'});
        my $net_addr = NetAddr::IP->new($network,$NetworkConfig{$network}{'netmask'});
        my $cidr = $net_addr->cidr();
        $tags{'alerts'} .= <<"EOT";
template: dhcp_missing_leases_$cidr
families: *
      on: statsd_gauge.source.packetfence.dhcp_leases.percentused.$cidr
      os: linux
   hosts: *
   units: %
   every: 1m
    warn: \$gauge > 80
    crit: \$gauge > 90
   delay: down 5m multiplier 1.5 max 1h
    info: DHCP leases usage $cidr
      to: sysadmin

EOT
    }

    $tags{'httpd_portal_modstatus_port'} = "$Config{'ports'}{'httpd_portal_modstatus'}";
    $tags{'management_ip'}
        = defined( $management_network->tag('vip') )
        ? $management_network->tag('vip')
        : $management_network->tag('ip');
    if ($Config{'database'}{'host'} ne '127.0.0.1') {
        $tags{'db_host'}       = "$Config{'database'}{'host'}";
    } else {
        $tags{'db_host'}       = $tags{'management_ip'};
    }
    $tags{'db_username'}   = "$Config{'database'}{'user'}";
    $tags{'db_password'}   = "$Config{'database'}{'pass'}";
    $tags{'db_database'}   = "$Config{'database'}{'db'}";

    $tags{'active_active_ip'} = pf::cluster::management_cluster_ip() || $management_network->tag('vip') || $management_network->tag('ip');

    parse_template( \%tags, "$conf_dir/monitoring/netdata.conf", "$generated_conf_dir/monitoring/netdata.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/apps_groups.conf", "$generated_conf_dir/monitoring/apps_groups.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d.conf", "$generated_conf_dir/monitoring/charts.d.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/example.conf", "$generated_conf_dir/monitoring/charts.d/example.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/fping.conf", "$generated_conf_dir/monitoring/fping.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/apache.conf", "$generated_conf_dir/monitoring/health.d/apache.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/backend.conf", "$generated_conf_dir/monitoring/health.d/backend.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/beanstalkd.conf", "$generated_conf_dir/monitoring/health.d/beanstalkd.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/bind_rndc.conf", "$generated_conf_dir/monitoring/health.d/bind_rndc.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/couchdb.conf", "$generated_conf_dir/monitoring/health.d/couchdb.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/cpu.conf", "$generated_conf_dir/monitoring/health.d/cpu.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/disks.conf", "$generated_conf_dir/monitoring/health.d/disks.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/elasticsearch.conf", "$generated_conf_dir/monitoring/health.d/elasticsearch.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/entropy.conf", "$generated_conf_dir/monitoring/health.d/entropy.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/fping.conf", "$generated_conf_dir/monitoring/health.d/fping.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/haproxy.conf", "$generated_conf_dir/monitoring/health.d/haproxy.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/ipc.conf", "$generated_conf_dir/monitoring/health.d/ipc.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/ipfs.conf", "$generated_conf_dir/monitoring/health.d/ipfs.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/ipmi.conf", "$generated_conf_dir/monitoring/health.d/ipmi.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/isc_dhcpd.conf", "$generated_conf_dir/monitoring/health.d/isc_dhcpd.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/lighttpd.conf", "$generated_conf_dir/monitoring/health.d/lighttpd.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/mdstat.conf", "$generated_conf_dir/monitoring/health.d/mdstat.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/memcached.conf", "$generated_conf_dir/monitoring/health.d/memcached.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/memory.conf", "$generated_conf_dir/monitoring/health.d/memory.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/mongodb.conf", "$generated_conf_dir/monitoring/health.d/mongodb.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/mysql.conf", "$generated_conf_dir/monitoring/health.d/mysql.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/named.conf", "$generated_conf_dir/monitoring/health.d/named.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/net.conf", "$generated_conf_dir/monitoring/health.d/net.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/netfilter.conf", "$generated_conf_dir/monitoring/health.d/netfilter.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/nginx.conf", "$generated_conf_dir/monitoring/health.d/nginx.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/postgres.conf", "$generated_conf_dir/monitoring/health.d/postgres.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/qos.conf", "$generated_conf_dir/monitoring/health.d/qos.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/ram.conf", "$generated_conf_dir/monitoring/health.d/ram.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/redis.conf", "$generated_conf_dir/monitoring/health.d/redis.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/retroshare.conf", "$generated_conf_dir/monitoring/health.d/retroshare.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/softnet.conf", "$generated_conf_dir/monitoring/health.d/softnet.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/squid.conf", "$generated_conf_dir/monitoring/health.d/squid.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/swap.conf", "$generated_conf_dir/monitoring/health.d/swap.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/tcp_conn.conf", "$generated_conf_dir/monitoring/health.d/tcp_conn.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/tcp_listen.conf", "$generated_conf_dir/monitoring/health.d/tcp_listen.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/tcp_mem.conf", "$generated_conf_dir/monitoring/health.d/tcp_mem.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/tcp_orphans.conf", "$generated_conf_dir/monitoring/health.d/tcp_orphans.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/tcp_resets.conf", "$generated_conf_dir/monitoring/health.d/tcp_resets.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/udp_errors.conf", "$generated_conf_dir/monitoring/health.d/udp_errors.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/varnish.conf", "$generated_conf_dir/monitoring/health.d/varnish.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/web_log.conf", "$generated_conf_dir/monitoring/health.d/web_log.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/zfs.conf", "$generated_conf_dir/monitoring/health.d/zfs.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health.d/statsd.conf", "$generated_conf_dir/monitoring/health.d/statsd.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health_alarm_notify.conf", "$generated_conf_dir/monitoring/health_alarm_notify.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/health_email_recipients.conf", "$generated_conf_dir/monitoring/health_email_recipients.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/node.d.conf", "$generated_conf_dir/monitoring/node.d.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/node.d/README.md", "$generated_conf_dir/monitoring/node.d/README.md" );
    parse_template( \%tags, "$conf_dir/monitoring/node.d/fronius.conf.md", "$generated_conf_dir/monitoring/node.d/fronius.conf.md" );
    parse_template( \%tags, "$conf_dir/monitoring/node.d/named.conf.md", "$generated_conf_dir/monitoring/node.d/named.conf.md" );
    parse_template( \%tags, "$conf_dir/monitoring/node.d/sma_webbox.conf.md", "$generated_conf_dir/monitoring/node.d/sma_webbox.conf.md" );
    parse_template( \%tags, "$conf_dir/monitoring/node.d/snmp.conf.md", "$generated_conf_dir/monitoring/node.d/snmp.conf.md" );
    parse_template( \%tags, "$conf_dir/monitoring/node.d/stiebeleltron.conf.md", "$generated_conf_dir/monitoring/node.d/stiebeleltron.conf.md" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d.conf", "$generated_conf_dir/monitoring/python.d.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/apache.conf", "$generated_conf_dir/monitoring/python.d/apache.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/chrony.conf", "$generated_conf_dir/monitoring/python.d/chrony.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/cpufreq.conf", "$generated_conf_dir/monitoring/python.d/cpufreq.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/dns_query_time.conf", "$generated_conf_dir/monitoring/python.d/dns_query_time.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/example.conf", "$generated_conf_dir/monitoring/python.d/example.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/freeradius.conf", "$generated_conf_dir/monitoring/python.d/freeradius.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/go_expvar.conf", "$generated_conf_dir/monitoring/python.d/go_expvar.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/haproxy.conf", "$generated_conf_dir/monitoring/python.d/haproxy.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/mysql.conf", "$generated_conf_dir/monitoring/python.d/mysql.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/postfix.conf", "$generated_conf_dir/monitoring/python.d/postfix.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/redis.conf", "$generated_conf_dir/monitoring/python.d/redis.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/web_log.conf", "$generated_conf_dir/monitoring/python.d/web_log.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/statsd.d/packetfence.conf", "$generated_conf_dir/monitoring/statsd.d/packetfence.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/stream.conf", "$generated_conf_dir/monitoring/stream.conf" );
    return 1;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
