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

# DBI injection
BEGIN { push @ARGV, "--dbitest"; }
use Test::MockDBI qw( :all );
my $md = Test::MockDBI::get_instance();
$pf::db::dbh = DBI->connect( "", "", "" );

use lib '/usr/local/pf/lib';
use pf::config;

BEGIN { 
    use_ok('pf::vlan'); 
    use_ok('pf::vlan::custom');
}

# overload conf_dir from pf::config so that SwitchFactory will use data/switches.conf
$conf_dir = 'data/';

# test the object
my $vlan_obj = new pf::vlan::custom();
isa_ok($vlan_obj, 'pf::vlan');

# subs
can_ok($vlan_obj, qw(
    vlan_determine_for_node
    custom_doWeActOnThisTrap
    custom_getCorrectVlan
    custom_getNodeInfo
    custom_getNodeInfoForAutoReg
    custom_shouldAutoRegister
  ));

# Return 0 violation on first query and 1 on second one
my $qid = 0;
sub violation_count {
    $qid++;
    if ($qid == 1) {
        return (1);
    } elsif ($qid == 2) {
        return (0);
    } else {
        return ();
    }
}

# violation_count_trap
$md->set_retval_array(
    MOCKDBI_WILDCARD,
    "count.*violation.*mac.*",
    \&violation_count
);

my $vlan;
$vlan = $vlan_obj->vlan_determine_for_node('bb:bb:cc:dd:ee:ff', '192.168.0.1', '1001');
is($vlan, 2, "determine vlan for node with violation");

# violation_count_trap return 0
$md->set_retval_array(
    MOCKDBI_WILDCARD,
    "count.*violation.*mac.*",
    ( 0 )
);

# result of node_exist
$md->set_retval_array(
    MOCKDBI_WILDCARD,
    "select mac from node where mac=?",
    ('aa:bb:cc:dd:ee:ff')
);

my $node_entry = [
    { mac => 'aa:bb:cc:dd:ee:ff', pid => 1, detect_date => '', regdate => '', unregdate => '',
      lastskip => '', status => 'reg', user_agent => '', computername => '', notes => '', last_arp => '',
      last_dhcp => '', dhcp_fingerprint => '', switch => '', port => '', vlan => 1, nbopenviolations => ''
    },
    { mac => 'aa:bb:cc:dd:ee:ff', pid => 1, status => 'reg' },
];

$md->set_retval_scalar(
    MOCKDBI_WILDCARD,
    # TODO this does't work
    #".*node.*node\.mac=.*",
    ".*",
    sub { shift @$node_entry }
);

# TODO: complete the test suite with more tests above the other cases
$vlan = $vlan_obj->vlan_determine_for_node('aa:bb:cc:dd:ee:ff', '10.0.0.1', '1001');
is($vlan, 15, "determine vlan for registered user on custom switch");

$vlan = $vlan_obj->custom_getCorrectVlan();
is($vlan, 1, "obtain normalVlan with no switch ip");

$vlan = $vlan_obj->custom_getCorrectVlan('192.168.0.1');
is($vlan, 1, "obtain normalVlan on a switch with no normalVlan override");

$vlan = $vlan_obj->custom_getCorrectVlan('10.0.0.1');
is($vlan, 15, "obtain normalVlan on a switch with normalVlan override");
