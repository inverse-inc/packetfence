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
use Readonly;

use pf::util qw(int2ip);

our @ascii_options = (
    15, # Domain Name (RFC2132)
    12, # Host Name (RFC2132)
    60, # Vendor class (RFC2132)
    66, # TFTP server name (RFC2132)
    67, # Bootfile name (RFC2132)
    81, # Client FQDN option (RFC4702)
    4, # Time Server (RFC2132)
);

Readonly my %MESSAGE_TYPE => (
    'DHCPDISCOVER' => 1,
    'DHCPOFFER' => 2,
    'DHCPREQUEST' => 3,
    'DHCPDECLINE' => 4,
    'DHCPACK' => 5,
    'DHCPNAK' => 6,
    'DHCPRELEASE' => 7,
    'DHCPINFORM' => 8,
);

Readonly my %MESSAGE_TYPE_TO_STRING => reverse %MESSAGE_TYPE;

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

    # the following parameters are converted into IP addresses
    foreach my $param ('ciaddr', 'yiaddr', 'siaddr', 'giaddr') {
        $dhcp_ref->{$param} = int2ip($dhcp_ref->{$param});
    }

    # grabbing the rest as one byte options in an array
    my @options = unpack( 'x236 C*', $udp_payload);
    decode_dhcp_options($dhcp_ref, @options);

    return $dhcp_ref;
}

=item decode_dhcp_options

Parses the Options portion of a DHCP packet and populate the hashref passed as a parameter.

We try to be as clever as possible regarding how data should be formatted and we convert it to appropriate types.

  decode_dhcp_options( hashref, @options )

=cut
sub decode_dhcp_options {
    my ($dhcp_ref, @options) = @_;

    # we are expecting DHCP's magic cookies (63:82:53:63) right before the options
    if ( !join( ":", splice( @options, 0, 4 ) ) =~ /^99:130:83:99$/ ) {
        die("Invalid magic DHCP Options received from $dhcp_ref->{chaddr}");
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

    # Validating mandatory option for DHCP
    # Option 53: DHCP Message Type (RFC2132)
    #    Value   Message Type
    #    -----   ------------
    #      1     DHCPDISCOVER
    #      2     DHCPOFFER
    #      3     DHCPREQUEST
    #      4     DHCPDECLINE
    #      5     DHCPACK
    #      6     DHCPNAK
    #      7     DHCPRELEASE
    #      8     DHCPINFORM
    if ( ! defined( $dhcp_ref->{'options'}->{53}[0] ) ) {
        die("Invalid DHCP Option 53 (Message Type) received from $dhcp_ref->{chaddr}");
    }

    # Here we format some well known DHCP options
    # -------------------------------------------

    # Option 12: Host Name (RFC2132)
    if ( exists( $dhcp_ref->{'options'}->{12} ) ) {
        $dhcp_ref->{'options'}->{12} = join( "", @{ $dhcp_ref->{'options'}->{'12'} } ); 
    }

    # Option 50: Requested IP Address (RFC2132)
    if ( exists( $dhcp_ref->{'options'}->{50} ) ) {
        $dhcp_ref->{'options'}->{50} = join ('.', @{ $dhcp_ref->{'options'}->{50} } );
    }

    # Option 51: IP Address Lease Time (RFC2132)
    if ( exists( $dhcp_ref->{'options'}->{51} ) ) {
        $dhcp_ref->{'options'}->{51} = unpack( "N", pack( "C4", @{ $dhcp_ref->{'options'}->{51} } ) );
    }

    # Option 55: Parameter Request List (RFC2132)
    if ( exists( $dhcp_ref->{'options'}->{55} ) ) {
        $dhcp_ref->{'options'}->{55} = join( ",", @{ $dhcp_ref->{'options'}->{'55'} } );
    }
}

sub dhcp_message_type_to_string {
    my ($id) = @_;

    return $MESSAGE_TYPE_TO_STRING{$id};
}

=back

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
