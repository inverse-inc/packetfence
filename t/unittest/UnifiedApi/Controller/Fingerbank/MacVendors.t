#!/usr/bin/perl

=head1 NAME

MacVenders

=head1 DESCRIPTION

unit test for MacVenders

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

use Test::More tests => 24;
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

$t->get_ok("/api/v1/fingerbank/local/mac_vendors")
  ->status_is(200);;

$t->get_ok("/api/v1/fingerbank/upstream/mac_vendors")
  ->status_is(200);;

$t->post_ok("/api/v1/fingerbank/upstream/mac_vendors" => json => {})
  ->status_is(404);

$t->post_ok("/api/v1/fingerbank/local/mac_vendors" => json => {mac => "00:22:33", name => "me"})
  ->status_is(200);

my $location = $t->tx->res->headers->location();

$t->get_ok($location)
  ->status_is(200)
  ->json_is("/item/mac" => "00:22:33")
  ->json_is("/item/name" => "me");

$t->patch_ok($location => json => { "garabage_field_$$" =>  \1, mac => "00:22:44" })
  ->status_is(200);

$t->get_ok($location)
  ->status_is(200)
  ->json_is("/item/mac" => "00:22:44")
  ->json_is("/item/name" => "me");


$t->post_ok("/api/v1/fingerbank/local/mac_vendors/search" => json =>{ query => {op => "equals", field => "name", value => "me"}})
  ->status_is(200)
  ->json_is("/items/0/name", "me");

$t->delete_ok($location)
  ->status_is(200);


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

