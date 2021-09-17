#!/usr/bin/perl

=head1 NAME

Report

=head1 DESCRIPTION

unit test for Report

=cut

use strict;
use warnings;

our @BuildQueryOptionsTests;
our @NextCursorTests;
our @CreateBindTests;
our @IsaTests;
our @ValidateQueryTests;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);

    #Module for overriding configuration paths
    use setup_test_config;
    @BuildQueryOptionsTests = (
        {
            id  => "User::Registration::Sponsor",
            in  => {},
            out => [
                200,
                {
                    offset     => 0,
                    limit      => 25,
                    sql_limit  => 26,
                    start_date => undef,
                    end_date   => undef,
                }
            ]
        },
        {
            id => "User::Registration::Sponsor",
            in => {
                limit  => 100,
                cursor => 100,
            },
            out => [
                200,
                {
                    offset     => 100,
                    limit      => 100,
                    sql_limit  => 101,
                    start_date => undef,
                    end_date   => undef,
                }
            ]
        },
        {
            id => "User::Registration::Sponsor",
            in => {
                limit      => 100,
                cursor     => 200,
                start_date => '2012-12-25'
            },
            out => [
                200,
                {
                    offset     => 200,
                    limit      => 100,
                    sql_limit  => 101,
                    start_date => '2012-12-25',
                    end_date   => undef,
                }
            ]
        },
        {
            id => "User::Registration::SMS",
            in => {
                limit      => 100,
                cursor     => 200,
                start_date => '2012-12-25',
                end_date   => '2013-12-25',
                'sort'     => 'pid',
                query      => {
                    op     => 'and',
                    values => [
                        {
                            op    => 'equals',
                            field => "activation.pid",
                            value => 'bob'
                        },
                    ],
                },
            },
            out => [
                200,
                {
                    offset     => 200,
                    limit      => 100,
                    sql_limit  => 101,
                    order      => 'pid',
                    start_date => '2012-12-25',
                    end_date   => '2013-12-25',
                    where      => {
                        'activation.pid' => { '=' => 'bob' }
                    },
                }
            ]
        },
        {
            id  => "Node::Active::All",
            in  => { cursor => "22:33:22:33:33:33" },
            out => [
                200,
                {
                    cursor    => "22:33:22:33:33:33",
                    limit     => 100,
                    sql_limit => 101
                }
            ]
        },
        {
            id  => "Node::Active::All",
            in  => {},
            out => [
                200,
                {
                    cursor    => "00:00:00:00:00:00",
                    limit     => 100,
                    sql_limit => 101
                }
            ]
        }
    );

    @NextCursorTests = (
        {
            id => "Node::Active::All",
            in => [
                [ {}, {}, { mac => "22:33:22:33:33:33" } ], sql_limit => 3,
            ],
            out     => "22:33:22:33:33:33",
            results => [ {}, {} ],
        },
        {
            id => "Node::Active::All",
            in => [
                [ {}, {}, { mac => "22:33:22:33:33:33" } ], sql_limit => 4,
            ],
            out     => undef,
            results => [ {}, {}, { mac => "22:33:22:33:33:33" } ],
        },
        {
            id => "User::Registration::Sponsor",
            in => [
                [ {}, {}, { mac => "22:33:22:33:33:33" } ],
                limit  => 2,
                cursor => 2,
            ],
            out     => 4,
            results => [ {}, {}, ],
        },
        {
            id => "User::Registration::Sponsor",
            in => [
                [ {}, {}, { mac => "22:33:22:33:33:33" } ],
                limit  => 3,
                cursor => 3,
            ],
            out     => undef,
            results => [ {}, {}, { mac => "22:33:22:33:33:33" } ],
        },
    );

    @CreateBindTests = (
        {
            id => 'Node::Active::All',
            in => [
                {
                    cursor    => '00:00:00:00:00:00',
                    sql_limit => 101,
                    limit     => 100,
                }
            ],
            out => [ 1, '00:00:00:00:00:00', 101 ],
        }
    );

    @IsaTests = (
        {
            id  => 'User::Registration::Sponsor',
            isa => 'pf::Report::abstract',
        },
        {
            id  => 'Node::Active::All',
            isa => 'pf::Report::sql',
        }
    );

    @ValidateQueryTests = (
        {
            id => 'User::Registration::Sponsor',
            in => {
                op => 'and',
            },
            out => [],
        },
        {
            id => 'User::Registration::Sponsor',
            in => {
                field => 'garbage',
                op    => 'equals',
                value => '',
            },
            out => [
                {
                    field   => 'garbage',
                    message => 'invalid field',
                }
            ],
        },
        {
            id => 'User::Registration::Sponsor',
            in => {
                field => 'activation.pid',
                op    => 'equals',
                value => 'bob',
            },
            out => [],
        },
        {
            id  => 'User::Registration::Sponsor',
            in  => undef,
            out => [],
        },
        {
            id  => 'User::Registration::Sponsor',
            in  => {
                op => 'and',
                values => [
                    {
                        field => 'garbage',
                        op    => 'equals',
                        value => '',
                    }
                ],
            },
            out => [
                {
                    field   => 'garbage',
                    message => 'invalid field',
                }
            ],
        },
        {
            id  => 'User::Registration::Sponsor',
            in  => {
                op => 'and',
                values => [
                    {
                        field => 'garbage',
                        op    => undef,
                        value => '',
                    }
                ],
            },
            out => [
                { message => 'op (null) is invalid'}
            ],
        },
        {
            id  => 'User::Registration::Sponsor',
            in  => {
                op => 'garbage',
            },
            out => [
                { message => 'op (garbage) is invalid'}
            ],
        },
        {
            id  => 'User::Registration::Sponsor',
            in  => {
                op => 'garbage',
            },
            out => [
                { message => 'op (garbage) is invalid'}
            ],
        },
        {
            id  => 'User::Registration::Sponsor',
            in  => {
                op => 'equals',
                field => undef,
            },
            out => [
                { message => 'field must be set'}
            ],
        },
        {
            id  => 'User::Registration::Sponsor',
            in  => {
                op => 'contains',
                field => 'activation.pid',
            },
            out => [
                { message => 'op (contains) is not allowed to have a null value'}
            ],
        },
    );
}

use Test::More tests => 1 + (scalar @BuildQueryOptionsTests) + ( scalar @NextCursorTests ) * 2 + (scalar @CreateBindTests) + (scalar @IsaTests) * 2 + scalar @ValidateQueryTests;

use pf::SQL::Abstract;
use pf::factory::report;

#This test will running last
use Test::NoWarnings;

{
    for my $t (@IsaTests) {
        my $id = $t->{id};
        my $report = pf::factory::report->new($id);
        ok ($report, "report '$id' created");
        isa_ok ($report, $t->{isa}, );
    }
}

{
    for my $t (@ValidateQueryTests) {
        my $id = $t->{id};
        my $report = pf::factory::report->new($id);
        my $in = $t->{in};
        my @errors;
        $report->validate_query($in, \@errors),
        is_deeply(
            \@errors,
            $t->{out},
            "$id: pf::Report->validate_query"
        );
    }
}

{
    for my $t (@CreateBindTests) {
        my $id = $t->{id};
        my $report = pf::factory::report->new($id);
        my $in = $t->{in};
        is_deeply($report->create_bind(@$in), $t->{out}, "$id: pf::Report::sql->create_bind");
    }
}

{
    for my $t (@BuildQueryOptionsTests) {
        my $id = $t->{id};
        my $report = pf::factory::report->new($id);
        is_deeply(
            [$report->build_query_options($t->{in})],
            $t->{out},
            "build_query_options $id",
        );
    }
}

{
    for my $t (@NextCursorTests) {
        my $id = $t->{id};
        my $report = pf::factory::report->new($id);
        my $in = $t->{in};
        is($report->nextCursor(@$in), $t->{out}, "$id: pf::Report->nextCursor");
        is_deeply($in->[0], $t->{results}, "$id: pf::Report::sql->nextCursor results");
    }
}

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

