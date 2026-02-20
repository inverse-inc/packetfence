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
use Mojo::JSON;
use Utils;
use pf::dal::node;
use pf::ConfigStore::Roles;
use pf::ConfigStore::RolesReadonly;

my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Roles");
my ($fh_ro, $filename_ro) = Utils::tempfileForConfigStore("pf::ConfigStore::RolesReadonly");

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/roles';

my $base_url = '/api/v1/config/role';

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

# Read-only role enforcement tests

# 1. Set read-only on role 'bob'
$t->put_ok("$base_url/bob/set_readonly" => json => { readonly => \1 })
  ->status_is(200);

# 2. GET bob shows readonly metadata
$t->get_ok("$base_url/bob")
  ->status_is(200)
  ->json_is("/item/not_updatable", Mojo::JSON->true)
  ->json_is("/item/readonly", Mojo::JSON->true);

# 3. PATCH bob is blocked
$t->patch_ok("$base_url/bob" => json => { notes => 'test' })
  ->status_is(403);

# 4. PUT bob is blocked
$t->put_ok("$base_url/bob" => json => { id => 'bob' })
  ->status_is(403);

# 5. DELETE bob is blocked
$t->delete_ok("$base_url/bob")
  ->status_is(403);

# 6. bulk_update with bob returns per-item 403
$t->patch_ok("$collection_base_url/bulk_update" => json => { items => [ { id => 'bob', notes => 'test' } ] })
  ->status_is(200)
  ->json_is("/items/0/status", 403);

# 7. bulk_delete with bob returns per-item 403
$t->post_ok("$collection_base_url/bulk_delete" => json => { items => ['bob'] })
  ->status_is(200)
  ->json_is("/items/0/status", 403);

# 8. reassign on bob is blocked
$t->patch_ok("$base_url/bob/reassign" => json => { id => 'default' })
  ->status_is(403);

# 9. bulk_import updating bob returns per-item 403
$t->post_ok("$collection_base_url/bulk_import" => json => { items => [ { id => 'bob' } ] })
  ->status_is(200)
  ->json_is("/items/0/status", 403);

# 10. Unset read-only on bob
$t->put_ok("$base_url/bob/set_readonly" => json => { readonly => \0 })
  ->status_is(200);

# 11. PATCH bob succeeds again
$t->patch_ok("$base_url/bob" => json => { notes => 'updated' })
  ->status_is(200);

# 12. GET readonly list endpoint
$t->get_ok("$collection_base_url/list_readonly")
  ->status_is(200)
  ->json_has("/items");

# 13. Set readonly on nonexistent role returns 404
$t->put_ok("$base_url/nonexistent_role_xyz/set_readonly" => json => { readonly => \1 })
  ->status_is(404);

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

