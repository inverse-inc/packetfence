#!/usr/bin/perl

=head1 NAME

UsersNodes

=cut

=head1 DESCRIPTION

unit test for UsersNodes

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 47;
use Test::Mojo;
use pf::node;
use pf::nodecategory;
use List::MoreUtils qw(all);
use Utils;

#This test will running last
use Test::NoWarnings;

my $t = Test::Mojo->new('pf::UnifiedApi');

my $test_mac = Utils::test_mac();

my $test_user = "test_user_$$";

$t->post_ok('/api/v1/users/' => json => {pid => $test_user})
  ->status_is(201)
  ->header_is('Location' => "/api/v1/user/$test_user");

$t->post_ok("/api/v1/user/$test_user/nodes" => json => {mac => $test_mac})
  ->status_is(201)
  ->header_is('Location' => "/api/v1/user/$test_user/node/$test_mac");

my $location = $t->tx->res->headers->location;

$t->get_ok($location)
  ->status_is(200);

my $new_notes =  "Notes $test_mac updated";

$t->patch_ok($location => json => { notes => $new_notes, GARBAGE_FIELD => 'sad' })
  ->status_is(200);

$t->get_ok($location)
  ->status_is(200)
  ->json_is('/item/notes' => $new_notes);

$t->get_ok("/api/v1/user/$test_user/nodes")
  ->status_is(200)
  ->json_is('/items/0/pid' => $test_user) ;

node_add("ff:ff:ff:ff:ff:fe");

for my $pid ('default', $test_user) {

    $t->get_ok("/api/v1/user/$pid/nodes")
      ->status_is(200);

    my $items = $t->tx->res->json->{items};

    ok( (all {$_->{pid} eq $pid} @$items), "All nodes are owned by the '$pid' user");
}

{
    my $test_user = "host/test_user_$$";
    my $id = $test_user;
    $id =~ s#/#~#g;
    my $test_mac = Utils::test_mac();

    $t->post_ok('/api/v1/users/' => json => {pid => $test_user})
      ->status_is(201)
      ->header_is('Location' => "/api/v1/user/$id");

    $t->post_ok("/api/v1/user/$id/nodes" => json => {mac => $test_mac})
      ->status_is(201)
      ->header_is('Location' => "/api/v1/user/$id/node/$test_mac");

    my $location = $t->tx->res->headers->location;

    $t->get_ok($location)
      ->status_is(200);

    $t->get_ok("/api/v1/user/$id/nodes")
      ->status_is(200);
}

{
    # The nodes of the users are changed with the nodes permissions and role restrictions
    my $roles_header = 'X-PacketFence-Admin-Roles';
    my %user_manager = ($roles_header => 'User Manager');
    my %node_manager = ($roles_header => 'Node Manager Allowed Roles');

    $t->post_ok("/api/v1/user/$test_user/nodes" => \%user_manager => json => {mac => Utils::test_mac()})
      ->status_is(403);

    $t->patch_ok($location => \%user_manager => json => { notes => 'not allowed' })
      ->status_is(403);

    $t->delete_ok($location => \%user_manager)
      ->status_is(403);

    $t->post_ok("/api/v1/users/bulk_apply_role" => \%user_manager => json => { items => [$test_user], category_id => pf::nodecategory::nodecategory_lookup('guest') })
      ->status_is(403);

    my $gaming = pf::nodecategory::nodecategory_lookup('gaming');
    $t->patch_ok($location => \%node_manager => json => { category_id => $gaming })
      ->status_is(422);

    $t->post_ok("/api/v1/users/bulk_apply_role" => \%node_manager => json => { items => [$test_user], category_id => $gaming })
      ->status_is(422);

    $t->patch_ok($location => \%node_manager => json => { category_id => pf::nodecategory::nodecategory_lookup('guest') })
      ->status_is(200);
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
