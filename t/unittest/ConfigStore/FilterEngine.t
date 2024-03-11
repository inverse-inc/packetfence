#!/usr/bin/perl

=head1 NAME

FilterEngine

=head1 DESCRIPTION

unit test for FilterEngine

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

use Test::More tests => 7;

#This test will running last
use Test::NoWarnings;
use pf::ConfigStore::VlanFilters;
use Utils;

my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::VlanFilters");
my $cs = pf::ConfigStore::VlanFilters->new();
my $item = {
    condition => '!(a == "b")',
    top_op    => 'not_and',
};

$cs->expandCondition($item, 'condition');
is_deeply(
    $item->{condition},
    {
        'value' => 'b',
        'field' => 'a',
        'op'    => 'not_equals'
    }
);

{
    my $item = {
        condition => 'a == "b"',
    };

    $cs->expandCondition($item, 'condition');
    is_deeply(
        $item->{condition},
        {
            'values' => [
                {
                    'value' => 'b',
                    'field' => 'a',
                    'op'    => 'equals'
                }
            ],
            'op' => 'and'
        }
    );
}

{
    my $item = {
        condition => '!(a == "b")',
    };

    $cs->expandCondition($item, 'condition');
    is_deeply(
        $item->{condition},
        {
            'values' => [
                {
                    'value' => 'b',
                    'field' => 'a',
                    'op'    => 'not_equals'
                }
            ],
            'op' => 'and'
        }
    );
}

{
    my $item = {
        condition => '!(a == b)',
    };

    $cs->expandCondition($item, 'condition');
    is_deeply(
        $item->{condition},
        {
            'values' => [
                {
                    'value' => 'b',
                    'field' => 'a',
                    'op'    => 'not_equals'
                }
            ],
            'op' => 'and'
        }
    );
}

{
    $item = $cs->read("registration2", "id");
    is_deeply(
        $item,
        {
            id => "registration2",
            condition => {
                op => 'and',
                values => [
                    { op => "equals", field => "ssid", value => 'TEST' },
                    {
                        op     => 'and',
                        values => [
                            {
                                value => 'bob',
                                op    => 'not_contains',
                                field => "node_info.category"
                            },
                            {
                                op    => "equals",
                                field => "node_info.status",
                                value => "unreg"
                            }
                        ]
                    }
                  ],
            },
            actions => [
                'function0: mac, $mac',
                'function1: mac, $mac',
            ],
            scopes => ['RegistrationRole'],
            status => 'enabled',
            role => 'registration2',
        }
    );

    $item->{actions} = [
        'function3: mac, $mac',
    ];

    $cs->update("registration2", $item);
    is_deeply(
        $cs->read("registration2", "id"),
        {
            id => "registration2",
            condition => {
                op => 'and',
                values => [
                    { op => "equals", field => "ssid", value => 'TEST' },
                    {
                        op     => 'and',
                        values => [
                            {
                                value => 'bob',
                                op    => 'not_contains',
                                field => "node_info.category"
                            },
                            {
                                op    => "equals",
                                field => "node_info.status",
                                value => "unreg"
                            }
                        ]
                    }
                  ],
            },
            actions => [
                'function3: mac, $mac',
            ],
            scopes => ['RegistrationRole'],
            status => 'enabled',
            role => 'registration2',
        }
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

