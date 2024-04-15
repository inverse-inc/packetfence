#!/usr/bin/perl

=head1 NAME

Switches

=cut

=head1 DESCRIPTION

unit test for Switches

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 80;
use List::Util qw(first);
use Test::Mojo;
use Utils;
use pf::ConfigStore::Switch;
use JSON::PP::Boolean;
use Test2::Tools::Compare qw(hash field etc);

my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Switch");

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/switches';

my $base_url = '/api/v1/config/switch';

my @roles = qw(registration isolation inline Machine REJECT User custom1 default gaming guest macDetection normal r1 r2 r3 voice);
my $roles_allowed = [ map { {text => $_, value => $_} } @roles];
my $false = bless( do{\(my $o = 0)}, 'JSON::PP::Boolean' );
my $true = bless( do{\(my $o = 1)}, 'JSON::PP::Boolean' );
my $cs  = pf::ConfigStore::Switch->new();
my $defaults = $cs->read('defaults');


{

    $t->post_ok(
        $collection_base_url => json => {
            type => 'Cisco::Cisco_IOS_15_5',
            id                     => "33:44:55:22:33:44",
            voiceVlan              => '222',
            description            => "Bob",
            registrationAccessList => "permit ip any any\n" x 80,

        }
    )->status_is(422);
}

{

    my $id =  "arubra.packetfence.org";
    $t->post_ok(
        $collection_base_url => json => {
            type => 'Aruba',
            id                     => $id,
            voiceVlan              => '222',
            description            => "Bob",

        }
    )->status_is(422);

    $t->post_ok(
        $collection_base_url => json => {
            type => 'Aruba::Instant',
            id                     => $id,
            voiceVlan              => '222',
            description            => "Bob",

        }
    )->status_is(201);

    $t->get_ok("$base_url/$id")
    ->status_is(200);
}

{

    $t->post_ok(
        $collection_base_url => json => {
            type => 'Cisco::Cisco_IOS_15_5',
            id                     => "33:44:55:22:33:99",
            voiceVlan              => '222',
            description            => "Bob",
            ACLsLimit              => 80,
            registrationAccessList => "permit ip any any\n" x 80,

        }
    )->status_is(201);
}

$t->options_ok($collection_base_url)
  ->status_is(200);

my $json = $t->tx->res->json;

Test2::Tools::Compare::is(
    $json->{meta},
    hash {
        field normalVlan => {
            default     => undef,
            type        => 'string',
            required    => $false,
            placeholder => 1,
        };
        field isolationVlan => {
            default     => undef,
            type        => 'string',
            required    => $false,
            placeholder => 2
        };
        field registrationVlan => {
            default     => undef,
            type        => 'string',
            required    => $false,
            placeholder => 3
        };
        field guestVlan => {
            default     => undef,
            type        => 'string',
            required    => $false,
            placeholder => 5
        };
        field voiceVlan => {
            default     => undef,
            type        => 'string',
            required    => $false,
            placeholder => 10
        };
        field custom1Vlan => {
            default     => undef,
            type        => 'string',
            required    => $false,
            placeholder => 'patate'
        };
        etc();
    },
    "Placeholders for VlanMapping is correct"
);

$t->post_ok($collection_base_url => json => { id => "172.16.9.1", type => 'Cisco::ASA', description => "ss"})
  ->status_is(201)
  ->json_is( '/warnings/0/code', 10002);

$t->post_ok($collection_base_url => json => { id => "172.16.9.2", type => 'Cisco::ASA', description => "ss", UseDownloadableACLs => 'enabled'})
  ->status_is(201)
  ->json_is( '/warnings/0/code', 10001);

$t->post_ok($collection_base_url => json => { id => "blahasas", description => "ss"})
  ->status_is(422);

$t->post_ok($collection_base_url => json => { id => "172.16.8.20/32", description => "ss"})
  ->status_is(201);

$t->post_ok($collection_base_url => json => { id => "172.16.8.20", description => "ss"})
  ->status_is(409);

$t->get_ok( "$base_url/172.16.8.20" )
  ->status_is(200);

$t->get_ok( "$base_url/172.16.8.20%2f32" )
  ->status_is(404);

{
    my $id = '111.1.1.1';
    my $switch_url = "$base_url/$id";
    my $group_id = 'bug-5482';
    my $group_url = "/api/v1/config/switch_group/$group_id";
    $t->patch_ok( $switch_url => json => { voiceVlan => 501 })
        ->status_is(200);
    $t->patch_ok( $group_url => json => { voiceRole => "zammit" });
    $t->get_ok( $group_url  )
      ->status_is(200)
      ->json_is("/item/voiceRole", "zammit")
      ->json_is(
        "/item/ControllerRoleMapping",
        [
            {
                'role'            => 'inline',
                'controller_role' => 'inline'
            },
            {
                'role'            => 'isolation',
                'controller_role' => ''
            },
            {
                'role'            => 'macDetection',
                'controller_role' => ''
            },
            {
                'role'            => 'normal',
                'controller_role' => ''
            },
            {
                'role'            => 'registration',
                'controller_role' => ''
            },
            {
                'role'            => 'voice',
                'controller_role' => 'zammit'
            }
        ]
    );

    $t->get_ok( $switch_url  )
      ->status_is(200)
      ->json_is("/item/voiceRole", "zammit")
      ->json_is("/item/ControllerRoleMapping", [
            {
                'role'            => 'inline',
                'controller_role' => 'inline'
            },
            {
                'role'            => 'isolation',
                'controller_role' => ''
            },
            {
                'role'            => 'macDetection',
                'controller_role' => ''
            },
            {
                'role'            => 'normal',
                'controller_role' => ''
            },
            {
                'role'            => 'registration',
                'controller_role' => ''
            },
            {
                'role'            => 'voice',
                'controller_role' => 'zammit'
            }
      ]);

    $t->patch_ok( $switch_url => json => { voiceVlan => undef })
        ->status_is(200);

    $t->get_ok( $group_url )
        ->status_is(200)
        ->json_is("/item/voiceVlan", 500);

    $t->get_ok( $switch_url  )
      ->status_is(200)
      ->json_is("/item/voiceVlan", "500")
      ->json_is("/item/group", $group_id);
}

$t->get_ok($collection_base_url)
  ->status_is(200);

$t->post_ok($collection_base_url => json => {})
  ->status_is(422);

$t->post_ok($collection_base_url => json => { id => "33:44:55:22:33:44", voiceVlan => '222', description => "Bob" })
  ->status_is(201);

$t->get_ok("$base_url/33:44:55:22:33:44")
  ->status_is(200)
  ->json_is("/item/id", "33:44:55:22:33:44")
  ->json_is("/item/voiceVlan", "222")
  ;

$t->post_ok($collection_base_url, {'Content-Type' => 'application/json'} => '{')
  ->status_is(400);

$t->get_ok("$base_url/172.16.0.0%2f16")
  ->status_is(200);

$t->get_ok("$base_url/172.16.0.0~16")
  ->status_is(200);

$t->patch_ok("$base_url/172.16.8.24" => json => {RoleMap => undef})
  ->status_is(200);

$t->get_ok("$base_url/172.16.8.24")
  ->status_is(200)
  ->json_is('/item/RoleMap', 'N');

$t->patch_ok("$base_url/172.16.8.24" => json => {RoleMap => 'Y'})
  ->status_is(200);

$t->get_ok("$base_url/172.16.8.24")
  ->status_is(200)
  ->json_is('/item/RoleMap', 'Y');

$t->get_ok("$base_url/172.16.8.37")
  ->status_is(200)->json_is(
    '/item/registrationAccessList',
    "permit udp any range bootps 65347 any range bootpc 65348\ndeny ip any any"
  )
  ->json_is(
    '/item/AccessListMapping',
    [
        {
            accesslist =>
"permit udp any range bootps 65347 any range bootpc 65348\ndeny ip any any",
            role => 'registration'
        }
    ]
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

