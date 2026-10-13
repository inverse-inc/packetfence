#!/usr/bin/perl

=head1 NAME

Tests for pf::condition::date_before

=cut

=head1 DESCRIPTION

Tests for pf::condition::date_before

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 21;                      # last test to print

use Test::NoWarnings;

use_ok("pf::condition::date_before");

my $filter = new_ok ( "pf::condition::date_before", [value => '2034-10-28 13:37:42'],"Test pf::condition::date_before constructor with control date");

ok($filter->match('2015-11-27 13:49:42'), "given date is before control date");

ok(!$filter->match('2042-11-27 13:49:42'),"given date is not before control date");

$filter = new_ok ( "pf::condition::date_before", [],"Test pf::condition::date_before constructor without control date");

ok($filter->match('2015-11-27 13:49:42'), "given date is before control date");

ok(!$filter->match('2042-11-27 13:49:42'),"given date is not before control date");

$filter = new_ok ( "pf::condition::date_before", [value => 'now'],"Test pf::condition::date_before constructor with 'now'");

ok($filter->match('2015-11-27 13:49:42'), "given date is before now");

ok(!$filter->match('2042-11-27 13:49:42'), "given date is not before now");

$filter = new_ok ( "pf::condition::date_before", [value => ''],"Test pf::condition::date_before constructor with an empty value");

ok($filter->match('2015-11-27 13:49:42'), "empty value means now");

ok(!$filter->match('0000-00-00 00:00:00'), "unset date doesn't match");

ok(!$filter->match(undef), "undefined date doesn't match");

ok(!$filter->match('not a date'), "invalid date doesn't match");

$filter = new_ok ( "pf::condition::date_before", [value => '2030-01-01'],"Test pf::condition::date_before constructor with a date only");

ok($filter->match('2015-11-27 13:49:42'), "date only control date");

ok($filter->match("2015-11-27"), "date only given date");

$filter = new_ok ( "pf::condition::date_before", [value => 'garbage'],"Test pf::condition::date_before constructor with an invalid control date");

ok(!$filter->match('2015-11-27 13:49:42'), "invalid control date doesn't match");

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


