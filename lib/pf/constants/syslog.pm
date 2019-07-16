package pf::constants::syslog;

=head1 NAME

pf::constants::syslog -

=cut

=head1 DESCRIPTION

pf::constants::syslog

=cut

use strict;
use warnings;

our @SyslogInfo = (
    {
        'name'       => 'fingerbank.log',
        'conditions' => [ '$syslogtag contains "fingerbank"' ]
    },
    {
        'name'       => 'httpd.aaa.error',
        'conditions' => [ '$programname contains "httpd_aaa_err"' ]
    },
    {
        'name'       => 'httpd.aaa.access',
        'conditions' => [ '$programname contains "httpd_aaa"' ]
    },
    {
        'name'       => 'httpd.admin.access',
        'conditions' => [ '$syslogtag contains "httpd_admin_access"' ]
    },
    {
        'name'       => 'httpd.admin.catalyst',
        'conditions' => [ '$syslogtag contains "admin_catalyst"' ]
    },
    {
        'name'       => 'httpd.admin.error',
        'conditions' => [ '$syslogtag contains "httpd_admin_err"' ]
    },
    {
        'name'       => 'httpd.admin.log',
        'conditions' => [ '$syslogtag contains "httpd_admin"' ]
    },
    {
        'name'       => 'httpd.collector.error',
        'conditions' => [ '$syslogtag contains "httpd_collector_err"' ]
    },
    {
        'name'       => 'httpd.collector.log',
        'conditions' => [ '$syslogtag contains "httpd_collector"' ]
    },
    {
        'name'       => 'httpd.parking.error',
        'conditions' => [ '$syslogtag contains "httpd_parking_err"' ]
    },
    {
        'name'       => 'httpd.parking.access',
        'conditions' => [ '$syslogtag contains "httpd_parking"' ]
    },
    {
        'name'       => 'httpd.portal.error',
        'conditions' => [ '$syslogtag contains "httpd_portal_err"' ]
    },
    {
        'name'       => 'httpd.portal.access',
        'conditions' => [ '$syslogtag contains "httpd_portal"' ]
    },
    {
        'name'       => 'httpd.portal.catalyst',
        'conditions' => [ '$syslogtag contains "portal_catalyst"' ]
    },
    {
        'name'       => 'httpd.proxy.error',
        'conditions' => [ '$syslogtag contains "httpd_proxy_err"' ]
    },
    {
        'name'       => 'httpd.proxy.access',
        'conditions' => [ '$syslogtag contains "httpd_proxy"' ]
    },
    {
        'name'       => 'httpd.webservices.error',
        'conditions' => [ '$programname contains "httpd_webservices_err"' ]
    },
    {
        'name'       => 'httpd.webservices.access',
        'conditions' => [ '$programname contains "httpd_webservices"' ]
    },
    {
        'name'      => 'httpd.api-frontend.access',
        'conditions' => [ '$msg contains "api-frontend-access"' ],
    },
    {
        'name'      => 'api-frontend.log',
        'conditions' => [ '$programname == "api-frontend"' ],
    },
    {
        'name'       => 'pfstats.log',
        'conditions' => [ '$programname == "pfstats"' ]
    },
    {
        'name'       => 'packetfence.log',
        'conditions' => [
            '$syslogtag contains "packetfence"',
            '$programname == "pfqueue"',
            '$programname == "pfhttpd"',
            '$programname == "pfipset"',
        ]
    },
    {
        'name'       => 'pfdhcp.log',
        'conditions' => [ '$programname == "pfdhcp"' ]
    },
    {
        'name'       => 'pfbandwidthd.log',
        'conditions' => [ '$programname == "pfbandwidthd"' ]
    },
    {
        'name'       => 'pfconfig.log',
        'conditions' => [ '$programname == "pfconfig"' ]
    },
    {
        'name'       => 'pfdetect.log',
        'conditions' => [ '$programname == "pfdetect"' ]
    },
    {
        'name'       => 'pfdhcplistener.log',
        'conditions' => [ '$syslogtag contains "pfdhcplistener"' ]
    },
    {
        'name'       => 'pfdns.log',
        'conditions' => [ '$programname == "pfdns"' ]
    },
    {
        'name'       => 'pffilter.log',
        'conditions' => [ '$programname == "pffilter"' ]
    },
    {
        'name'       => 'pfmon.log',
        'conditions' => [ '$programname == "pfmon"' ]
    },
    {
        'name'       => 'pfsso.log',
        'conditions' => [ '$programname == "pfsso"' ]
    },
    {
        'name'       => 'radius-acct.log',
        'conditions' => [
'$programname contains "radius" and $syslogfacility-text == "local2"',
            '$syslogtag contains "acct" and $syslogfacility-text == "local2"'
        ]
    },
    {
        'name'       => 'radius-cli.log',
        'conditions' =>
          [ '$syslogtag contains "cli" and $syslogfacility-text == "local3"' ]
    },
    {
        'name'       => 'radius-eduroam.log',
        'conditions' => [ '$syslogtag contains "eduroam" ' ]
    },
    {
        'name'       => 'radius-load_balancer.log',
        'conditions' => [
'$syslogtag contains "load_balancer" and $syslogfacility-text == "local5"'
        ]
    },
    {
        'name'       => 'radius.log',
        'conditions' => [
            '$syslogtag contains "auth" and $syslogfacility-text == "local1"',
'$programname contains "radius" and $syslogfacility-text == "local1"'
        ]
    },
    {
        'name'       => 'redis_cache.log',
        'conditions' => [ '$syslogtag contains "redis-cache"' ]
    },
    {
        'name'       => 'redis_ntlm_cache.log',
        'conditions' => [ '$syslogtag contains "redis-ntlm-cache"' ]
    },
    {
        'name'       => 'redis_queue.log',
        'conditions' => [ '$syslogtag contains "redis-queue"' ]
    },
    {
        'name'       => 'redis_server.log',
        'conditions' => [ '$programname == "redis-server"' ]
    },
    {
        'name'       => 'mariadb_error.log',
        'conditions' => [ '$syslogtag contains "mysqld"' ],
    },
    {
        'name'       => 'haproxy_portal.log',
        'conditions' => [ '$programname == "haproxy" and ($msg contains "portal-http" or $msg contains "backend has no server available")' ],
    },
    {
        'name'       => 'haproxy_db.log',
        'conditions' => [ '$programname == "haproxy" and ($msg contains "mysql" or $msg contains "backend has no server available")' ],
    },
);

our $ALL_LOGS = join(",", map { $_->{name} } @pf::constants::syslog::SyslogInfo);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

