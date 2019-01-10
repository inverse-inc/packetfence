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
use lib '/usr/local/pf/lib';
our (@VALID_STRING_TESTS, @INVALID_STRINGS, $TEST_COUNT);

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);

    #Module for overriding configuration paths
    use setup_test_config;

    @VALID_STRING_TESTS = (
        ['a && b',      ['AND', 'a', 'b']],
        ['a && b && c', ['AND', 'a', 'b', 'c']],
        ['a || b',      ['OR',  'a', 'b']],
        ['a || b || c', ['OR',  'a', 'b', 'c']],
        ['a || b && c', ['OR', 'a', ['AND', 'b', 'c']]],
        ['(a || b && c) && (d || e)', ['AND', ['OR', 'a', ['AND', 'b', 'c']], ['OR', 'd', 'e']]],
        ['a & b',      ['AND', 'a', 'b']],
        ['a & b && c', ['AND', 'a', 'b', 'c']],
        ['a | b',      ['OR',  'a', 'b']],
        ['a | b | c',  ['OR',  'a', 'b', 'c']],
        ['a | b & c', ['OR', 'a', ['AND', 'b', 'c']]],
        ['(a | b & c) && (d | e)', ['AND', ['OR', 'a', ['AND', 'b', 'c']], ['OR', 'd', 'e']]],
        ['a', 'a'],
        ['(a)', 'a'],
        ['((a))', 'a'],
        ['( ( a ) )     ', 'a'],
        ['!a', ['NOT', 'a']],
        ['!!a', ['NOT', ['NOT', 'a']]],
        ['!(a && b)',  ['NOT', ['AND', 'a', 'b']]],
        ['a == b', ['==', 'a', 'b']],
        ['a.x == b', ['==', 'a.x', 'b']],
        ['a.x == "b"', ['==', 'a.x', 'b']],
        ['a.x == "b\""', ['==', 'a.x', 'b"']],
        ['a.x == "b\\\\"', ['==', 'a.x', 'b\\']],
        ['a == "b" && c == "d"', ['AND',['==', 'a', 'b'], ['==', 'c', 'd']]],
        ['a == ""', ['==', 'a', '']],
        ['a == b && c == d', ['AND', ['==', 'a', 'b'], ['==', 'c', 'd']]],
        ['a == b && (c == d || c == e)', ['AND', ['==', 'a', 'b'], ['OR', ['==', 'c', 'd'],['==', 'c', 'e']]]],
        ['a =~ "^bob" && (c == d || c == e)', ['AND', ['=~', 'a', '^bob'], ['OR', ['==', 'c', 'd'],['==', 'c', 'e']]]],
        ["a > 6", ['>', 'a', 6]],
        ["a >= 6", ['>=', 'a', 6]],
        ["a < 6", ['<', 'a', 6]],
        ["a <= 6", ['<=', 'a', 6]],
        ["F() > 6", ['>', ['FUNC', 'F', []], 6]],
        ["F(\"bob\", fid) > 6", ['>', ['FUNC', 'F', ['bob', ['VAR', 'fid']]], 6]],
    );

    @INVALID_STRINGS = ('(a', '(a) b', '(a;) && b', ' a == "');

    $TEST_COUNT = 1 + (scalar @VALID_STRING_TESTS) + (scalar @INVALID_STRINGS);
}

use Test::More tests => $TEST_COUNT;
use Test::Exception;

use pf::condition_parser qw(parse_condition_string);

#This test will running last
use Test::NoWarnings;

for my $test (@VALID_STRING_TESTS) {
    test_valid_string(@$test);
}

for my $test (@INVALID_STRINGS) {
    test_invalid_string($test);
}

sub test_valid_string {
    my ($string, $expected) = @_;
    my ($array, $msg) = parse_condition_string($string);
    is_deeply($expected, $array, "Check if '$string' is valid");
    unless ($array){
        print "$msg\n";
    }
}

sub test_invalid_string {
    my ($string) = @_;
    my ($array,$msg) = parse_condition_string($string);
    is(undef, $array, "Check if '$string' invalid");
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

