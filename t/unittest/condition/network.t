#!/usr/bin/perl

=head1 NAME

Tests for pf::condition::network

=cut

=head1 DESCRIPTION

Tests for pf::condition::network

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}
use NetAddr::IP;

use Test::More tests => 9;                      # last test to print

use Test::NoWarnings;

use_ok("pf::condition::network");

my $filter = new_ok ( "pf::condition::network", [ value => '192.168.1.0/24'   ],"Test network based filter");

ok($filter->match('192.168.1.1' ),"filter matches");

ok(!$filter->match('192.168.2.1'),"filter does not match");

ok(!$filter->match( undef ),"last_ip undefined does not match");

ok(!$filter->match( '' ),"empty string does not match");

ok(!$filter->match( 'invalid ip' ),"invalid ip address string does not match");

ok(!$filter->match( 0 ),"invalid ip address number does not match");



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


