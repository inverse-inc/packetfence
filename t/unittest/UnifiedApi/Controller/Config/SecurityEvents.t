#!/usr/bin/perl

=head1 NAME

SecurityEvents

=cut

=head1 DESCRIPTION

unit test for SecurityEvents

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

use Test::More tests => 12;
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/security_events';

my $base_url = '/api/v1/config/security_event';
my $limit = 10;
$t->get_ok("$collection_base_url?limit=$limit")
  ->status_is(200);

my $json1 = $t->tx->res->json;
is(scalar @{$json1->{items}}, $limit, "returned $limit items");

$t->post_ok($collection_base_url => json => {})
  ->status_is(422);

$t->post_ok($collection_base_url, {'Content-Type' => 'application/json'} => '{')
  ->status_is(400);

$t->get_ok("$collection_base_url?limit=$limit&cursor=$json1->{nextCursor}")
  ->status_is(200);

my $json2 = $t->tx->res->json;

$t->get_ok("$collection_base_url?limit=$limit&cursor=$json2->{nextCursor}")
  ->status_is(200);
my $json3 = $t->tx->res->json;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

