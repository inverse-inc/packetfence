#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 3;
use lib '/usr/local/pf/lib';

use File::Basename qw(basename);
Log::Log4perl->init("./log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

use pf::SwitchFactory;

BEGIN { use_ok('pf::SNMP') }

# test the object
my $snmp_obj = new pf::SNMP;
isa_ok($snmp_obj, 'pf::SNMP');

# test subs
#TODO: list all mandatory subs here
can_ok($snmp_obj, qw(
    connectRead
    connectWrite
    setVlan
    _setVlanByOnlyModifyingPvid
    setVlanByName
    setMacDetectionVlan
  ));

# getting a switch instance (pf::SNMP::PacketFence but still inherit most subs from pf::SNMP)
my $switchFactory = new pf::SwitchFactory( -configFile => './data/switches.conf' );
my $switch = $switchFactory->instantiate('127.0.0.1');

# setVlanByName
ok(!defined($switch->setVlanByName(1001, 'inexistantVlan', {})), 
    "call setVlanByName with a vlan that doesn't exist in switches.conf");

ok(!defined($switch->setVlanByName(1001, 'customVlan1', {})), 
    "call setVlanByName with a vlan that exists but with a non-numeric value");
 
ok(!defined($switch->setVlanByName(1001, 'customVlan2', {})), 
    "call setVlanByName with a vlan that exists but with an undef value");

# TODO: one day we should do a positive test for setVlanByName 
# but current architecture doesn't allow without redefining subs
