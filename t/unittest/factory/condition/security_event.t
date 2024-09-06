#!/usr/bin/perl

=head1 NAME

security_event

=head1 DESCRIPTION

unit test for security_event

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 2;

#This test will running last
use Test::NoWarnings;
use pf::factory::condition::security_event;

my $c = pf::factory::condition::security_event->instantiate('(internal::new_dhcp_info_from_production_network&switch_group::bobob)');
is_deeply(
    $c,
    pf::condition::all->new(
        conditions => [
            pf::condition::key->new(
                key       => 'last_internal_id',
                condition => pf::condition::equals->new(
                    value => 'new_dhcp_info_from_production_network'
                )
            ),
            pf::condition::switch_group->new(
                key       => 'last_switch',
                condition => pf::condition::equals->new(
                    value => 'bobob'
                )
            )
        ],
    ),
);

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

