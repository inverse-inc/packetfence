#!/usr/bin/perl -w

=head1 NAME

smoke.t

=head1 DESCRIPTION

A suite of tests quick to run, with no side-effects and that should always pass.

To be used by nightly build systems.

=cut

use strict;
use warnings;
use diagnostics;

use TAP::Formatter::Console;
use TAP::Harness;
use TAP::Parser::Aggregator;

use lib qw(/usr/local/pf/t);
use TestUtils;

my $formatter   = TAP::Formatter::Console->new({jobs => 4});
my $ser_harness = TAP::Harness->new( { formatter => $formatter, jobs => 4 } );
my $par_harness = TAP::Harness->new(
    {   formatter => $formatter,
        jobs      => 4
    }
);

my @ser_tests = qw(
    pfconfig.t 
    merged_list.t
);
my @par_tests = (
    @TestUtils::compile_tests,
    @TestUtils::unit_tests,
    TestUtils::get_all_unittests(),
    @TestUtils::cli_tests,
    @TestUtils::quality_tests,
    @TestUtils::config_store_test,
);

my $aggregator = TAP::Parser::Aggregator->new;
$aggregator->start();
$ser_harness->aggregate_tests( $aggregator, @ser_tests );
$par_harness->aggregate_tests( $aggregator, @par_tests );
$aggregator->stop();
$formatter->summary($aggregator);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
