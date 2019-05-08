#!/usr/bin/perl

=head1 NAME

Nodes

=cut

=head1 DESCRIPTION

unit test for pf::UnifiedApi::Search::Builder::Config

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

use Test::More tests => 11;

#This test will running last
use Test::NoWarnings;
use pf::UnifiedApi::Search::Builder::Config;
use pf::ConfigStore;

my $sb = pf::UnifiedApi::Search::Builder::Config->new();

{
    is_deeply(
        $sb->make_condition(
            {
                query => {
                    op    => 'equals',
                    field => 'mac',
                    value => "00:11:22:33:44:55",
                }
            }
        ),
        pf::condition::key->new(
            {
                key       => 'mac',
                condition => pf::condition::equals->new(
                    { value => "00:11:22:33:44:55" }
                )
            }
        ),
        'Build a simple condition'
    );

    is_deeply(
        $sb->make_condition( {query => undef} ),
        pf::condition::true->new(),
        'No query'
    );

    is_deeply(
        $sb->make_condition(
            {
                query => {
                    op     => 'and',
                    values => [
                        { op => 'not_equals', field => 'mac', value => '11' },
                        { op => 'not_equals', field => 'mac', value => '12' }
                    ]
                }
            }
          ),
        pf::condition::all->new({
            conditions => [
                pf::condition::key->new({ key => 'mac', condition => pf::condition::not_equals->new({value => '11'}) }),
                pf::condition::key->new({ key => 'mac', condition => pf::condition::not_equals->new({value => '12'}) }),
            ],
        }),
        'Logical ops'
    );

    is_deeply(
        $sb->make_condition(
            {
                query => {
                    op     => 'and',
                    values => [
                        { op => 'not_equals', field => 'mac', value => '11' },
                    ]
                }
            }
        ),
        pf::condition::key->new(
            {
                key       => 'mac',
                condition => pf::condition::not_equals->new( { value => '11' } )
            }
        ),
        'Single sub'
    );

}

{
    my $file =<<FILE;
[a]
s=bob

[b]
s=bob

[c]
s=bob

[d]
s=bob

[e]
s=bob

[f]
s=abobh

[g]
s=bbobh

[h]
s=cbobh

[i]
s=dbobh

[j]
s=ebobh

FILE
    my $configStore = pf::ConfigStore->new(cachedConfig => pf::IniFiles->new(-file => \$file));
    is_deeply(
        [
            $sb->search(
                {
                    configStore => $configStore,
                    query       => {
                        op    => 'equals',
                        field => 's',
                        value => 'bob',
                    },
                }
            )
        ],
        [
            200,
            {
                'prevCursor'  => 0,
                'total_count' => 5,
                'items'       => [
                    {
                        'id' => 'a',
                        's'  => 'bob'
                    },
                    {
                        'id' => 'b',
                        's'  => 'bob'
                    },
                    {
                        'id' => 'c',
                        's'  => 'bob'
                    },
                    {
                        'id' => 'd',
                        's'  => 'bob'
                    },
                    {
                        'id' => 'e',
                        's'  => 'bob'
                    },
                  ]

            }
        ],
        "Test equals"
    );

    is_deeply(
        [
            $sb->search(
                {
                    configStore => $configStore,
                    query       => {
                        op    => 'contains',
                        field => 's',
                        value => 'bob',
                    },
                    limit => 3,
                }
            )
        ],
        [
            200,
            {
                'prevCursor'  => 0,
                'total_count' => 10,
                'items'       => [
                    {
                        'id' => 'a',
                        's'  => 'bob'
                    },
                    {
                        'id' => 'b',
                        's'  => 'bob'
                    },
                    {
                        'id' => 'c',
                        's'  => 'bob'
                    },
                  ],
                'nextCursor' => '3',

            }
        ],
        "contain start"
    );

    is_deeply(
        [
            $sb->search(
                {
                    configStore => $configStore,
                    query       => {
                        op    => 'contains',
                        field => 's',
                        value => 'bob',
                    },
                    limit => 3,
                    cursor => 3,
                }
            )
        ],
        [
            200,
            {
                prevCursor  => 3,
                total_count => 10,
                items       => [
                    {
                        'id' => 'd',
                        's'  => 'bob'
                    },
                    {
                        'id' => 'e',
                        's'  => 'bob'
                    },
                    {
                        'id' => 'f',
                        's'  => 'abobh'
                    },
                ],
                nextCursor => 6,
            }
        ],
        "contains cursor"
    );

    is_deeply(
        [
            $sb->search(
                {
                    configStore => $configStore,
                    query       => {
                        op    => 'contains',
                        field => 's',
                        value => 'bob',
                    },
                    limit => 3,
                    cursor => 6,
                }
            )
        ],
        [
            200,
            {
                prevCursor  => 6,
                total_count => 10,
                items       => [
                    {
                        'id' => 'g',
                        's'  => 'bbobh'
                    },
                    {
                        'id' => 'h',
                        's'  => 'cbobh'
                    },
                    {
                        'id' => 'i',
                        's'  => 'dbobh'
                    },
                ],
                nextCursor => 9,
            }
        ],
        "contains next cursor"
    );

    is_deeply(
        [
            $sb->search(
                {
                    configStore => $configStore,
                    query       => {
                        op    => 'contains',
                        field => 's',
                        value => 'bob',
                    },
                    limit => 3,
                    cursor => 9,
                }
            )
        ],
        [
            200,
            {
                prevCursor  => 9,
                total_count => 10,
                items       => [
                    {
                        'id' => 'j',
                        's'  => 'ebobh'
                    },
                ],
            }
        ],
        "Next cursor near the end"
    );

    is_deeply(
        [
            $sb->search(
                {
                    configStore => $configStore,
                    query       => {
                        op    => 'contains',
                        field => 's',
                        value => 'bob',
                    },
                    limit => 3,
                    sort => [{field => 's', dir => 'desc'}],
                }
            )
        ],
        [
            200,
            {
                'prevCursor'  => 0,
                'total_count' => 10,
                'items'       => [
                    {
                        'id' => 'j',
                        's'  => 'ebobh'
                    },
                    {
                        'id' => 'i',
                        's'  => 'dbobh'
                    },
                    {
                        'id' => 'h',
                        's'  => 'cbobh'
                    },
                  ],
                'nextCursor' => '3',

            }
        ],
        "Sort by s"
    );
}

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
