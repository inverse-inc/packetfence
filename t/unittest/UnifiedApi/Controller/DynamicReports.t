#!/usr/bin/perl

=head1 NAME

Iplogs

=cut

=head1 DESCRIPTION

unit test for Iplogs

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use DateTime;
use DateTime::Format::Strptime;
use Test::More tests => 17;
use Test::Mojo;
use Test::NoWarnings;
use pf::UnifiedApi::Controller::DynamicReports;
my $true = do { bless \(my $d = 1), "JSON::PP::Boolean" };
my $false = do { bless \(my $d = 0), "JSON::PP::Boolean" };

my $t = Test::Mojo->new('pf::UnifiedApi');

$t->options_ok('/api/v1/dynamic_report/ip4log-archive')->status_is(200)
  ->json_is(
    {
        report_meta => {
            query_fields => [
                {
                    name => 'ip4log_archive.mac',
                    text => 'MAC Address',
                    type => 'string',
                },
                { name => 'ip4log_archive.ip', text => 'IP', type => 'string' },
            ],
            columns => [
                {
                    text      => 'MAC Address',
                    name      => 'MAC Address',
                    is_person => $false,
                    is_node   => $true
                },
                {
                    text      => 'IP',
                    name      => 'IP',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'Start time',
                    name      => 'Start time',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'End time',
                    name      => 'End time',
                    is_person => $false,
                    is_node   => $false
                },
            ],
            has_date_range => $true,
            has_cursor     => $true,
            description => 'IP address archive of the devices on your network when enabled (see Maintenance section)',
            charts => [],
        },
        status => 200,
    }
  );

$t->options_ok('/api/v1/dynamic_report/Node::Active::All')
  ->status_is(200)
  ->json_is(
    {
        report_meta => {
            charts => [],
            query_fields => [ ],
            columns => [
                {
                    text      => 'mac',
                    name      => 'mac',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'ip',
                    name      => 'ip',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'start_time',
                    name      => 'start_time',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'pid',
                    name      => 'pid',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'detect_date',
                    name      => 'detect_date',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'regdate',
                    name      => 'regdate',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'lastskip',
                    name      => 'lastskip',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'status',
                    name      => 'status',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'user_agent',
                    name      => 'user_agent',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'computername',
                    name      => 'computername',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'notes',
                    name      => 'notes',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'last_arp',
                    name      => 'last_arp',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'last_dhcp',
                    name      => 'last_dhcp',
                    is_person => $false,
                    is_node   => $false
                },
                {
                    text      => 'os',
                    name      => 'os',
                    is_person => $false,
                    is_node   => $false
                },
              ],
            has_date_range => $false,
            has_cursor     => $true,
            description    => 'All currently known active nodes',
        },
        status => 200,
    }
  );

$t->get_ok('/api/v1/dynamic_reports' => json => { })
  ->status_is(200);

$t->get_ok('/api/v1/dynamic_report/authentications' => json => { })
  ->json_is('/item/id',"authentications")
  ->json_is('/item/type',"abstract")
  ->status_is(200);
  
$t->post_ok('/api/v1/dynamic_report/authentications/search', {'Content-Type' => 'application/json'} => '{')
  ->status_is(400);

$t->post_ok(
    '/api/v1/dynamic_report/authentications/search' => json => {
        query => {
            op    => 'equals',
            field => 'auth_log.process_name',
            value => 'bob'
        }
    }
  )
  ->status_is(200)
;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
