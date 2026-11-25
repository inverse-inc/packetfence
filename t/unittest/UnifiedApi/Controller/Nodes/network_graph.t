#!/usr/bin/perl

=head1 NAME

network_graph

=head1 DESCRIPTION

Switch properties returned by the network graph of the nodes

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

use Test::More tests => 12;
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
use pf::UnifiedApi::Controller::Nodes;

my $t = Test::Mojo->new('pf::UnifiedApi');

$t->post_ok('/api/v1/nodes/network_graph' => json => { fields => [qw(mac switch.description switch.radiusSecret)] })
  ->status_is(422)
  ->json_is('/errors/0/field', 'switch.radiusSecret');

ok(pf::UnifiedApi::Controller::Nodes::is_network_graph_switch_field('switch.description'), 'switch.description is allowed');
ok(pf::UnifiedApi::Controller::Nodes::is_network_graph_switch_field('switch.type'), 'switch.type is allowed');
ok(!pf::UnifiedApi::Controller::Nodes::is_network_graph_switch_field('switch.radiusSecret'), 'switch.radiusSecret is not allowed');
ok(!pf::UnifiedApi::Controller::Nodes::is_network_graph_switch_field('switch.cliPwd'), 'switch.cliPwd is not allowed');
ok(!pf::UnifiedApi::Controller::Nodes::is_network_graph_switch_field('description'), 'a field without the switch prefix is not a switch field');

# 192.168.0.1 of the test switches.conf
my ($switch) = pf::UnifiedApi::Controller::Nodes->pf_network_graph_switch_info(
    { switch_fields => [qw(switch.radiusSecret switch.description switch.type)] },
    {},
    '192.168.0.1',
);
ok(!exists $switch->{properties}{radiusSecret}, 'radiusSecret is not a display property');
ok(exists $switch->{properties}{description}, 'the description is returned');
ok(exists $switch->{properties}{type}, 'the type is returned');

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
