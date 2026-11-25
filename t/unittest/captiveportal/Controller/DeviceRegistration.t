#!/usr/bin/perl

=head1 NAME

DeviceRegistration

=head1 DESCRIPTION

Role of the devices registered with the device registration page

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 11;
use Test::NoWarnings;

use_ok('captiveportal::PacketFence::Controller::DeviceRegistration');

my $registration_role = \&captiveportal::PacketFence::Controller::DeviceRegistration::registration_role;

is($registration_role->('default,guest', 'guest'), 'guest', 'requested role from the list');
is($registration_role->('default,guest', 'gaming'), 'default', 'requested role outside the list gives the first role of the list');
is($registration_role->('default,guest', undef), 'default', 'no requested role gives the first role of the list');
is($registration_role->(' guest , default ', 'default'), 'default', 'spaces around the roles of the list are ignored');
is($registration_role->('guest', 'guest '), 'guest', 'requested role with a space is not in the list');
is($registration_role->('', 'gaming'), undef, 'requested role is ignored without a list');
is($registration_role->(undef, 'gaming'), undef, 'requested role is ignored without a list (undef)');
is_deeply([captiveportal::PacketFence::Controller::DeviceRegistration::registration_roles(' guest , default,')], ['guest', 'default'], 'the roles shown are the trimmed roles of the list');
is_deeply([captiveportal::PacketFence::Controller::DeviceRegistration::registration_roles(undef)], [], 'no roles without a list');

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
