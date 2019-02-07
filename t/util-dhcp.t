#!/usr/bin/perl
=head1 NAME

util-dhcp.t

=head1 DESCRIPTION

pf::util::dhcp module tests

=cut

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More;
use Test::NoWarnings;

=head1 Tests

=cut

=head2 Packet Analysis

The raw packets differ in that one contains the VLAN layer and the other does not.

They are raw Net::Pcap output unpacked to hex for easier string storage.

=cut

# TODO add one relayed packet (through udp helpers)
my %discover_packets = ( 
    'centos5 dhcp discover' => 'fffffffffffff04da2cbd9c5080045100148000000008011399600000000ffffffff0044004301344246010106000ea2614a0000000000000000000000000000000000000000f04da2cbd9c500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000638253633501013204c0a8c8640c0d54657374696e674c6170746f703711011c02030f06770c2c2f1a792a79f9fc2aff00000000000000000000000000000000',
    'centos6 dhcp discover' => 'fffffffffffff04da2cbd9c5810000c8080045100148000000008011399600000000ffffffff004400430134e87b01010600336a9442000a000000000000000000000000000000000000f04da2cbd9c500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000638253633501013204c0a8c8640c0d54657374696e674c6170746f703711011c02030f06770c2c2f1a792a79f9fc2aff00000000000000000000000000000000',
);

my %request_packets = ( 
    'centos6 dhcp request' => 'ffffffffffff90e6ba70e74b08004500014816c10000801122e500000000ffffffff004400430134339201010600d11b0641000000000000000000000000000000000000000090e6ba70e74b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000638253633501033d070190e6ba70e74b3204ac1596640c0d696e76657273652d65656570633c084d53465420352e30370c010f03062c2e2f1f2179f92bff0000',
);

my %ack_packets = ( 
    'centos6 dhcp ack' => '90e6ba70e74bdeadbeef0150080045100148000000008011b504ac159601ac159664004300440134e23f02010600d11b06410000000000000000ac159664000000000000000090e6ba70e74b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000638253633501053604ac1596013304000151800104ffffff000f12696e6c696e652e644d6163426f6f6b50726f0304ac159601060404020202ff000000000000',
);

# On old perl's (RHEL5) Test::More doesn't support "done testing" or starting testing before creating the plan :(
plan tests => 
    scalar(keys %discover_packets) * 6
    + scalar(keys %request_packets) * 2
    + scalar(keys %ack_packets) * 3
    + 2 # no warnings, use_ok pf::util::dhcp
;

use_ok('pf::util::dhcp', qw(decompose_dhcp));

foreach my $packet (keys %discover_packets) {
    my ($l2, $l3, $l4, $dhcp) = decompose_dhcp(pack('H*', $discover_packets{$packet}));

    is_deeply(
        [ $l2->{'src_mac'}, $l2->{'dest_mac'} ],
        [ "f04da2cbd9c5", "ffffffffffff" ],
        "$packet: Layer 2 properly parsed" 
    );

    is_deeply(
        [ $l3->{'src_ip'}, $l3->{'dest_ip'} ],
        [ "0.0.0.0", "255.255.255.255" ],
        "$packet: Layer 3 properly parsed" 
    );

    is_deeply(
        [ $l3->{'src_ip'}, $l3->{'dest_ip'} ],
        [ "0.0.0.0", "255.255.255.255" ],
        "$packet: Layer 3 properly parsed" 
    );

    is_deeply(
        [ $l4->{'src_port'}, $l4->{'dest_port'} ],
        [ 68, 67 ],
        "$packet: Layer 4 properly parsed" 
    );

    is_deeply(
        [ $dhcp->{'chaddr'}, $dhcp->{'yiaddr'} ],
        [ 'f04da2cbd9c500000000000000000000', '0.0.0.0' ],
        "$packet: DHCP properly parsed" 
    );

    is_deeply(
        $dhcp->{'options'},
        { 
          '50' => '192.168.200.100',
          '53' => 1,
          '12' => 'TestingLaptop',
          '55' => '1,28,2,3,15,6,119,12,44,47,26,121,42,121,249,252,42',
        },
        "$packet: DHCP options properly parsed" 
    );

    #use Data::Dumper;
    #print Dumper(\$l2, \$l3, \$l4, \$dhcp);
}

foreach my $packet (keys %request_packets) {
    my ($l2, $l3, $l4, $dhcp) = decompose_dhcp(pack('H*', $request_packets{$packet}));

    is($dhcp->{'options'}{'53'}, 3, "$packet: Parse option 53 (DHCP Message Type)");
    is($dhcp->{'options'}{'50'}, '172.21.150.100', "$packet: Parse option 50 (Requested IP Address)");
}

foreach my $packet (keys %ack_packets) {
    my ($l2, $l3, $l4, $dhcp) = decompose_dhcp(pack('H*', $ack_packets{$packet}));

    is($dhcp->{'options'}{'53'}, 5, "$packet: Parse option 53 (DHCP Message Type)");
    is($dhcp->{'options'}{'51'}, 24*60*60, "$packet: Parse option 51 (IP Address Lease Time)");
    is($dhcp->{'yiaddr'}, '172.21.150.100', "$packet: Parse yiaddr (Your IP Address)");
}

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

