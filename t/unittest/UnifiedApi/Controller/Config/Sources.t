#!/usr/bin/perl

=head1 NAME

Sources

=cut

=head1 DESCRIPTION

unit test for Sources

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
    use pf::authentication;
}

use Test::More tests => 26;
use Test::Mojo;
use Utils;
use pf::ConfigStore::Source;

my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Source");
#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/sources';

my $base_url = '/api/v1/config/source';

my $true = bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' );
my $false = bless( do { \( my $o = 0 ) }, 'JSON::PP::Boolean' );
{
    my $id = "htpasswd_test$$";
    $t->post_ok(
        $collection_base_url => json => {
            "administration_rules" => [
                {
                    "actions" => [
                        {
                            "type"  => "set_access_level",
                            "value" => ["ALL"],
                        }
                    ],
                    "conditions"  => [],
                    "description" => undef,
                    "id"          => "catchall",
                    "match"       => "all",
                    "status"      => "enabled"
                }
            ],
            "authentication_rules"        => [],
            "description"                 => "htpasswd",
            "id"                          => $id,
            "isClone"                     => $false,
            "isNew"                       => $true,
            "ldapfilter_operator"         => undef,
            "path"                        => "/usr/local/pf/t/data/htpasswd.conf",
            "realms"                      => [],
            "set_access_durations_action" => [],
            "set_role_from_source_action" => undef,
            "sourceType"                  => "Htpasswd",
            "type"                        => "Htpasswd"
        }
    )->status_is(201);

    $t->get_ok("${base_url}/$id")
    ->status_is(200)
    ->json_is('/item/administration_rules/0/actions/0/value', ['ALL']);
}

$t->options_ok($collection_base_url)
  ->status_is(200)
  ->json_has("/meta/type/allowed");

my @types = sort  map { lc($_->{value}) } @{$t->tx->res->json->{meta}{type}{allowed}};

is_deeply(
    \@types,
    [sort grep { $_ ne 'sql' } keys %pf::authentication::TYPE_TO_SOURCE],
);

$t->post_ok($collection_base_url => json => {})
  ->status_is(422);

$t->post_ok($collection_base_url, {'Content-Type' => 'application/json'} => '{')
  ->status_is(400);

$t->delete_ok("$base_url/sms")
  ->status_is(422);

$t->get_ok($collection_base_url)
  ->json_has('/items/0/class')
  ->status_is(200);

my $items = $t->tx->res->json->{items};

my @names = reverse sort map { $_->{id} } @$items;

$t->patch_ok("$collection_base_url/sort_items" => json => {items => \@names})
  ->status_is(200);

$t->get_ok($collection_base_url)
  ->status_is(200);

$items = $t->tx->res->json->{items};
my @new_names = map { $_->{id} } @$items;

is_deeply(\@new_names, \@names, "Resorting");

$t->post_ok(
    $collection_base_url => json => {
        "administration_rules" => [],
        "authentication_rules" => [
            {
                "actions" => [
                    {
                        "type"  => "set_access_duration",
                        "value" => "12h"
                    },
                    {
                        "type"  => "set_role",
                        "value" => "ROLE_NOT_CREATED"
                    }
                ],
                "conditions"  => [],
                "description" => "asas",
                "id"          => "catchall",
                "match"       => "all",
                "status"      => "enabled"
            }
        ],
        "description"                 => "authorization_catchall",
        "host"                        => "",
        "id"                          => "ROLE_NOT_CREATED_$$",
        "realms"                      => [],
        "set_access_durations_action" => [],
        "type"                        => "Authorization"
    }
)
->status_is(422);

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

