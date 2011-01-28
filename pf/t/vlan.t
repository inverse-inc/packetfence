#!/usr/bin/perl -w
=head1 NAME

vlan.t

=head1 DESCRIPTION

pf::vlan module testing

=cut
use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';

use Test::More tests => 10;
use Test::MockModule;
use Test::NoWarnings;

use File::Basename qw(basename);

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

use pf::config;
use pf::SwitchFactory;

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

# setup a fake switch object
my $switchFactory = new pf::SwitchFactory( -configFile => './data/switches.conf' );
my $switch = $switchFactory->instantiate('192.168.0.1');

# redefining violation functions (we stay in pf::vlan's context because methods are imported there from pf::violation)
my $mock = new Test::MockModule('pf::vlan');
# violation_count_trap will return 1
$mock->mock('violation_count_trap', sub { return (1); });

my $vlan;
$vlan = $vlan_obj->fetchVlanForNode('bb:bb:cc:dd:ee:ff', $switch, '1001');
is($vlan, 2, "determine vlan for node with violation");

# violation_count_trap will return 0
$mock->mock('violation_count_trap', sub { return (0); });

# mocking used node method calls
$mock->mock('node_exist', sub { return (1); });
$mock->mock('node_view', sub { 
    return { mac => 'aa:bb:cc:dd:ee:ff', pid => 1, detect_date => '', regdate => '', unregdate => '',
        lastskip => '', status => 'reg', user_agent => '', computername => '', notes => '', last_arp => '',
        last_dhcp => '', dhcp_fingerprint => '', switch => '', port => '', vlan => 1, nbopenviolations => ''}
});

# TODO: complete the test suite with more tests above the other cases
my $switch_vlan_override = $switchFactory->instantiate('10.0.0.1');
$vlan = $vlan_obj->fetchVlanForNode('aa:bb:cc:dd:ee:ff', $switch_vlan_override, '1001');
is($vlan, 15, "determine vlan for registered user on custom switch");

# mocked node_view returns unreg node
$mock->mock('node_view', sub {
    return { mac => 'aa:bb:cc:dd:ee:ff', pid => 1, detect_date => '', regdate => '', unregdate => '',
        lastskip => '', status => 'unreg', user_agent => '', computername => '', notes => '', last_arp => '',
        last_dhcp => '', dhcp_fingerprint => '', switch => '', port => '', vlan => 1, nbopenviolations => ''}
});

$vlan = $vlan_obj->fetchVlanForNode('aa:bb:cc:dd:ee:ff', $switch, '1001');
is($vlan, 3, "obtain registrationVlan for an unreg node");

$vlan = $vlan_obj->getNormalVlan($switch);
is($vlan, 1, "obtain normalVlan on a switch with no normalVlan override");

$vlan = $vlan_obj->getNormalVlan($switch_vlan_override);
is($vlan, 15, "obtain normalVlan on a switch with normalVlan override");

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2009-2011 Inverse inc.

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

