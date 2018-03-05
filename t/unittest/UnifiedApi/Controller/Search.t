#!/usr/bin/perl

=head1 NAME

Search

=cut

=head1 DESCRIPTION

unit test for Search

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

use Test::More tests => 14;
use Test::Mojo;

use pf::SQL::Abstract;

#This test will running last
use Test::NoWarnings;

our %OP_TO_SQL_OP = (
    equals              => '=',
    not_equals          => '!=',
    greater_than        => '>',
    less_than           => '<',
    greater_than_equals => '>=',
    less_than_equals    => '<=',
    between             => '-between',
    contains            => '-like',
    ends_with           => '-like',
    starts_with         => '-like',
);

our %OP_TO_HANDLER = (
    (
        map { $_ => \&standard_query_to_sql} qw(equals not_equals greater_than less_than greater_than_equals less_than_equals)
    ),
    between => sub {
        my ($q) = @_;
        return { $q->{field} => { "-between" => $q->{values} } };
    },
    contains => sub {
        my ($q) = @_;
        return { $q->{field} => { "-like" => '%' . $q->{value} . '%' } };
    },
    ends_with => sub {
        my ($q) = @_;
        return { $q->{field} => { "-like" => '%' . $q->{value} } };
    },
    starts_with => sub {
        my ($q) = @_;
        return { $q->{field} => { "-like" => $q->{value} . '%' } };
    },
    and => sub {
        my ($q) = @_;
        local $_;
        my @sub_queries =
          map { searchQueryToSqlAbstract($_) } @{ $q->{values} };
        if ( @sub_queries == 1 ) {
            return $sub_queries[0];
        }
        return { '-and' => \@sub_queries };
    },
    or => sub {
        my ($q) = @_;
        local $_;
        my @sub_queries =
          map { searchQueryToSqlAbstract($_) } @{ $q->{values} };
        if ( @sub_queries == 1 ) {
            return $sub_queries[0];
        }
        return { '-or' => \@sub_queries };
    }
);

sub standard_query_to_sql {
    my ($q) = @_;
    return { $q->{field} => { $OP_TO_SQL_OP{ $q->{op} } => $q->{value} } };
}

my $t = Test::Mojo->new('pf::UnifiedApi');
#This is the first test
is_deeply(
    searchQueryToSqlAbstract(
        {
            "field" => "pid",
            "op"    => "equals",
            "value" => "lzammit"
        }
    ),
    {
        pid => { "=" => "lzammit" }
    },
    "pid = 'lzammit'"
);

is_deeply(
    searchQueryToSqlAbstract(
        {
            "field" => "pid",
            "op"    => "greater_than",
            "value" => "lzammit"
        }
    ),
    {
        pid => { ">" => "lzammit" }
    },
    "pid > 'lzammit'"
);

is_deeply(
    searchQueryToSqlAbstract(
        {
            "field" => "pid",
            "op"    => "less_than",
            "value" => "lzammit"
        }
    ),
    {
        pid => { "<" => "lzammit" }
    },
    "pid < 'lzammit'"
);

is_deeply(
    searchQueryToSqlAbstract(
        {
            "field" => "pid",
            "op"    => "greater_than_equals",
            "value" => "lzammit"
        }
    ),
    {
        pid => { ">=" => "lzammit" }
    },
    "pid >= 'lzammit'"
);

is_deeply(
    searchQueryToSqlAbstract(
        {
            "field" => "pid",
            "op"    => "less_than_equals",
            "value" => "lzammit"
        }
    ),
    {
        pid => { "<=" => "lzammit" }
    },
    "pid <= 'lzammit'"
);

is_deeply(
    searchQueryToSqlAbstract(
        {
            "field" => "pid",
            "op"    => "not_equals",
            "value" => "lzammit"
        }
    ),
    {
        pid => { "!=" => "lzammit" },
    },
    "pid != 'lzammit'"
);

is_deeply(
    searchQueryToSqlAbstract(
        {
            "field" => "pid",
            "op"    => "starts_with",
            "value" => "lzammit"
        }
    ),
    {
        pid => { "-like" => "lzammit%" },
    },
    "pid LIKE 'lzammit%'"
);

is_deeply(
    searchQueryToSqlAbstract(
        {
            "field" => "pid",
            "op"    => "ends_with",
            "value" => "lzammit"
        }
    ),
    {
        pid => { "-like" => "%lzammit" },
    },
    "pid LIKE 'lzammit%'"
);

is_deeply(
    searchQueryToSqlAbstract(
        {
            "field" => "pid",
            "op"    => "contains",
            "value" => "lzammit"
        }
    ),
    {
        pid => { "-like" => "%lzammit%" },
    },
    "pid LIKE '%lzammit%'"
);

is_deeply(
    searchQueryToSqlAbstract(
                {
                    "field"  => "detect_date",
                    "op"     => "between",
                    "values" => [ "2017-01-01 ", "2017-01-02 " ]
                },
    ),
    {
        detect_date => {
            -between => ["2017-01-01 ", "2017-01-02 "]
        },
    },
    "detect_date BETWEEN '2017-01-01' AND '2017-01-02'",
);


is_deeply(
    searchQueryToSqlAbstract(
        {
            "op"     => "and",
            "values" => [
                {
                    "field"  => "detect_date",
                    "op"     => "between",
                    "values" => [ "2017-01-01 ", "2017-01-02 " ]
                },
                {
                    "op"     => "or",
                    "values" => [
                        {
                            "field" => "mac",
                            "op"    => "ends_with",
                            "value" => "ab:cd"
                        },
                        {
                            "field" => "pid",
                            "op"    => "equals",
                            "value" => "lzammit"
                        }
                    ]
                }
            ]
        }

    ),
    {
        -and => [
            {
                detect_date => {
                    -between => ["2017-01-01 ", "2017-01-02 "],
                },
            },
            {
                -or => [
                    {
                        mac => { -like => '%ab:cd' }
                    },
                    {
                        pid => { "=" => "lzammit" }
                    }
                ],
            }
        ],
    },
    "Parsing a complex query"
);

is_deeply(
    searchQueryToSqlAbstract(
        {
            "op"     => "and",
            "values" => [
                {
                    "field"  => "detect_date",
                    "op"     => "between",
                    "values" => [ "2017-01-01 ", "2017-01-02 " ]
                },
            ]
        }

    ),
    {
        detect_date => {
            -between => [ "2017-01-01 ", "2017-01-02 " ],
        },
    },
    "Flatten a single sub query for an and op"
);

is_deeply(
    searchQueryToSqlAbstract(
        {
            "op"     => "or",
            "values" => [
                {
                    "field"  => "detect_date",
                    "op"     => "between",
                    "values" => [ "2017-01-01 ", "2017-01-02 " ]
                },
            ]
        }

    ),
    {
        detect_date => {
            -between => [ "2017-01-01 ", "2017-01-02 " ],
        },
    },
    "Flatten a single sub query for an or op"
);

sub searchQueryToSqlAbstract {
    my ($query) = @_;
    my $op = $query->{op};
    if (exists $OP_TO_HANDLER{$op} ) {
        return $OP_TO_HANDLER{$op}->($query);
    }

    return "die unsupported op $op"
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

