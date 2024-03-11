#!/usr/bin/perl

=head1 NAME

example pf test

=cut

=head1 DESCRIPTION

example pf test script

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More;
use pf::Switch::Accton;
use pf::Switch::Accton::ES3526XA;
use pf::Switch::Accton::ES3528M;
use pf::Switch::AeroHIVE;
use pf::Switch::AeroHIVE::AP;
use pf::Switch::AeroHIVE::BR100;
use pf::Switch::Alcatel;
use pf::Switch::AlliedTelesis;
use pf::Switch::AlliedTelesis::AT8000GS;
use pf::Switch::AlliedTelesis::GS950;
use pf::Switch::Amer;
use pf::Switch::Amer::SS2R24i;
use pf::Switch::Anyfi;
use pf::Switch::Aruba;
use pf::Switch::Aruba::2930M;
use pf::Switch::Aruba::5400;
use pf::Switch::Aruba::Controller_200;
use pf::Switch::Aruba::Instant_Access;
use pf::Switch::ArubaSwitch;
use pf::Switch::Avaya;
use pf::Switch::Avaya::ERS2500;
use pf::Switch::Avaya::ERS3500;
use pf::Switch::Avaya::ERS4000;
use pf::Switch::Avaya::ERS5000;
use pf::Switch::Avaya::ERS5000_6x;
use pf::Switch::Avaya::WC;
use pf::Switch::Belair;
use pf::Switch::Brocade;
use pf::Switch::Brocade::RFS;
use pf::Switch::Cambium;
use pf::Switch::Cisco;
use pf::Switch::Cisco::ASA;
use pf::Switch::Cisco::Aironet;
use pf::Switch::Cisco::Aironet_1130;
use pf::Switch::Cisco::Aironet_1242;
use pf::Switch::Cisco::Aironet_1250;
use pf::Switch::Cisco::Aironet_1600;
use pf::Switch::Cisco::Aironet_WDS;
use pf::Switch::Cisco::Catalyst_2900XL;
use pf::Switch::Cisco::Cisco_IOS_12_x;
use pf::Switch::Cisco::Cisco_IOS_15_5;
use pf::Switch::Cisco::Catalyst_2960G;
use pf::Switch::Cisco::Catalyst_2970;
use pf::Switch::Cisco::Catalyst_3500XL;
use pf::Switch::Cisco::Catalyst_3550;
use pf::Switch::Cisco::Catalyst_3560;
use pf::Switch::Cisco::Catalyst_3560G;
use pf::Switch::Cisco::Catalyst_3750;
use pf::Switch::Cisco::Catalyst_3750G;
use pf::Switch::Cisco::Catalyst_4500;
use pf::Switch::Cisco::Catalyst_6500;
use pf::Switch::Cisco::ISR_1800;
use pf::Switch::Cisco::SG300;
use pf::Switch::Cisco::WLC;
use pf::Switch::Cisco::WLC_2100;
use pf::Switch::Cisco::WLC_2106;
use pf::Switch::Cisco::WLC_2500;
use pf::Switch::Cisco::WLC_4400;
use pf::Switch::Cisco::WLC_5500;
use pf::Switch::Cisco::WiSM;
use pf::Switch::Cisco::WiSM2;
use pf::Switch::CoovaChilli;
use pf::Switch::Dell;
use pf::Switch::Dell::Force10;
use pf::Switch::Dell::N1500;
use pf::Switch::Dell::PowerConnect3424;
use pf::Switch::Dlink;
use pf::Switch::Dlink::DES_3028;
use pf::Switch::Dlink::DES_3526;
use pf::Switch::Dlink::DES_3550;
use pf::Switch::Dlink::DGS_3100;
use pf::Switch::Dlink::DGS_3200;
use pf::Switch::Dlink::DWL;
use pf::Switch::Dlink::DWS_3026;
use pf::Switch::EdgeCore;
use pf::Switch::Enterasys;
use pf::Switch::Enterasys::D2;
use pf::Switch::Enterasys::Matrix_N3;
use pf::Switch::Enterasys::SecureStack_C2;
use pf::Switch::Enterasys::SecureStack_C3;
use pf::Switch::Enterasys::V2110;
use pf::Switch::Extreme;
use pf::Switch::Extreme::Summit;
use pf::Switch::Extreme::Summit_X250e;
use pf::Switch::Extricom;
use pf::Switch::Extricom::EXSW;
use pf::Switch::Fortinet;
use pf::Switch::Fortinet::FortiGate;
use pf::Switch::Fortinet::FortiSwitch;
use pf::Switch::Foundry;
use pf::Switch::Foundry::FastIron_4802;
use pf::Switch::Foundry::MC;
use pf::Switch::Generic;
use pf::Switch::H3C;
use pf::Switch::H3C::S5120;
use pf::Switch::HP;
use pf::Switch::HP::Controller_MSM710;
use pf::Switch::HP::E4800G;
use pf::Switch::HP::E5500G;
use pf::Switch::HP::MSM;
use pf::Switch::HP::Procurve_2500;
use pf::Switch::HP::Procurve_2600;
use pf::Switch::HP::Procurve_2920;
use pf::Switch::HP::Procurve_3400cl;
use pf::Switch::HP::Procurve_4100;
use pf::Switch::HP::Procurve_5300;
use pf::Switch::HP::Procurve_5400;
use pf::Switch::Hostapd;
use pf::Switch::Huawei;
use pf::Switch::Huawei::S5710;
use pf::Switch::IBM;
use pf::Switch::IBM::IBM_RackSwitch_G8052;
use pf::Switch::Intel;
use pf::Switch::Intel::Express_460;
use pf::Switch::Intel::Express_530;
use pf::Switch::Juniper;
use pf::Switch::Juniper::EX;
use pf::Switch::Juniper::EX2200;
use pf::Switch::Juniper::EX2200_v15;
use pf::Switch::Juniper::EX2300;
use pf::Switch::LG;
use pf::Switch::LG::ES4500G;
use pf::Switch::Linksys;
use pf::Switch::Linksys::SRW224G4;
use pf::Switch::Meraki;
use pf::Switch::Meraki::MR;
use pf::Switch::Meraki::MR_v2;
use pf::Switch::Meraki::MS220_8;
use pf::Switch::Meru;
use pf::Switch::Meru::MC;
use pf::Switch::Mikrotik;
use pf::Switch::MockedSwitch;
use pf::Switch::Mojo;
use pf::Switch::Motorola;
use pf::Switch::Motorola::RFS;
use pf::Switch::Netgear;
use pf::Switch::Netgear::FSM726v1;
use pf::Switch::Netgear::FSM7328S;
use pf::Switch::Netgear::GS110;
use pf::Switch::Netgear::MSeries;
use pf::Switch::Nortel;
use pf::Switch::Nortel::BPS2000;
use pf::Switch::Nortel::BayStack4550;
use pf::Switch::Nortel::BayStack470;
use pf::Switch::Nortel::BayStack5500;
use pf::Switch::Nortel::BayStack5500_6x;
use pf::Switch::Nortel::ERS2500;
use pf::Switch::Nortel::ERS4000;
use pf::Switch::Nortel::ERS5000;
use pf::Switch::Nortel::ERS5000_6x;
use pf::Switch::Nortel::ES325;
use pf::Switch::PacketFence;
use pf::Switch::Pica8;
use pf::Switch::Ruckus;
use pf::Switch::Ruckus::Legacy;
use pf::Switch::Ruckus::SmartZone;
use pf::Switch::SMC;
use pf::Switch::SMC::TS6128L2;
use pf::Switch::SMC::TS6224M;
use pf::Switch::SMC::TS8800M;
use pf::Switch::ThreeCom;
use pf::Switch::ThreeCom::E4800G;
use pf::Switch::ThreeCom::E5500G;
use pf::Switch::ThreeCom::NJ220;
use pf::Switch::ThreeCom::SS4200;
use pf::Switch::ThreeCom::SS4500;
use pf::Switch::ThreeCom::Switch_4200G;
use pf::Switch::Trapeze;
use pf::Switch::Ubiquiti;
use pf::Switch::Ubiquiti::EdgeSwitch;
use pf::Switch::Ubiquiti::Unifi;
use pf::Switch::WirelessModuleTemplate;
use pf::Switch::Xirrus;
use pf::Switch::constants;


is(pf::Switch::AeroHIVE->new->supportsWirelessMacAuth, 1, "pf::Switch::AeroHIVE supportsWirelessMacAuth still works");
is(pf::Switch::AeroHIVE->new->supportsRoamingAccounting, 1, "pf::Switch::AeroHIVE supportsRoamingAccounting still works");
is(pf::Switch::AeroHIVE->new->supportsWirelessDot1x, 1, "pf::Switch::AeroHIVE supportsWirelessDot1x still works");
is(pf::Switch::AeroHIVE->new->supportsRoleBasedEnforcement, 1, "pf::Switch::AeroHIVE supportsRoleBasedEnforcement still works");
is(pf::Switch::AeroHIVE::AP->new->supportsWebFormRegistration, 1, "pf::Switch::AeroHIVE::AP supportsWebFormRegistration still works");
is(pf::Switch::AeroHIVE::AP->new->supportsExternalPortal, 1, "pf::Switch::AeroHIVE::AP supportsExternalPortal still works");
is(pf::Switch::AeroHIVE::AP->new->supportsWiredMacAuth, 1, "pf::Switch::AeroHIVE::AP supportsWiredMacAuth still works");
is(pf::Switch::AeroHIVE::AP->new->supportsWiredDot1x, 1, "pf::Switch::AeroHIVE::AP supportsWiredDot1x still works");
is(pf::Switch::AeroHIVE::BR100->new->supportsWiredMacAuth, 1, "pf::Switch::AeroHIVE::BR100 supportsWiredMacAuth still works");
is(pf::Switch::Alcatel->new->supportsRadiusDynamicVlanAssignment, 1, "pf::Switch::Alcatel supportsRadiusDynamicVlanAssignment still works");
is(pf::Switch::Alcatel->new->supportsRadiusVoip, 1, "pf::Switch::Alcatel supportsRadiusVoip still works");
is(pf::Switch::Alcatel->new->supportsRoleBasedEnforcement, 1, "pf::Switch::Alcatel supportsRoleBasedEnforcement still works");
is(pf::Switch::Alcatel->new->supportsWiredMacAuth, 1, "pf::Switch::Alcatel supportsWiredMacAuth still works");
is(pf::Switch::Alcatel->new->supportsWiredDot1x, 1, "pf::Switch::Alcatel supportsWiredDot1x still works");
is(pf::Switch::AlliedTelesis->new->supportsWiredMacAuth, 1, "pf::Switch::AlliedTelesis supportsWiredMacAuth still works");
is(pf::Switch::AlliedTelesis->new->supportsWiredDot1x, 1, "pf::Switch::AlliedTelesis supportsWiredDot1x still works");
is(pf::Switch::AlliedTelesis::GS950->new->supportsWiredMacAuth, 1, "pf::Switch::AlliedTelesis::GS950 supportsWiredMacAuth still works");
is(pf::Switch::AlliedTelesis::GS950->new->supportsWiredDot1x, 1, "pf::Switch::AlliedTelesis::GS950 supportsWiredDot1x still works");
is(pf::Switch::Anyfi->new->supportsWirelessMacAuth, 1, "pf::Switch::Anyfi supportsWirelessMacAuth still works");
is(pf::Switch::Anyfi->new->supportsWirelessDot1x, 1, "pf::Switch::Anyfi supportsWirelessDot1x still works");
is(pf::Switch::Aruba->new->supportsWirelessMacAuth, 1, "pf::Switch::Aruba supportsWirelessMacAuth still works");
is(pf::Switch::Aruba->new->supportsExternalPortal, 1, "pf::Switch::Aruba supportsExternalPortal still works");
is(pf::Switch::Aruba->new->supportsWiredDot1x, 1, "pf::Switch::Aruba supportsWiredDot1x still works");
is(pf::Switch::Aruba->new->supportsRoleBasedEnforcement, 1, "pf::Switch::Aruba supportsRoleBasedEnforcement still works");
is(pf::Switch::Aruba->new->supportsWiredMacAuth, 1, "pf::Switch::Aruba supportsWiredMacAuth still works");
is(pf::Switch::Aruba->new->supportsWirelessDot1x, 1, "pf::Switch::Aruba supportsWirelessDot1x still works");
is(pf::Switch::Aruba::2930M->new->supportsAccessListBasedEnforcement, 1, "pf::Switch::Aruba::2930M supportsAccessListBasedEnforcement still works");
is(pf::Switch::Aruba::5400->new->supportsRadiusVoip, 1, "pf::Switch::Aruba::5400 supportsRadiusVoip still works");
is(pf::Switch::Aruba::5400->new->supportsAccessListBasedEnforcement, 1, "pf::Switch::Aruba::5400 supportsAccessListBasedEnforcement still works");
is(pf::Switch::Aruba::5400->new->supportsWiredMacAuth, 1, "pf::Switch::Aruba::5400 supportsWiredMacAuth still works");
is(pf::Switch::Aruba::5400->new->supportsWiredDot1x, 1, "pf::Switch::Aruba::5400 supportsWiredDot1x still works");
is(pf::Switch::ArubaSwitch->new->supportsRadiusDynamicVlanAssignment, 1, "pf::Switch::ArubaSwitch supportsRadiusDynamicVlanAssignment still works");
is(pf::Switch::ArubaSwitch->new->supportsRoleBasedEnforcement, 1, "pf::Switch::ArubaSwitch supportsRoleBasedEnforcement still works");
is(pf::Switch::ArubaSwitch->new->supportsWiredMacAuth, 1, "pf::Switch::ArubaSwitch supportsWiredMacAuth still works");
is(pf::Switch::ArubaSwitch->new->supportsWiredDot1x, 1, "pf::Switch::ArubaSwitch supportsWiredDot1x still works");
is(pf::Switch::Avaya->new->supportsRadiusVoip, 1, "pf::Switch::Avaya supportsRadiusVoip still works");
is(pf::Switch::Avaya->new->supportsWiredMacAuth, 1, "pf::Switch::Avaya supportsWiredMacAuth still works");
is(pf::Switch::Avaya->new->supportsWiredDot1x, 1, "pf::Switch::Avaya supportsWiredDot1x still works");
is(pf::Switch::Avaya::ERS3500->new->supportsRadiusDynamicVlanAssignment, 1, "pf::Switch::Avaya::ERS3500 supportsRadiusDynamicVlanAssignment still works");
is(pf::Switch::Avaya::ERS4000->new->supportsRadiusVoip, 1, "pf::Switch::Avaya::ERS4000 supportsRadiusVoip still works");
is(pf::Switch::Avaya::ERS4000->new->supportsWiredMacAuth, 1, "pf::Switch::Avaya::ERS4000 supportsWiredMacAuth still works");
is(pf::Switch::Avaya::WC->new->supportsWirelessMacAuth, 1, "pf::Switch::Avaya::WC supportsWirelessMacAuth still works");
is(pf::Switch::Avaya::WC->new->supportsWirelessDot1x, 1, "pf::Switch::Avaya::WC supportsWirelessDot1x still works");
is(pf::Switch::Belair->new->supportsWirelessMacAuth, 0, "pf::Switch::Belair supportsWirelessMacAuth still works");
is(pf::Switch::Belair->new->supportsWirelessDot1x, 1, "pf::Switch::Belair supportsWirelessDot1x still works");
is(pf::Switch::Brocade->new->supportsRadiusDynamicVlanAssignment, 1, "pf::Switch::Brocade supportsRadiusDynamicVlanAssignment still works");
is(pf::Switch::Brocade->new->supportsRadiusVoip, 1, "pf::Switch::Brocade supportsRadiusVoip still works");
is(pf::Switch::Brocade->new->supportsLldp, 1, "pf::Switch::Brocade supportsLldp still works");
is(pf::Switch::Brocade->new->supportsWiredMacAuth, 1, "pf::Switch::Brocade supportsWiredMacAuth still works");
is(pf::Switch::Brocade->new->supportsWiredDot1x, 1, "pf::Switch::Brocade supportsWiredDot1x still works");
is(pf::Switch::Cambium->new->supportsWebFormRegistration, 1, "pf::Switch::Cambium supportsWebFormRegistration still works");
is(pf::Switch::Cambium->new->supportsWirelessMacAuth, 1, "pf::Switch::Cambium supportsWirelessMacAuth still works");
is(pf::Switch::Cambium->new->supportsExternalPortal, 1, "pf::Switch::Cambium supportsExternalPortal still works");
is(pf::Switch::Cambium->new->supportsWirelessDot1x, 1, "pf::Switch::Cambium supportsWirelessDot1x still works");
is(pf::Switch::Cisco->new->supportsSaveConfig, 1, "pf::Switch::Cisco supportsSaveConfig still works");
is(pf::Switch::Cisco->new->supportsCdp, 1, "pf::Switch::Cisco supportsCdp still works");
is(pf::Switch::Cisco::ASA->new->supportsRadiusDynamicVlanAssignment, 1, "pf::Switch::Cisco::ASA supportsRadiusDynamicVlanAssignment still works");
is(pf::Switch::Cisco::ASA->new->supportsExternalPortal, 1, "pf::Switch::Cisco::ASA supportsExternalPortal still works");
is(pf::Switch::Cisco::ASA->new->supportsVPN, 1, "pf::Switch::Cisco::ASA supportsVPN still works");
is(pf::Switch::Cisco::ASA->new->supportsRoleBasedEnforcement, 1, "pf::Switch::Cisco::ASA supportsRoleBasedEnforcement still works");
is(pf::Switch::Cisco::ASA->new->supportsAccessListBasedEnforcement, 1, "pf::Switch::Cisco::ASA supportsAccessListBasedEnforcement still works");
is(pf::Switch::Cisco::Aironet->new->supportsWirelessMacAuth, 1, "pf::Switch::Cisco::Aironet supportsWirelessMacAuth still works");
is(pf::Switch::Cisco::Aironet->new->supportsWirelessDot1x, 1, "pf::Switch::Cisco::Aironet supportsWirelessDot1x still works");
is(pf::Switch::Cisco::Aironet->new->supportsSaveConfig, 0, "pf::Switch::Cisco::Aironet supportsSaveConfig still works");
is(pf::Switch::Cisco::Aironet->new->supportsLldp, 0, "pf::Switch::Cisco::Aironet supportsLldp still works");
is(pf::Switch::Cisco::Aironet->new->supportsCdp, 0, "pf::Switch::Cisco::Aironet supportsCdp still works");
is(pf::Switch::Cisco::Cisco_IOS_12_x->new->supportsFloatingDevice, 1, "pf::Switch::Cisco::Cisco_IOS_12_x supportsFloatingDevice still works");
is(pf::Switch::Cisco::Cisco_IOS_12_x->new->supportsRadiusDynamicVlanAssignment, 0, "pf::Switch::Cisco::Cisco_IOS_12_x supportsRadiusDynamicVlanAssignment still works");
is(pf::Switch::Cisco::Cisco_IOS_12_x->new->supportsRadiusVoip, 1, "pf::Switch::Cisco::Cisco_IOS_12_x supportsRadiusVoip still works");
is(pf::Switch::Cisco::Cisco_IOS_12_x->new->supportsLldp, 1, "pf::Switch::Cisco::Cisco_IOS_12_x supportsLldp still works");
is(pf::Switch::Cisco::Cisco_IOS_12_x->new->supportsWiredDot1x, 1, "pf::Switch::Cisco::Cisco_IOS_12_x supportsWiredDot1x still works");
is(pf::Switch::Cisco::Cisco_IOS_15_5->new->supportsRadiusDynamicVlanAssignment, 1, "pf::Switch::Cisco::Cisco_IOS_15_5 supportsRadiusDynamicVlanAssignment still works");
is(pf::Switch::Cisco::Cisco_IOS_15_5->new->supportsExternalPortal, 1, "pf::Switch::Cisco::Cisco_IOS_15_5 supportsExternalPortal still works");
is(pf::Switch::Cisco::Cisco_IOS_15_5->new->supportsRadiusVoip, 1, "pf::Switch::Cisco::Cisco_IOS_15_5 supportsRadiusVoip still works");
is(pf::Switch::Cisco::Cisco_IOS_15_5->new->supportsRoleBasedEnforcement, 1, "pf::Switch::Cisco::Cisco_IOS_15_5 supportsRoleBasedEnforcement still works");
is(pf::Switch::Cisco::Cisco_IOS_15_5->new->supportsAccessListBasedEnforcement, 1, "pf::Switch::Cisco::Cisco_IOS_15_5 supportsAccessListBasedEnforcement still works");
is(pf::Switch::Cisco::Cisco_IOS_15_5->new->supportsWiredMacAuth, 1, "pf::Switch::Cisco::Cisco_IOS_15_5 supportsWiredMacAuth still works");
is(pf::Switch::Cisco::Cisco_IOS_15_5->new->supportsWiredDot1x, 1, "pf::Switch::Cisco::Cisco_IOS_15_5 supportsWiredDot1x still works");
is(pf::Switch::Cisco::WLC->new->supportsWirelessMacAuth, 1, "pf::Switch::Cisco::WLC supportsWirelessMacAuth still works");
is(pf::Switch::Cisco::WLC->new->supportsExternalPortal, 1, "pf::Switch::Cisco::WLC supportsExternalPortal still works");
is(pf::Switch::Cisco::WLC->new->supportsSaveConfig, 0, "pf::Switch::Cisco::WLC supportsSaveConfig still works");
is(pf::Switch::Cisco::WLC->new->supportsRoleBasedEnforcement, 1, "pf::Switch::Cisco::WLC supportsRoleBasedEnforcement still works");
is(pf::Switch::Cisco::WLC->new->supportsLldp, 0, "pf::Switch::Cisco::WLC supportsLldp still works");
is(pf::Switch::Cisco::WLC->new->supportsWiredMacAuth, 1, "pf::Switch::Cisco::WLC supportsWiredMacAuth still works");
is(pf::Switch::Cisco::WLC->new->supportsWirelessDot1x, 1, "pf::Switch::Cisco::WLC supportsWirelessDot1x still works");
is(pf::Switch::Cisco::WLC->new->supportsWiredDot1x, 1, "pf::Switch::Cisco::WLC supportsWiredDot1x still works");
is(pf::Switch::Cisco::WLC->new->supportsCdp, 0, "pf::Switch::Cisco::WLC supportsCdp still works");
is(pf::Switch::Cisco::WLC_2100->new->supportsSaveConfig, 0, "pf::Switch::Cisco::WLC_2100 supportsSaveConfig still works");
is(pf::Switch::Cisco::WLC_2100->new->supportsWirelessMacAuth, 1, "pf::Switch::Cisco::WLC_2100 supportsWirelessMacAuth still works");
is(pf::Switch::Cisco::WLC_2100->new->supportsWirelessDot1x, 1, "pf::Switch::Cisco::WLC_2100 supportsWirelessDot1x still works");
is(pf::Switch::CoovaChilli->new->supportsWebFormRegistration, 1, "pf::Switch::CoovaChilli supportsWebFormRegistration still works");
is(pf::Switch::CoovaChilli->new->supportsExternalPortal, 1, "pf::Switch::CoovaChilli supportsExternalPortal still works");
is(pf::Switch::Dell::Force10->new->supportsRadiusVoip, 1, "pf::Switch::Dell::Force10 supportsRadiusVoip still works");
is(pf::Switch::Dell::Force10->new->supportsWiredDot1x, 1, "pf::Switch::Dell::Force10 supportsWiredDot1x still works");
is(pf::Switch::Dell::Force10->new->supportsRadiusDynamicVlanAssignment, 1, "pf::Switch::Dell::Force10 supportsRadiusDynamicVlanAssignment still works");
is(pf::Switch::Dell::Force10->new->supportsWiredMacAuth, 1, "pf::Switch::Dell::Force10 supportsWiredMacAuth still works");
is(pf::Switch::Dell::N1500->new->supportsRadiusVoip, 1, "pf::Switch::Dell::N1500 supportsRadiusVoip still works");
is(pf::Switch::Dell::N1500->new->supportsWiredDot1x, 1, "pf::Switch::Dell::N1500 supportsWiredDot1x still works");
is(pf::Switch::Dell::N1500->new->supportsRadiusDynamicVlanAssignment, 1, "pf::Switch::Dell::N1500 supportsRadiusDynamicVlanAssignment still works");
is(pf::Switch::Dell::N1500->new->supportsWiredMacAuth, 1, "pf::Switch::Dell::N1500 supportsWiredMacAuth still works");
is(pf::Switch::Dell::N1500->new->supportsLldp, 1, "pf::Switch::Dell::N1500 supportsLldp still works");
is(pf::Switch::Dlink::DGS_3100->new->supportsWiredMacAuth, 1, "pf::Switch::Dlink::DGS_3100 supportsWiredMacAuth still works");
is(pf::Switch::Dlink::DGS_3100->new->supportsWiredDot1x, 1, "pf::Switch::Dlink::DGS_3100 supportsWiredDot1x still works");
is(pf::Switch::Dlink::DGS_3200->new->supportsWiredMacAuth, 1, "pf::Switch::Dlink::DGS_3200 supportsWiredMacAuth still works");
is(pf::Switch::Dlink::DGS_3200->new->supportsWiredDot1x, 1, "pf::Switch::Dlink::DGS_3200 supportsWiredDot1x still works");
is(pf::Switch::Dlink::DWS_3026->new->supportsWirelessMacAuth, 1, "pf::Switch::Dlink::DWS_3026 supportsWirelessMacAuth still works");
is(pf::Switch::Dlink::DWS_3026->new->supportsWirelessDot1x, 1, "pf::Switch::Dlink::DWS_3026 supportsWirelessDot1x still works");
is(pf::Switch::EdgeCore->new->supportsWiredMacAuth, 1, "pf::Switch::EdgeCore supportsWiredMacAuth still works");
is(pf::Switch::Enterasys::D2->new->supportsWiredMacAuth, 1, "pf::Switch::Enterasys::D2 supportsWiredMacAuth still works");
is(pf::Switch::Enterasys::V2110->new->supportsWirelessMacAuth, 1, "pf::Switch::Enterasys::V2110 supportsWirelessMacAuth still works");
is(pf::Switch::Enterasys::V2110->new->supportsRoleBasedEnforcement, 1, "pf::Switch::Enterasys::V2110 supportsRoleBasedEnforcement still works");
is(pf::Switch::Enterasys::V2110->new->supportsWirelessDot1x, 1, "pf::Switch::Enterasys::V2110 supportsWirelessDot1x still works");
is(pf::Switch::Extreme->new->supportsWiredMacAuth, 1, "pf::Switch::Extreme supportsWiredMacAuth still works");
is(pf::Switch::Extreme->new->supportsWiredDot1x, 1, "pf::Switch::Extreme supportsWiredDot1x still works");
is(pf::Switch::Extricom->new->supportsWirelessMacAuth, 1, "pf::Switch::Extricom supportsWirelessMacAuth still works");
is(pf::Switch::Extricom->new->supportsWirelessDot1x, 1, "pf::Switch::Extricom supportsWirelessDot1x still works");
is(pf::Switch::Fortinet::FortiGate->new->supportsWebFormRegistration, 1, "pf::Switch::Fortinet::FortiGate supportsWebFormRegistration still works");
is(pf::Switch::Fortinet::FortiGate->new->supportsWirelessMacAuth, 1, "pf::Switch::Fortinet::FortiGate supportsWirelessMacAuth still works");
is(pf::Switch::Fortinet::FortiGate->new->supportsExternalPortal, 1, "pf::Switch::Fortinet::FortiGate supportsExternalPortal still works");
is(pf::Switch::Fortinet::FortiGate->new->supportsVPN, 1, "pf::Switch::Fortinet::FortiGate supportsVPN still works");
is(pf::Switch::Fortinet::FortiGate->new->supportsWiredMacAuth, 1, "pf::Switch::Fortinet::FortiGate supportsWiredMacAuth still works");
is(pf::Switch::Fortinet::FortiGate->new->supportsWirelessDot1x, 1, "pf::Switch::Fortinet::FortiGate supportsWirelessDot1x still works");
is(pf::Switch::Fortinet::FortiSwitch->new->supportsWiredMacAuth, 1, "pf::Switch::Fortinet::FortiSwitch supportsWiredMacAuth still works");
is(pf::Switch::Fortinet::FortiSwitch->new->supportsWiredDot1x, 1, "pf::Switch::Fortinet::FortiSwitch supportsWiredDot1x still works");
is(pf::Switch::Generic->new->supportsWiredDot1x, 1, "pf::Switch::Generic supportsWiredDot1x still works");
is(pf::Switch::Generic->new->supportsWirelessMacAuth, 1, "pf::Switch::Generic supportsWirelessMacAuth still works");
is(pf::Switch::Generic->new->supportsWiredMacAuth, 1, "pf::Switch::Generic supportsWiredMacAuth still works");
is(pf::Switch::Generic->new->supportsWirelessDot1x, 1, "pf::Switch::Generic supportsWirelessDot1x still works");
is(pf::Switch::H3C->new->supportsWiredDot1x, 1, "pf::Switch::H3C supportsWiredDot1x still works");
is(pf::Switch::H3C->new->supportsWiredMacAuth, 1, "pf::Switch::H3C supportsWiredMacAuth still works");
is(pf::Switch::H3C->new->supportsRadiusVoip, 1, "pf::Switch::H3C supportsRadiusVoip still works");
is(pf::Switch::HP::Controller_MSM710->new->supportsWirelessMacAuth, 1, "pf::Switch::HP::Controller_MSM710 supportsWirelessMacAuth still works");
is(pf::Switch::HP::Controller_MSM710->new->supportsWirelessDot1x, 1, "pf::Switch::HP::Controller_MSM710 supportsWirelessDot1x still works");
is(pf::Switch::HP::Procurve_2500->new->supportsFloatingDevice, 1, "pf::Switch::HP::Procurve_2500 supportsFloatingDevice still works");
is(pf::Switch::HP::Procurve_2500->new->supportsWiredMacAuth, 1, "pf::Switch::HP::Procurve_2500 supportsWiredMacAuth still works");
is(pf::Switch::HP::Procurve_2500->new->supportsWiredDot1x, 1, "pf::Switch::HP::Procurve_2500 supportsWiredDot1x still works");
is(pf::Switch::HP::Procurve_2600->new->supportsWiredDot1x, 1, "pf::Switch::HP::Procurve_2600 supportsWiredDot1x still works");
is(pf::Switch::HP::Procurve_2600->new->supportsWiredMacAuth, 1, "pf::Switch::HP::Procurve_2600 supportsWiredMacAuth still works");
is(pf::Switch::HP::Procurve_2920->new->supportsRadiusVoip, 1, "pf::Switch::HP::Procurve_2920 supportsRadiusVoip still works");
is(pf::Switch::HP::Procurve_2920->new->supportsLldp, 1, "pf::Switch::HP::Procurve_2920 supportsLldp still works");
is(pf::Switch::HP::Procurve_2920->new->supportsWiredMacAuth, 1, "pf::Switch::HP::Procurve_2920 supportsWiredMacAuth still works");
is(pf::Switch::HP::Procurve_2920->new->supportsWiredDot1x, 1, "pf::Switch::HP::Procurve_2920 supportsWiredDot1x still works");
is(pf::Switch::HP::Procurve_5400->new->supportsRadiusVoip, 1, "pf::Switch::HP::Procurve_5400 supportsRadiusVoip still works");
is(pf::Switch::HP::Procurve_5400->new->supportsWiredMacAuth, 1, "pf::Switch::HP::Procurve_5400 supportsWiredMacAuth still works");
is(pf::Switch::HP::Procurve_5400->new->supportsWiredDot1x, 1, "pf::Switch::HP::Procurve_5400 supportsWiredDot1x still works");
is(pf::Switch::Hostapd->new->supportsWirelessMacAuth, 1, "pf::Switch::Hostapd supportsWirelessMacAuth still works");
is(pf::Switch::Hostapd->new->supportsWirelessDot1x, 1, "pf::Switch::Hostapd supportsWirelessDot1x still works");
is(pf::Switch::Huawei->new->supportsWirelessMacAuth, 1, "pf::Switch::Huawei supportsWirelessMacAuth still works");
is(pf::Switch::Huawei->new->supportsWirelessDot1x, 1, "pf::Switch::Huawei supportsWirelessDot1x still works");
is(pf::Switch::Huawei::S5710->new->supportsWiredDot1x, 1, "pf::Switch::Huawei::S5710 supportsWiredDot1x still works");
is(pf::Switch::Huawei::S5710->new->supportsWiredMacAuth, 1, "pf::Switch::Huawei::S5710 supportsWiredMacAuth still works");
is(pf::Switch::IBM::IBM_RackSwitch_G8052->new->supportsRadiusDynamicVlanAssignment, 1, "pf::Switch::IBM::IBM_RackSwitch_G8052 supportsRadiusDynamicVlanAssignment still works");
is(pf::Switch::IBM::IBM_RackSwitch_G8052->new->supportsWiredDot1x, 1, "pf::Switch::IBM::IBM_RackSwitch_G8052 supportsWiredDot1x still works");
is(pf::Switch::Juniper->new->supportsWiredMacAuth, 1, "pf::Switch::Juniper supportsWiredMacAuth still works");
is(pf::Switch::Juniper->new->supportsWiredDot1x, 0, "pf::Switch::Juniper supportsWiredDot1x still works");
is(pf::Switch::Juniper->new->supportsSnmpTraps, 0, "pf::Switch::Juniper supportsSnmpTraps still works");
is(pf::Switch::Juniper::EX2200->new->supportsFloatingDevice, 1, "pf::Switch::Juniper::EX2200 supportsFloatingDevice still works");
is(pf::Switch::Juniper::EX2200->new->supportsRadiusVoip, 1, "pf::Switch::Juniper::EX2200 supportsRadiusVoip still works");
is(pf::Switch::Juniper::EX2200->new->supportsMABFloatingDevices, 1, "pf::Switch::Juniper::EX2200 supportsMABFloatingDevices still works");
is(pf::Switch::Juniper::EX2200->new->supportsWiredMacAuth, 1, "pf::Switch::Juniper::EX2200 supportsWiredMacAuth still works");
is(pf::Switch::Juniper::EX2200->new->supportsWiredDot1x, 1, "pf::Switch::Juniper::EX2200 supportsWiredDot1x still works");
is(pf::Switch::LG->new->supportsWiredDot1x, 1, "pf::Switch::LG supportsWiredDot1x still works");
is(pf::Switch::LG->new->supportsWiredMacAuth, 1, "pf::Switch::LG supportsWiredMacAuth still works");
is(pf::Switch::LG->new->supportsSnmpTraps, 1, "pf::Switch::LG supportsSnmpTraps still works");
is(pf::Switch::Meraki::MR->new->supportsWebFormRegistration, 1, "pf::Switch::Meraki::MR supportsWebFormRegistration still works");
is(pf::Switch::Meraki::MR->new->supportsWirelessMacAuth, 1, "pf::Switch::Meraki::MR supportsWirelessMacAuth still works");
is(pf::Switch::Meraki::MR->new->supportsExternalPortal, 1, "pf::Switch::Meraki::MR supportsExternalPortal still works");
is(pf::Switch::Meraki::MS220_8->new->supportsRadiusVoip, 1, "pf::Switch::Meraki::MS220_8 supportsRadiusVoip still works");
is(pf::Switch::Meraki::MS220_8->new->supportsWiredMacAuth, 1, "pf::Switch::Meraki::MS220_8 supportsWiredMacAuth still works");
is(pf::Switch::Meraki::MS220_8->new->supportsWiredDot1x, 1, "pf::Switch::Meraki::MS220_8 supportsWiredDot1x still works");
is(pf::Switch::Meru->new->supportsWirelessMacAuth, 1, "pf::Switch::Meru supportsWirelessMacAuth still works");
is(pf::Switch::Meru->new->supportsWirelessDot1x, 1, "pf::Switch::Meru supportsWirelessDot1x still works");
is(pf::Switch::Meru->new->supportsRoleBasedEnforcement, 1, "pf::Switch::Meru supportsRoleBasedEnforcement still works");
is(pf::Switch::Mikrotik->new->supportsWirelessMacAuth, 1, "pf::Switch::Mikrotik supportsWirelessMacAuth still works");
is(pf::Switch::Mikrotik->new->supportsExternalPortal, 1, "pf::Switch::Mikrotik supportsExternalPortal still works");
is(pf::Switch::Mikrotik->new->supportsWebFormRegistration, 1, "pf::Switch::Mikrotik supportsWebFormRegistration still works");
is(pf::Switch::MockedSwitch->new->supportsWebFormRegistration, 1, "pf::Switch::MockedSwitch supportsWebFormRegistration still works");
is(pf::Switch::MockedSwitch->new->supportsFloatingDevice, 1, "pf::Switch::MockedSwitch supportsFloatingDevice still works");
is(pf::Switch::MockedSwitch->new->supportsRoamingAccounting, 0, "pf::Switch::MockedSwitch supportsRoamingAccounting still works");
is(pf::Switch::MockedSwitch->new->supportsExternalPortal, 1, "pf::Switch::MockedSwitch supportsExternalPortal still works");
is(pf::Switch::MockedSwitch->new->supportsLldp, 0, "pf::Switch::MockedSwitch supportsLldp still works");
is(pf::Switch::MockedSwitch->new->supportsMABFloatingDevices, 1, "pf::Switch::MockedSwitch supportsMABFloatingDevices still works");
is(pf::Switch::MockedSwitch->new->supportsWiredMacAuth, 1, "pf::Switch::MockedSwitch supportsWiredMacAuth still works");
is(pf::Switch::MockedSwitch->new->supportsWiredDot1x, 1, "pf::Switch::MockedSwitch supportsWiredDot1x still works");
is(pf::Switch::MockedSwitch->new->supportsCdp, 1, "pf::Switch::MockedSwitch supportsCdp still works");
is(pf::Switch::MockedSwitch->new->supportsRadiusDynamicVlanAssignment, 1, "pf::Switch::MockedSwitch supportsRadiusDynamicVlanAssignment still works");
is(pf::Switch::MockedSwitch->new->supportsRadiusVoip, 1, "pf::Switch::MockedSwitch supportsRadiusVoip still works");
is(pf::Switch::MockedSwitch->new->supportsSaveConfig, 0, "pf::Switch::MockedSwitch supportsSaveConfig still works");
is(pf::Switch::MockedSwitch->new->supportsAccessListBasedEnforcement, 1, "pf::Switch::MockedSwitch supportsAccessListBasedEnforcement still works");
is(pf::Switch::Mojo->new->supportsWebFormRegistration, 1, "pf::Switch::Mojo supportsWebFormRegistration still works");
is(pf::Switch::Mojo->new->supportsExternalPortal, 1, "pf::Switch::Mojo supportsExternalPortal still works");
is(pf::Switch::Mojo->new->supportsWirelessDot1x, 1, "pf::Switch::Mojo supportsWirelessDot1x still works");
is(pf::Switch::Motorola->new->supportsWirelessMacAuth, 1, "pf::Switch::Motorola supportsWirelessMacAuth still works");
is(pf::Switch::Motorola->new->supportsWirelessDot1x, 1, "pf::Switch::Motorola supportsWirelessDot1x still works");
is(pf::Switch::Motorola->new->supportsRoleBasedEnforcement, 1, "pf::Switch::Motorola supportsRoleBasedEnforcement still works");
is(pf::Switch::Netgear::MSeries->new->supportsRadiusDynamicVlanAssignment, 1, "pf::Switch::Netgear::MSeries supportsRadiusDynamicVlanAssignment still works");
is(pf::Switch::Netgear::MSeries->new->supportsWiredMacAuth, 1, "pf::Switch::Netgear::MSeries supportsWiredMacAuth still works");
is(pf::Switch::Nortel->new->supportsFloatingDevice, 1, "pf::Switch::Nortel supportsFloatingDevice still works");
is(pf::Switch::Nortel->new->supportsLldp, 1, "pf::Switch::Nortel supportsLldp still works");
is(pf::Switch::Nortel::BPS2000->new->supportsLldp, 0, "pf::Switch::Nortel::BPS2000 supportsLldp still works");
is(pf::Switch::Nortel::ERS4000->new->supportsRadiusVoip, 1, "pf::Switch::Nortel::ERS4000 supportsRadiusVoip still works");
is(pf::Switch::Nortel::ERS4000->new->supportsWiredMacAuth, 1, "pf::Switch::Nortel::ERS4000 supportsWiredMacAuth still works");
is(pf::Switch::Pica8->new->supportsRadiusDynamicVlanAssignment, 1, "pf::Switch::Pica8 supportsRadiusDynamicVlanAssignment still works");
is(pf::Switch::Pica8->new->supportsExternalPortal, 1, "pf::Switch::Pica8 supportsExternalPortal still works");
is(pf::Switch::Pica8->new->supportsWiredMacAuth, 1, "pf::Switch::Pica8 supportsWiredMacAuth still works");
is(pf::Switch::Pica8->new->supportsWiredDot1x, 1, "pf::Switch::Pica8 supportsWiredDot1x still works");
is(pf::Switch::Ruckus->new->supportsWebFormRegistration, 0, "pf::Switch::Ruckus supportsWebFormRegistration still works");
is(pf::Switch::Ruckus->new->supportsWirelessMacAuth, 1, "pf::Switch::Ruckus supportsWirelessMacAuth still works");
is(pf::Switch::Ruckus->new->supportsExternalPortal, 1, "pf::Switch::Ruckus supportsExternalPortal still works");
is(pf::Switch::Ruckus->new->supportsWirelessDot1x, 1, "pf::Switch::Ruckus supportsWirelessDot1x still works");
is(pf::Switch::Ruckus->new->supportsRoleBasedEnforcement, 1, "pf::Switch::Ruckus supportsRoleBasedEnforcement still works");
is(pf::Switch::Ruckus::SmartZone->new->supportsWebFormRegistration, 0, "pf::Switch::Ruckus::SmartZone supportsWebFormRegistration still works");
is(pf::Switch::Ruckus::SmartZone->new->supportsWirelessMacAuth, 1, "pf::Switch::Ruckus::SmartZone supportsWirelessMacAuth still works");
is(pf::Switch::ThreeCom::SS4500->new->supportsWiredMacAuth, 1, "pf::Switch::ThreeCom::SS4500 supportsWiredMacAuth still works");
is(pf::Switch::ThreeCom::SS4500->new->supportsRadiusVoip, 1, "pf::Switch::ThreeCom::SS4500 supportsRadiusVoip still works");
is(pf::Switch::ThreeCom::SS4500->new->supportsLldp, 1, "pf::Switch::ThreeCom::SS4500 supportsLldp still works");
is(pf::Switch::ThreeCom::Switch_4200G->new->supportsLldp, 1, "pf::Switch::ThreeCom::Switch_4200G supportsLldp still works");
is(pf::Switch::ThreeCom::Switch_4200G->new->supportsWiredDot1x, 1, "pf::Switch::ThreeCom::Switch_4200G supportsWiredDot1x still works");
is(pf::Switch::ThreeCom::Switch_4200G->new->supportsWiredMacAuth, 1, "pf::Switch::ThreeCom::Switch_4200G supportsWiredMacAuth still works");
is(pf::Switch::ThreeCom::Switch_4200G->new->supportsRadiusVoip, 1, "pf::Switch::ThreeCom::Switch_4200G supportsRadiusVoip still works");
is(pf::Switch::Trapeze->new->supportsWirelessMacAuth, 1, "pf::Switch::Trapeze supportsWirelessMacAuth still works");
is(pf::Switch::Trapeze->new->supportsWirelessDot1x, 1, "pf::Switch::Trapeze supportsWirelessDot1x still works");
is(pf::Switch::Ubiquiti::EdgeSwitch->new->supportsRadiusVoip, 1, "pf::Switch::Ubiquiti::EdgeSwitch supportsRadiusVoip still works");
is(pf::Switch::Ubiquiti::EdgeSwitch->new->supportsWiredDot1x, 1, "pf::Switch::Ubiquiti::EdgeSwitch supportsWiredDot1x still works");
is(pf::Switch::Ubiquiti::EdgeSwitch->new->supportsRadiusDynamicVlanAssignment, 1, "pf::Switch::Ubiquiti::EdgeSwitch supportsRadiusDynamicVlanAssignment still works");
is(pf::Switch::Ubiquiti::EdgeSwitch->new->supportsWiredMacAuth, 1, "pf::Switch::Ubiquiti::EdgeSwitch supportsWiredMacAuth still works");
is(pf::Switch::Ubiquiti::EdgeSwitch->new->supportsLldp, 1, "pf::Switch::Ubiquiti::EdgeSwitch supportsLldp still works");
is(pf::Switch::Ubiquiti::Unifi->new->supportsWirelessMacAuth, 1, "pf::Switch::Ubiquiti::Unifi supportsWirelessMacAuth still works");
is(pf::Switch::Ubiquiti::Unifi->new->supportsExternalPortal, 1, "pf::Switch::Ubiquiti::Unifi supportsExternalPortal still works");
is(pf::Switch::Ubiquiti::Unifi->new->supportsWirelessDot1x, 1, "pf::Switch::Ubiquiti::Unifi supportsWirelessDot1x still works");
is(pf::Switch::WirelessModuleTemplate->new->supportsWirelessMacAuth, 1, "pf::Switch::WirelessModuleTemplate supportsWirelessMacAuth still works");
is(pf::Switch::WirelessModuleTemplate->new->supportsWirelessDot1x, 1, "pf::Switch::WirelessModuleTemplate supportsWirelessDot1x still works");
is(pf::Switch::Xirrus->new->supportsWirelessMacAuth, 1, "pf::Switch::Xirrus supportsWirelessMacAuth still works");
is(pf::Switch::Xirrus->new->supportsExternalPortal, 1, "pf::Switch::Xirrus supportsExternalPortal still works");
is(pf::Switch::Xirrus->new->supportsWebFormRegistration, 1, "pf::Switch::Xirrus supportsWebFormRegistration still works");
is(pf::Switch::Xirrus->new->supportsRoleBasedEnforcement, 1, "pf::Switch::Xirrus supportsRoleBasedEnforcement still works");
is(pf::Switch::Xirrus->new->supportsWirelessDot1x, 1, "pf::Switch::Xirrus supportsWirelessDot1x still works");


done_testing();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
