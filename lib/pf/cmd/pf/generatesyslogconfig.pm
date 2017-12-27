package pf::cmd::pf::generatesyslogconfig;

=head1 NAME

pf::cmd::pf::generatesyslogconfig -

=cut

=head1 DESCRIPTION

pf::cmd::pf::generatesyslogconfig

=cut

use strict;
use warnings;

use base qw(pf::cmd);
use pf::file_paths qw($syslog_config_file $syslog_default_config_file);
use pf::IniFiles;
use Template;
use pf::constants::exit_code qw($EXIT_SUCCESS);


sub items {
    [
        {
            condition =>
              '$syslogtag contains "auth" and $syslogfacility-text == "local1"',
            action => '-/usr/local/pf/logs/radius.log'
        },
        {
            condition =>
'$programname contains "radius" and $syslogfacility-text == "local1"',
            action => '-/usr/local/pf/logs/radius.log'
        },
        {
            condition =>
'$programname contains "radius" and $syslogfacility-text == "local2"',
            action => '-/usr/local/pf/logs/radius-acct.log'
        },
        {
            condition =>
              '$syslogtag contains "acct" and $syslogfacility-text == "local2"',
            action => '-/usr/local/pf/logs/radius-acct.log'
        },
        {
            condition =>
              '$syslogtag contains "cli" and $syslogfacility-text == "local3"',
            action => '-/usr/local/pf/logs/radius-cli.log'
        },
        {
            condition => '$syslogtag contains "eduroam" ',
            action    => '-/usr/local/pf/logs/radius-eduroam.log'
        },
        {
            condition =>
'$syslogtag contains "load_balancer" and $syslogfacility-text == "local5"',
            action => '-/usr/local/pf/logs/radius-load_balancer.log'
        },
        {
            condition => '$syslogtag contains "redis-queue"',
            action    => '-/usr/local/pf/logs/redis_queue.log'
        },

        {
            condition => '$syslogtag contains "redis-cache"',
            action    => '-/usr/local/pf/logs/redis_cache.log'
        },

        {
            condition => '$syslogtag contains "redis-ntlm-cache"',
            action    => '-/usr/local/pf/logs/redis_ntlm_cache.log'
        },
        {
            condition => '$syslogtag contains "pfdhcplistener"',
            action    => '-/usr/local/pf/logs/pfdhcplistener.log'
        },
        {
            condition => '$syslogtag contains "fingerbank"',
            action    => '-/usr/local/pf/logs/fingerbank.log'
        },
        {
            condition => '$syslogtag contains "httpd_parking_err"',
            action    => '-/usr/local/pf/logs/httpd.parking.error'
        },

        {
            condition => '$syslogtag contains "httpd_parking"',
            action    => '-/usr/local/pf/logs/httpd.parking.access'
        },

        {
            condition => '$syslogtag contains "httpd_portal_err"',
            action    => '-/usr/local/pf/logs/httpd.portal.error'
        },

        {
            condition => '$syslogtag contains "httpd_portal"',
            action    => '-/usr/local/pf/logs/httpd.portal.access'
        },

        {
            condition => '$programname contains "httpd_webservices_err"',
            action    => '-/usr/local/pf/logs/httpd.webservices.error'
        },

        {
            condition => '$programname contains "httpd_webservices"',
            action    => '-/usr/local/pf/logs/httpd.webservices.access'
        },

        {
            condition => '$programname contains "httpd_aaa_err"',
            action    => '-/usr/local/pf/logs/httpd.aaa.error'
        },

        {
            condition => '$programname contains "httpd_aaa"',
            action    => '-/usr/local/pf/logs/httpd.aaa.access'
        },

        {
            condition => '$syslogtag contains "packetfence"',
            action    => '-/usr/local/pf/logs/packetfence.log'
        },

        {
            condition => '$syslogtag contains "httpd_admin_err"',
            action    => '-/usr/local/pf/logs/httpd.admin.error'
        },

        {
            condition => '$syslogtag contains "httpd_admin_access"',
            action    => '-/usr/local/pf/logs/httpd.admin.access'
        },

        {
            condition => '$syslogtag contains "httpd_admin"',
            action    => '-/usr/local/pf/logs/httpd.admin.log'
        },

        {
            condition => '$syslogtag contains "httpd_collector_err"',
            action    => '-/usr/local/pf/logs/httpd.collector.error'
        },

        {
            condition => '$syslogtag contains "httpd_collector"',
            action    => '-/usr/local/pf/logs/httpd.collector.log'
        },

        {
            condition => '$syslogtag contains "httpd_graphite_err"',
            action    => '-/usr/local/pf/logs/httpd.graphite.error'
        },

        {
            condition => '$syslogtag contains "httpd_graphite"',
            action    => '-/usr/local/pf/logs/httpd.graphite.access'
        },

        {
            condition => '$syslogtag contains "httpd_proxy_err"',
            action    => '-/usr/local/pf/logs/httpd.proxy.error'
        },

        {
            condition => '$syslogtag contains "httpd_proxy"',
            action    => '-/usr/local/pf/logs/httpd.proxy.access'
        },

        {
            condition => '$syslogtag contains "admin_catalyst"',
            action    => '-/usr/local/pf/logs/httpd.admin.catalyst'
        },

        {
            condition => '$syslogtag contains "portal_catalyst"',
            action    => '-/usr/local/pf/logs/httpd.portal.catalyst'
        },

        # PFCONFIG
        {
            condition => '$programname == "pfconfig"',
            action    => '-/usr/local/pf/logs/pfconfig.log'
        },

        # PFDNS
        {
            condition => '$programname == "pfdns"',
            action    => '-/usr/local/pf/logs/pfdns.log'
        },

        # PFFILTER
        {
            condition => '$programname == "pffilter"',
            action    => '-/usr/local/pf/logs/pffilter.log'
        },

        # PFMON
        {
            condition => '$programname == "pfmon"',
            action    => '-/usr/local/pf/logs/pfmon.log'
        },

        # PFQUEUE
        {
            condition => '$programname == "pfqueue"',
            action    => '-/usr/local/pf/logs/packetfence.log'
        },

        # PFSSO and all pfhttpd services
        {
            condition => '$programname == "pfhttpd"',
            action    => '-/usr/local/pf/logs/packetfence.log'
        },

        # COLLECTD
        {
            condition => '$programname == "collectd"',
            action    => '-/usr/local/pf/logs/collectd.log'
        },

        # PFDETECT
        {
            condition => '$programname == "pfdetect"',
            action    => '-/usr/local/pf/logs/pfdetect.log'
        },

        # PFBANDWIDTHD
        {
            condition => '$programname == "pfbandwidthd"',
            action    => '-/usr/local/pf/logs/pfbandwidthd.log'
        },
    ];
}

sub _run {
    my ($self) = @_;
    my $template = "/usr/local/pf/conf/rsyslog.conf.tt";
    my $tt = Template->new(ABSOLUTE => 1);
    $tt->process($template, {items => $self->items}) || die $tt->error();
    return $EXIT_SUCCESS; 
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
