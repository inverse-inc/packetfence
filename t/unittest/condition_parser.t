#!/usr/bin/perl

=head1 NAME

condition_parser

=cut

=head1 DESCRIPTION

unit test for condition_parser

=cut

use strict;
use warnings;
#
our (@VALID_STRING_TESTS, @INVALID_STRINGS, @VALID_IDS, $TEST_COUNT, @OBJECT_TO_STR_TESTS);

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
    use List::MoreUtils qw(true);

    @VALID_STRING_TESTS = (
        [
            'a && b',
            [ 'AND', 'a', 'b' ],
            {
                op     => "and",
                values => [
                    { op => 'var', field => 'a' },
                    { op => 'var', field => 'b' }
                ]
            }
        ],
        [
            'a && b && c',
            [ 'AND', 'a', 'b', 'c' ],
            {
                op     => "and",
                values => [
                    { op => 'var', field => 'a' },
                    { op => 'var', field => 'b' },
                    { op => 'var', field => 'c' }
                ]
            }
        ],
        [
            'a || b',
            [ 'OR', 'a', 'b' ],
            {
                op     => "or",
                values => [
                    { op => 'var', field => 'a' },
                    { op => 'var', field => 'b' }
                ]
            }
        ],
        [
            'a || b || c',
            [ 'OR', 'a', 'b', 'c' ],
            {
                op     => "or",
                values => [
                    { op => 'var', field => 'a' },
                    { op => 'var', field => 'b' },
                    { op => 'var', field => 'c' }
                ]
            }
        ],
        [
            'a || b && c',
            [ 'OR', 'a', [ 'AND', 'b', 'c' ] ],
            {
                op     => "or",
                values => [
                    { op => 'var', field => 'a' },
                    {
                        op     => 'and',
                        values => [
                            { op => 'var', field => 'b' },
                            { op => 'var', field => 'c' }
                        ]
                    }
                ]
            }
        ],
        [
            '(a || b && c) && (d || e)',
            [ 'AND', [ 'OR', 'a', [ 'AND', 'b', 'c' ] ], [ 'OR', 'd', 'e' ] ],
            {
                op     => 'and',
                values => [
                    {
                        op     => 'or',
                        values => [
                            { op => 'var', field => 'a' },
                            {
                                op     => 'and',
                                values => [
                                    { op => 'var', field => 'b' },
                                    { op => 'var', field => 'c' }
                                ]
                            }
                        ]
                    },
                    {
                        op     => 'or',
                        values => [
                            { op => 'var', field => 'd' },
                            { op => 'var', field => 'e' }
                        ]
                    }
                ]
            }
        ],
        [
            'a & b',
            [ 'AND', 'a', 'b' ],
            {
                op     => "and",
                values => [
                    { op => 'var', field => 'a' },
                    { op => 'var', field => 'b' },
                ]
            }
        ],
        [
            'a & b & c',
            [ 'AND', 'a', 'b', 'c' ],
            {
                op     => "and",
                values => [
                    { op => 'var', field => 'a' },
                    { op => 'var', field => 'b' },
                    { op => 'var', field => 'c' },
                ]
            }
        ],
        [
            'a | b',
            [ 'OR',  'a', 'b' ],
            {
                op     => "or",
                values => [
                    { op => 'var', field => 'a' },
                    { op => 'var', field => 'b' },
                ]
            }
        ],
        [
            'a | b | c',
            [ 'OR',  'a', 'b', 'c' ],
            {
                op     => "or",
                values => [
                    { op => 'var', field => 'a' },
                    { op => 'var', field => 'b' },
                    { op => 'var', field => 'c' },
                ]
            }
        ],
        [
            'a | b & c',
            [ 'OR', 'a', [ 'AND', 'b', 'c' ] ],
            {
                op     => "or",
                values => [
                    { op => 'var', field => 'a' },
                    {
                        op => 'and',
                        values => [
                            { op => 'var', field => 'b' },
                            { op => 'var', field => 'c' },
                        ]
                    }
                ]
            }
        ],
        [
            '(a | b & c) && (d | e)',
            [ 'AND', [ 'OR', 'a', [ 'AND', 'b', 'c' ] ], [ 'OR', 'd', 'e' ] ],
            {
                op     => "and",
                values => [
                    {
                        op => 'or',
                        values => [
                            { op => 'var', field => 'a' },
                            {
                                op => 'and',
                                values => [
                                    { op => 'var', field => 'b' },
                                    { op => 'var', field => 'c' },
                                ]
                            }
                        ]
                    },
                    {
                        op => 'or',
                        values => [
                            { op => 'var', field => 'd' },
                            { op => 'var', field => 'e' },
                        ]
                    }
                ]
            }
        ],
        [ 'a',              'a' ],
        [ '(a)',            'a' ],
        [ '((a))',          'a' ],
        [ '( ( a ) )     ', 'a' ],
        [ '!a', [ 'NOT', 'a' ] ],
        [ '!!a', [ 'NOT',['NOT', 'a'] ] ],
        [ '!(a && b)', [ 'NOT', [ 'AND', 'a', 'b' ] ] ],
        [ 'a == b', [ '==', 'a', 'b' ] ],
        [ 'a.x', 'a.x' ],
        [
            'a.x == b',
            [ '==', 'a.x', 'b' ],
            {
                op => "equals",
                field => "a.x",
                value => "b"
            },
        ],
        [ 'a.x == "b"',     [ '==', 'a.x', 'b' ] ],
        [ "a.x == 'b'",     [ '==', 'a.x', 'b' ] ],
        [ 'a.x == "b\""',   [ '==', 'a.x', 'b"' ] ],
        [ "a.x == 'b\\''",  [ '==', 'a.x', "b'" ] ],
        [ 'a.x == "b\\\\"', [ '==', 'a.x', 'b\\' ] ],
        [ "a.x == 'b\\\\'", [ '==', 'a.x', "b\\" ] ],
        [
            'a == "b" && c == "d"',
            [ 'AND', [ '==', 'a', 'b' ], [ '==', 'c', 'd' ] ],
            {
                op => "and",
                values => [
                    {
                        op => "equals",
                        field => "a",
                        value => "b"
                    },
                    {
                        op => "equals",
                        field => "c",
                        value => "d"
                    }
                ]
            }
        ],
        [
            '!(a == "b" && c == "d")',
            ['NOT', [ 'AND', [ '==', 'a', 'b' ], [ '==', 'c', 'd' ] ]],
            {
                op => "not_and",
                values => [
                    {
                        op => "equals",
                        field => "a",
                        value => "b"
                    },
                    {
                        op => "equals",
                        field => "c",
                        value => "d"
                    }
                ]
            }
        ],
        [
            '!(a == "b")',
            ['NOT', [ '==', 'a', 'b' ], ],
            {
                op => "not_equals",
                field => "a",
                value => "b"
            }
        ],
        [ 'a == ""', [ '==', 'a', '' ] ],
        [
            'a == b && c == d',
            [ 'AND', [ '==', 'a', 'b' ], [ '==', 'c', 'd' ] ]
        ],
        [
            'a == b && (c == d || c == e)',
            [
                'AND',
                [ '==', 'a', 'b' ],
                [ 'OR', [ '==', 'c', 'd' ], [ '==', 'c', 'e' ] ]
            ]
        ],
        [
            'a =~ "^bob" && (c == d || c == e)',
            [
                'AND',
                [ '=~', 'a', '^bob' ],
                [ 'OR', [ '==', 'c', 'd' ], [ '==', 'c', 'e' ] ]
            ],
        ],
        [ "a == __NULL__ ", [ '==', 'a', '__NULL__' ] ],
        [ "a != __NULL__ ", [ '!=', 'a', '__NULL__' ] ],
        [ "a > 6",          [ '>',  'a', 6 ] ],
        [ "a >= 6",         [ '>=', 'a', 6 ] ],
        [ "a < 6",          [ '<',  'a', 6 ] ],
        [ "a <= 6",         [ '<=', 'a', 6 ] ],
        [ "F() > 6", [ '>', [ 'FUNC', 'F', [] ], 6 ] ],
        [
            'F("bob", ${fid}) > 6',
            [ '>', [ 'FUNC', 'F', [ 'bob', [ 'VAR', 'fid' ] ] ], 6 ]
        ],
        [ 'F("bob") > 6', [ '>', [ 'FUNC', 'F', ['bob'] ], 6 ] ],
        [
            'F(${bob}) == 6', [ '==', [ 'FUNC', 'F', [ [ 'VAR', 'bob' ] ] ], 6 ]
        ],
        [
            'F(F(${bob})) == 6',
            [
                '==',
                [ 'FUNC', 'F', [ [ 'FUNC', 'F', [ [ 'VAR', 'bob' ] ] ] ] ], 6
            ]
        ],
        [ 'F()',               [ 'FUNC', 'F', [] ] ],
        [ 'F("bob", ${bob})',  [ 'FUNC', 'F', [ "bob", [ 'VAR', 'bob' ] ] ] ],
        [ "F('bob', \${bob})", [ 'FUNC', 'F', [ "bob", [ 'VAR', 'bob' ] ] ] ],
        [ 'F(bob, ${bob})',    [ 'FUNC', 'F', [ "bob", [ 'VAR', 'bob' ] ] ] ],
        #[ 'F(bob, $bob)',    [ 'FUNC', 'F', [ "bob", '$bob' ] ] ],
        [
            'starts_with(bob, "bobby")',
            [ 'FUNC', 'starts_with', [ "bob", "bobby" ] ],
            {
                op => "starts_with",
                field => "bob",
                value => "bobby",
            },
        ],
        [
            'radius_request.NAS-Port-Type == "19"',
            ['==', 'radius_request.NAS-Port-Type', '19'],
            {
                op => 'equals',
                field => 'radius_request.NAS-Port-Type',
                value => "19",
            }
        ],
        [
            'a !~ "^bob"',
            ['!~', 'a', '^bob'],
            {
                op => 'not_regex',
                field => 'a',
                value => '^bob',
            }
        ],
        [
            'not_defined(node_info.category, "")',
            ['FUNC', 'not_defined', ['node_info.category', ""]],
            {
                op => 'not_defined',
                field => 'node_info.category',
                value => '',
            }
        ],
        [
            'true()',
            ['FUNC', 'true', []],
            {
                op => 'true',
            },
        ],
        [
            'a == "b" && !(b =~ "j")',
            ['AND', ['==', 'a', 'b'], ['NOT', ['=~', 'b', 'j']]],
            {
                op => 'and',
                values => [
                    { op => 'equals', field => 'a', value => 'b'},
                    { op => 'not_regex', field => 'b', value => 'j'},
                ],
            },
        ],
        [
            'connection_type == "Ethernet-EAP" && user_name =~ "^host\\\\/.*\\\\.bh\\\\.local$" && !(user_name =~ "^host\\\\/(BradEhlert|BEhlert).*") && !(user_name =~ "^host\\\\/(dahlstrom|LMMSETUP|wied1419|lmmpunch).*")',
            [
                'AND',
                ['==', 'connection_type', 'Ethernet-EAP'],
                ['=~', 'user_name', '^host\\/.*\\.bh\\.local$'], 
                ['NOT', ['=~', 'user_name', '^host\\/(BradEhlert|BEhlert).*']],
                ['NOT', ['=~', 'user_name', '^host\\/(dahlstrom|LMMSETUP|wied1419|lmmpunch).*']]
            ],
            { 
                op => 'and',
                values => [
                    { op => 'equals', field => 'connection_type', value => 'Ethernet-EAP'},
                    { op => 'regex', field => 'user_name', value => '^host\\/.*\\.bh\\.local$'},
                    { op => 'not_regex', field => 'user_name', value => '^host\\/(BradEhlert|BEhlert).*'},
                    { op => 'not_regex', field => 'user_name', value => '^host\\/(dahlstrom|LMMSETUP|wied1419|lmmpunch).*'},
                ],
            },
        ]
    );

    @VALID_IDS = (
        "a.x",
        "a1.x2",
    );

    @INVALID_STRINGS = (
        '(a', '(a) b',
        '(a;) && b',
        ' a == "',
        'a.',
        '.a',
        'F(',
    );

    @OBJECT_TO_STR_TESTS = (
        [
            {
                op     => "not_and",
                values => [
                    {
                        op    => "equals",
                        field => "a",
                        value => "b"
                    },
                    {
                        op    => "equals",
                        field => "c",
                        value => "d"
                    }
                ]
            },
            '!(a == "b" && c == "d")',
        ],
        [
            {
                op     => "not_and",
                values => [
                    {
                        op    => "equals",
                        field => "c",
                        value => "d"
                    }
                ]
            },
            '!(c == "d")',
        ],
        [
            {
                op     => "not_and",
                values => [
                    {
                        op    => "contains",
                        field => "c",
                        value => "d"
                    }
                ]
            },
            '!(contains(c, "d"))',
        ],
        [
            {
                op     => "not_regex",
                value => "^bob",
                field => 'a',
            },
            'a !~ "^bob"'
        ],
        [
            {
                op => 'true',
            },
            'true()',
        ],
    );

    $TEST_COUNT = 1 + (scalar @VALID_STRING_TESTS) + (true { @$_ == 3  } @VALID_STRING_TESTS ) + (scalar @INVALID_STRINGS) + (scalar @VALID_IDS) + (scalar @OBJECT_TO_STR_TESTS);
}

use Test::More tests => $TEST_COUNT;
use Test::Exception;

use pf::condition_parser qw(parse_condition_string ast_to_object);

#This test will running last
use Test::NoWarnings;

for my $test (@VALID_STRING_TESTS) {
    test_valid_string(@$test);
}

for my $test (@INVALID_STRINGS) {
    test_invalid_string($test);
}

for my $test (@VALID_IDS) {
    local $_ = $test;
    is($test, pf::condition_parser::_parse_id(), "Check if '$test' a valid id");
}

sub test_valid_string {
    my ($string, $expected, $object) = @_;
    my ($ast, $err) = parse_condition_string($string);
    is_deeply($ast, $expected, "Check if '$string' is valid");
    unless ($ast){
        print "$err->{highlighted_error}\n";
    }

    if (defined $object) {
        my $msg = "Object serialization worked for '$string'";
        if ($err) {
            fail($msg);
        } else {
            is_deeply(pf::condition_parser::_ast_to_object($ast), $object, "Object serialization worked for '$string'");
        }
    }
}

{
    for my $test (@OBJECT_TO_STR_TESTS) {
        my $expected = $test->[1];
        is(
            pf::condition_parser::object_to_str($test->[0]),
            $expected,
            "Check object to string '$expected'",
        );
    }
}

sub test_invalid_string {
    my ($string) = @_;
    my ($ast,$err) = parse_condition_string($string);
    is(undef, $ast, "Check if '$string' invalid");
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

