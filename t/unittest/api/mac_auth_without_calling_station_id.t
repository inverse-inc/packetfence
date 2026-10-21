#!/usr/bin/perl

=head1 NAME

mac_auth_without_calling_station_id

=head1 DESCRIPTION

unit test for pf::api::_is_mac_auth_without_calling_station_id

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 15;

#This test will running last
use Test::NoWarnings;
use pf::api;

# Avaya ERS NEAP: MAC only in the User-Name, as sent by FreeRADIUS (numeric values)
my %neap = ('User-Name' => ['00e04c680308'], 'Service-Type' => [1], 'NAS-Port-Type' => [15], 'NAS-Port' => [2]);

ok(pf::api::_is_mac_auth_without_calling_station_id(\%neap), 'NEAP request is a MAC authentication');
ok(pf::api::_is_mac_auth_without_calling_station_id({ %neap, 'Service-Type' => 'Login-User', 'NAS-Port-Type' => 'Ethernet' }), 'NEAP request with named values');
ok(!pf::api::_is_mac_auth_without_calling_station_id({ %neap, 'User-Name' => ['admin'] }), 'User-Name is not a MAC');
ok(!pf::api::_is_mac_auth_without_calling_station_id({ %neap, 'Service-Type' => [7] }), 'NAS-Prompt-User is a CLI login');
ok(!pf::api::_is_mac_auth_without_calling_station_id({ %neap, 'Service-Type' => [6] }), 'Administrative-User is a CLI login');
ok(!pf::api::_is_mac_auth_without_calling_station_id({ %neap, 'Service-Type' => 'NAS-Prompt-User' }), 'NAS-Prompt-User (named) is a CLI login');
ok(!pf::api::_is_mac_auth_without_calling_station_id({ %neap, 'NAS-Port-Type' => [5] }), 'Virtual port is a CLI login');
ok(!pf::api::_is_mac_auth_without_calling_station_id({ %neap, 'NAS-Port-Type' => [0] }), 'Async port is a CLI login');
ok(!pf::api::_is_mac_auth_without_calling_station_id({ %neap, 'NAS-Port-Type' => undef }), 'without NAS-Port-Type it stays a switch login');
ok(pf::api::_is_mac_auth_without_calling_station_id({ %neap, 'NAS-Port-Type' => [19] }), 'Wireless-802.11 is a MAC authentication');

# The Nortel and Avaya modules take the MAC from the User-Name when there is no Calling-Station-Id
use pf::Switch::Nortel::ERS4000;
use pf::Switch::Avaya::ERS4000;
for my $class (qw(pf::Switch::Nortel::ERS4000 pf::Switch::Avaya::ERS4000)) {
    my $switch = $class->new({ id => '192.0.2.1', ip => '192.0.2.1' });
    is(($switch->parseRequest({ %neap }))[2], '00:e0:4c:68:03:08', "$class: MAC from the User-Name without Calling-Station-Id");
    is(($switch->parseRequest({ %neap, 'Calling-Station-Id' => ['aa-bb-cc-dd-ee-ff'] }))[2], 'aa:bb:cc:dd:ee:ff', "$class: the Calling-Station-Id comes first");
}

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
