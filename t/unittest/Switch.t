#!/usr/bin/perl

=head1 NAME

Switch

=head1 DESCRIPTION

unit test for Switch

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

use Test::More tests => 8;
use pf::Switch;

#This test will running last
use Test::NoWarnings;
my $switch = pf::Switch->new();

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

