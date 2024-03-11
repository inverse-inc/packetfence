#!/usr/bin/perl

=head1 NAME

Nodes

=cut

=head1 DESCRIPTION

unit test for Nodes

=cut

use strict;
use warnings;
#

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 37;

#This test will running last
use Test::NoWarnings;
use pf::UnifiedApi::Search::Builder::Nodes;
use pf::error qw(is_error);
use pf::constants qw($ZERO_DATE);
use pf::dal::node;
my $dal = "pf::dal::node";

my $sb = pf::UnifiedApi::Search::Builder::Nodes->new();

{
    my @f = qw(mac online);
    my %search_info = (
        dal => $dal,
        fields => \@f,
        "query" => {
            "op"     => "and",
            "values" => [
                {
                    "field" => "online",
                    "op"    => "equals",
                    "value" => "on"
                },
                {
                    "op"  => 'or',
                    "values" => [
                            {
                                op => 'equals',
                                value => '00:00:00:00:00:01',
                                field => 'mac',
                            },
                            {
                                op => 'equals',
                                value => '00:00:00:00:00:02',
                                field => 'mac',
                            },
                    ],
                }
            ]
        },
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.mac',
                "CASE IFNULL( (SELECT is_online from node_current_session as ncs WHERE ncs.mac = node.mac), 'unknown') WHEN 'unknown' THEN 'unknown' WHEN 0 THEN 'off' ELSE 'on' END|online",
            ],
        ],
        'Return the columns'
    );

    my $where = [ $sb->make_where(\%search_info) ];
    is_deeply(
        $where,
        [
            200,
            {
                -and => [
                    \["EXISTS (SELECT 1 from node_current_session as ncs WHERE ncs.mac = node.mac AND is_online)"],
                    {
                        -or => [
                            { 'node.mac' => { '=' => '00:00:00:00:00:01'} },
                            { 'node.mac' => { '=' => '00:00:00:00:00:02'} },
                        ],
                    }
                ],
            }
        ],
        'Make where'
    );
}

{
    my @f = qw(mac);
    my %search_info = (
        dal => $dal,
        fields => \@f,
        "query" => {
            "op"     => "and",
            "values" => [
                {
                    "values" => [
                        {
                            "field" => "mac",
                            "op"    => "equals",
                            "value" => "1"
                        }
                    ]
                }
            ]
        },
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.mac',
            ],
        ],
        'Return the columns'
    );

    is_deeply(
        [ $sb->make_where(\%search_info) ],
        [
            422,
              {
                'errors' => [
                              {
                                'value' => '(null)',
                                'scope' => 'op',
                                'message' => 'op is not valid'
                              }
                            ],
                'message' => 'Invalid query'
              }
        ],
        'No op provided'
    );
}

{
    my ($status, $col) = $sb->make_columns({ dal => $dal,  fields => [qw(mac $garbage ip4log.ip)] });
    ok(is_error($status), "Do no accept invalid columns");
}

{
    my @f = qw(mac ip4log.ip locationlog.ssid locationlog.port);

    my %search_info = (
        dal => $dal,
        fields => \@f,
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [ 200, [ 'node.mac', \'`ip4log`.`ip` AS `ip4log.ip`', \'`locationlog`.`ssid` AS `locationlog.ssid`', \'`locationlog`.`port` AS `locationlog.port`'] ],
        'Return the columns'
    );

    is_deeply(
        [
            $sb->make_from(\%search_info)
        ],
        [
            200,
            [
                -join => 'node',
                @pf::UnifiedApi::Search::Builder::Nodes::IP4LOG_JOIN,
                @pf::UnifiedApi::Search::Builder::Nodes::LOCATION_LOG_JOIN,
            ]
        ],
        'Return the joined tables'
    );
}

{
    my @f = qw(mac);
    my %search_info = (
        dal => $dal,
        fields => \@f,
        query => {
            op => 'and',
            values => [
                {
                    op => 'equals',
                    field => 'ip4log.ip',
                    value => undef,
                },
                {
                    op => 'not_equals',
                    field => 'mac',
                    value => undef,
                },
            ]
        },
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.mac',
            ],
        ],
        'Return the columns'
    );

    is_deeply(
        [ $sb->make_where(\%search_info) ],
        [
            200,
            {
                '-and' => [
                    {
                        'ip4log.ip' => {
                            '=' => undef
                        }
                    },
                    {
                        'node.mac' => {
                            '!=' => undef
                        }
                    }
                ]
            }
        ],
        'Return the joined tables'
    );

}

{
    my @f = qw(mac);
    my %search_info = (
        dal => $dal,
        fields => \@f,
        query => {
            op    => 'greater_than',
            field => 'ip4log.ip',
            value => undef,
        },
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.mac',
            ],
        ],
        'Return the columns'
    );

    is_deeply(
        [ $sb->make_where(\%search_info) ],
        [
            422,
            {
                'message' => 'Invalid query',
                'errors'  => [
                    {
                        'message' => 'value for greater_than cannot be null',
                        'scope'   => 'query'
                    }
                ]
            }
        ],
        'Return the joined tables'
    );

}


{
    my @f = qw(mac);
    my %q = (
        op     => 'between',
        field  => 'ip4log.ip',
        values => undef,
    );
    my %search_info = (
        dal    => $dal,
        fields => \@f,
        query  => \%q,
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.mac',
            ],
        ],
        'Return the columns'
    );

    is_deeply(
        [ $sb->make_where(\%search_info) ],
        [
            422,
            {
                'message' => 'Invalid query',
                'errors'  => [
                    {
                        'message' => 'values for between cannot be null',
                        'scope'   => 'query'
                    }
                ]
            }
        ],
        'values cannot be null'
    );
    $q{values} = [];

    is_deeply(
        [ $sb->make_where(\%search_info) ],
        [
            422,
            {
                'errors' => [
                    {
                        'scope'   => 'query',
                        'message' => 'between values must be an array of size 2'
                    }
                ],
                'message' => 'Invalid query'
            }
        ],
        'values must be an array of 2'
    );

    push @{$q{values}}, 1;

    is_deeply(
        [ $sb->make_where(\%search_info) ],
        [
            422,
            {
                'errors' => [
                    {
                        'message' =>
                          'between values must be an array of size 2',
                        'scope' => 'query'
                    }
                ],
                'message' => 'Invalid query'
            }
        ],
        'values must be an array of 2'
    );
    push @{$q{values}}, 2;
    is_deeply(
        [ $sb->make_where(\%search_info) ],
        [
            200,
            {
                'ip4log.ip' => {
                    -between => [1,2],
                }
            }
        ],
        'values must be an array of 2'
    );
    push @{$q{values}}, 2;
    is_deeply(
        [ $sb->make_where(\%search_info) ],
        [
            422,
            {
                'message' => 'Invalid query',
                'errors'  => [
                    {
                        'message' =>
                          'between values must be an array of size 2',
                        'scope' => 'query'
                    }
                ]
            }
        ],
        'values must be an array of 2'
    );
}

{
    my @f = qw(mac);
    my %search_info = (
        dal => $dal,
        fields => \@f,
        query => {
            op => 'equals',
            field => 'ip4log.ip',
            value => undef,
        },
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.mac',
            ],
        ],
        'Return the columns'
    );

    is_deeply(
        [
            $sb->make_where(\%search_info)
        ],
        [
            200,
            {
                'ip4log.ip' => {
                    '=' => undef,
                },
            },
        ],
        'Return the joined tables'
    );

}

{
    my @f = qw(mac locationlog.ssid locationlog.port);

    my %search_info = (
        dal => $dal,
        fields => \@f,
        query => {
            op => 'equals',
            field => 'ip4log.ip',
            value => "1.1.1.1"
        },
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.mac',
                \'`locationlog`.`ssid` AS `locationlog.ssid`',
                \'`locationlog`.`port` AS `locationlog.port`',
            ],
        ],
        'Return the columns'
    );
    is_deeply(
        [
            $sb->make_where(\%search_info)
        ],
        [
            200,
            {
                'ip4log.ip' => { "=" => "1.1.1.1"},
            },
        ],
        'Return the joined tables'
    );

    $sb->make_where(\%search_info);

    my @a = $sb->make_from(\%search_info);
    is_deeply(
        \@a,
        [
            200,
            [
                -join => 'node',
                @pf::UnifiedApi::Search::Builder::Nodes::LOCATION_LOG_JOIN,
                @pf::UnifiedApi::Search::Builder::Nodes::IP4LOG_JOIN,
            ]
        ],
        'Return the joined tables'
    );
}

{
    my @f = qw(status mac pid ip4log.ip bypass_role_id);

    my %search_info = (
        dal => $dal,
        fields => \@f,
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.status',
                'node.mac',
                'node.pid',
                \'`ip4log`.`ip` AS `ip4log.ip`',
                'node.bypass_role_id',
            ],
        ],
        'Return the columns'
    );
    is_deeply(
        [
            $sb->make_where(\%search_info)
        ],
        [
            200,
            {
            },
        ],
        'Return the joined tables'
    );

    my @a = $sb->make_from(\%search_info);
    is_deeply(
        \@a,
        [
            200,
            [
                -join => 'node',
                @pf::UnifiedApi::Search::Builder::Nodes::IP4LOG_JOIN,
            ]
        ],
        'Return the joined tables'
    );
}

{
    my @f = qw(mac security_event.open_count security_event.closed_count);

    my %search_info = (
        dal => $dal,
        fields => \@f,
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.mac',
                \"(SELECT COUNT(*) as count FROM security_event WHERE node.mac = security_event.mac AND status = 'open' ) AS `security_event.open_count`",
                \"(SELECT COUNT(*) as count FROM security_event WHERE node.mac = security_event.mac AND status = 'closed' ) AS `security_event.closed_count`",
            ],
        ],
        'Return the columns'
    );

    is_deeply(
        [ $sb->make_where(\%search_info) ],
        [
            200,
            {
            },
        ],
        'Return the joined tables'
    );

    is_deeply(
        [ $sb->make_from(\%search_info) ],
        [
            200,
            [
                'node',
            ]
        ],
        'Return the joined tables'
    );

}

{
    my @f = qw(mac mac);

    my %search_info = (
        dal => $dal,
        fields => \@f,
    );
    my ($status, $error) = $sb->make_columns( \%search_info );
    is($status, 422, "Duplicated fields error");
}

{
    my @f = qw(mac );

    my %search_info = (
        dal => $dal,
        fields => \@f,
        with_total_count => 1,
    );
    is_deeply(
        [
            $sb->make_columns(\%search_info)
        ],
        [
            200,
            [qw(-SQL_CALC_FOUND_ROWS node.mac)],
        ],
        "with count",
    )
}

{
    my @f = qw(mac);
    my %search_info = (
        dal => $dal,
        fields => \@f,
        query => {
            op => 'and',
            values => [
                {
                    op => 'greater_than_equals',
                    field => 'locationlog.switch_ip',
                    value => '1.2.3.1',
                },
                {
                    op => 'less_than_equals',
                    field => 'locationlog.switch_ip',
                    value => '1.2.3.254',
                },
            ]
        },
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.mac',
            ],
        ],
        'Return the columns'
    );

    is_deeply(
        [ $sb->make_where(\%search_info) ],
        [
            200,
            {
                '-and' => [
                    {
                        'locationlog.switch_ip_int' => {
                            '>=' => 16909057,
                        }
                    },
                    {
                        'locationlog.switch_ip_int' => {
                            '<=' => 16909310,
                        }
                    }
                ]
            }
        ],
        'Return the joined tables'
    );

}

{
    my @f = qw(mac online);

    my %search_info = (
        dal    => $dal,
        fields => \@f,
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.mac',
                "CASE IFNULL( (SELECT is_online from node_current_session as ncs WHERE ncs.mac = node.mac), 'unknown') WHEN 'unknown' THEN 'unknown' WHEN 0 THEN 'off' ELSE 'on' END|online"
            ]
        ],
        'Return the columns'
    );

    is_deeply(
        [ $sb->make_from( \%search_info ) ],
        [ 200, ['node'] ],
        'Return the joined tables'
    );
}

{
    my @f = qw(mac security_event.closed_security_event_id security_event.open_security_event_id);

    my %search_info = (
        dal    => $dal,
        fields => \@f,
    );

    is_deeply(
        [ $sb->make_columns( \%search_info ) ],
        [
            200,
            [
                'node.mac',
                \"(SELECT GROUP_CONCAT(security_event_id) FROM security_event WHERE node.mac = security_event.mac AND status = 'closed' ) AS `security_event.closed_security_event_id`",
                \"(SELECT GROUP_CONCAT(security_event_id) FROM security_event WHERE node.mac = security_event.mac AND status = 'open' ) AS `security_event.open_security_event_id`",
            ]
        ],
        'Return the columns'
    );

    is_deeply(
        [ $sb->make_from( \%search_info ) ],
        [ 200, ['node'] ],
        'Return the joined tables'
    );
}

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
