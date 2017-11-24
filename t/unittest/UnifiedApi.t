#!/usr/bin/perl

=head1 NAME

Mojo

=cut

=head1 DESCRIPTION

unit test for Mojo

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

use Test::More tests => 48;
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
use pf::dal;
use pf::dal::tenant;
use pf::tenant qw(
    tenant_add
    tenant_view_by_name
);

my $t = Test::Mojo->new('pf::UnifiedApi');

$t->get_ok('/api/v1/users/admin')
  ->status_is(200)
  ->json_is('/item/pid' => 'admin') ;

$t->get_ok('/api/v1/users/NoSuchUser')
  ->status_is(404);

$t->get_ok('/api/v1/users/admin')
  ->status_is(200)
  ->json_is('/item/pid' => 'admin') ;

my $test_pid = "test_pid_$$";

$t->post_ok('/api/v1/users' => json => { pid => $test_pid })
  ->status_is(201);

my $notes = "notes for $test_pid";

$t->put_ok("/api/v1/users/$test_pid" => json => { notes => "$notes" })
  ->status_is(200);

$t->get_ok("/api/v1/users/$test_pid")
  ->status_is(200)
  ->json_is('/item/pid' => $test_pid)
  ->json_is('/item/notes' => $notes);

$t->patch_ok("/api/v1/users/$test_pid" => json => { notes => $notes })
  ->status_is(200);

$t->delete_ok("/api/v1/users/$test_pid")
  ->status_is(200);

$t->delete_ok("/api/v1/users/$test_pid")
  ->status_is(404);

my $unused_tenant_id = get_unused_tenant_id();

$t->get_ok('/api/v1/users/admin' => {'X-PacketFence-Tenant-Id' => $unused_tenant_id})
  ->status_is(404)
  ->json_like('/message' => qr/\Q$unused_tenant_id\E/);

$t->get_ok('/api/v1/users/admin' => {'X-PacketFence-Tenant-Id' => 1})
  ->status_is(200);

my $tenant_name = "test_tenant_$$";

$t->post_ok('/api/v1/tenants' => json => { name => "default" })
   ->status_is(409);

$t->post_ok('/api/v1/tenants' => json => { name => $tenant_name })
  ->status_is(201)
  ->header_like('Location' => qr#^/api/v1/tenants/#);

my $location = $t->tx->res->headers->location;

$t->get_ok($location)
  ->status_is(200);

my $tenant = $t->tx->res->json->{item};

my $tenant_id = $tenant->{id};

my $headers = {'X-PacketFence-Tenant-Id' => $tenant_id};

$t->get_ok('/api/v1/users/default' => $headers)
  ->status_is(200)
  ->json_is('/item/tenant_id' => $tenant_id);

$notes = "notes $tenant_id";

$t->post_ok('/api/v1/users' => $headers => json => { pid => $test_pid })
  ->status_is(201);

$t->put_ok("/api/v1/users/$test_pid" => $headers => json => { notes => $notes })
  ->status_is(200);

$t->get_ok("/api/v1/users/$test_pid" => $headers)
  ->status_is(200)
  ->json_is('/item/pid' => $test_pid)
  ->json_is('/item/notes' => $notes);

$t->delete_ok("/api/v1/users/$test_pid" => $headers)
  ->status_is(200);

sub get_unused_tenant_id {
    my $old_tentant_id = pf::dal->get_tenant;

    my ($status, $iter) = pf::dal::tenant->search(
        -columns => ["MAX(id)|max_id"],
        -group_by => 'id',
        -with_class => undef,
    );

    my $data = $iter->next;

    return $data->{max_id} + $$ + int(rand($$));
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

