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
        'conditions' => [ '$syslogtag contains "fingerbank"' ]
    },
    {
        'description' => 'httpd.aaa Apache error log',
        'name'       => 'httpd.aaa.error',
        'conditions' => [ '$programname contains "httpd_aaa_err"' ]
    },
    {
        'description' => 'httpd.aaa Apache access log',
        'name'       => 'httpd.aaa.access',
        'conditions' => [ '$programname contains "httpd_aaa"' ]
    },
    {
        'description' => 'httpd.admin Apache access log',
        'name'       => 'httpd.admin.access',
        'conditions' => [ '$syslogtag contains "httpd_admin_access"' ]
    },
    {
        'description' => 'httpd.admin Catalyst log',
        'name'       => 'httpd.admin.catalyst',
        'conditions' => [ '$syslogtag contains "admin_catalyst"' ]
    },
    {
        'description' => 'httpd.admin Apache error log',
        'name'       => 'httpd.admin.error',
        'conditions' => [ '$syslogtag contains "httpd_admin_err"' ]
    },
    {
        'description' => 'httpd.admin general log',
        'name'       => 'httpd.admin.log',
        'conditions' => [ '$syslogtag contains "httpd_admin"' ]
    },
    {
        'description' => 'httpd.collector Apache error log',
        'name'       => 'httpd.collector.error',
        'conditions' => [ '$syslogtag contains "httpd_collector_err"' ]
    },
    {
        'description' => 'httpd.collector general log',
        'name'       => 'httpd.collector.log',
        'conditions' => [ '$syslogtag contains "httpd_collector"' ]
    },
    {
        'description' => 'httpd.portal Apache error log',
        'name'       => 'httpd.portal.error',
        'conditions' => [ '$syslogtag contains "httpd_portal_err"' ]
    },
    {
        'description' => 'httpd.portal Apache access log',
        'name'       => 'httpd.portal.access',
        'conditions' => [ '$syslogtag contains "httpd_portal"' ]
    },
    {
        'description' => 'httpd.portal Catalyst log',
        'name'       => 'httpd.portal.catalyst',
        'conditions' => [ '$syslogtag contains "portal_catalyst"' ]
    },
    {
        'description' => 'httpd.proxy Apache error log',
        'name'       => 'httpd.proxy.error',
        'conditions' => [ '$syslogtag contains "httpd_proxy_err"' ]
    },
    {
        'description' => 'httpd.proxy Apache access log',
        'name'       => 'httpd.proxy.access',
        'conditions' => [ '$syslogtag contains "httpd_proxy"' ]
    },
    {
        'description' => 'httpd.webservices Apache error log',
        'name'       => 'httpd.webservices.error',
        'conditions' => [ '$programname contains "httpd_webservices_err"' ]
    },
    {
        'description' => 'httpd.webservices Apache access log',
        'name'       => 'httpd.webservices.access',
        'conditions' => [ '$programname contains "httpd_webservices"' ]
    },
    {
        'description' => 'api-frontend access log',
        'name'      => 'httpd.api-frontend.access',
        'conditions' => [ '$msg contains "api-frontend-access"' ],
    },
    {
        'description' => 'api-frontend general log',
        'name'      => 'api-frontend.log',
        'conditions' => [ '$programname == "api-frontend"' ],
    },
    {
        'description' => 'pfacct general log',
        'name'       => 'pfacct.log',
        'conditions' => [ '$programname == "pfacct"' ]
    },
    {
        'description' => 'pfcertmanager general log',
        'name'       => 'pfcertmanager.log',
        'conditions' => [ '$programname == "pfcertmanager"' ]
    },
    {
        'description' => 'pfstats general log',
        'name'       => 'pfstats.log',
        'conditions' => [ '$programname == "pfstats"' ]
    },
    {
        'description' => 'PacketFence general log',
        'name'       => 'packetfence.log',
        'conditions' => [
            '$syslogtag contains "packetfence"',
            '$programname == "pfqueue"',
            '($programname == "pfhttpd" and not $msg contains "GET /api/v1/logs/tail/")',
            '$programname == "pfipset"',
            '$programname == "pfpki"',
        ]
    },
    {
        'description' => 'pfdhcp general log',
        'name'       => 'pfdhcp.log',
        'conditions' => [ '$programname == "pfdhcp"' ]
    },
    {
        'description' => 'pfconfig general log',
        'name'       => 'pfconfig.log',
        'conditions' => [ '$programname == "pfconfig"' ]
    },
    {
        'description' => 'pfdetect general log',
        'name'       => 'pfdetect.log',
        'conditions' => [ '$programname == "pfdetect"' ]
    },
    {
        'description' => 'pfdhcplistener general log',
        'name'       => 'pfdhcplistener.log',
        'conditions' => [ '$syslogtag contains "pfdhcplistener"' ]
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
        'conditions' => [ '$programname == "pfcron"' ]
    },
    {
        'description' => 'pfsso general log',
        'name'       => 'pfsso.log',
        'conditions' => [ '$programname == "pfsso"' ]
    },
    {
        'description' => 'FreeRADIUS accounting server log',
        'name'       => 'radius-acct.log',
        'conditions' => [
'$programname contains "radius" and $syslogfacility-text == "local2"',
            '$syslogtag contains "acct" and $syslogfacility-text == "local2"'
        ]
    },
    {
        'description' => 'FreeRADIUS CLI server log',
        'name'       => 'radius-cli.log',
        'conditions' =>
          [ '$syslogtag contains "cli" and $syslogfacility-text == "local3"' ]
    },
    {
        'description' => 'FreeRADIUS eduroam server log',
        'name'       => 'radius-eduroam.log',
        'conditions' => [ '$syslogtag contains "eduroam" ' ]
    },
    {
        'description' => 'FreeRADIUS load balancing server log (cluster only)',
        'name'       => 'radius-load_balancer.log',
        'conditions' => [
'$syslogtag contains "load_balancer" and $syslogfacility-text == "local5"'
        ]
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
        'conditions' => [ '$syslogtag contains "redis-cache"' ]
    },
    {
        'description' => 'Redis NTLM cache logs',
        'name'       => 'redis_ntlm_cache.log',
        'conditions' => [ '$syslogtag contains "redis-ntlm-cache"' ]
    },
    {
        'description' => 'Redis queue logs',
        'name'       => 'redis_queue.log',
        'conditions' => [ '$syslogtag contains "redis-queue"' ]
    },
    {
        'description' => 'Redis server logs',
        'name'       => 'redis_server.log',
        'conditions' => [ '$programname == "redis-server"' ]
    },
    {
        'description' => 'MariaDB log',
        'name'       => 'mariadb_error.log',
        'conditions' => [ '$syslogtag contains "mysqld"' ],
    },
    {
        'description' => 'haproxy portal log',
        'name'       => 'haproxy_portal.log',
        'conditions' => [ '$programname == "haproxy" and ($msg contains "portal-http" or $msg contains "backend has no server available")' ],
    },
    {
        'description' => 'haproxy DB log',
        'name'       => 'haproxy_db.log',
        'conditions' => [ '$programname == "haproxy" and ($msg contains "mysql" or $msg contains "backend has no server available")' ],
    },
    {
        'description' => 'haproxy admin log',
        'name'       => 'haproxy_admin.log',
        'conditions' => [ '$programname == "haproxy" and ($msg contains "admin-https" or $msg contains "backend has no server available")' ],
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

Copyright (C) 2005-2020 Inverse inc.

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

