#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
use Test::More tests => 62;
use Test::NoWarnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
    use_ok('pf::SwitchFactory');
}



my $switch = pf::SwitchFactory->instantiate('192.168.0.1');

isa_ok( $switch, 'pf::Switch::Cisco::Catalyst_2900XL' );
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
is( $switch->{_SNMPCommunityRead},
    'readCommunity', 'read community of 192.168.0.1' );
is( $switch->{_SNMPCommunityWrite},
    'writeCommunity', 'write community of 192.168.0.1' );

# CLI parameter tests
is( $switch->{_cliTransport}, 'ssh', 'cli transport of 192.168.0.1' );
is( $switch->{_cliUser},      'cliUser',   'cli user of 192.168.0.1' );
is( $switch->{_cliPwd},       'cliPwd',    'cli pwd of 192.168.0.1' );
is( $switch->{_cliEnablePwd}, 'cliEnable', 'cli enable pwd of 192.168.0.1' );

# Web Services parameter tests
is( $switch->{_wsTransport}, 'https', 'web services transport of 192.168.0.1' );
is( $switch->{_wsUser},      'webservices_user',   'web services user of 192.168.0.1' );
is( $switch->{_wsPwd},       'webservices_pwd',    'web services pwd of 192.168.0.1' );

# RADIUS Secret parameter tests
is( $switch->{_radiusSecret}, 'bigsecret', 'RADIUS secret of 192.168.0.1' );

is( $switch->getVlanByName('voice'),    '10',        'voice VLAN of 192.168.0.1' );
is( $switch->{_SNMPEngineID},
    '0123456', 'SNMP Engine ID of 192.168.0.1' );
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

# switch of default type
$switch = pf::SwitchFactory->instantiate('default');
isa_ok($switch, 'pf::Switch');

#Test using mac address as an id
$switch = pf::SwitchFactory->instantiate('01:01:01:01:01:01');
isa_ok($switch, 'pf::Switch::Cisco::Catalyst_2960',"mac address style switch id");

#Test using mac address
$switch = pf::SwitchFactory->instantiate({ switch_mac => "01:01:01:01:01:02", switch_ip => "192.168.1.2", controllerIp => "1.1.1.1"});
isa_ok($switch, 'pf::Switch::Cisco::Catalyst_2960');
is($switch->{_id}, '01:01:01:01:01:02', "Proper id is set");
is($switch->{_ip}, '192.168.1.2',       "Proper ip address is set");
is($switch->{_controllerIp}, '1.1.1.1', "Proper controllerIp address is set");

$switch = pf::SwitchFactory->instantiate({ switch_mac => "01:01:01:01:01:03", switch_ip => "192.168.1.2", controllerIp => "1.1.1.1"});
isa_ok($switch, 'pf::Switch::Cisco::Catalyst_2960');
is($switch->{_controllerIp}, '1.2.3.4', "Do not override  controllerIp address if set");

$switch = pf::SwitchFactory->instantiate({ switch_mac => "ff:01:01:01:01:04", switch_ip => "192.168.0.1", controllerIp => "1.1.1.1"});
isa_ok( $switch, 'pf::Switch::Cisco::Catalyst_2900XL' );
is($switch->{_id}, '192.168.0.1', "Proper id is set for 192.168.0.1");

#Test using ip address in a range
$switch = pf::SwitchFactory->instantiate('172.16.3.1');
isa_ok($switch, 'pf::Switch::Cisco::Catalyst_3750G');
is("pf::Switch::Cisco::Catalyst_3750G",ref $switch, "Got the correct switch type");
is($switch->{_id}, '172.16.3.1', "Proper id is set for 172.16.3.1");

$switch = pf::SwitchFactory->instantiate('172.16.3.2');
isa_ok($switch, 'pf::Switch::Cisco::Catalyst_2960G');
is('pf::Switch::Cisco::Catalyst_2960G', ref $switch,"Got the proper switch type for 172.16.3.2");
is($switch->{_id}, '172.16.3.2', "Proper id is set for 172.16.3.2");

$switch = pf::SwitchFactory->instantiate('172.16.0.1');
isa_ok($switch, 'pf::Switch::Cisco::Catalyst_2960');
is("pf::Switch::Cisco::Catalyst_2960",ref $switch, "Got the correct switch type for 172.16.0.1");
is($switch->{_id}, '172.16.0.1', "Proper id is set for 172.16.0.1");

$switch = pf::SwitchFactory->instantiate({ switch_mac => "ff:01:01:01:01:04", switch_ip => "172.16.0.1"});
isa_ok($switch, 'pf::Switch::Cisco::Catalyst_2960');
is("pf::Switch::Cisco::Catalyst_2960",ref $switch, "Got the correct switch type for 172.16.0.1");
is($switch->{_id}, '172.16.0.1', "Proper id is set for 172.16.0.1");

$switch = pf::SwitchFactory->instantiate('192.168.190.217');
isa_ok($switch, 'pf::Switch::Cisco::Catalyst_2960');
is("pf::Switch::Cisco::Catalyst_2960",ref $switch, "Got the correct switch type for 192.168.190.217");
is($switch->{_id}, '192.168.190.217', "Proper id is set for 192.168.190.217");

$switch = pf::SwitchFactory->instantiate('172.16.8.25');
isa_ok($switch, 'pf::Switch::Template');
is(ref($switch->{_template}), 'HASH', "template args are passed");

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

