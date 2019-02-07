#!/usr/bin/perl

=head1 NAME

Tests for pf::condition::key

=cut

=head1 DESCRIPTION

Tests for pf::condition::key

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 8;                      # last test to print

use Test::NoWarnings;
use pf::condition::equals;

use_ok("pf::condition::key");

my $filter = new_ok ( "pf::condition::key", [profile => 'Test', condition => pf::condition::equals->new(value => 'test'), type => 'test', key => 'test' ],"Test value based filter");

ok($filter->match({ test => 'test'}),"filter matches");

ok($filter->match(bless({ test => 'test'} , "t")),"filter matches a blessed object");

ok(!$filter->match({ test_not_there => 'test'}),"value not found filter does not match matches");

ok(!$filter->match({ test => 'wrong_test'}),"value does not match filter");

ok(!$filter->match({ test => undef }),"value undef does not match filter");

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


