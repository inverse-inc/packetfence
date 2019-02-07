#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 34;
use Test::NoWarnings;

use lib '/usr/local/pf/lib';

use File::Basename qw(basename);
Log::Log4perl->init("./log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );
BEGIN { use lib qw(/usr/local/pf/t); }
BEGIN { use setup_test_config; }

use pf::SwitchFactory;

BEGIN { use_ok('pf::Switch') }

# test the object
my $SNMP = new pf::Switch;
isa_ok($SNMP, 'pf::Switch');

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

# extractSsid
my $radius_request = { 'Called-Station-Id' => 'aa-bb-cc-dd-ee-ff:Secure SSID' };
is($SNMP->extractSsid($radius_request), 'Secure SSID',
    "Extract SSID from Called-Station-Id format xx-xx-xx-xx-xx-xx:SSID");

$radius_request = { 'Called-Station-Id' => 'aa:bb:cc:dd:ee:ff:Secure SSID' };
is($SNMP->extractSsid($radius_request), 'Secure SSID',
    "Extract SSID from Called-Station-Id format xx:xx:xx:xx:xx:xx:SSID");

$radius_request = { 'Called-Station-Id' => 'aabbccddeeff:Secure SSID' };
is($SNMP->extractSsid($radius_request), 'Secure SSID',
    "Extract SSID from Called-Station-Id format xxxxxxxxxxxx:SSID");

# Switch object tests
# BE CAREFUL: if you change the configuration files, tests will break!
# getting a switch instance (pf::Switch::PacketFence but still inherit most subs from pf::Switch)
my $switch = pf::SwitchFactory->instantiate('127.0.0.1');

# setVlanByName
ok(!defined($switch->setVlanByName(1001, 'inexistantVlan', {})),
    "call setVlanByName with a vlan that doesn't exist in switches.conf");

ok(defined($switch->setVlanByName(1001, 'customVlan1', {})),
    "call setVlanByName with a vlan that exists but with a non-numeric value");

ok(defined($switch->setVlanByName(1001, 'custom1Vlan', {})),
    "call setVlanByName with a vlan that exists but with a non-numeric value");

ok(!defined($switch->setVlanByName(1001, 'customVlan2', {})),
    "call setVlanByName with a vlan that exists but with an undef value");

# TODO: one day we should do a positive test for setVlanByName (mocking setVlan)

#
# Role parsing tests
#
$switch = pf::SwitchFactory->instantiate('10.0.0.6');
is($switch->getRoleByName('admin'), 'full-access', 'normal role lookup (not cached)');
is($switch->getRoleByName('guest'), 'restricted', 'normal role lookup (from cache)');
is($switch->getRoleByName('admin'), 'full-access', 'normal role lookup (from cache)');

$switch = pf::SwitchFactory->instantiate('10.0.0.7');
is($switch->getRoleByName('admin'), 'full-access', 'normal role lookup with undefined role (not cached)');
is($switch->getRoleByName('guest'), undef, 'expecting undef (from cache)');
is($switch->getRoleByName('admin'), 'full-access', 'normal role lookup with undefined role (from cache)');

$switch = pf::SwitchFactory->instantiate('10.0.0.8');
is($switch->getRoleByName('admin'), undef, 'category but no assignment expecting undef (not cached)');
is($switch->getRoleByName('admin'), undef, 'category but no assignment expecting undef (from cache)');

$switch = pf::SwitchFactory->instantiate('10.0.0.9');
is($switch->getRoleByName('admin'), undef, 'roles not configured expecting undef (not cached)');
is($switch->getRoleByName('admin'), undef, 'roles not configured expecting undef (from cache)');

# 0x0400 is 0000 0100 0000 0000
is($switch->getBitAtPosition("0x0400", 5), 1, 'getBitAtPosition returns correct bit set to 1');

# 0x04 is 0000 0100
is($switch->getBitAtPosition("0x04", 5), 1, 'getBitAtPosition returns correct bit set to 1');

# 0x40 is 0100 0000
is($switch->getBitAtPosition("0x40", 5), 0, 'getBitAtPosition returns correct bit set to 0');


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

