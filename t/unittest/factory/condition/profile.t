#!/usr/bin/perl

=head1 NAME

profile

=head1 DESCRIPTION

unit test for profile

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);

    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::factory::condition::profile;
use Test::More tests => 13;
use Test::NoWarnings;

{
    my $condition =
      pf::factory::condition::profile->instantiate('switch_group:james');
    isa_ok( $condition, "pf::condition::switch_group" );

    is_deeply(
        $condition,
        pf::condition::switch_group->new(
            {
                key       => 'last_switch',
                condition => pf::condition::equals->new( value => "james" ),
            }
        ),
    );

}

{
    my $condition = pf::factory::condition::profile->instantiate_advanced(
        'switch_group == "james"');
    isa_ok( $condition, "pf::condition::switch_group" );

    is_deeply(
        $condition,
        pf::condition::switch_group->new(
            {
                key       => 'last_switch',
                condition => pf::condition::equals->new( value => "james" ),
            }
        ),
    );
}

{
    my $condition = pf::factory::condition::profile->instantiate_advanced(
        'switch_group != "james"');
    isa_ok( $condition, "pf::condition::switch_group" );

    is_deeply(
        $condition,
        pf::condition::switch_group->new(
            {
                key       => 'last_switch',
                condition => pf::condition::not_equals->new( value => "james" ),
            }
        ),
    );
}

{
    my $condition = pf::factory::condition::profile->instantiate_advanced(
        'connection_sub_type == "EAP-TLS"');
    isa_ok( $condition, "pf::condition::key" );

    is_deeply(
        $condition,
        pf::condition::key->new(
            {
                key       => 'last_connection_sub_type',
                condition => pf::condition::equals->new( value => '13' ),
            }
        ),
    );
}

{
    my $condition = pf::factory::condition::profile->instantiate_advanced(
        'connection_sub_type == "13"');
    isa_ok( $condition, "pf::condition::key" );

    is_deeply(
        $condition,
        pf::condition::key->new(
            {
                key       => 'last_connection_sub_type',
                condition => pf::condition::equals->new( value => '13' ),
            }
        ),
    );
}

{
    my $condition =
      pf::factory::condition::profile->instantiate('connection_sub_type:EAP-TLS');
    isa_ok( $condition, "pf::condition::key" );

    is_deeply(
        $condition,
        pf::condition::key->new(
            {
                key       => 'last_connection_sub_type',
                condition => pf::condition::equals->new( value => '13' ),
            }
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
