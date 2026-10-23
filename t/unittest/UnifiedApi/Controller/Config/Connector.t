#!/usr/bin/perl

=head1 NAME

Connector

=head1 DESCRIPTION

unit test for Connector

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 17;
use Test::Mojo;
use Utils;
use pf::ConfigStore::Connector;

my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Connector");

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/connectors';

my $base_url = '/api/v1/config/connector';

my $true = bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' );
my $false = bless( do { \( my $o = 0 ) }, 'JSON::PP::Boolean' );
$t->options_ok($collection_base_url)
  ->status_is(200);

$t->post_ok($collection_base_url => json => {
        id=> "bob",
        secret => "secret",
        description => "dsfdf",
        networks => ["12.36.23.0/23", "12.36.23.0/23"],
    })
  ->status_is(422);

$t->post_ok($collection_base_url => json => {
        id=> "bob",
        secret => "secret",
        description => "dsfdf",
        networks => ["12.36.23.32/23"],
    })
  ->status_is(201);

$t->post_ok($collection_base_url => json => {
        id=> "test_networks2",
        secret => "secret",
        description => "dsfdf",
        networks => ["12.36.24.0/24"],
    })
  ->status_is(422);

# Equipment located behind the connector, based on its networks.
# t/data/firewall_sso.conf has a firewall at 12.36.24.254, inside
# test_networks' 12.36.24.0/24; nothing else in the test fixtures does.
$t->get_ok("$base_url/test_networks/equipment")
  ->status_is(200)
  ->json_is('/networks/0' => '12.36.24.0/24')
  ->json_is('/equipment/firewalls/0/id' => '12.36.24.254')
  ->json_is('/equipment/firewalls/0/type' => 'FortiGate')
  ->json_is('/equipment/switches' => []);

$t->get_ok("$base_url/not_a_connector/equipment")
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
