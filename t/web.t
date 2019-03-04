#!/usr/bin/perl
=head1 NAME

web.t

=head1 DESCRIPTION

Tests for our pf::web and friends modules.

=cut

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}
use Test::More tests => 23;
use Test::MockObject::Extends;
use Test::NoWarnings;

use CGI;

use pf::config;

BEGIN { use_ok('pf::web') }
BEGIN { use_ok('pf::web::constants') }
BEGIN { use_ok('pf::web::dispatcher') }
BEGIN { use_ok('pf::web::guest') }
BEGIN { use_ok('pf::web::release') }
BEGIN { use_ok('pf::web::util') }
BEGIN { use_ok('pf::web::custom') }

=head1 TESTS

=head2 pf::web::util's subroutines

=cut

# phone number validation (north american style)
my $expected = "5145554918";
is(pf::web::util::validate_phone_number("5145554918"), $expected, "validate phone number format xxxxxxxxxx");
is(pf::web::util::validate_phone_number("514-555-4918"), $expected, "validate phone number format xxx-xxx-xxxx");
is(pf::web::util::validate_phone_number("514.555.4918"), $expected, "validate phone number format xxx.xxx.xxxx");
is(pf::web::util::validate_phone_number("514 555 4918"), $expected, "validate phone number format xxx xxx xxxx");
is(pf::web::util::validate_phone_number("(514) 555 4918"), $expected, "validate phone number format (xxx) xxx xxxx");
is(pf::web::util::validate_phone_number("(514) 555-4918"), $expected, "validate phone number format (xxx) xxx-xxxx");
$expected = "15145554918";
is(pf::web::util::validate_phone_number("+1 514 555-4918"), $expected, "validate phone number format +1 xxx xxx-xxxx");
is(pf::web::util::validate_phone_number("1 514 555-4918"), $expected, "validate phone number format 1 xxx xxx-xxxx");
is(pf::web::util::validate_phone_number("1-514-555-4918"), $expected, "validate phone number format 1 xxx xxx-xxxx");
is(
    pf::web::util::validate_phone_number("1 (514) 555-4918"), $expected, "validate phone number format 1 (xxx) xxx-xxxx"
);

# phone number validation (international style)
$expected = "223344556677";
is(
    pf::web::util::validate_phone_number("22 33 44 55 66 77"), $expected,
    "validate phone number format xx xx xx xx xx xx"
);
is(
    pf::web::util::validate_phone_number("+22 33 44 55 66 77"), $expected,
    "validate phone number format +xx xx xx xx xx xx"
);
is(
    pf::web::util::validate_phone_number("223344556677"), $expected,
    "validate phone number format xxxxxxxxxxxx"
);

=head2 pf::web::constants

=cut

ok(defined($WEB::URL_SIGNUP), 'WEB constants are available since we imported pf::web::constants');

my %result =  pf::web::constants::to_hash();
is(
    $result{'URL_SIGNUP'}, '/signup', 'constant from pf::web::constant is returned in hashref by to_hash'
);


# TODO add more tests, we should test:
#  - all methods ;)

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

