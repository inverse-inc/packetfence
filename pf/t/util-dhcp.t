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

use Test::More;
use Test::NoWarnings;

=head1 Tests

=cut
BEGIN { use_ok('pf::util::dhcp', qw(decompose_dhcp)); }

=item Packet Analysis

The raw packets differ in that one contains the VLAN layer and the other does not.

They are raw Net::Pcap output unpacked to hex for easier string storage.

=cut
# TODO add one relayed packet (through udp helpers)
my %packets = ( 
    'centos5 dhcp discover' => 'fffffffffffff04da2cbd9c5080045100148000000008011399600000000ffffffff0044004301344246010106000ea2614a0000000000000000000000000000000000000000f04da2cbd9c500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000638253633501013204c0a8c8640c0d54657374696e674c6170746f703711011c02030f06770c2c2f1a792a79f9fc2aff00000000000000000000000000000000',
    'centos6 dhcp discover' => 'fffffffffffff04da2cbd9c5810000c8080045100148000000008011399600000000ffffffff004400430134e87b01010600336a9442000a000000000000000000000000000000000000f04da2cbd9c500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000638253633501013204c0a8c8640c0d54657374696e674c6170746f703711011c02030f06770c2c2f1a792a79f9fc2aff00000000000000000000000000000000'
);

plan tests => scalar(keys %packets) * 6 + 1;

foreach my $packet (keys %packets) {
    my ($l2, $l3, $l4, $dhcp) = decompose_dhcp(pack('H*', $packets{$packet}));

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
        [ $dhcp->{'chaddr'}, ],
        [ 'f04da2cbd9c500000000000000000000' ],
        "$packet: Layer 7 properly parsed" 
    );

    is_deeply(
        $dhcp->{'options'},
        { 
          '50' => [ 192, 168, 200, 100 ],
          '53' => [ 1 ],
          '12' => [ 'T', 'e', 's', 't', 'i', 'n', 'g', 'L', 'a', 'p', 't', 'o', 'p' ],
          '55' => [ 1, 28, 2, 3, 15, 6, 119, 12, 44, 47, 26, 121, 42, 121, 249, 252, 42 ]
        },
        "$packet: DHCP Options properly parsed" 
    );

    #use Data::Dumper;
    #print Dumper(\$l2, \$l3, \$l4, \$dhcp);
}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2011 Inverse inc.

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

