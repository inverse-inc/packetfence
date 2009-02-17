#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 36;
use lib '/usr/local/pf/lib';

BEGIN { use_ok('pf::SwitchFactory') }

my $switchFactory
    = new pf::SwitchFactory( -configFile => './data/switches.conf' );

my $switch;
$switch = $switchFactory->instantiate('127.0.0.1');
isa_ok( $switch, 'pf::SNMP::PacketFence' );
is( $switch->{_ip}, '127.0.0.1', 'IP Address of 127.0.0.1' );
is_deeply( $switch->{_uplink}, [qw(dynamic)], 'Uplink of 127.0.0.1' );
is( $switch->{_SNMPVersion}, '2c', 'SNMP version of 127.0.0.1' );
is( $switch->{_SNMPCommunityTrap},
    'public', 'SNMP trap community of 127.0.0.1' );
is( $switch->{_SNMPVersionTrap}, '2c', 'SNMP trap version of 127.0.0.1' );

$switch = $switchFactory->instantiate('192.168.0.1');
isa_ok( $switch, 'pf::SNMP::Cisco::Catalyst_2900XL' );
is( $switch->{_ip}, '192.168.0.1', 'IP Address of 192.168.0.1' );
is_deeply( $switch->{_uplink}, [qw(23)], 'Uplink of 192.168.0.1' );
is( $switch->{_SNMPVersion}, '2c', 'SNMP version of 192.168.0.1' );
is( $switch->{_SNMPCommunityTrap},
    'trapCommunity', 'SNMP trap community of 192.168.0.1' );
is( $switch->{_SNMPVersionTrap}, '3', 'SNMP trap version of 192.168.0.1' );
is( $switch->{_SNMPUserNameTrap},
    'readUser', 'SNMP trap user of 192.168.0.1' );
is( $switch->{_SNMPAuthProtocolTrap},
    'MD5', 'SNMP trap auth proto of 192.168.0.1' );
is( $switch->{_SNMPAuthPasswordTrap},
    'authpwdread', 'SNMP trap auth pwd of 192.168.0.1' );
is( $switch->{_SNMPPrivProtocolTrap},
    'DES', 'SNMP trap priv proto of 192.168.0.1' );
is( $switch->{_SNMPPrivPasswordTrap},
    'privpwdread', 'SNMP trap priv pwd of 192.168.0.1' );
is( $switch->{_cliTransport}, 'ssh', 'cli transport of 192.168.0.1' );
is( $switch->{_SNMPCommunityRead},
    'readCommunity', 'read community of 192.168.0.1' );
is( $switch->{_SNMPCommunityWrite},
    'writeCommunity', 'write community of 192.168.0.1' );
is( $switch->{_cliUser},      'cliUser',   'cli user of 192.168.0.1' );
is( $switch->{_cliPwd},       'cliPwd',    'cli pwd of 192.168.0.1' );
is( $switch->{_cliEnablePwd}, 'cliEnable', 'cli enable pwd of 192.168.0.1' );
is( $switch->{_voiceVlan},    '10',        'voice VLAN of 192.168.0.1' );
is( $switch->{_SNMPEngineID},
    'SNMPEngineID', 'SNMP Engine ID of 192.168.0.1' );
is( $switch->{_SNMPUserNameRead},
    'userRead', 'SNMP read user of 192.168.0.1' );
is( $switch->{_SNMPAuthProtocolRead},
    'AutProtoRead', 'SNMP read auth proto of 192.168.0.1' );
is( $switch->{_SNMPAuthPasswordRead},
    'AuthPassRead', 'SNMP read auth pwd of 192.168.0.1' );
is( $switch->{_SNMPPrivProtocolRead},
    'PrivProtoRead', 'SNMP read priv proto of 192.168.0.1' );
is( $switch->{_SNMPPrivPasswordRead},
    'PrivPassRead', 'SNMP read priv pwd of 192.168.0.1' );
is( $switch->{_SNMPUserNameWrite},
    'UserWrite', 'SNMP write user of 192.168.0.1' );
is( $switch->{_SNMPAuthProtocolWrite},
    'authProtoWrite', 'SNMP write auth proto of 192.168.0.1' );
is( $switch->{_SNMPAuthPasswordWrite},
    'authPassWrite', 'SNMP write auth pwd of 192.168.0.1' );
is( $switch->{_SNMPPrivProtocolWrite},
    'privProtoWrite', 'SNMP write priv proto of 192.168.0.1' );
is( $switch->{_SNMPPrivPasswordWrite},
    'privPassWrite', 'SNMP write priv pwd of 192.168.0.1' );

