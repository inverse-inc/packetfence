#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use Test::More tests => 37;
use lib '/usr/local/pf/lib';

BEGIN {
    use FilePaths;
    use_ok('pf::SwitchFactory');
}

my $switchFactory = pf::SwitchFactory->getInstance;

my $switch;
$switch = $switchFactory->instantiate('192.168.0.1');
isa_ok( $switch, 'pf::SNMP::Cisco::Catalyst_2900XL' );
is( $switch->{_id}, '192.168.0.1', 'The id of the switch 192.168.0.1' );
is( $switch->{_ip}, '192.168.0.1', 'IP Address of 192.168.0.1 old name' );
is( $switch->{_switchIp}, '192.168.0.1', 'IP Address of 192.168.0.1 new name' );
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
$switch = $switchFactory->instantiate('default');
isa_ok($switch, 'pf::SNMP');


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

