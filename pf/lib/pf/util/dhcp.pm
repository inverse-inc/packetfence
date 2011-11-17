package pf::util::dhcp;

=head1 NAME

pf::util::dhcp - DHCP related utilities

=cut

=head1 DESCRIPTION

DHCP related functions necessary to analyze DHCP traffic.

=cut
use strict;
use warnings;
use lib qw(/usr/local/pf/lib);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw(decompose_dhcp decode_dhcp);
    @EXPORT_OK = qw();
}

use NetPacket::Ethernet;
use NetPacket::IP;
use NetPacket::UDP;

our @ascii_options = (
    15, # Domain Name (RFC2132)
    12, # Host Name (RFC2132)
    60, # Vendor class (RFC2132)
    66, # TFTP server name (RFC2132)
    67, # Bootfile name (RFC2132)
    81, # Client FQDN option (RFC4702)
    4, # Time Server (RFC2132)
);

=head1 SUBROUTINES

=over

=item decompose_dhcp

Parses a raw Ethernet frame and decompose it into layers and 
returns every layer as objects (l2, l3, l4) or hashref (dhcp).

=cut
sub decompose_dhcp {
    my ($raw_packet) = @_;

    my $l2 = NetPacket::Ethernet->decode($raw_packet);
    my $l3 = NetPacket::IP->decode($l2->{'data'});
    my $l4 = NetPacket::UDP->decode($l3->{'data'});
    my $dhcp = decode_dhcp($l4->{'data'});

    return ($l2, $l3, $l4, $dhcp);
}

=item decode_dhcp

Parses raw UDP packet and create an hashref with all the properties of DHCP.

We throw exceptions here on decoding failures.

=cut
# TODO consider migrating to Net::DHCP::Packet
sub decode_dhcp {
    my ($udp_payload) = @_;

    # DHCP data (order _is_ important)
    my @keys = (
        'op', 'htype', 'hlen', 'hops', 'xid', 'secs', 'dflags', 
        'ciaddr', 'yiaddr', 'siaddr', 'giaddr', 'chaddr', 'sname', 'file'
    );

    # assigning keys one by one to the result of unpack and returning the whole thing as an hashref
    my $dhcp_ref = { map { shift(@keys) => $_ } unpack( 'CCCCNnnNNNNH32A64A128', $udp_payload) };

    # grabbing the rest as one byte options in an array
    my @options = unpack( 'x236 C*', $udp_payload);

    # we are expecting DHCP's magic cookies (63:82:53:63) right before the options
    if ( !join( ":", splice( @options, 0, 4 ) ) =~ /^99:130:83:99$/ ) {
        die("Invalid DHCP Options received from $dhcp_ref->{chaddr}");
    }

    # populate DHCP options
    # ASCII-ify textual data and treat option 55 (parameter list) as an array
    while (@options) {
        my $code   = shift(@options);
        my $length = shift(@options);
        next if ( $code == 0 );
        while ($length) {
            my $val = shift(@options);
            if ( scalar grep({ $code eq $_ } @ascii_options) ) {

                if ( defined($val) && $val != 0 && $val != 1 ) {
                    $val = chr($val);
                } else {
                    $length--;
                    next;
                }

            }
            push( @{ $dhcp_ref->{'options'}->{$code} }, $val );
            $length--;
        }
    }

    return $dhcp_ref;
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

1;
