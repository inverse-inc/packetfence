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

use pf::config qw(
    $management_network
);

use Moo;
extends 'pf::services::manager';

has '+name' => (default => sub { 'netdata' } );

sub generateConfig {
    my ($self,$quick) = @_;
    my $logger = get_logger();
    my %tags;

    $tags{'members'} = '';
    if ($cluster_enabled) {
        my $int = $management_network->tag('int');
        $tags{'members'} = join(" ", values %{pf::cluster::members_ips($int)});
    }
    parse_template( \%tags, "$conf_dir/monitoring/netdata.conf", "$generated_conf_dir/monitoring/netdata.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/apps_groups.conf", "$generated_conf_dir/monitoring/apps_groups.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d.conf", "$generated_conf_dir/monitoring/charts.d.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/ap.conf", "$generated_conf_dir/monitoring/charts.d/ap.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/apache.conf", "$generated_conf_dir/monitoring/charts.d/apache.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/apcupsd.conf", "$generated_conf_dir/monitoring/charts.d/apcupsd.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/cpu_apps.conf", "$generated_conf_dir/monitoring/charts.d/cpu_apps.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/cpufreq.conf", "$generated_conf_dir/monitoring/charts.d/cpufreq.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/example.conf", "$generated_conf_dir/monitoring/charts.d/example.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/exim.conf", "$generated_conf_dir/monitoring/charts.d/exim.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/hddtemp.conf", "$generated_conf_dir/monitoring/charts.d/hddtemp.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/load_average.conf", "$generated_conf_dir/monitoring/charts.d/load_average.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/mem_apps.conf", "$generated_conf_dir/monitoring/charts.d/mem_apps.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/mysql.conf", "$generated_conf_dir/monitoring/charts.d/mysql.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/nginx.conf", "$generated_conf_dir/monitoring/charts.d/nginx.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/nut.conf", "$generated_conf_dir/monitoring/charts.d/nut.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/opensips.conf", "$generated_conf_dir/monitoring/charts.d/opensips.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/phpfpm.conf", "$generated_conf_dir/monitoring/charts.d/phpfpm.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/postfix.conf", "$generated_conf_dir/monitoring/charts.d/postfix.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/sensors.conf", "$generated_conf_dir/monitoring/charts.d/sensors.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/squid.conf", "$generated_conf_dir/monitoring/charts.d/squid.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/charts.d/tomcat.conf", "$generated_conf_dir/monitoring/charts.d/tomcat.conf" );
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
    parse_template( \%tags, "$conf_dir/monitoring/python.d/beanstalk.conf", "$generated_conf_dir/monitoring/python.d/beanstalk.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/bind_rndc.conf", "$generated_conf_dir/monitoring/python.d/bind_rndc.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/chrony.conf", "$generated_conf_dir/monitoring/python.d/chrony.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/couchdb.conf", "$generated_conf_dir/monitoring/python.d/couchdb.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/cpufreq.conf", "$generated_conf_dir/monitoring/python.d/cpufreq.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/dns_query_time.conf", "$generated_conf_dir/monitoring/python.d/dns_query_time.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/dnsdist.conf", "$generated_conf_dir/monitoring/python.d/dnsdist.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/dovecot.conf", "$generated_conf_dir/monitoring/python.d/dovecot.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/elasticsearch.conf", "$generated_conf_dir/monitoring/python.d/elasticsearch.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/example.conf", "$generated_conf_dir/monitoring/python.d/example.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/exim.conf", "$generated_conf_dir/monitoring/python.d/exim.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/fail2ban.conf", "$generated_conf_dir/monitoring/python.d/fail2ban.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/freeradius.conf", "$generated_conf_dir/monitoring/python.d/freeradius.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/go_expvar.conf", "$generated_conf_dir/monitoring/python.d/go_expvar.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/haproxy.conf", "$generated_conf_dir/monitoring/python.d/haproxy.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/hddtemp.conf", "$generated_conf_dir/monitoring/python.d/hddtemp.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/ipfs.conf", "$generated_conf_dir/monitoring/python.d/ipfs.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/isc_dhcpd.conf", "$generated_conf_dir/monitoring/python.d/isc_dhcpd.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/mdstat.conf", "$generated_conf_dir/monitoring/python.d/mdstat.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/memcached.conf", "$generated_conf_dir/monitoring/python.d/memcached.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/mongodb.conf", "$generated_conf_dir/monitoring/python.d/mongodb.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/mysql.conf", "$generated_conf_dir/monitoring/python.d/mysql.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/nginx.conf", "$generated_conf_dir/monitoring/python.d/nginx.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/nsd.conf", "$generated_conf_dir/monitoring/python.d/nsd.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/ovpn_status_log.conf", "$generated_conf_dir/monitoring/python.d/ovpn_status_log.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/phpfpm.conf", "$generated_conf_dir/monitoring/python.d/phpfpm.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/postfix.conf", "$generated_conf_dir/monitoring/python.d/postfix.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/postgres.conf", "$generated_conf_dir/monitoring/python.d/postgres.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/powerdns.conf", "$generated_conf_dir/monitoring/python.d/powerdns.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/rabbitmq.conf", "$generated_conf_dir/monitoring/python.d/rabbitmq.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/redis.conf", "$generated_conf_dir/monitoring/python.d/redis.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/retroshare.conf", "$generated_conf_dir/monitoring/python.d/retroshare.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/samba.conf", "$generated_conf_dir/monitoring/python.d/samba.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/sensors.conf", "$generated_conf_dir/monitoring/python.d/sensors.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/smartd_log.conf", "$generated_conf_dir/monitoring/python.d/smartd_log.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/squid.conf", "$generated_conf_dir/monitoring/python.d/squid.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/tomcat.conf", "$generated_conf_dir/monitoring/python.d/tomcat.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/varnish.conf", "$generated_conf_dir/monitoring/python.d/varnish.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/python.d/web_log.conf", "$generated_conf_dir/monitoring/python.d/web_log.conf" );
    parse_template( \%tags, "$conf_dir/monitoring/statsd.d/example.conf", "$generated_conf_dir/monitoring/statsd.d/example.conf" );
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
