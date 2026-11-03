#!/usr/bin/perl

=head1 NAME

Cisco_WLC_AireOS

=head1 DESCRIPTION

unit test for pf::Switch::Cisco::Cisco_WLC_AireOS

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 14;

#This test will running last
use Test::NoWarnings;
use pf::Switch::Cisco::Cisco_WLC_AireOS;
use pf::Switch::Cisco::Cisco_WLC_IOS_XE;

my $switch = pf::Switch::Cisco::Cisco_WLC_AireOS->new({ id => 'test' });

for my $test (
    [ "aa-bb-cc-dd-ee-ff:Bobby", "Bobby", "AP MAC address with dashes and SSID" ],
    [ "aa:bb:cc:dd:ee:ff:Bobby", "Bobby", "AP MAC address with colons and SSID" ],
    [ "aabbccddeeff:Bobby", "Bobby", "AP MAC address without separators and SSID" ],
    [ "Tremough_HSE_0_MG29_AP1:PFTest", "PFTest", "AP name and SSID (ap-name-ssid)" ],
    [ "AP-Name:Guest:WiFi", "Guest:WiFi", "AP name and SSID with a colon" ],
    [ "aa:bb:cc:dd:ee:ff", "Bob", "AP MAC address without SSID uses Called-Station-SSID" ],
    [ "AP-Name", "Bob", "AP name without SSID uses Called-Station-SSID" ],
    [ "ap1.floor-2:PFTest", "PFTest", "AP name with dots and dashes and SSID" ],
    [ "Bldg A:Floor 2", "Bob", "Location with a space (ap-location) uses Called-Station-SSID" ],
    [ "2001:db8::5", "Bob", "IPv6 address (ipaddr) uses Called-Station-SSID" ],
    [ "fe80::1:2:3:4:5", "Bob", "IPv6 address with 6 groups uses Called-Station-SSID" ],
) {
    my ($called_station_id, $expected, $name) = @$test;
    is(
        $switch->extractSsid({ 'Called-Station-Id' => $called_station_id, 'Called-Station-SSID' => 'Bob' }),
        $expected,
        $name,
    );
}

is(
    pf::Switch::Cisco::Cisco_WLC_IOS_XE->new({ id => 'test' })->extractSsid({ 'Called-Station-Id' => "AP-Name:PFTest" }),
    "PFTest",
    "Cisco WLC IOS XE: AP name and SSID",
);

is(
    pf::Switch->new({ id => 'test' })->extractSsid({ 'Called-Station-Id' => "aa:bb:cc:dd:ee:ff", 'Called-Station-SSID' => 'Bob' }),
    "Bob",
    "Other switches are unchanged",
);

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

