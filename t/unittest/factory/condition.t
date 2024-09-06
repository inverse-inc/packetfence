#!/usr/bin/perl

=head1 NAME

unittest/factory/condition.t

=head1 DESCRIPTION

unit test for pf::factory::condition

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::constants::eap_type qw(%RADIUS_EAP_TYPE_2_VALUES %RADIUS_EAP_VALUES_2_TYPE);
use Test::More tests => (scalar keys %RADIUS_EAP_TYPE_2_VALUES) * 2 + 5;
use pf::factory::condition;

#This test will running last
use Test::NoWarnings;

while (my ($k, $v) = each %RADIUS_EAP_TYPE_2_VALUES) {
    is(pf::factory::condition::normalize_connection_sub_type($k), $v);
    is(pf::factory::condition::normalize_connection_sub_type($v), $v);
}

{
    my $c = pf::factory::condition::build_binary_condition('==', 'a', 'b');
    is_deeply(
        $c,
        pf::condition::key->new(
            key => 'a',
            condition => pf::condition::equals->new(value => 'b'),
        )
    );
}

{
    my $c = pf::factory::condition::build_binary_condition('==', 'a.x', 'b');
    is_deeply(
        $c,
        pf::condition::key->new(
            key => 'a',
            condition => pf::condition::key->new(
                key => 'x',
                condition => pf::condition::equals->new(value => 'b'),
            )
        ),
    );
}

{
    my $c = pf::factory::condition::build_binary_condition('==', 'connection_sub_type', 'EAP-TLS');
    is_deeply(
        $c,
        pf::condition::key->new(
            key => 'connection_sub_type',
            condition => pf::condition::equals->new(value => 13),
        )
    );
}

{
    my $c = pf::factory::condition::build_binary_condition('==', 'bob.connection_sub_type', 'EAP-TLS');
    is_deeply(
        $c,
        pf::condition::key->new(
            key => 'bob',
            condition => pf::condition::key->new(
                key => 'connection_sub_type',
                condition => pf::condition::equals->new(value => 13),
            ),
        ),
    );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

