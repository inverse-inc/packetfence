#!/usr/bin/perl

=head1 NAME

Provisionings

=cut

=head1 DESCRIPTION

unit test for Provisionings

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::ConfigStore::Provisioning;
use Utils;
my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Provisioning");

use Test::More tests => 101;
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/provisionings';

$t->post_ok($collection_base_url => json => {
    type => 'google_workspace_chromebook',
    service_account => '{',
    id => "id_google_workspace_chromebook_$$",
    user => 'test@test.test',
})->status_is(422);

$t->post_ok($collection_base_url => json => {
    type => 'google_workspace_chromebook',
    service_account => '{}',
    id => "id_google_workspace_chromebook_$$",
    user => 'test@test.test',
})->status_is(201);

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

$t->post_ok($collection_base_url => json => $item)
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

# generic_http provisioner

my $generic_http_id = "id_generic_http_$$";
$t->post_ok($collection_base_url => json => {
    type     => 'generic_http',
    id       => $generic_http_id,
    url      => 'https://mdm.example.com/api/v1/devices?mac=$mac',
    headers  => "Authorization: Bearer abc123\nX-Pid: \$node.pid",
    jq_query => '.status == "enrolled"',
})->status_is(201);

$t->get_ok("$base_url/$generic_http_id")
  ->status_is(200)
  ->json_is('/item/type', 'generic_http')
  ->json_is('/item/url', 'https://mdm.example.com/api/v1/devices?mac=$mac')
  ->json_is('/item/headers', "Authorization: Bearer abc123\nX-Pid: \$node.pid")
  ->json_is('/item/jq_query', '.status == "enrolled"');

$t->delete_ok("$base_url/$generic_http_id")
  ->status_is(200);

# missing required fields (url, jq_query)
$t->post_ok($collection_base_url => json => {
    type => 'generic_http',
    id   => "id_generic_http_invalid_$$",
})->status_is(422);

# a jq query that does not compile is rejected on create
$t->post_ok($collection_base_url => json => {
    type     => 'generic_http',
    id       => "id_generic_http_badjq_$$",
    url      => 'https://mdm.example.com/api/v1/devices?mac=$mac',
    jq_query => '.devices | bogus_fn',
})->status_is(422);

# a query that would pull definitions in from a .jq file on disk is rejected
# with the same validation, rather than at the first authorization
$t->post_ok($collection_base_url => json => {
    type     => 'generic_http',
    id       => "id_generic_http_include_$$",
    url      => 'https://mdm.example.com/api/v1/devices?mac=$mac',
    jq_query => 'include "evil"; .status == "enrolled"',
})->status_is(422);

# a valid query using brackets compiles and saves
my $bracket_id = "id_generic_http_brackets_$$";
$t->post_ok($collection_base_url => json => {
    type     => 'generic_http',
    id       => $bracket_id,
    url      => 'https://mdm.example.com/api/v1/devices?mac=$mac',
    jq_query => '.devices[0].status == "enrolled"',
})->status_is(201);

# an unescaped '$' in a template is rejected: it would be read as a variable
# and silently dropped from the rendered value
$t->post_ok($collection_base_url => json => {
    type     => 'generic_http',
    id       => "id_generic_http_baddollar_$$",
    url      => 'https://mdm.example.com/api/v1/devices?mac=$mac',
    headers  => 'Authorization: Bearer sk-abc$def',
    jq_query => '.status == "enrolled"',
})->status_is(422);

$t->post_ok($collection_base_url => json => {
    type     => 'generic_http',
    id       => "id_generic_http_badurl_$$",
    url      => 'https://mdm.example.com/api/v1/devices?token=abc$def',
    jq_query => '.status == "enrolled"',
})->status_is(422);

# a jq query that does not compile is rejected on update
$t->patch_ok("$base_url/$bracket_id" => json => {
    jq_query => '.devices[',
})->status_is(422);

$t->delete_ok("$base_url/$bracket_id")
  ->status_is(200);

# test_jq

$t->post_ok("$collection_base_url/test_jq" => json => {
    jq_query => '.status == "enrolled"',
    json     => '{"status":"enrolled"}',
})->status_is(200)
  ->json_is('/passes' => Mojo::JSON->true);

$t->post_ok("$collection_base_url/test_jq" => json => {
    jq_query => '.status == "enrolled"',
    json     => '{"status":"removed"}',
})->status_is(200)
  ->json_is('/passes' => Mojo::JSON->false);

$t->post_ok("$collection_base_url/test_jq" => json => {
    jq_query => '.status',
    json     => 'not json',
})->status_is(422);

# the tester compiles the query the way the provisioner does: no modules from
# disk, and no reading the environment of the process answering the request
$t->post_ok("$collection_base_url/test_jq" => json => {
    jq_query => 'include "evil"; .status',
    json     => '{"status":"enrolled"}',
})->status_is(422);

$t->post_ok("$collection_base_url/test_jq" => json => {
    jq_query => 'env.PATH',
    json     => '{}',
})->status_is(200)
  ->json_is('/passes' => Mojo::JSON->false);

$t->post_ok("$collection_base_url/test_jq" => json => {
    jq_query => '.status',
})->status_is(422);

# a test node is handed to the query as $mac and $node, and comes back with
# the result so the admin can see which attributes it held
$t->post_ok("$collection_base_url/test_jq" => json => {
    jq_query => '.mac == $mac and .owner == $node.pid',
    json     => '{"mac":"aa:bb:cc:dd:ee:ff","owner":"bob"}',
    mac      => 'AA-BB-CC-DD-EE-FF',
    node     => { pid => 'bob' },
})->status_is(200)
  ->json_is('/passes' => Mojo::JSON->true)
  ->json_is('/mac' => 'aa:bb:cc:dd:ee:ff')
  ->json_is('/node/pid' => 'bob');

# a node given on its own names the mac itself
$t->post_ok("$collection_base_url/test_jq" => json => {
    jq_query => '$mac',
    json     => '{}',
    node     => { mac => 'aa:bb:cc:dd:ee:ff', pid => 'bob' },
})->status_is(200)
  ->json_is('/mac' => 'aa:bb:cc:dd:ee:ff');

# and without either, both variables are null
$t->post_ok("$collection_base_url/test_jq" => json => {
    jq_query => '[$mac, $node]',
    json     => '{}',
})->status_is(200)
  ->json_is('/results/0' => [undef, undef])
  ->json_is('/node' => undef);

$t->post_ok("$collection_base_url/test_jq" => json => {
    jq_query => '.status',
    json     => '{"status":"enrolled"}',
    mac      => 'not a mac',
})->status_is(422);

$t->post_ok("$collection_base_url/test_jq" => json => {
    jq_query => '.status',
    json     => '{"status":"enrolled"}',
    node     => 'not an object',
})->status_is(422);

$t->post_ok("$collection_base_url/test_jq", {'Content-Type' => 'application/json'} => '{')
  ->status_is(400);

# valid JSON that is not an object is a bad request, not a 500
$t->post_ok("$collection_base_url/test_jq", {'Content-Type' => 'application/json'} => '[1,2]')
  ->status_is(400);

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
