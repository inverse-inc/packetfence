#!/usr/bin/perl
=head1 NAME

vlan.t

=head1 DESCRIPTION

pf::role module testing

=cut

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';

use Test::More tests => 18;
use Test::MockModule;
use Test::MockObject::Extends;
use Test::NoWarnings;

use File::Basename qw(basename);

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );
BEGIN { use lib qw(/usr/local/pf/t); }
BEGIN { use setup_test_config; }

use pf::constants;
use pf::config qw(%Config);
use pf::SwitchFactory;
use pf::Switch::constants;

BEGIN { use pf::security_event;
}

BEGIN {
    use_ok('pf::role');
    use_ok('pf::role::custom');
    use_ok('pf::access_filter::vlan');
}

# test the object
my $role_obj = new pf::role::custom();
isa_ok($role_obj, 'pf::role');

# subs
can_ok($role_obj, qw(
    fetchRoleForNode
    doWeActOnThisTrap
    getSecurityEventRole
    getRegistrationRole
    getRegisteredRole
    getNodeInfoForAutoReg
    shouldAutoRegister
  ));

# setup a fake switch object
my $switch = pf::SwitchFactory->instantiate('192.168.0.1');

# redefining security_event functions (we stay in pf::role's context because methods are imported there from pf::security_event)
my $mock = new Test::MockModule('pf::role');
my $mock_security_event = new Test::MockModule('pf::security_event');
# emulate the presence of a security_event
# TODO this is a cheap test, the false in view_top is to avoid the cascade of security_event_id, class, etc. checking
# mocked node_attributes returns security_event node
$mock->mock('node_attributes', sub {
    return { mac => 'bb:bb:cc:dd:ee:ff', pid => 1, detect_date => '', regdate => '', unregdate => '', category => 'default',
        lastskip => '', status => 'unreg', user_agent => '', computername => '', notes => '', last_arp => '',
        last_dhcp => '', dhcp_fingerprint => '', switch => '', port => '', bypass_vlan => 1, }
});
$mock_security_event->mock('security_event_count_reevaluate_access', sub { return (1); });
$mock_security_event->mock('security_event_view_top', sub { return $FALSE; });

my $role;
$role = $role_obj->fetchRoleForNode({ mac => 'bb:bb:cc:dd:ee:ff', switch => $switch, ifIndex => '1001'});
is($role->{role}, 'isolation', "determine vlan for node with security_event");

# security_event_count_reevaluate_access will return 0
$mock_security_event->mock('security_event_count_reevaluate_access', sub { return (0); });

# mocking used node method calls
$mock->mock('node_exist', sub { return (1); });
my $node_attributes = { mac => 'aa:bb:cc:dd:ee:ff', pid => 1, detect_date => '', regdate => '', unregdate => '', category => 'default',
        lastskip => '', status => 'reg', user_agent => '', computername => '', notes => '', last_arp => '',
        last_dhcp => '', dhcp_fingerprint => '', switch => '', port => '', bypass_vlan => 1 };

# TODO: complete the test suite with more tests above the other cases
my $switch_vlan_override = pf::SwitchFactory->instantiate('10.0.0.2');
my $profile = pf::Connection::ProfileFactory->instantiate('aa:bb:cc:dd:ee:ff'); # should return default profile
$role = $role_obj->fetchRoleForNode({mac => 'aa:bb:cc:dd:ee:ff', switch => $switch_vlan_override, ifIndex => '1001', node_info => $node_attributes, profile => $profile });
is($role->{vlan}, '1', "determine vlan for registered user on custom switch");

$node_attributes = { mac => 'aa:bb:cc:dd:ee:ff', pid => 1, detect_date => '', regdate => '', unregdate => '', category => 'default',
        lastskip => '', status => 'reg', user_agent => '', computername => '', notes => '', last_arp => '',
        last_dhcp => '', dhcp_fingerprint => '', switch => '', port => '', bypass_vlan => '', };

$role = $role_obj->fetchRoleForNode({mac => 'aa:bb:cc:dd:ee:ff', switch => $switch_vlan_override, ifIndex => '1001', node_info => $node_attributes, profile => $profile});
is($role->{role}, 'default', "determine role for registered user on custom switch");

$node_attributes = { mac => 'aa:bb:cc:dd:ee:ff', pid => 1, detect_date => '', regdate => '', unregdate => '', category => 'default',
        lastskip => '', status => 'reg', user_agent => '', computername => '', notes => '', last_arp => '',
        last_dhcp => '', dhcp_fingerprint => '', switch => '', port => '', bypass_vlan => '', bypass_role => 'normal'};

$role = $role_obj->fetchRoleForNode({mac => 'aa:bb:cc:dd:ee:ff', switch => $switch_vlan_override, ifIndex => '1001', node_info => $node_attributes, profile => $profile });
is($role->{role}, 'normal', "determine bypass_role for registered user on custom switch");

# mocked node_attributes returns unreg node
$node_attributes = { mac => 'aa:bb:cc:dd:ee:ff', pid => 1, detect_date => '', regdate => '', unregdate => '', category => 'default',
        lastskip => '', status => 'unreg', user_agent => '', computername => '', notes => '', last_arp => '',
        last_dhcp => '', dhcp_fingerprint => '', switch => '', port => '', bypass_vlan => 1,};

$role = $role_obj->fetchRoleForNode({mac => 'aa:bb:cc:dd:ee:ff', switch => $switch, ifIndex => '1001', node_info => $node_attributes, profile => $profile});
is($role->{role}, 'registration', "obtain registrationVlan for an unreg node");

$node_attributes =  { mac => 'aa:bb:cc:dd:ee:ff', pid => 1, detect_date => '', regdate => '', unregdate => '', category => 'default',
        lastskip => '', status => 'unreg', user_agent => '', computername => '', notes => '', last_arp => '',
        last_dhcp => '', dhcp_fingerprint => '', switch => '', port => '', bypass_vlan => 1, };

$role = $role_obj->filterVlan('RegistrationRole',{ switch => $switch, IfIndex => '10000', mac => 'aa:bb:cc:dd:ee:ff', node_info => $node_attributes, connection_type => 'Wireless-802.11-NoEAP', username => 'pf', ssid => 'OPEN'});
is($role, 'registration', "obtain registration role for the device");

$role = $role_obj->filterVlan('RegistrationRole',{switch => $switch, IfIndex => '10000', mac => 'aa:bb:cc:dd:ee:ff', node_info => $node_attributes, connection_type => 'Wireless-802.11-NoEAP', username => 'pf', ssid => 'TEST'});
is($role, 'registration2', "obtain registration role for the device");

#($vlan,$wasInline) = $role_obj->getRegisteredRole($switch);
#is($vlan, 1, "obtain normalVlan on a switch with no normalVlan override");

#($vlan,$wasInline) = $role_obj->getRegisteredRole($switch_vlan_override);
#is($vlan, 15, "obtain normalVlan on a switch with normalVlan override");

# doWeActOnThisTrap tests
#
# mock switch's relevant calls
$switch = pf::SwitchFactory->instantiate('192.168.0.1');
$switch  = Test::MockObject::Extends->new( $switch );
$switch->mock('getIfType', sub { return $SNMP::GIGABIT_ETHERNET; });
$switch->mock('getUpLinks', sub { return; });

is(
    $role_obj->doWeActOnThisTrap( $switch, 1000, 'secureMacAddrViolation' ),
    1,
    "avoid empty array warning (issue #832)"
);

$switch->mock('getUpLinks', sub { return (); });
is(
    $role_obj->doWeActOnThisTrap( $switch, 1000, 'secureMacAddrViolation' ),
    1,
    "Zero uplinks"
);

$switch->mock('getUpLinks', sub { return -1; });
is(
    $role_obj->doWeActOnThisTrap( $switch, 1000, 'secureMacAddrViolation' ),
    0,
    "getUpLinks not supported return 0"
);

$switch->mock('getUpLinks', sub { return (1000, 1001); });
is(
    $role_obj->doWeActOnThisTrap( $switch, 1000, 'secureMacAddrViolation' ),
    0,
    "do we act on uplink?"
);

my $filter = pf::access_filter::vlan->new;

my $results = $filter->evalParamAction("key1 = val1, key2 = \$var2 ", {var2 => 'val2'}, "test eval of parameters");

is_deeply({key1 => 'val1', 'key2' => 'val2'}, $results);

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
