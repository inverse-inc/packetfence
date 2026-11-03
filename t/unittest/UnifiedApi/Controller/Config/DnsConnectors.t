#!/usr/bin/perl

=head1 NAME

DnsConnectors

=head1 DESCRIPTION

unit test for the DNS connectors pfconnector_port validation

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);

    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 14;
use Test::Mojo;
use Utils;

#This test will running last
use Test::NoWarnings;
use pf::ConfigStore::Connector::DnsConnectors;

my ( $fh, $filename ) =
  Utils::tempfileForConfigStore("pf::ConfigStore::Connector::DnsConnectors");

my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/dns_connectors';

my $base_url = '/api/v1/config/dns_connector';

my $port_not_unique = {
    status => 422,
    errors => [
        {
            field   => 'pfconnector_port',
            message => 'Port should be unique',
        }
    ],
    message => 'Unable to validate',
};

# Saving a DNS server with its own port must not conflict with itself
$t->patch_ok(
    "$base_url/TEST" => json => {
        pfconnector_port => 30001,
    }
)->status_is(200);

# Port of another DNS server
$t->post_ok(
    $collection_base_url => json => {
        id               => 'TEST2',
        ip               => '192.0.2.53',
        port             => 53,
        pfconnector_port => 30001,
    }
)->status_is(422)->json_is($port_not_unique);

# Port of a RADIUS source
$t->post_ok(
    $collection_base_url => json => {
        id               => 'TEST2',
        ip               => '192.0.2.53',
        port             => 53,
        pfconnector_port => 30000,
    }
)->status_is(422)->json_is($port_not_unique);

# Port of a RADIUS source with the same id as the DNS server
$t->post_ok(
    $collection_base_url => json => {
        id               => 'RADIUS_CONNECT_THROUGH_TEST',
        ip               => '192.0.2.53',
        port             => 53,
        pfconnector_port => 30000,
    }
)->status_is(422)->json_is($port_not_unique);

$t->post_ok(
    $collection_base_url => json => {
        id               => 'TEST2',
        ip               => '192.0.2.53',
        port             => 53,
        pfconnector_port => 30002,
    }
)->status_is(201);

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

