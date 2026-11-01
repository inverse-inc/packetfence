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

use Test::More tests => 19;
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

$t->post_ok($collection_base_url => json => {
    id => 'radius_attributes_group',
    type => 'Cisco::Cisco_IOS_15_5',
    RadiusAttributesMap => 'Y',
    guestRadiusAttributes => "Lab-Unknown-Attribute",
})
  ->status_is(422)
  ->json_like('/errors/0/message', qr/'Lab-Unknown-Attribute' is not in the format 'Attribute-Name = value'/);

# as the RADIUS attributes of the switch templates, the names are not checked
$t->post_ok($collection_base_url => json => {
    id => 'radius_attributes_group_unknown',
    type => 'Cisco::Cisco_IOS_15_5',
    RadiusAttributesMap => 'Y',
    guestRadiusAttributes => "Lab-Unknown-Attribute = 1",
})
  ->status_is(201);

# PUT must expand flat ${role}RadiusAttributes into RadiusAttributesMapping
# before validation, same as POST (cleanupItemForReplace → cleanupItemForCreate)
$t->put_ok("$base_url/radius_attributes_group_unknown" => json => {
    id => 'radius_attributes_group_unknown',
    type => 'Cisco::Cisco_IOS_15_5',
    RadiusAttributesMap => 'Y',
    guestRadiusAttributes => "Lab-Unknown-Attribute",
})
  ->status_is(422)
  ->json_like('/errors/0/message', qr/'Lab-Unknown-Attribute' is not in the format 'Attribute-Name = value'/);

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

