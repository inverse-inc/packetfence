#!/usr/bin/perl -w

=head1 NAME

all.t

=head1 DESCRIPTION

Test suite for all tests.

=cut

use strict;
use warnings;
use diagnostics;

use Test::Harness;

use lib qw(/usr/local/pf/t);
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}
use TestUtils;

# trying to run tests in order were they provide most bang for the buck
runtests(
    @TestUtils::compile_tests,
    @TestUtils::unit_tests,
    @TestUtils::unit_failing_tests,
    @TestUtils::cli_tests,
    @TestUtils::dao_tests,
    @TestUtils::quality_tests,
    @TestUtils::quality_failing_tests,
    @TestUtils::integration_tests,
);

# TODO pfdetect_remote tests

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
