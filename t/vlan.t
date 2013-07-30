#!/usr/bin/perl
=head1 NAME

vlan.t

=head1 DESCRIPTION

pf::vlan module testing

=cut
use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';

use Test::More tests => 12;
use Test::MockModule;
use Test::MockObject::Extends;
use Test::NoWarnings;

use File::Basename qw(basename);

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );
BEGIN { use SwitchFactoryConfig; }

use pf::config;
use pf::SwitchFactory;
use pf::SNMP::constants;

BEGIN { use pf::violation; }
BEGIN {
    use_ok('pf::vlan');
    use_ok('pf::vlan::custom');
}

# test the object
my $vlan_obj = new pf::vlan::custom();
isa_ok($vlan_obj, 'pf::vlan');

# subs
can_ok($vlan_obj, qw(
    fetchVlanForNode
    doWeActOnThisTrap
    getViolationVlan
    getRegistrationVlan
    getNormalVlan
    getNodeInfoForAutoReg
    shouldAutoRegister
  ));

# forcing pf configuration's registration trapping to be true
$Config{'trapping'}{'registration'} = 'enabled';

# setup a fake switch object
my $switchFactory = new pf::SwitchFactory;
my $switch = $switchFactory->instantiate('192.168.0.1');

# redefining violation functions (we stay in pf::vlan's context because methods are imported there from pf::violation)
my $mock = new Test::MockModule('pf::vlan');
# emulate the presence of a violation
# TODO this is a cheap test, the false in view_top is to avoid the cascade of vid, class, etc. checking
# mocked node_attributes returns violation node
$mock->mock('node_attributes', sub {
    return { mac => 'bb:bb:cc:dd:ee:ff', pid => 1, detect_date => '', regdate => '', unregdate => '', category => 'default',
        lastskip => '', status => 'unreg', user_agent => '', computername => '', notes => '', last_arp => '',
        last_dhcp => '', dhcp_fingerprint => '', switch => '', port => '', bypass_vlan => 1, nbopenviolations => '1'}
});
$mock->mock('violation_count_trap', sub { return (1); });
$mock->mock('violation_view_top', sub { return $FALSE; });

my $vlan;
my $wasInline;
($vlan,$wasInline) = $vlan_obj->fetchVlanForNode('bb:bb:cc:dd:ee:ff', $switch, '1001');
is($vlan, 2, "determine vlan for node with violation");

# violation_count_trap will return 0
$mock->mock('violation_count_trap', sub { return (0); });

# mocking used node method calls
$mock->mock('node_exist', sub { return (1); });
$mock->mock('node_attributes', sub {
    return { mac => 'aa:bb:cc:dd:ee:ff', pid => 1, detect_date => '', regdate => '', unregdate => '', category => 'default',
        lastskip => '', status => 'reg', user_agent => '', computername => '', notes => '', last_arp => '',
        last_dhcp => '', dhcp_fingerprint => '', switch => '', port => '', bypass_vlan => 1, nbopenviolations => ''}
});

# TODO: complete the test suite with more tests above the other cases
my $switch_vlan_override = $switchFactory->instantiate('10.0.0.2');
($vlan,$wasInline) = $vlan_obj->fetchVlanForNode('aa:bb:cc:dd:ee:ff', $switch_vlan_override, '1001');
is($vlan, 1, "determine vlan for registered user on custom switch");

# mocked node_attributes returns unreg node
$mock->mock('node_attributes', sub {
    return { mac => 'aa:bb:cc:dd:ee:ff', pid => 1, detect_date => '', regdate => '', unregdate => '', category => 'default',
        lastskip => '', status => 'unreg', user_agent => '', computername => '', notes => '', last_arp => '',
        last_dhcp => '', dhcp_fingerprint => '', switch => '', port => '', bypass_vlan => 1, nbopenviolations => ''}
});

($vlan,$wasInline) = $vlan_obj->fetchVlanForNode('aa:bb:cc:dd:ee:ff', $switch, '1001');
is($vlan, 3, "obtain registrationVlan for an unreg node");

#($vlan,$wasInline) = $vlan_obj->getNormalVlan($switch);
#is($vlan, 1, "obtain normalVlan on a switch with no normalVlan override");

#($vlan,$wasInline) = $vlan_obj->getNormalVlan($switch_vlan_override);
#is($vlan, 15, "obtain normalVlan on a switch with normalVlan override");

# doWeActOnThisTrap tests
#
# mock switch's relevant calls
$switch = $switchFactory->instantiate('192.168.0.1');
$switch  = Test::MockObject::Extends->new( $switch );
$switch->mock('getIfType', sub { return $SNMP::GIGABIT_ETHERNET; });
$switch->mock('getUpLinks', sub { return; });

is(
    $vlan_obj->doWeActOnThisTrap( $switch, 1000, 'secureMacAddrViolation' ),
    1,
    "avoid empty array warning (issue #832)"
);

$switch->mock('getUpLinks', sub { return (); });
is(
    $vlan_obj->doWeActOnThisTrap( $switch, 1000, 'secureMacAddrViolation' ),
    1,
    "Zero uplinks"
);

$switch->mock('getUpLinks', sub { return -1; });
is(
    $vlan_obj->doWeActOnThisTrap( $switch, 1000, 'secureMacAddrViolation' ),
    0,
    "getUpLinks not supported return 0"
);

$switch->mock('getUpLinks', sub { return (1000, 1001); });
is(
    $vlan_obj->doWeActOnThisTrap( $switch, 1000, 'secureMacAddrViolation' ),
    0,
    "do we act on uplink?"
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

