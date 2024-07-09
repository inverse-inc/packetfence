package pf::constants::syslog;

=head1 NAME

pf::constants::syslog -

=cut

=head1 DESCRIPTION

pf::constants::syslog

=cut

use strict;
use warnings;

use pf::util;
use pf::file_paths qw($log_dir);

our @SyslogInfo = (
    {
        'description' => 'Fingerbank log',
        'name'       => 'fingerbank.log',
        'conditions' => [
            '$syslogtag contains "fingerbank"',
            '$msg contains "[GIN]"',
        ]
    },
    {
        'description' => 'PacketFence general log',
        'name'       => 'packetfence.log',
        'conditions' => [
            '$programname contains "packetfence"',
            '$programname == "pfqueue"',
            '$programname == "pfqueue-go"',
            '$programname == "pfqueue-backend"',
            '($syslogtag == "pfhttpd" and not $msg contains "GET /api/v1/logs/tail/")',
            '$programname == "pfipset"',
            '$programname == "pfpki-docker-wrapper"',
            '$programname == "pfldapexplorer-docker-wrapper"',
            '($programname == "httpd.aaa-docker-wrapper" and $msg contains "httpd.aaa")',
            '($programname == "httpd.portal-docker-wrapper" and $msg contains "httpd.portal")',
            '($programname == "httpd.webservices-docker-wrapper" and $msg contains "httpd.webservices")',
            '($programname == "httpd.dispatcher-docker-wrapper" and $msg contains "httpd.dispatcher")',
            '($programname == "httpd.admin_dispatcher-docker-wrapper" and $msg contains "httpd.admin_dispatcher")',
            '($programname == "pfperl-api-docker-wrapper" and $msg contains "pfperl-api")',
        ]
    },
    {
        'description' => 'Apache logs',
        'name'       => 'httpd.apache',
        'conditions' => [
            '$programname == "httpd.aaa-docker-wrapper"',
            '$programname == "httpd.portal-docker-wrapper"',
            '$programname == "httpd.webservices-docker-wrapper"',
            '$programname == "httpd.dispatcher-docker-wrapper"',
            '$programname == "httpd.admin_dispatcher-docker-wrapper"',
            '$msg contains "api-frontend-access"',
        ]
    },
    {
        'description' => 'api-frontend general log',
        'name'      => 'api-frontend.log',
        'conditions' => [ '$programname == "api-frontend-docker-wrapper"' ],
    },
    {
        'description' => 'pfacct general log',
        'name'       => 'pfacct.log',
        'conditions' => [ '$programname == "pfacct"' ]
    },
    {
        'description' => 'pfstats general log',
        'name'       => 'pfstats.log',
        'conditions' => [ '$programname == "pfstats"' ]
    },
    {
        'description' => 'pfdhcp general log',
        'name'       => 'pfdhcp.log',
        'conditions' => [ '$programname == "pfdhcp"' ]
    },
    {
        'description' => 'pfconfig general log',
        'name'       => 'pfconfig.log',
        'conditions' => [ '$programname == "pfconfig-docker-wrapper"' ]
    },
    {
        'description' => 'pfdetect general log',
        'name'       => 'pfdetect.log',
        'conditions' => [ '$programname == "pfdetect"' ]
    },
    {
        'description' => 'pfdhcplistener general log',
        'name'       => 'pfdhcplistener.log',
        'conditions' => [ '$programname == "pfdhcplistener"' ]
    },
    {
        'description' => 'pfdns general log',
        'name'       => 'pfdns.log',
        'conditions' => [ '$programname == "pfdns"' ]
    },
    {
        'description' => 'pffilter general log',
        'name'       => 'pffilter.log',
        'conditions' => [ '$programname == "pffilter"' ]
    },
    {
        'description' => 'pfcron general log',
        'name'       => 'pfcron.log',
        'conditions' => [ '$programname == "pfcron-docker-wrapper"' ]
    },
    {
        'description' => 'pfsso general log',
        'name'       => 'pfsso.log',
        'conditions' => [ '$programname == "pfsso-docker-wrapper"' ]
    },
    {
        'description' => 'FreeRADIUS accounting server log',
        'name'       => 'radius-acct.log',
        'conditions' => [ '$programname == "radiusd-acct-docker-wrapper"' ]
    },
    {
        'description' => 'FreeRADIUS CLI server log',
        'name'       => 'radius-cli.log',
        'conditions' => [ '$programname == "radiusd-cli-docker-wrapper"' ]
    },
    {
        'description' => 'FreeRADIUS eduroam server log',
        'name'       => 'radius-eduroam.log',
        'conditions' => [ '$syslogtag contains "eduroam" ' ]
    },
    {
        'description' => 'FreeRADIUS load balancing server log (cluster only)',
        'name'       => 'radius-load_balancer.log',
        'conditions' => [ '$programname == "radiusd-load-balancer-docker-wrapper"' ]
    },
    {
        'description' => 'FreeRADIUS authentication server log',
         'name'       => 'radius.log',
        'conditions' => [
            '$syslogtag contains "auth" and $syslogfacility-text == "local1"',
            '$programname contains "radius" and $syslogfacility-text == "local1"'
        ]

    },
    {
        'description' => 'Redis global cache logs',
        'name'       => 'redis_cache.log',
        'conditions' => [ '$programname == "redis-cache"' ]
    },
    {
        'description' => 'Redis NTLM cache logs',
        'name'       => 'redis_ntlm_cache.log',
        'conditions' => [ '$programname == "redis-ntlm-cache"' ]
    },
    {
        'description' => 'Redis queue logs',
        'name'       => 'redis_queue.log',
        'conditions' => [ '$programname == "redis-queue"' ]
    },
    {
        'description' => 'Redis server logs',
        'name'       => 'redis_server.log',
        'conditions' => [ '$programname == "redis-server"' ]
    },
    {
        'description' => 'MariaDB log',
        'name'       => 'mariadb.log',
         'conditions' => [
             '$programname contains "mysqld"',
             '$programname == "pf-mariadb"',
         ]
    },
    {
        'description' => 'MySQL probe log',
        'name'       => 'mysql-probe.log',
         'conditions' => [ '$programname == "mysql-probe"' ]
    },
    {
        'description' => 'galera-autofix log',
        'name'       => 'galera-autofix.log',
        'conditions' => [ '$syslogtag contains "galera-autofix"' ]
    },
    {
        'description' => 'ProxySQL log',
        'name'       => 'proxysql.log',
         'conditions' => [ '$programname == "proxysql-docker-wrapper"' ]
    },
    {
        'description' => 'haproxy portal log',
        'name'       => 'haproxy_portal.log',
        'conditions' => [ '$programname == "haproxy-portal-docker-wrapper"' ]
    },
    {
        'description' => 'haproxy admin log',
        'name'       => 'haproxy_admin.log',
        'conditions' => [ '$programname == "haproxy-admin-docker-wrapper"' ]
    },
    {
        'description' => 'haproxy DB log',
        'name'       => 'haproxy_db.log',
        'conditions' => [ '$programname == "haproxy" and ($msg contains "mysql" or $msg contains "backend has no server available")' ]
    },
    {
        'description' => 'haproxy general log',
        'name'       => 'haproxy.log',
        'conditions' => [ '$programname == "haproxy"' ]
    },
    {
        'description' => 'Firewall log',
        'name'       => 'firewall.log',
        'conditions' => [
             '$programname contains "firewalld"',
             '$programname == "firewalld"',
        ]
    },
    {
        'description' => 'pfconnector client log',
        'name'       => 'pfconnector-client.log',
        'conditions' => [ '$programname == "pfconnector-client-docker-wrapper"' ]
    },
    {
        'description' => 'pfconnector server log',
        'name'       => 'pfconnector-server.log',
        'conditions' => [ '$programname == "pfconnector-server-docker-wrapper"' ]
    },
    {
        'description' => 'keepalived log',
        'name'       => 'keepalived.log',
        'conditions' => [ '$programname contains "Keepalived"' ]
    },
    {
        'description' => 'ntlm auth api log',
        'name'       => 'ntlm-auth-api.log',
        'conditions' => [ '$programname contains "ntlm-auth-api"' ]
    },
);

our @LOGS = (
    (map { my $h = { %{$_} } ; $h->{name} = "$log_dir/".$h->{name} ; $h } @SyslogInfo),
    {
        'description' => 'Global syslog',
        'name'       => os_detection() eq "debian" ? '/var/log/syslog' : '/var/log/messages',
    },
);

our $ALL_LOGS = join(",", map { $_->{name} } @pf::constants::syslog::SyslogInfo);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

