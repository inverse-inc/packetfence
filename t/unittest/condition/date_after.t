#!/usr/bin/perl

=head1 NAME

Tests for pf::condition::date_after

=cut

=head1 DESCRIPTION

Tests for pf::condition::date_after

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 29;                      # last test to print

use Test::NoWarnings;

use_ok("pf::condition::date_after");
use pf::condition_parser;
use pf::factory::condition;

my $filter = new_ok ( "pf::condition::date_after", [value => '2034-10-28 13:37:42'],"Test pf::condition::date_after constructor with control date");

ok($filter->match('2042-11-27 13:49:42'), "given date is after control date");

ok(!$filter->match('2015-11-27 13:49:42'),"given date is not after control date");

$filter = new_ok ( "pf::condition::date_after", [],"Test pf::condition::date_after constructor without control date");

ok($filter->match('2042-11-27 13:49:42'), "given date is after control date");

ok(!$filter->match('2015-11-27 13:49:42'),"given date is not after control date");

$filter = new_ok ( "pf::condition::date_after", [value => 'now'],"Test pf::condition::date_after constructor with 'now'");

ok($filter->match('2042-11-27 13:49:42'), "given date is after now");

ok(!$filter->match('2015-11-27 13:49:42'), "given date is not after now");

$filter = new_ok ( "pf::condition::date_after", [value => ''],"Test pf::condition::date_after constructor with an empty value");

ok($filter->match('2042-11-27 13:49:42'), "empty value means now");

ok(!$filter->match('0000-00-00 00:00:00'), "unset date doesn't match");

ok(!$filter->match(undef), "undefined date doesn't match");

ok(!$filter->match('not a date'), "invalid date doesn't match");

$filter = new_ok ( "pf::condition::date_after", [value => '2030-01-01'],"Test pf::condition::date_after constructor with a date only");

ok($filter->match('2042-11-27 13:49:42'), "date only control date");

ok($filter->match("2042-11-27"), "date only given date");

ok(!eval { pf::condition::date_after->new(value => 'garbage') }, "invalid control date fails the construction");

like($@, qr/Invalid date 'garbage'/, "with the reason");

ok(!eval { pf::condition::date_after->new(value => '2030-01-01 12:00') }, "control date with a partial time fails the construction");

ok(!eval { pf::condition::date_after->new(value => '2030-01-01T12:00:00') }, "control date in another format fails the construction");

$filter = pf::condition::date_after->new(value => 'now');

ok(!$filter->match('2042-11-27 12:00'), "given date with a partial time doesn't match");

# the negated operator, built like a filter rule
sub rule {
    my ($condition) = @_;
    my ($ast, $err) = pf::condition_parser::parse_condition_string($condition);
    die $err->{highlighted_error} if $err;
    return pf::factory::condition::buildCondition($ast);
}

my $not_rule = rule('not_date_is_after(node_info.unregdate, "now")');

ok($not_rule->match({ node_info => { unregdate => '2015-11-27 13:49:42' } }), "not_date_is_after matches a date not after now");

ok(!$not_rule->match({ node_info => { unregdate => '2042-11-27 13:49:42' } }), "not_date_is_after doesn't match a date after now");

ok(!$not_rule->match({ node_info => { unregdate => '0000-00-00 00:00:00' } }), "not_date_is_after doesn't match an unset date");

ok(!$not_rule->match({ node_info => { } }), "not_date_is_after doesn't match a missing date");

ok(!eval { rule('not_date_is_after(node_info.unregdate, "2030-13")') }, "a rule with an invalid control date fails to build");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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


