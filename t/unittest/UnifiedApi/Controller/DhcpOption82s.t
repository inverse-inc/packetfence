#!/usr/bin/perl

=head1 NAME

Dhcpoption82s

=cut

=head1 DESCRIPTION

unit test for Dhcpoption82s

=cut

use strict;
use warnings;
use DateTime::Format::Strptime;
use lib '/usr/local/pf/lib';
use pf::dal::dhcp_option82;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}
#run tests
use Test::More tests => 33;
use Test::Mojo;
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

#truncate the dhcp_option82 table
pf::dal::dhcp_option82->remove_items();

#unittest (empty)
$t->get_ok('/api/v1/dhcp_option82s' => json => { })
  ->json_is('/items', []) 
  ->status_is(200);

#insert known data
my $dt_format = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M:%S');
my $dt_now = DateTime->now(time_zone=>'local');
my %values = (
    mac               => '00:01:02:03:04:05',
    option82_switch   => 'option82_switch',
    switch_id         => 'test switch_id',
    port              => 'port',
    vlan              => 'test vlan',
    circuit_id_string => 'test circuit_id_string',
    module            => 'test module',
    host              => 'test host',
);

#my $status = pf::dal::dhcp_option82->create(\%values);
$t->post_ok('/api/v1/dhcp_option82s' => json => \%values)
  ->status_is(201);

$t->get_ok('/api/v1/dhcp_option82s' => json => { })
  ->json_is('/items/0/mac', $values{mac})
  ->json_is('/items/0/created_at', $dt_format->format_datetime($dt_now))
  ->json_is('/items/0/option82_switch', $values{option82_switch})
  ->json_is('/items/0/switch_id', $values{switch_id})
  ->json_is('/items/0/port', $values{port})
  ->json_is('/items/0/vlan', $values{vlan})
  ->json_is('/items/0/circuit_id_string', $values{circuit_id_string})
  ->json_is('/items/0/module', $values{module})
  ->json_is('/items/0/host', $values{host})
  ->status_is(200);

my $mac = $t->tx->res->json->{items}[0]{mac};

#run unittest, use $mac
$t->get_ok("/api/v1/dhcp_option82/$mac")
  ->json_is('/item/mac', $values{mac})
  ->json_is('/item/created_at', $dt_format->format_datetime($dt_now))
  ->json_is('/item/option82_switch', $values{option82_switch})
  ->json_is('/item/switch_id', $values{switch_id})
  ->json_is('/item/port', $values{port})
  ->json_is('/item/vlan', $values{vlan})
  ->json_is('/item/circuit_id_string', $values{circuit_id_string})
  ->json_is('/item/module', $values{module})
  ->json_is('/item/host', $values{host})
  ->status_is(200);
  
#truncate the dhcp_option82 table
#pf::dal::dhcp_option82->remove_items();
$t->delete_ok("/api/v1/dhcp_option82/$mac")
  ->status_is(200);
  
#unittest (empty)
$t->get_ok('/api/v1/dhcp_option82s' => json => { })
  ->json_is('/items', []) 
  ->status_is(200);

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
