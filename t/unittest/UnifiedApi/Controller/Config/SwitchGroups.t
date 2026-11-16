#!/usr/bin/perl

=head1 NAME

SwitchGroups

=cut

=head1 DESCRIPTION

unit test for SwitchGroups

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 23;
use Test::Mojo;
use Utils;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::SwitchGroup");

my $collection_base_url = '/api/v1/config/switch_groups';

my $base_url = '/api/v1/config/switch_group';

$t->get_ok($collection_base_url)
  ->status_is(200);

$t->post_ok($collection_base_url => json => {})
  ->status_is(422);

$t->post_ok($collection_base_url => json => {
    id => 'asasa',
    type => 'Hostapd_template'
})
  ->status_is(201);

# PUT expands the flat per-role parameters into their mappings and validates
# them, as POST does
$t->post_ok($collection_base_url => json => {
    id => 'put_group',
    type => 'Cisco::Cisco_IOS_15_5',
})
  ->status_is(201);

$t->put_ok("$base_url/put_group" => json => {
    id => 'put_group',
    type => 'Cisco::Cisco_IOS_15_5',
    r1Vlan => '42',
})
  ->status_is(200);

$t->get_ok("$base_url/put_group")
  ->status_is(200)
  ->json_is('/item/r1Vlan', '42');

$t->put_ok("$base_url/put_group" => json => {
    id => 'put_group',
    type => 'Cisco::Cisco_IOS_15_5',
    registrationAccessList => "permit ip any any\n" x 80,
})
  ->status_is(422);

$t->get_ok("$base_url/put_group")
  ->status_is(200)
  ->json_is('/item/r1Vlan', '42');

$t->post_ok($collection_base_url, {'Content-Type' => 'application/json'} => '{')
  ->status_is(400);

$t->get_ok("$base_url/default/members")
  ->status_is(200);

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

