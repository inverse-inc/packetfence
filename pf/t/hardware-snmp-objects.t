#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 136;
use lib '/usr/local/pf/lib';

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
BEGIN { use_ok('pf::SNMP::Cisco::Controller_4400_4_2_130') }
BEGIN { use_ok('pf::SNMP::Cisco::ISR_1800') }
BEGIN { use_ok('pf::SNMP::Cisco::WiSM') }
BEGIN { use_ok('pf::SNMP::Cisco::WLC_2106') }
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
BEGIN { use_ok('pf::SNMP::HP::Procurve_4100') }
BEGIN { use_ok('pf::SNMP::Intel') }
BEGIN { use_ok('pf::SNMP::Intel::Express_460') }
BEGIN { use_ok('pf::SNMP::Intel::Express_530') }
BEGIN { use_ok('pf::SNMP::Linksys') }
BEGIN { use_ok('pf::SNMP::Linksys::SRW224G4') }
BEGIN { use_ok('pf::SNMP::Nortel') }
BEGIN { use_ok('pf::SNMP::Nortel::BayStack4550') }
BEGIN { use_ok('pf::SNMP::Nortel::BayStack470') }
BEGIN { use_ok('pf::SNMP::Nortel::BayStack5520') }
BEGIN { use_ok('pf::SNMP::Nortel::BayStack5520Stacked') }
BEGIN { use_ok('pf::SNMP::Nortel::BPS2000') }
BEGIN { use_ok('pf::SNMP::Nortel::ES325') }
BEGIN { use_ok('pf::SNMP::PacketFence') }
BEGIN { use_ok('pf::SNMP::SMC') }
BEGIN { use_ok('pf::SNMP::SMC::TS6224M') }
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
    pf::SNMP::Cisco::Controller_4400_4_2_130
    pf::SNMP::Cisco::ISR_1800
    pf::SNMP::Cisco::WiSM
    pf::SNMP::Cisco::WLC_2106
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
    pf::SNMP::HP::Procurve_4100
    pf::SNMP::Intel
    pf::SNMP::Intel::Express_460
    pf::SNMP::Intel::Express_530
    pf::SNMP::Linksys
    pf::SNMP::Linksys::SRW224G4
    pf::SNMP::Nortel
    pf::SNMP::Nortel::BayStack4550
    pf::SNMP::Nortel::BayStack470
    pf::SNMP::Nortel::BayStack5520
    pf::SNMP::Nortel::BayStack5520Stacked
    pf::SNMP::Nortel::BPS2000
    pf::SNMP::Nortel::ES325
    pf::SNMP::PacketFence
    pf::SNMP::SMC
    pf::SNMP::SMC::TS6224M
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

# basic SNMP functions
my $SNMP = pf::SNMP->new();

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

