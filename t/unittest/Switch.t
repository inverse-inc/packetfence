#!/usr/bin/perl

=head1 NAME

Switch

=head1 DESCRIPTION

unit test for Switch

=cut

use strict;
use warnings;
#
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 14;
use pf::Switch;

#This test will running last
use Test::NoWarnings;
my $switch = pf::Switch->new( { vlans => { r1 => "gotOne", r2 => "gotTwo" }, id => 'test' });

is(
    $switch->extractSsid({'Called-Station-SSID' => 'Bob'}),
    "Bob",
    "Extract SSID from Called-Station-SSID"
);

is(
    $switch->extractSsid({'Called-Station-SSID' => 'Bob', 'Called-Station-Id' => "aa-bb-cc-dd-ee-ff:Bobby"}),
    "Bobby",
    "Extract SSID from Called-Station-Id"
);

is(
    $switch->extractSsid({'Called-Station-SSID' => 'Bob', 'Called-Station-Id' => "aa:bb:cc:dd:ee:ff:Bobby"}),
    "Bobby",
    "Extract SSID from Called-Station-Id"
);

is(
    $switch->extractSsid({'Called-Station-SSID' => 'Bob', 'Called-Station-Id' => "aabbccddeeff:Bobby"}),
    "Bobby",
    "Extract SSID from Called-Station-Id"
);

is(
    $switch->extractSsid({'Called-Station-SSID' => 'Bob', 'Called-Station-Id' => "aabbccddeef:oBbby"}),
    "Bob",
    "Extract SSID from Called-Station-SSID is Called-Station-Id is invalid"
);

is(
    $switch->getAccessListByName('r3'),
    "allow tcp 80\n",
    "getAccessListByName",
);

is(
    $switch->getAccessListByName('r1'),
    undef,
    "getAccessListByName undef",
);

is(pf::Switch::_parentRoleForVlan("r3"), "r2", "parent role for vlan r3 is r2");
is(pf::Switch::_parentRoleForVlan("r2"), "r1", "parent role for vlan r2 is r1");
is(pf::Switch::_parentRoleForVlan("r1"), undef, "parent role for vlan r1 is undef");

is($switch->getVlanByName("r3"), "gotTwo", "Got the parent vlan");
is($switch->getVlanByName("r2"), "gotTwo", "Got my vlan");
is($switch->getVlanByName("r1"), "gotOne", "Got my vlan");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

