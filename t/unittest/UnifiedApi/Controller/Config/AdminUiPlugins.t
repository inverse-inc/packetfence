#!/usr/bin/perl

=head1 NAME

AdminUiPlugins

=cut

=head1 DESCRIPTION

unit test for AdminUiPlugins

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::ConfigStore::AdminUiPlugins;
use Utils;
my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::AdminUiPlugins");

use Test::More tests => 44;
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/admin_ui_plugins';

my $base_url = '/api/v1/config/admin_ui_plugin';

$t->get_ok($collection_base_url)
  ->status_is(200);

# the enabled plugins with their manifest, the disabled ones are not listed
$t->get_ok("$collection_base_url/enabled")
  ->status_is(200)
  ->json_is('/items/0/id', 'demo')
  ->json_is('/items/0/api', 'plugins/demo')
  ->json_is('/items/0/acl', 'SYSTEM')
  ->json_is('/items/0/manifest/collections/0/id', 'items')
  ->json_hasnt('/items/1');

$t->post_ok($collection_base_url => json => { id => 'test' })
  ->status_is(422);

$t->post_ok($collection_base_url => json => { id => 'test', upstream => 'ftp://127.0.0.1' })
  ->status_is(422);

$t->post_ok($collection_base_url => json => { id => 'test', upstream => 'http://127.0.0.1:8082', manifest => '[]' })
  ->status_is(422);

$t->post_ok($collection_base_url => json => { id => 'test', upstream => 'http://127.0.0.1:8082', config_files => ['../pf.conf:config::Pf'] })
  ->status_is(422);

my $item = {
    id           => 'test',
    description  => 'Test plugin',
    upstream     => 'http://127.0.0.1:8082/api/v1/test',
    config_files => ['connectors.conf:config::Connector'],
};

$t->post_ok($collection_base_url => json => $item)
  ->status_is(201);

$t->post_ok($collection_base_url => json => $item)
  ->status_is(409);

$t->get_ok("$base_url/test")
  ->status_is(200)
  ->json_is('/item/upstream', $item->{upstream})
  ->json_is('/item/enabled', 'enabled')
  ->json_is('/item/acl', 'SYSTEM')
  ->json_is('/item/config_files', $item->{config_files});

$t->patch_ok("$base_url/test" => json => { enabled => 'disabled' })
  ->status_is(200);

$t->get_ok("$collection_base_url/enabled")
  ->status_is(200)
  ->json_hasnt('/items/1');

# only the configuration files declared by the plugin can be committed
$t->post_ok("$base_url/test/commit" => json => { files => ['pf.conf'] })
  ->status_is(422);

$t->post_ok("$base_url/unknown/commit" => json => {})
  ->status_is(404);

$t->post_ok("$base_url/test/commit" => json => { files => ['connectors.conf'] })
  ->status_is(200)
  ->json_is('/files/0', 'connectors.conf');

$t->delete_ok("$base_url/test")
  ->status_is(200);

$t->get_ok("$base_url/test")
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
