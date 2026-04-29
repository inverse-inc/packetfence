#!/usr/bin/perl

=head1 NAME

Roles

=cut

=head1 DESCRIPTION

unit test for Roles

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 70;
use Test::Mojo;
use Utils;
use pf::dal::node;
use pf::ConfigStore::Roles;

my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Roles");

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/roles';

my $base_url = '/api/v1/config/role';

$t->options_ok($collection_base_url)
  ->status_is(200)
  ->json_is({
        meta => {
              'parent_id' => {
                   'implied' => undef,
                   'type' => 'string',
                   'allow_custom' => 0,
                   'placeholder' => '',
                   'allowed' => [
                                  {
                                    'text' => 'Machine',
                                    'value' => 'Machine'
                                  },
                                  {
                                    'text' => 'REJECT',
                                    'value' => 'REJECT'
                                  },
                                  {
                                    'text' => 'User',
                                    'value' => 'User'
                                  },
                                  {
                                    'text' => 'acls_error1',
                                    'value' => 'acls_error1'
                                  },
                                  {
                                    'value' => 'acls_error2',
                                    'text' => 'acls_error2'
                                  },
                                  {
                                    'value' => 'custom1',
                                    'text' => 'custom1'
                                  },
                                  {
                                    'text' => 'default',
                                    'value' => 'default'
                                  },
                                  {
                                    'value' => 'gaming',
                                    'text' => 'gaming'
                                  },
                                  {
                                    'text' => 'guest',
                                    'value' => 'guest'
                                  },
                                  {
                                    'value' => 'macDetection',
                                    'text' => 'macDetection'
                                  },
                                  {
                                    'text' => 'normal',
                                    'value' => 'normal'
                                  },
                                  {
                                    'text' => 'r1',
                                    'value' => 'r1'
                                  },
                                  {
                                    'value' => 'r2',
                                    'text' => 'r2'
                                  },
                                  {
                                    'value' => 'r3',
                                    'text' => 'r3'
                                  },
                                  {
                                    'value' => 'r4',
                                    'text' => 'r4'
                                  },
                                  {
                                    'value' => 'r5',
                                    'text' => 'r5'
                                  },
                                  {
                                    'value' => 'voice',
                                    'text' => 'voice'
                                  }
                                ],
                   'default' => 'r4',
                   'required' => 0,
             },
          'fingerbank_dynamic_access_list' => {
                'required' => 0,
                'allow_custom' => 0,
                'implied' => undef,
                'type' => 'string',
                'allowed' => [
                               {
                                 'value' => 'enabled',
                                 'text' => 'enabled'
                               },
                               {
                                 'value' => 'disabled',
                                 'text' => 'disabled'
                               }
                             ],
                'default' => undef,
                'placeholder' => undef
          },
            acls => {
                "default" => undef,
                "implied" => undef,
                "placeholder" => "permit tcp any any",
                "required" => 0,
                "type" => "string"
            },
          'notes' => {
                       'placeholder' => undef,
                       'default' => undef,
                       'required' => 0,
                       'type' => 'string',
                       'implied' => undef
                     },
          'id' => {
                    'required' => 1,
                    'type' => 'string',
                    'implied' => undef,
                    'placeholder' => undef,
                    'default' => undef
                  },
          'inherit_vlan' => {
              'allowed' => [
                             {
                               'value' => 'enabled',
                               'text' => 'enabled'
                             },
                             {
                               'value' => 'disabled',
                               'text' => 'disabled'
                             }
                           ],
              'allow_custom' => 0,
              'required' => 0,
              'implied' => undef,
              'type' => 'string',
              'default' => 'disabled',
              'placeholder' => 'enabled'
            },
            'inherit_web_auth_url' => {
                  'required' => 0,
                  'allow_custom' => 0,
                  'implied' => undef,
                  'type' => 'string',
                  'allowed' => [
                                 {
                                   'text' => 'enabled',
                                   'value' => 'enabled'
                                 },
                                 {
                                   'text' => 'disabled',
                                   'value' => 'disabled'
                                 }
                               ],
                  'default' => 'disabled',
                  'placeholder' => 'enabled'
            },
            'max_nodes_per_pid' => {
               'implied' => undef,
               'type' => 'integer',
               'required' => 0,
               'min_value' => 0,
               'placeholder' => 0,
               'default' => 0
             },
             'include_parent_acls' => {
                 'type' => 'string',
                 'implied' => undef,
                 'allow_custom' => 0,
                 'required' => 0,
                 'allowed' => [
                                {
                                  'text' => 'enabled',
                                  'value' => 'enabled'
                                },
                                {
                                  'text' => 'disabled',
                                  'value' => 'disabled'
                                }
                              ],
                 'default' => undef,
                 'placeholder' => undef
               },
              'inherit_role' => {
                  'type' => 'string',
                  'implied' => undef,
                  'allow_custom' => 0,
                  'required' => 0,
                  'allowed' => [
                                 {
                                   'text' => 'enabled',
                                   'value' => 'enabled'
                                 },
                                 {
                                   'value' => 'disabled',
                                   'text' => 'disabled'
                                 }
                               ],
                  'placeholder' => 'enabled',
                  'default' => 'disabled'
            },
            acls_enabled => {
                implied => undef,
                required => 0,
                allow_custom => 0,
                type => 'string',
                allowed => [
                       {
                         'text' => 'enabled',
                         'value' => 'enabled'
                       },
                       {
                         'value' => 'disabled',
                         'text' => 'disabled'
                       }
                ],
                placeholder => 'enabled',
                default => 'enabled'
            }
        },
        status => 200,
  });

{
    my $id = "test_role_${$}_1";
    my $acl = <<ACL;
permit ip 172.16.1.0 0.0.0.255 host 192.168.3.154
ACL
    $t->post_ok($collection_base_url => json => { id => $id, acls => $acl })
      ->status_is(201);
}

{
    my $id = "test_role_${$}_2";
    my $acl = "permit ip 172.16.1.0 0.0.0.255 host 192.168.3.154\n" x 80;
    $t->post_ok($collection_base_url => json => { id => $id, acls => $acl })
      ->status_is(201)
      ->json_has('/warnings');
}

{
    my $id = "test_role_${$}_3";
    my $acl = <<ACL;
in|permit ip 172.16.1.0 0.0.0.255 host 192.168.3.154
out|permit ip 172.16.1.0 0.0.0.255 host 192.168.3.154
  out|permit ip 172.16.1.0 0.0.0.255 host 192.168.3.154
ACL
    $t->post_ok($collection_base_url => json => { id => $id, acls => $acl })
      ->status_is(201);
}

$t->get_ok($collection_base_url)
  ->status_is(200);

$t->post_ok($collection_base_url => json => {})
  ->status_is(422);

$t->post_ok($collection_base_url => json => { id => 'bob.bib', max_nodes_per_pid => 0})
  ->status_is(422)
  ->json_is("/errors/0/field", "id");

$t->post_ok($collection_base_url, {'Content-Type' => 'application/json'} => '{')
  ->status_is(400);

$t->delete_ok("$base_url/default")
  ->status_is(422);

$t->patch_ok("$base_url/gaming/reassign" => json => {})
  ->status_is(422);

my $acls = <<EOS;
permit ip 172.16.1.0 0.0.0.255 host 192.168.3.181
permit ip 172.16.1.0 0.0.0.255 host 192.168.3.182
permit ip 172.16.1.0 0.0.0.255 host 192.168.3.183
EOS

$t->post_ok($collection_base_url => json => { id => 'bob', acls => $acls})
  ->status_is(201);

$t->get_ok("$base_url/bob")
  ->status_is(200)
  ->json_is("/item/acls", $acls);

$t->patch_ok("$base_url/r1" => json => { parent_id => 'r2' })
  ->status_is(422);

$t->patch_ok("$base_url/r1" => json => { parent_id => 'r3' })
  ->status_is(422);

$t->delete_ok("$base_url/r1" => json => {  })
  ->status_is(422);

$t->delete_ok("$base_url/r3" => json => {  })
  ->status_is(200);


pf::dal::node->remove_items(
    -where => {
        "category_id" => {
            -in => \['SELECT node_category.category_id FROM node_category WHERE name = ?', 'r2'],
        },
    },
);

for my $i (1...10) {
    my $mac = Utils::test_mac();
    pf::node::node_add($mac, category => 'r2', pid => 'default');
}

$t->post_ok("$base_url/r2/bulk_reevaluate_access" => json => {  })
  ->status_is(200);

$t->post_ok("$base_url/r2/bulk_reevaluate_access" => json => { async => \1 })
  ->status_is(202);

$t->options_ok("$base_url/r5")
  ->status_is(200)
  ->json_is("/meta/acls",
        {
            "default" => undef,
            "implied" => undef,
            "placeholder" => "permit tcp any any",
            "required" => 0,
            "type" => "string"
        }
  );

$t->post_ok($collection_base_url => json => { id => 'r6', parent_id => 'r5'})
  ->status_is(201);

# parent_id missing/null/'' semantics — see cleanupItemForCreate /
# cleanupItemForUpdate in lib/pf/UnifiedApi/Controller/Config/Roles.pm.
# Test fixture has advanced.default_role_parent_id=r4 (see t/data/pf.conf).
my $cs = pf::ConfigStore::Roles->new;
my $raw_parent_id = sub { $cs->cachedConfig->val($_[0], 'parent_id') };

# CREATE: omitted parent_id -> advanced.default_role_parent_id ('r4')
{
    my $id = "test_parent_${$}_create_omit";
    $t->post_ok($collection_base_url => json => { id => $id })
      ->status_is(201);
    is($raw_parent_id->($id), 'r4',
        "CREATE with omitted parent_id materializes default_role_parent_id");
}

# CREATE: parent_id => null -> empty lock
{
    my $id = "test_parent_${$}_create_null";
    $t->post_ok($collection_base_url => json => { id => $id, parent_id => undef })
      ->status_is(201);
    is($raw_parent_id->($id), '',
        "CREATE with parent_id:null persists explicit empty lock");
}

# CREATE: parent_id => '' -> empty lock
{
    my $id = "test_parent_${$}_create_empty";
    $t->post_ok($collection_base_url => json => { id => $id, parent_id => '' })
      ->status_is(201);
    is($raw_parent_id->($id), '',
        "CREATE with parent_id:'' persists explicit empty lock");
}

# CREATE: parent_id => '<value>' -> stored verbatim
{
    my $id = "test_parent_${$}_create_value";
    $t->post_ok($collection_base_url => json => { id => $id, parent_id => 'r5' })
      ->status_is(201);
    is($raw_parent_id->($id), 'r5',
        "CREATE with explicit parent_id stores the value");
}

# UPDATE: omitted parent_id -> preserved (mergeUpdate carries old value)
{
    my $id = "test_parent_${$}_create_value"; # currently r5
    $t->patch_ok("$base_url/$id" => json => { notes => 'preserved' })
      ->status_is(200);
    is($raw_parent_id->($id), 'r5',
        "UPDATE with omitted parent_id preserves stored value");
}

# UPDATE: parent_id => null -> empty lock
{
    my $id = "test_parent_${$}_create_value"; # currently r5
    $t->patch_ok("$base_url/$id" => json => { parent_id => undef })
      ->status_is(200);
    is($raw_parent_id->($id), '',
        "UPDATE with parent_id:null persists explicit empty lock");
}

# UPDATE: parent_id => '' -> empty lock
{
    my $id = "test_parent_${$}_create_omit"; # currently r4
    $t->patch_ok("$base_url/$id" => json => { parent_id => '' })
      ->status_is(200);
    is($raw_parent_id->($id), '',
        "UPDATE with parent_id:'' persists explicit empty lock");
}

# UPDATE: parent_id => '<value>' -> stored verbatim
{
    my $id = "test_parent_${$}_create_null"; # currently empty
    $t->patch_ok("$base_url/$id" => json => { parent_id => 'r5' })
      ->status_is(200);
    is($raw_parent_id->($id), 'r5',
        "UPDATE with explicit parent_id stores the new value");
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

