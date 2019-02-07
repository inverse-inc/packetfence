#!/usr/bin/perl

=head1 NAME

Nodes

=cut

=head1 DESCRIPTION

unit test for Nodes

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';
use Date::Parse;
use pf::dal::node;
use pf::dal::locationlog;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;

}

#insert known data
#run tests
use Test::More tests => 57;
use Test::Mojo;
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

$t->get_ok('/api/v1/nodes')
  ->status_is(200);

$t->post_ok('/api/v1/nodes/search' => json => { fields => [qw(mac ip4log.ip)], query => { op=> 'equals', field => 'ip4log.ip', value => '1.2.2.3'  }  })
  ->status_is(200);

my $mac = "00:02:34:23:22:11";

$t->delete_ok("/api/v1/node/$mac");

$t->post_ok('/api/v1/nodes' => json => { mac => $mac })
  ->status_is(201);

$t->post_ok('/api/v1/nodes' => json => { mac => $mac })
  ->status_is(409)
  ->json_like("/message", qr/\QThere's already a node with this MAC address\E/);

$t->patch_ok("/api/v1/node/$mac" => json => { notes => "$mac" })
  ->status_is(200);

$t->post_ok("/api/v1/node/$mac/register" => json => {   })
  ->status_is(200);

$t->post_ok("/api/v1/node/$mac/register" => json => { pid => 'default'  })
  ->status_is(200);

$t->post_ok("/api/v1/node/$mac/deregister" => json => { })
  ->status_is(200);

$t->get_ok("/api/v1/node/$mac/fingerbank_info" => json => {})
  ->status_is(200);

$t->post_ok("/api/v1/nodes/bulk_register" => json => { items => [$mac] })
  ->status_is(200)
  ->json_is('/items/0/mac', $mac)
  ->json_is('/items/0/status', 'success');

$t->post_ok("/api/v1/nodes/bulk_register" => json => { items => [$mac] })
  ->status_is(200)
  ->json_is('/items/0/mac', $mac)
  ->json_is('/items/0/status', 'skipped');

$t->post_ok('/api/v1/nodes/bulk_deregister' => json => { items => [$mac] })
  ->status_is(200)
  ->json_is('/items/0/mac', $mac)
  ->json_is('/items/0/status', 'success');

$t->post_ok('/api/v1/nodes/bulk_deregister' => json => { items => [$mac] })
  ->status_is(200)
  ->json_is('/items/0/mac', $mac)
  ->json_is('/items/0/status', 'skipped');

$t->post_ok('/api/v1/nodes/bulk_restart_switchport' => json => { items => [$mac] })
  ->status_is(200)
  ->json_is('/items/0/mac', $mac)
  ->json_is('/items/0/status', 'skipped');

$t->post_ok('/api/v1/nodes/bulk_apply_role' => json => { category_id => 1,  items => [$mac] })
  ->status_is(200)
  ->json_is('/items/0/mac', $mac)
  ->json_is('/items/0/status', 'success');

$t->post_ok('/api/v1/nodes/bulk_apply_role' => json => { category_id => 1,  items => [$mac] })
  ->status_is(200)
  ->json_is('/items/0/mac', $mac)
  ->json_is('/items/0/status', 'skipped');

$t->post_ok("/api/v1/node/$mac/apply_security_event" => json => { security_event_id => '1100013' })
  ->status_is(200);

$t->post_ok('/api/v1/nodes/search' => json => { fields => [qw(mac security_event.open_count)] })
  ->status_is(200)
  ->json_has('/items/0/security_event.open_count');

$t->post_ok('/api/v1/nodes/search' => json => { fields => [qw(mac)], with_total_count => \1 })
  ->status_is(200)
  ->json_has('total_count');

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
