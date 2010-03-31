#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use File::Basename qw(basename);
Log::Log4perl->init("/usr/local/pf/t/log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

use Test::More tests => 9;
use Test::MockModule;

# DBI injection
BEGIN { push @ARGV, "--dbitest"; }
use Test::MockDBI qw( :all );
my $md = Test::MockDBI::get_instance();
$pf::db::dbh = DBI->connect( "", "", "" );

use lib '/usr/local/pf/lib';
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
    vlan_determine_for_node
    custom_doWeActOnThisTrap
    custom_getCorrectVlan
    getNodeUpdatedInfo
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
$vlan = $vlan_obj->vlan_determine_for_node('bb:bb:cc:dd:ee:ff', $switch, '1001');
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
$vlan = $vlan_obj->vlan_determine_for_node('aa:bb:cc:dd:ee:ff', $switch_vlan_override, '1001');
is($vlan, 15, "determine vlan for registered user on custom switch");

$vlan = $vlan_obj->custom_getCorrectVlan();
is($vlan, 1, "obtain normalVlan with no switch ip");

$vlan = $vlan_obj->custom_getCorrectVlan($switch);
is($vlan, 1, "obtain normalVlan on a switch with no normalVlan override");

$vlan = $vlan_obj->custom_getCorrectVlan($switch_vlan_override);
is($vlan, 15, "obtain normalVlan on a switch with normalVlan override");
