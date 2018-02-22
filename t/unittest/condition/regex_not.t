=head1 NAME

Tests for pf::condition::regex_not

=cut

=head1 DESCRIPTION

Tests for pf::condition::regex_not

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 9;                      # last test to print

use Test::Exception;
use Test::NoWarnings;

use_ok("pf::condition::regex");
use_ok("pf::condition::regex_not");

my $filter = new_ok ( "pf::condition::regex_not", [value => '^test'],"Test regex based filter");

ok(!$filter->match('testing123'),"filter regex_not");

ok($filter->match('desting'),"filter does not match regex_not");

ok($filter->match('atesting'),"filter does not match regex_not");

ok(!$filter->match(undef),"value undef does not match filter");

$filter = dies_ok(sub { pf::condition::regex_not->new(value => "(invalid") }, "Unable to build regexp (invalid");

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


