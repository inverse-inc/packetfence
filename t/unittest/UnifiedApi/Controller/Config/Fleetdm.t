#!/usr/bin/perl

=head1 NAME

Fleetdm

=cut

=head1 DESCRIPTION

unit test for FleetDM config

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 10;
use Test::Mojo;
use Mojo::JSON qw(decode_json);

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $collection_base_url = '/api/v1/config/base/fleetdm';

$t->patch_ok($collection_base_url => json => { host => 'https://www.dummy.org', email => 'dummy@gmail.com', password => 'secure_password', token => 'VALIDTOKEN==' })
    ->status_is(200);

$t->get_ok($collection_base_url)
    ->status_is(200)
    ->json_is('/item/id', 'fleetdm')
    ->json_is('/item/host', 'https://www.dummy.org')
    ->json_is('/item/email', 'dummy@gmail.com')
    ->json_is('/item/password', 'secure_password')
    ->json_is('/item/token', 'VALIDTOKEN==');

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

