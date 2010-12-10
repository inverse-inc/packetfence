#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 149;
use lib '/usr/local/pf/lib';
my $lib_path = '/usr/local/pf/lib';

BEGIN { use_ok('pf::SNMP') }
BEGIN { use_ok('pf::SNMP::Accton') }
BEGIN { use_ok('pf::SNMP::Accton::ES3526XA') }
BEGIN { use_ok('pf::SNMP::Accton::ES3528M') }
BEGIN { use_ok('pf::SNMP::Amer') }
BEGIN { use_ok('pf::SNMP::Amer::SS2R24i') }
BEGIN { use_ok('pf::SNMP::Aruba') }
BEGIN { use_ok('pf::SNMP::Aruba::Controller_200') }
BEGIN { use_ok('pf::SNMP::Cisco') }
BEGIN { use_ok('pf::SNMP::Cisco::Aironet') }
BEGIN { use_ok('pf::SNMP::Cisco::Aironet_1130') }
BEGIN { use_ok('pf::SNMP::Cisco::Aironet_1242') }
BEGIN { use_ok('pf::SNMP::Cisco::Aironet_1250') }
BEGIN { use_ok('pf::SNMP::Cisco::Catalyst_2900XL') }
BEGIN { use_ok('pf::SNMP::Cisco::Catalyst_2950') }
BEGIN { use_ok('pf::SNMP::Cisco::Catalyst_2960') }
BEGIN { use_ok('pf::SNMP::Cisco::Catalyst_2970') }
BEGIN { use_ok('pf::SNMP::Cisco::Catalyst_3500XL') }
BEGIN { use_ok('pf::SNMP::Cisco::Catalyst_3550') }
BEGIN { use_ok('pf::SNMP::Cisco::Catalyst_3560') }
BEGIN { use_ok('pf::SNMP::Cisco::Catalyst_3750') }
BEGIN { use_ok('pf::SNMP::Cisco::Catalyst_4500') }
BEGIN { use_ok('pf::SNMP::Cisco::ISR_1800') }
BEGIN { use_ok('pf::SNMP::Cisco::WiSM') }
BEGIN { use_ok('pf::SNMP::Cisco::WLC_2106') }
BEGIN { use_ok('pf::SNMP::Cisco::WLC_4400') }
BEGIN { use_ok('pf::SNMP::Dell') }
BEGIN { use_ok('pf::SNMP::Dell::PowerConnect3424') }
BEGIN { use_ok('pf::SNMP::Dlink') }
BEGIN { use_ok('pf::SNMP::Dlink::DES_3526') }
BEGIN { use_ok('pf::SNMP::Dlink::DWS_3026') }
BEGIN { use_ok('pf::SNMP::Enterasys') }
BEGIN { use_ok('pf::SNMP::Enterasys::D2') }
BEGIN { use_ok('pf::SNMP::Enterasys::Matrix_N3') }
BEGIN { use_ok('pf::SNMP::Enterasys::SecureStack_C2') }
BEGIN { use_ok('pf::SNMP::Enterasys::SecureStack_C3') }
BEGIN { use_ok('pf::SNMP::Extreme') }
BEGIN { use_ok('pf::SNMP::Extreme::Summit') }
BEGIN { use_ok('pf::SNMP::Extreme::Summit_X250e') }
BEGIN { use_ok('pf::SNMP::Foundry') }
BEGIN { use_ok('pf::SNMP::Foundry::FastIron_4802') }
BEGIN { use_ok('pf::SNMP::HP') }
BEGIN { use_ok('pf::SNMP::HP::Procurve_2500') }
BEGIN { use_ok('pf::SNMP::HP::Procurve_2600') }
BEGIN { use_ok('pf::SNMP::HP::Procurve_3400cl') }
BEGIN { use_ok('pf::SNMP::HP::Procurve_4100') }
BEGIN { use_ok('pf::SNMP::HP::Controller_MSM710') }
BEGIN { use_ok('pf::SNMP::Intel') }
BEGIN { use_ok('pf::SNMP::Intel::Express_460') }
BEGIN { use_ok('pf::SNMP::Intel::Express_530') }
BEGIN { use_ok('pf::SNMP::Juniper') }
BEGIN { use_ok('pf::SNMP::Juniper::EX') }
BEGIN { use_ok('pf::SNMP::Linksys') }
BEGIN { use_ok('pf::SNMP::Linksys::SRW224G4') }
BEGIN { use_ok('pf::SNMP::Meru') }
BEGIN { use_ok('pf::SNMP::Meru::MC3000') }
BEGIN { use_ok('pf::SNMP::MockedSwitch') }
BEGIN { use_ok('pf::SNMP::Nortel') }
BEGIN { use_ok('pf::SNMP::Nortel::BayStack4550') }
BEGIN { use_ok('pf::SNMP::Nortel::BayStack470') }
BEGIN { use_ok('pf::SNMP::Nortel::BayStack5520') }
BEGIN { use_ok('pf::SNMP::Nortel::BayStack5520Stacked') }
BEGIN { use_ok('pf::SNMP::Nortel::BPS2000') }
BEGIN { use_ok('pf::SNMP::Nortel::ERS2500') }
BEGIN { use_ok('pf::SNMP::Nortel::ERS4500') }
BEGIN { use_ok('pf::SNMP::Nortel::ES325') }
BEGIN { use_ok('pf::SNMP::PacketFence') }
BEGIN { use_ok('pf::SNMP::SMC') }
BEGIN { use_ok('pf::SNMP::SMC::TS6128L2') }
BEGIN { use_ok('pf::SNMP::SMC::TS6224M') }
BEGIN { use_ok('pf::SNMP::SMC::TS8800M') }
BEGIN { use_ok('pf::SNMP::ThreeCom') }
BEGIN { use_ok('pf::SNMP::ThreeCom::NJ220') }
BEGIN { use_ok('pf::SNMP::ThreeCom::SS4200') }
BEGIN { use_ok('pf::SNMP::ThreeCom::SS4500') }
BEGIN { use_ok('pf::SNMP::ThreeCom::Switch_4200G') }

my @SNMPobjects = qw(
    pf::SNMP
    pf::SNMP::Accton
    pf::SNMP::Accton::ES3526XA
    pf::SNMP::Accton::ES3528M
    pf::SNMP::Amer
    pf::SNMP::Amer::SS2R24i
    pf::SNMP::Aruba
    pf::SNMP::Aruba::Controller_200
    pf::SNMP::Cisco
    pf::SNMP::Cisco::Aironet
    pf::SNMP::Cisco::Aironet_1130
    pf::SNMP::Cisco::Aironet_1242
    pf::SNMP::Cisco::Aironet_1250
    pf::SNMP::Cisco::Catalyst_2900XL
    pf::SNMP::Cisco::Catalyst_2950
    pf::SNMP::Cisco::Catalyst_2960
    pf::SNMP::Cisco::Catalyst_2970
    pf::SNMP::Cisco::Catalyst_3500XL
    pf::SNMP::Cisco::Catalyst_3550
    pf::SNMP::Cisco::Catalyst_3560
    pf::SNMP::Cisco::Catalyst_3750
    pf::SNMP::Cisco::Catalyst_4500
    pf::SNMP::Cisco::ISR_1800
    pf::SNMP::Cisco::WiSM
    pf::SNMP::Cisco::WLC_2106
    pf::SNMP::Cisco::WLC_4400
    pf::SNMP::Dell
    pf::SNMP::Dell::PowerConnect3424
    pf::SNMP::Dlink
    pf::SNMP::Dlink::DES_3526
    pf::SNMP::Dlink::DWS_3026
    pf::SNMP::Enterasys
    pf::SNMP::Enterasys::D2
    pf::SNMP::Enterasys::Matrix_N3
    pf::SNMP::Enterasys::SecureStack_C2
    pf::SNMP::Enterasys::SecureStack_C3
    pf::SNMP::Extreme
    pf::SNMP::Extreme::Summit
    pf::SNMP::Extreme::Summit_X250e
    pf::SNMP::HP
    pf::SNMP::HP::Procurve_2500
    pf::SNMP::HP::Procurve_2600
    pf::SNMP::HP::Procurve_3400cl
    pf::SNMP::HP::Procurve_4100
    pf::SNMP::HP::Controller_MSM710
    pf::SNMP::Intel
    pf::SNMP::Intel::Express_460
    pf::SNMP::Intel::Express_530
    pf::SNMP::Linksys
    pf::SNMP::Linksys::SRW224G4
    pf::SNMP::Meru  
    pf::SNMP::Meru::MC3000
    pf::SNMP::MockedSwitch
    pf::SNMP::Nortel
    pf::SNMP::Nortel::BayStack4550
    pf::SNMP::Nortel::BayStack470
    pf::SNMP::Nortel::BayStack5520
    pf::SNMP::Nortel::BayStack5520Stacked
    pf::SNMP::Nortel::BPS2000
    pf::SNMP::Nortel::ERS2500
    pf::SNMP::Nortel::ERS4500
    pf::SNMP::Nortel::ES325
    pf::SNMP::PacketFence
    pf::SNMP::SMC
    pf::SNMP::SMC::TS6128L2
    pf::SNMP::SMC::TS6224M
    pf::SNMP::SMC::TS8800M
    pf::SNMP::ThreeCom
    pf::SNMP::ThreeCom::NJ220
    pf::SNMP::ThreeCom::SS4200
    pf::SNMP::ThreeCom::SS4500
    pf::SNMP::ThreeCom::Switch_4200G
);

foreach my $obj_name (@SNMPobjects) {
    my $obj = $obj_name->new();
    isa_ok( $obj, $obj_name, $obj_name );
}

# MockedSwitch is our special test switch that MUST implement all of pf::SNMP's method
# To ensure that it stays always that way, we test for it here.

my @mocked_switch_subs = `egrep "^sub " $lib_path/pf/SNMP/MockedSwitch.pm | awk '{ print \$2 }'`;
my @pf_snmp_subs = `egrep "^sub " $lib_path/pf/SNMP.pm | awk '{ print \$2 }'`;
# these methods are whitelisted because they have no [significant] side-effect, thus not useful to mock
my @whitelist = ( 
    'new', 'isUpLink', 'setVlanWithName', 'setVlanByName', 'setIsolationVlan', 'setRegistrationVlan',
    'setMacDetectionVlan', 'setNormalVlan', 'getMode', 'isTestingMode', 'isIgnoreMode', 'isRegistrationMode', 
    'isProductionMode', 'isDiscoveryMode', 'resetTaggedVlan', 'getBitAtPosition', 'modifyBitmask', 
    'createPortListWithOneItem', 'reverseBitmask', 'generateFakeMac', 'isFakeMac', 'isFakeVoIPMac', 'getVlanFdbId',
    'isNotUpLink', 'setVlan', 'setVlanAllPort', 'resetVlanAllPort', 'getMacAtIfIndex', 'hasPhoneAtIfIndex',
    'isPhoneAtIfIndex', '_authorizeMAC', 'getRegExpFromList', '_getMacAtIfIndex', 'getMacAddrVlan', 'getHubs',
    'getVlanByName', 'isManagedVlan', 'deauthenticateMac', 'setVlan', 'extractSsid'
);

my @missing_subs;
foreach my $sub (@pf_snmp_subs) {

    # skip if pf::SNMP sub is found in mocked_switch
    next if grep {$sub eq $_} @mocked_switch_subs;

    # removing newline to avoid comparison failures
    chop($sub); 
    # skip if this sub is in whitelist
    next if grep {$sub eq $_} @whitelist;

    # if we are still here, there's a missing sub in MockedSwitch
    push @missing_subs, $sub;
}

# is deeply will show what's missing from pf::SNMP::MockedSwitch which is kinda nice
is_deeply(
    \@missing_subs,
    [],
    "there must be no sub in pf::SNMP not implemented or whitelisted in pf::SNMP::MockedSwitch"
);

# TODO future MockedWireless module will have to test for: deauthenticateMac
