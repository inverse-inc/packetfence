#!/usr/bin/perl

=head1 NAME

Node

=cut

=head1 DESCRIPTION

unit test for Node

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 39;

#This test will running last
use Test::NoWarnings;
use pfappserver::Model::Search::Node;
use pf::dal::node;

my $DEFAULT_LIKE_FORMAT = '%%%s%%';

my @SECURITY_EVENT_JOINS = (
    '=>{security_event_status.mac=node.mac}',
    'security_event|security_event_status',
    '=>{security_event_status.vid=security_event_status_class.vid}',
    'class|security_event_status_class',
);

my $params = {
    'direction'  => 'asc',
    'all_or_any' => undef,
    'per_page'   => '25',
    'by'         => 'mac',
    'searches'   => [
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name'  => 'mac',
            'op'    => 'equal'
        }
    ]
};

is_deeply( pfappserver::Model::Search::Node->make_order_by($params), [{-asc => 'tenant_id'}, { -asc => 'mac' }], "MAC ASC");

is_deeply( pfappserver::Model::Search::Node->make_order_by({by => 'mac'}), [{-asc => 'tenant_id'}, { -asc => 'mac' }], "MAC ASC default order");

is_deeply( pfappserver::Model::Search::Node->make_order_by({direction => 'desc', by => 'mac'}), [{-desc => 'tenant_id'}, { -desc => 'mac' }], "MAC DESC");

is_deeply( pfappserver::Model::Search::Node->make_order_by({direction => 'DESC', by => 'mac'}), [{-desc => 'tenant_id'},{ -desc => 'mac' }], "MAC DESC upper");

is_deeply( pfappserver::Model::Search::Node->make_order_by({direction => 'ASC', by => 'mac'}), [{-asc => 'tenant_id'}, { -asc => 'mac' }], "MAC ASC upper");

is_deeply( pfappserver::Model::Search::Node->make_order_by({direction => 'BAD', by => 'mac'}), [{-asc => 'tenant_id'}, { -asc => 'mac' }], "MAC ASC bad");

is_deeply(
    pfappserver::Model::Search::Node->make_condition(
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name' => 'mac',
            'op' => 'equal'
        }
    ),
    { 'mac' => { '=' => 'ff:ff:ff:ff:ff:ff' } },
    "mac = 'ff:ff:ff:ff:ff:ff'"
);

is_deeply(
    pfappserver::Model::Search::Node->make_condition(
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name' => 'mac',
            'op' => 'not_equal'
        }
    ),
    { 'mac' => { '!=' => 'ff:ff:ff:ff:ff:ff' } },
    "mac != 'ff:ff:ff:ff:ff:ff'"
);

is_deeply(
    pfappserver::Model::Search::Node->make_condition(
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name' => 'mac',
            'op' => 'starts_with'
        }
    ),
    { 'mac' => { '-like' => 'ff:ff:ff:ff:ff:ff%' } },
    "mac LIKE 'ff:ff:ff:ff:ff:ff%'"
);

is_deeply(
    pfappserver::Model::Search::Node->make_condition(
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name' => 'mac',
            'op' => 'ends_with'
        }
    ),
    { 'mac' => { '-like' => '%ff:ff:ff:ff:ff:ff' } },
    "mac LIKE '%ff:ff:ff:ff:ff:ff'"
);

is_deeply(
    pfappserver::Model::Search::Node->make_condition(
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name' => 'mac',
            'op' => 'like'
        }
    ),
    { 'mac' => { '-like' => '%ff:ff:ff:ff:ff:ff%' } },
    "mac LIKE '%ff:ff:ff:ff:ff:ff%'"
);

is_deeply(
    pfappserver::Model::Search::Node->make_condition(
        {
            'value' => 'bob%bob',
            'name' => 'mac',
            'op' => 'like'
        }
    ),
    { 'mac' => { '-like' => \[q{? ESCAPE '\\\\'}, '%bob\\%bob%'] } },
    "mac LIKE '%bob\\%bob%' ESCAPE '\\\\'"
);

$params = {
    'direction'  => 'asc',
    'all_or_any' => undef,
    'per_page'   => '25',
    'by'         => 'mac',
    'searches'   => [
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name'  => 'mac',
            'op'    => 'equal'
        }
    ]
};

is_deeply(
    [
        {
            'regdate' => [
                -and => { ">=" => '2017-12-12 00:00:00' },
                { "<=" => '2017-12-12 23:59:59' }
            ]
        }
    ],
    [ pfappserver::Model::Search::Node->make_date_range( 'regdate', '2017-12-12', '2017-12-12' ) ],
    "regdate between 2017-12-12 2017-12-12"
);

is_deeply(
    [
        {
            'regdate' => [
                -and =>
                { "<=" => '2017-12-12 23:59:59' }
            ]
        }
    ],
    [ pfappserver::Model::Search::Node->make_date_range( 'regdate', undef, '2017-12-12' ) ],
    "regdate less than 2017-12-12"
);

is_deeply(
    [
        {
            'regdate' => [
                -and =>
                { ">=" => '2017-12-12 00:00:00' }
            ]
        }
    ],
    [ pfappserver::Model::Search::Node->make_date_range( 'regdate', '2017-12-12', undef ) ],
    "regdate greater than 2017-12-12"
);

is_deeply(
    [ ],
    [ pfappserver::Model::Search::Node->make_date_range( 'regdate', undef, undef ) ],
    "regdate none"
);


is_deeply(
    {
        -offset => 0,
        -limit => 26,
    },
    {
        pfappserver::Model::Search::Node->make_limit_offset({
            page_num => 1,
            per_page => 25,
        }),
    },
    "Make offset 0, limit 25"
);

is_deeply(
    {
        -offset => 25,
        -limit => 26,
    },
    {
        pfappserver::Model::Search::Node->make_limit_offset({
            page_num => 2,
            per_page => 25,
        }),
    },
    "Make offset 25, limit 25"
);

my @MAKE_LOGICAL_OP_TESTS = (
    {
        'expected' => '-and',
        'input' => undef,
        'test_name' => 'undef to -and',
    },
    {
        'expected' => '-or',
        'input' => 'any',
        'test_name' => 'any to -or',
    },
    {
        'expected' => '-or',
        'input' => 'Any',
        'test_name' => 'any to -or',
    },
    {
        'expected' => '-and',
        'input' => 'all',
        'test_name' => 'all to -and',
    },
    {
        'expected' => '-and',
        'input' => 'garabase',
        'test_name' => 'invalid data defaults to -and',
    },
);

sub test_in_out {
    my ($tests, $method) = @_;
    for my $t (@$tests) {
        is($t->{expected}, $method->($t->{'input'}), $t->{test_name});
    }
}

test_in_out(\@MAKE_LOGICAL_OP_TESTS, sub { pfappserver::Model::Search::Node->make_logical_op(@_) });

$params = {
    'direction'  => 'asc',
    'all_or_any' => undef,
    'per_page'   => '25',
    'by'         => 'mac',
    'searches'   => [
        {
            'value' => 'ff:ff:ff:ff:ff:ff',
            'name'  => 'mac',
            'op'    => 'equal'
        }
    ]
};

is_deeply(
    {
        -where => [
            -and => [
                'r2.radacctid' => undef,
                'locationlog2.id' => undef,
                'node.tenant_id' => 1,
                -and => [{'node.mac' => { "=" => "ff:ff:ff:ff:ff:ff"}}]
            ],
        ],
        -limit => 26,
        -offset => 0,
        -order_by => [{-asc => 'tenant_id'}, {-asc => 'mac'}],
    },
    {
        pfappserver::Model::Search::Node->build_additional_search_args($params),
    },
    "Build a simple search"

);

is_deeply(
    {
        -where => [
            -and => [
                'r2.radacctid' => undef,
                'locationlog2.id' => undef,
                'node.tenant_id' => 1,
            ],
        ],
        -limit => 26,
        -offset => 0,
        -order_by => [{-asc => 'tenant_id'}, {-asc => 'mac'}],
    },
    {
        pfappserver::Model::Search::Node->build_additional_search_args(
        {
            'all_or_any' => 'all',
            'per_page'   => '25',
            'by'         => 'mac',
            'searches'   => [
                {
                    'value' => undef,
                    'name'  => 'mac',
                    'op'    => 'equal'
                }
            ],
            'end'         => undef,
            'direction'   => 'asc',
            'online_date' => undef,
            'start'       => undef
        }
        ),
    },
    "Skip search with a null value and the operator is not null"
);


is_deeply(
    {
        "node.mac" => {
            '-in',
            \[
"select DISTINCT callingstationid from radacct where acctstarttime >= ? AND acctstoptime <= ?",
                "2017-11-06 00:00:00",
                "2017-11-06 23:59:59"
            ]
        }
    },
    pfappserver::Model::Search::Node->make_online_date(
        {
            'end'   => '2017-11-06',
            'start' => '2017-11-06'
        },
    ),
    "Search with an online date"
);

is_deeply(
    {
        -where => [
            -and => [
                    'r2.radacctid' => undef,
                    'locationlog2.id' => undef ,
                    'node.tenant_id' => 1,
                    {
                        "node.mac" => {
                            '-in',
                            \[
        "select DISTINCT callingstationid from radacct where acctstarttime >= ? AND acctstoptime <= ?",
                                "2017-11-06 00:00:00",
                                "2017-11-06 23:59:59"
                            ]
                        }
                    }
            ]
        ],
        -limit    => 26,
        -offset   => 0,
        -order_by => [{-asc => 'tenant_id'}, { -asc => 'mac' }],
    },
    {
        pfappserver::Model::Search::Node->build_additional_search_args(
            {
                'all_or_any' => 'all',
                'per_page'   => '25',
                'by'         => 'mac',
                'searches'   => [
                    {
                        'value' => undef,
                        'name'  => 'mac',
                        'op'    => 'equal'
                    }
                ],
                'end'         => undef,
                'direction'   => 'asc',
                'online_date' => {
                    'end'   => '2017-11-06',
                    'start' => '2017-11-06'
                },
                'start' => undef
            }
        ),
    },
    "Search with an online date"
);

is_deeply(
    {
        -where => [
            -and => [
                    'r2.radacctid' => undef,
                    'locationlog2.id' => undef ,
                    'node.tenant_id' => 1,
                    {
                        "node.mac" => {
                            '-in',
                            \[
        "select DISTINCT callingstationid from radacct where acctstarttime >= ? AND acctstoptime <= ?",
                                "2017-11-06 00:00:00",
                                "2017-11-06 23:59:59"
                            ]
                        }
                    },
                    { detect_date => [-and => {">=" => "2017-11-05 00:00:00" }, {"<=" => "2017-11-05 23:59:59" }]},
            ]
        ],
        -limit    => 26,
        -offset   => 0,
        -order_by => [{-asc => 'tenant_id'}, { -asc => 'mac' }],
    },
    {
        pfappserver::Model::Search::Node->build_additional_search_args(
            {
                'all_or_any' => 'all',
                'per_page'   => '25',
                'by'         => 'mac',
                'searches'   => [
                    {
                        'value' => undef,
                        'name'  => 'mac',
                        'op'    => 'equal'
                    }
                ],
                'start'       => '2017-11-05',
                'end'         => '2017-11-05',
                'direction'   => 'asc',
                'online_date' => {
                    'end'   => '2017-11-06',
                    'start' => '2017-11-06'
                },
            }
        ),
    },
    "Search with an online date "
);

is_deeply(
    {
        -where => [
            -and => [
                    'r2.radacctid' => undef,
                    'locationlog2.id' => undef ,
                    'node.tenant_id' => 1,
                    -and => [
                        {'locationlog.switch_ip' => {"=" => '1.1.1.1'}},
                    ],
            ]
        ],
        -limit    => 26,
        -offset   => 0,
        -order_by => [{-asc => 'tenant_id'}, { -asc => 'mac' }],
    },
    {
        pfappserver::Model::Search::Node->build_additional_search_args(
            {
                'all_or_any' => 'all',
                'per_page'   => '25',
                'by'         => 'mac',
                'searches'   => [
                    {
                        'value' => '1.1.1.1',
                        'name'  => 'switch_ip',
                        'op'    => 'equal'
                    }
                ],
                'direction'   => 'asc',
            }
        ),
    },
    "Search with an online date "
);

is_deeply(
    {
        -where => [
            -and => [
                'r2.radacctid'    => undef,
                'locationlog2.id' => undef,
                'node.tenant_id' => 1,
                -and              => [
                    {
                        -and => [
                            { 'r1.acctstarttime' => { "!=" => undef } },
                            { 'r1.acctstoptime'  => { "="  => undef } }
                        ]
                    },
                ],
            ]
        ],
        -limit    => 26,
        -offset   => 0,
        -order_by => [{-asc => 'tenant_id'}, { -asc => 'mac' }],
    },
    {
        pfappserver::Model::Search::Node->build_additional_search_args(
            {
                'all_or_any' => 'all',
                'per_page'   => '25',
                'by'         => 'mac',
                'searches'   => [
                    {
                        'value' => 'on',
                        'name'  => 'online',
                        'op'    => 'equal'
                    }
                ],
                'direction'   => 'asc',
            }
        ),
    },
    "Search online = 'on' ",
);

is_deeply(
    {
        -where => [
            -and => [
                    'r2.radacctid' => undef,
                    'locationlog2.id' => undef ,
                    'node.tenant_id' => 1,
                    -and              => [
                        {
                            -and => [
                                { 'r1.acctstarttime' => { "!=" => undef } },
                                { 'r1.acctstoptime'  => { "!="  => undef } }
                            ]
                        },
                    ],
            ]
        ],
        -limit    => 26,
        -offset   => 0,
        -order_by => [{-asc => 'tenant_id'}, { -asc => 'mac' }],
    },
    {
        pfappserver::Model::Search::Node->build_additional_search_args(
            {
                'all_or_any' => 'all',
                'per_page'   => '25',
                'by'         => 'mac',
                'searches'   => [
                    {
                        'value' => 'off',
                        'name'  => 'online',
                        'op'    => 'equal'
                    }
                ],
                'direction'   => 'asc',
            }
        ),
    },
    "Search online = 'off' ",
);

is_deeply(
    {
        -where => [
            -and => [
                    'r2.radacctid' => undef,
                    'locationlog2.id' => undef ,
                    'node.tenant_id' => 1,
                    -and => [
                        {'r1.acctstarttime' => {"=" => undef}},
                    ],
            ]
        ],
        -limit    => 26,
        -offset   => 0,
        -order_by => [{-asc => 'tenant_id'}, { -asc => 'mac' }],
    },
    {
        pfappserver::Model::Search::Node->build_additional_search_args(
            {
                'all_or_any' => 'all',
                'per_page'   => '25',
                'by'         => 'mac',
                'searches'   => [
                    {
                        'value' => 'unknown',
                        'name'  => 'online',
                        'op'    => 'equal'
                    }
                ],
                'direction'   => 'asc',
            }
        ),
    },
    "Search online == 'unknown' ",
);

is_deeply(
    {
        -where => [
            -and => [
                    'r2.radacctid' => undef,
                    'locationlog2.id' => undef ,
                    'node.tenant_id' => 1,
                    -and => [
                        {'node.mac' => {"=" => 'ff:ff:ff:ff:ff:fe'}},
                    ],
            ]
        ],
        -limit    => 26,
        -offset   => 0,
        -order_by => [{-asc => 'tenant_id'}, { -asc => 'mac' }],
    },
    {
        pfappserver::Model::Search::Node->build_additional_search_args(
            {
                'all_or_any' => 'all',
                'per_page'   => '25',
                'by'         => 'mac',
                'searches'   => [
                    {
                        'value' => 'FF:FF:FF:FF:FF:FE',
                        'name'  => 'mac',
                        'op'    => 'equal'
                    }
                ],
                'direction'   => 'asc',
            }
        ),
    },
    "Search with an online date "
);


is_deeply(
    [ ],
    [
        pfappserver::Model::Search::Node->make_additionial_joins([])
    ],
    "Test the additional joins based off queries"
);

is_deeply(
    \@pfappserver::Model::Search::Node::SECURITY_EVENT_JOINS_SPECS,
    [
        pfappserver::Model::Search::Node->make_additionial_joins([
            {
                name => 'security_event_status',
                op => 'equal',
                value => 'asas',
            }
        ])
    ]
    ,
    "Test the additional joins based off queries"
);

is_deeply(
    \@pfappserver::Model::Search::Node::SECURITY_EVENT_JOINS_SPECS,
    [
        pfappserver::Model::Search::Node->make_additionial_joins([
            {
                name => 'security_event_status',
                op => 'equal',
                value => 'asas',
            },
            {
                name => 'security_event',
                op => 'equal',
                value => 'asas',
            }
        ])
    ],
    "Only add join once",
);

is_deeply(
    [],
    [
        pfappserver::Model::Search::Node->make_additionial_columns([ ])
    ],
    "No additional columns if there are no searches",
);

is_deeply(
    \@pfappserver::Model::Search::Node::SECURITY_EVENT_ADDITIONAL_COLUMNS,
    [
        pfappserver::Model::Search::Node->make_additionial_columns([
            {
                name => 'security_event_status',
                op => 'equal',
                value => 'asas',
            },
        ]),
    ],
    "Find additional columns for security_event status",
);

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
