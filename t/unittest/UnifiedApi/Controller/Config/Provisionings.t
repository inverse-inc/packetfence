#!/usr/bin/perl

=head1 NAME

Provisionings

=cut

=head1 DESCRIPTION

unit test for Provisionings

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

use pf::ConfigStore::Provisioning;
use Utils;
my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Provisioning");

use Test::More tests => 36;
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/provisionings';

my $base_url = '/api/v1/config/provisioning';

$t->get_ok($collection_base_url)
  ->status_is(200);

$t->post_ok($collection_base_url => json => {})
  ->status_is(422);

$t->post_ok($collection_base_url, {'Content-Type' => 'application/json'} => '{')
  ->status_is(400);

my $item = {
    id          => 'test',
    description => 'v1',
    type        => 'accept'
};

$t->post_ok($collection_base_url => json => { id => 'test', description => 'v1', type => 'accept'})
  ->status_is(201);

$t->post_ok($collection_base_url => json => $item)
  ->status_is(409);

$t->get_ok("$base_url/test")
  ->status_is(200);

while (my ($k, $v) = each %$item) {
  $t->json_is( "/item/$k" => $v);
}

$t->patch_ok("$base_url/test" => json => {description => 'v2'})
  ->status_is(200);

$t->get_ok("$base_url/test")
  ->status_is(200)
  ->json_is('/item/id', 'test')
  ->json_is('/item/description', 'v2')
  ->json_is('/item/type', 'accept');

$t->put_ok("$base_url/test" => json => {description => 'v1'})
  ->status_is(422);

$t->put_ok("$base_url/test" => json => {description => 'v1', type => 'accept'})
  ->status_is(200);

$t->get_ok("$base_url/test")
  ->status_is(200);

while (my ($k, $v) = each %$item) {
  $t->json_is( "/item/$k" => $v);
}

$t->delete_ok("$base_url/test")
  ->status_is(200);

$t->get_ok("$base_url/test")
  ->status_is(404);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
