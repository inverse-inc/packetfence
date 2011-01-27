#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 16;
use lib '/usr/local/pf/lib';

use File::Basename qw(basename);
Log::Log4perl->init("./log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

use pf::SwitchFactory;

BEGIN { use_ok('pf::SNMP') }

# test the object
my $SNMP = new pf::SNMP;
isa_ok($SNMP, 'pf::SNMP');

# test subs
#TODO: list all mandatory subs here
can_ok($SNMP, qw(
    connectRead
    connectWrite
    setVlan
    _setVlanByOnlyModifyingPvid
    setVlanByName
    setMacDetectionVlan
  ));

# SNMP object tests
# -- variables to avoid repetition --
# VLAN is irrelevant unless it's 'VoIP'
my $non_voip = 0;
my $voip = 1;

my $fake_mac_prefix = '02:00:';
my $fake_mac_voip = '01:';
my $fake_mac_non_voip = '00:';

my $real_mac = "00:1f:5b:e8:b8:4f";

# generateFakeMac
is($SNMP->generateFakeMac($non_voip, 13),
    $fake_mac_prefix.$fake_mac_non_voip."00:00:13",
    "Generate fake MAC non-VoIP normal case");

is($SNMP->generateFakeMac($non_voip, 10001), 
    $fake_mac_prefix.$fake_mac_non_voip."01:00:01", 
    "Generate fake MAC non-VoIP big ifIndex case");

is($SNMP->generateFakeMac($non_voip, 1110001),
    $fake_mac_prefix.$fake_mac_non_voip."99:99:99",
    "Generate fake MAC non-VoIP too large case");

is($SNMP->generateFakeMac($voip, 13),
    $fake_mac_prefix.$fake_mac_voip."00:00:13",
    "Generate fake MAC VoIP normal case");

is($SNMP->generateFakeMac($voip, 10001),
    $fake_mac_prefix.$fake_mac_voip."01:00:01",
    "Generate fake MAC VoIP big ifIndex case");

is($SNMP->generateFakeMac($voip, 1110001),
    $fake_mac_prefix.$fake_mac_voip."99:99:99",
    "Generate fake MAC non-VoIP too large case");

# isFakeMac
ok($SNMP->isFakeMac($fake_mac_prefix.$fake_mac_non_voip."00:00:13"),
    "Is fake MAC with a fake MAC");

ok(!$SNMP->isFakeMac($real_mac),
    "Is fake MAC with a real MAC");

# isFakeVoIPMac
ok($SNMP->isFakeVoIPMac($fake_mac_prefix.$fake_mac_voip."00:00:13"),
    "Is VoIP fake MAC with a VoIP fake MAC");

ok(!$SNMP->isFakeVoIPMac($real_mac),
    "Is VoIP fake MAC with a real MAC");


# Switch object tests
# BE CAREFUL: if you change the configuration files, tests will break!
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

# TODO: one day we should do a positive test for setVlanByName (mocking setVlan)

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2010-2011 Inverse inc.

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

