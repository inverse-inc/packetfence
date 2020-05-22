#!/usr/bin/perl

=head1 NAME

radius

=head1 DESCRIPTION

unit test for radius

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

our @tests;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);

    #Module for overriding configuration paths
    use setup_test_config;
    @tests = (
        {
            name           => 'reply:Packetfence-Raw',
            value          => 'Name:bob',
            expected_name  => 'reply:Name',
            expected_value => 'bob',
        },
        {
            name           => 'Packetfence-Raw',
            value          => 'Name:bob',
            expected_name  => 'Name',
            expected_value => 'bob',
        },
        {
            name           => 'reply:Packetfence-Raw',
            value          => 'Name=bob',
            expected_name  => 'reply:Name',
            expected_value => 'bob',
        },
        {
            name           => 'reply:Packetfence-Raw',
            value          => 'Name = bob',
            expected_name  => 'reply:Name',
            expected_value => 'bob',
        },
        {
            name           => 'reply:Packetfence-Raw',
            value          => 'Name:bob=hope',
            expected_name  => 'reply:Name',
            expected_value => 'bob=hope',
        },
        {
            name           => 'reply:Id',
            value          => 'Name:bob',
            expected_name  => 'reply:Id',
            expected_value => 'Name:bob',
        },
        {
            name           => 'Id',
            value          => 'Name:bob',
            expected_name  => 'Id',
            expected_value => 'Name:bob',
        },
    );
}

use pf::access_filter::radius;
use Test::More tests => 1 + (scalar @tests * 2);

#This test will running last
use Test::NoWarnings;
my $filter = pf::access_filter::radius->new;


for my $test (@tests) {
    my ($name, $value) = $filter->updateAnswerNameValue($test->{name}, $test->{value});

    is ($name, $test->{expected_name}, "expected name '$test->{expected_name}'");
    is ($value, $test->{expected_value}, "expected value '$test->{expected_value}'");
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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

