#!/usr/bin/perl

=head1 NAME

radius

=head1 DESCRIPTION

unit test for radius

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

use Test::More tests => 5;
use pf::radius;
use pf::locationlog;
use Utils;

#This test will running last
use Test::NoWarnings;
my $mac = Utils::test_mac();
my $switch_id = '172.16.8.28';
my $first_switch = '00:1a:1e:01:68:f8';
my $second_switch = '00:1a:1e:01:68:f9';

my $radius = pf::radius->new;
$radius->authorize({
    "User-Name" => "77:77:77:77:77:77",
    "User-Password" => "77:77:77:77:77:77",
    "NAS-IP-Address" => $switch_id,
    "NAS-Port" => 1,
    "NAS-Port-Type" => 15,
    "Service-Type" => 10,
    "Called-Station-Id" => $first_switch,
    "Calling-Station-Id" => $mac,
    "Called-Station-SSID" => "Yeah",

});

my $location = locationlog_view_open_mac($mac);
is($location->{switch}, $switch_id);
is($location->{switch_mac}, $first_switch);
$radius->authorize({
    "User-Name" => "77:77:77:77:77:77",
    "User-Password" => "77:77:77:77:77:77",
    "NAS-IP-Address" => $switch_id,
    "NAS-Port" => 1,
    "NAS-Port-Type" => 15,
    "Service-Type" => 10,
    "Called-Station-Id" => $second_switch,
    "Calling-Station-Id" => $mac,
    "Called-Station-SSID" => "Yeah",

});
 $location = locationlog_view_open_mac($mac);
is($location->{switch}, $switch_id);
is($location->{switch_mac}, $second_switch);

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
