#!/usr/bin/perl

=head1 NAME

Roles

=cut

=head1 DESCRIPTION

unit test for Roles

=cut

use strict;
use warnings;
#
use lib qw(
    /usr/local/pf/lib
);

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 24;
use Test::Mojo;
use Utils;
use pf::ConfigStore::Roles;

my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Roles");

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/roles';

my $base_url = '/api/v1/config/role';

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

$t->post_ok($collection_base_url => json => { id => 'bob' })
  ->status_is(201);

$t->patch_ok("$base_url/r1" => json => { parent_id => 'r2' })
  ->status_is(422);

$t->patch_ok("$base_url/r1" => json => { parent_id => 'r3' })
  ->status_is(422);

$t->delete_ok("$base_url/r1" => json => {  })
  ->status_is(422);

$t->delete_ok("$base_url/r3" => json => {  })
  ->status_is(200);

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

