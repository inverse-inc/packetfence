#!/usr/bin/perl

=head1 NAME

locationlog_for_disconnect

=head1 DESCRIPTION

unit test for pf::Switch::locationlog_for_disconnect and the RADIUS
disconnect of the switch modules using it, when the locationlog is already
closed (e.g. the node was deleted)

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}
use Test::More tests => 9;
use Test::MockModule;
use pf::Switch;
use pf::Switch::Aruba::2930M;
use pf::Switch::Aruba::ArubaOS_Switch_16_x;
use pf::Switch::HP::AOS_Switch_v16_X;
use pf::Switch::Aruba::ArubaOS_CX_10_x;
use pf::Switch::Mojo;
use pf::dal::locationlog;
use pf::dal::locationlog_history;
use pf::dal::node;

my $mac = '00:65:80:65:00:02';

sub reset_locationlog {
    pf::dal::locationlog->remove_items(-where => { mac => $mac });
    pf::dal::locationlog_history->remove_items(-where => { mac => $mac });
}

sub add_locationlog {
    my (%args) = @_;
    pf::dal::locationlog->new({
        mac => $mac, switch => '10.0.0.1', switch_ip => '10.0.0.1', switch_mac => 'aa:bb:cc:dd:ee:03',
        port => 12, vlan => 1, connection_type => 'Ethernet-EAP', dot1x_username => 'alice', ssid => 'Lab',
        start_time => '2026-10-11 10:00:00', end_time => '2026-10-11 10:05:00', %args,
    })->insert;
}

pf::dal::node->remove_items(-where => { mac => $mac });
pf::dal::node->new({ mac => $mac })->insert;
reset_locationlog();

my $switch = pf::Switch->new({ id => '10.0.0.1', ip => '10.0.0.1' });

is($switch->locationlog_for_disconnect($mac), undef, 'no locationlog');

add_locationlog();
is($switch->locationlog_for_disconnect($mac)->{dot1x_username}, 'alice', 'closed locationlog on this switch is used');

reset_locationlog();
add_locationlog(switch => '10.0.0.2', switch_ip => '10.0.0.2');
is($switch->locationlog_for_disconnect($mac), undef, 'closed locationlog on another switch is not used');

reset_locationlog();
add_locationlog(switch => '10.0.0.2', switch_ip => '10.0.0.2', end_time => '0000-00-00 00:00:00');
is($switch->locationlog_for_disconnect($mac)->{switch}, '10.0.0.2', 'open locationlog is used whatever the switch');

# the RADIUS disconnect of the modules with a closed locationlog on the switch
my @sent;
my $mock = Test::MockModule->new('pf::Switch');
$mock->mock('handleRadiusDisconnect', sub { push @sent, $_[2]; return { Code => 'Disconnect-ACK' } });
$mock->mock('handleRadiusCoa', sub { push @sent, $_[2]; return { Code => 'CoA-ACK' } });
$mock->mock('radius_deauth_connection_info', sub { {} });
my $roles = Test::MockModule->new('pf::roles::custom');
$roles->mock('getRoleForNode', sub { 'default' });

reset_locationlog();
add_locationlog();
my %expected = (
    'pf::Switch::Aruba::2930M'               => { 'User-Name' => 'alice', 'NAS-Port-Id' => 12 },
    'pf::Switch::Aruba::ArubaOS_Switch_16_x' => { 'User-Name' => 'alice', 'NAS-Port-Id' => 12 },
    'pf::Switch::HP::AOS_Switch_v16_X'       => { 'User-Name' => 'alice', 'NAS-Port-Id' => 12 },
    'pf::Switch::Aruba::ArubaOS_CX_10_x'     => { 'User-Name' => 'alice', 'NAS-Port' => 12 },
    'pf::Switch::Mojo'                       => { 'NAS-Identifier' => 'AA:BB:CC:DD:EE:03-Lab' },
);
foreach my $class (sort keys %expected) {
    @sent = ();
    $class->new({ id => '10.0.0.1', ip => '10.0.0.1', radiusSecret => 'x' })->radiusDisconnect($mac);
    my $attributes = $sent[0] // {};
    is_deeply({ map { $_ => $attributes->{$_} } keys %{ $expected{$class} } }, $expected{$class}, "$class uses the closed locationlog");
}

reset_locationlog();
pf::dal::node->remove_items(-where => { mac => $mac });

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

