#!/usr/bin/perl

=head1 NAME

BulkImport

=head1 DESCRIPTION

unit test for BulkImport

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use File::Temp;
my ($fh, $filename) = File::Temp::tempfile( UNLINK => 0 );
$fh->truncate(0);
$fh->flush();
{
    package ConfigStore::BulkImport;
    use Moo;
    use namespace::autoclean;
    extends 'pf::ConfigStore';
    sub configFile {$filename};
}
{
    package Form::BulkImport;
    use HTML::FormHandler::Moose;
    extends 'pfappserver::Base::Form';
    has_field 'id' => (
        type     => 'Text',
        required => 1,
        messages => { required => 'Field id is required.' },
    );
    has_field 'description' => (
        type     => 'Text',
        required => 1,
        messages =>
          { required => 'Field description is required.' },
    );
    has_field 'value_1' => ();
    has_field 'value_2' => ();
}

{
    package pf::UnifiedApi::Controller::Config::BulkImport;
    use Mojo::Base qw(pf::UnifiedApi::Controller::Config);
    has 'config_store_class' => 'ConfigStore::BulkImport';
    has 'form_class' => 'Form::BulkImport';
    has 'primary_key' => 'bulk_import_id';
}

use Test::More tests => 38;
use Test::Mojo;
use Utils;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');
my $app = $t->app;
my $config_route = $app->routes->lookup("api.v1.Config");
$app->setup_api_v1_std_config_routes(
    $config_route,
    "Config::BulkImport",
    "/bulk_imports",
    "/bulk_import/#bulk_import_id",
    "api.v1.Config.BulkImport"
);
my $true = bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' );
my $false = bless( do { \( my $o = 0 ) }, 'JSON::PP::Boolean' );

my $collection_base_url = '/api/v1/config/bulk_imports';
my $resource_base_url = '/api/v1/config/bulk_import';

$t->post_ok("$collection_base_url/bulk_import" => json => { async => $true, items => [ { id => "id_0", description => "Description 0", value_1 => "0" } ] })
  ->json_has("/task_id")
  ->status_is(202);

my $json = $t->tx->res->json;
my $task_id = $json->{task_id};
ok($task_id, "Got the task ID");
my $client = pf::api::unifiedapiclient->new();
sleep(1);
my $results = $client->call("GET", "/api/v1/pfqueue/task/$task_id/status/poll");

is($results->{status}, 200);
$t->delete_ok("$resource_base_url/id_0")
  ->status_is(200);

$t->post_ok("$collection_base_url/bulk_import" => json => {  })
  ->status_is(200);

$t->post_ok( "$collection_base_url/bulk_import" => json =>
      { items => [ { id => "id_1", description => "Description 1", value_1 => "1" } ] } )
  ->status_is(200)
  ->json_is('/items/0/status', 200)
  ->json_is('/items/0/isNew', $true)
  ->json_is('/items/0/item/id', 'id_1')
  ->json_is('/items/0/item/description', 'Description 1')
  ->json_is('/items/0/item/value_1', '1')
  ->json_is('/items/0/item/value_2', undef)
  ;

$t->post_ok( "$collection_base_url/bulk_import" => json =>
      { items => [ { id => "id_1", value_1 => "a", value_2 => '2' } ] } )
  ->status_is(200)
  ->json_is('/items/0/status', 200)
  ->json_is('/items/0/isNew', $false)
  ->json_is('/items/0/item/id', 'id_1');

$t->get_ok("${resource_base_url}/id_1")
  ->status_is(200)
  ->json_is("/item/id", "id_1")
  ->json_is("/item/description", "Description 1")
  ->json_is("/item/value_1", "a")
  ->json_is("/item/value_2", "2")
  ;

$t->get_ok($collection_base_url)
  ->status_is(200)
  ->json_is("/items/0/id", "id_1")
  ->json_is("/items/0/description", "Description 1");

$t->post_ok( "$collection_base_url/bulk_import" => json =>
      {ignoreUpdateIfExists => \1, items => [ { id => "id_1", description => "Description 1" } ] } )
  ->status_is(200)
  ->json_is('/items/0/status', 409)
  ->json_is('/items/0/item/description', 'Description 1')
  ->json_is('/items/0/item/id', 'id_1');

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
