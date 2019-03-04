#!/usr/bin/perl
=head1 NAME

binaries.t

=head1 DESCRIPTION

Compile check on perl binaries

=cut

use strict;
use warnings;



use Test::More;
use Test::ParallelSubtest;
use Test::NoWarnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use TestUtils qw(get_all_perl_binaries get_all_perl_cgi);
my $jobs = $ENV{'PF_SMOKE_TEST_JOBS'} || @{TestUtils::cpuinfo()};
Test::ParallelSubtest::max_parallel($jobs);

my @binaries = (
    get_all_perl_binaries(),
    get_all_perl_cgi()
);

# all files + no warnings
plan tests => scalar @binaries * 1 + 1;

foreach my $current_binary (@binaries) {
    my $flags = '-I/usr/local/pf/t -Mtest_paths';
    if ($current_binary =~ m#/usr/local/pf/bin/pfcmd\.pl#) {
        $flags .= ' -T';
    }
    bg_subtest "$current_binary" => sub {
        plan tests => 1;
        is( system("/usr/bin/perl $flags -c $current_binary 2>&1"), 0, "$current_binary compiles" );
    };
}

bg_subtest_wait();

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

