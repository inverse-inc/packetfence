package pf::util::dhcp;

=head1 NAME

pf::util::dhcp - DHCP related utilities

=cut

=head1 DESCRIPTION

DHCP related functions necessary to analyze DHCP traffic.

=cut
use strict;
use warnings;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw(decompose_dhcp decode_dhcp dhcp_message_type_to_string dhcp_summary);
    @EXPORT_OK = qw();
}

use NetPacket::Ethernet;
use NetPacket::IP;
use NetPacket::UDP;
use Readonly;

use pf::util qw(int2ip clean_mac);

our @ascii_options = (
    4, # Time Server (RFC2132)
    12, # Host Name (RFC2132)
    15, # Domain Name (RFC2132)
    56, # Message (RFC2132)
    60, # Vendor class (RFC2132)
    66, # TFTP server name (RFC2132)
    67, # Bootfile name (RFC2132)
    81, # Client FQDN option (RFC4702)
);

our @ipv4_options = (
    50, # Requested IP Address (RFC2132)
    54, # Server Identifier (RFC2132)
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
    if ( defined( $dhcp_ref->{'options'}->{53}[0] ) ) {
        $dhcp_ref->{'options'}->{53} = $dhcp_ref->{'options'}->{53}[0];
    } else {
        die("Invalid DHCP Option 53 (Message Type) received from $dhcp_ref->{chaddr}");
    }

    # Here we format some well known DHCP options
    # -------------------------------------------

    # pack in scalar strings ascii options
    foreach my $option (@ascii_options) {
        if ( exists( $dhcp_ref->{'options'}->{$option} ) ) {
            $dhcp_ref->{'options'}->{$option} = join( "", @{ $dhcp_ref->{'options'}->{$option} } ); 
        }
    } 

    # pack IPv4 in dotted notation
    foreach my $option (@ipv4_options) {
        if ( exists( $dhcp_ref->{'options'}->{$option} ) ) {
            $dhcp_ref->{'options'}->{$option} = join ('.', @{ $dhcp_ref->{'options'}->{$option} } );
        }
    }

    # Option 51: IP Address Lease Time (RFC2132)
    if ( exists( $dhcp_ref->{'options'}->{51} ) ) {
        $dhcp_ref->{'options'}->{51} = unpack( "N", pack( "C4", @{ $dhcp_ref->{'options'}->{51} } ) );
    }

    # Option 55: Parameter Request List (RFC2132)
    if ( exists( $dhcp_ref->{'options'}->{55} ) ) {
        $dhcp_ref->{'options'}->{55} = join( ",", @{ $dhcp_ref->{'options'}->{'55'} } );
    }

    # Option 82: Relay Agent Information (RFC3046)
    if ( exists( $dhcp_ref->{'options'}->{82} ) ) {
        _decode_dhcp_option82($dhcp_ref);
    }
}

sub dhcp_message_type_to_string {
    my ($id) = @_;

    return $MESSAGE_TYPE_TO_STRING{$id};
}

=item dhcp_summary

Returns a one-liner string representing most important information about DHCP Packet hashref passed.

=cut
sub dhcp_summary {
    my ($dhcp_ref) = @_;

    my $message_type = $dhcp_ref->{'options'}{'53'};
    my $summary = dhcp_message_type_to_string($message_type);

    if ( $message_type == $MESSAGE_TYPE{'DHCPACK'} ) {
        $summary .= " received for $dhcp_ref->{'ciaddr'} ($dhcp_ref->{'chaddr'})";

    } elsif ( $message_type == $MESSAGE_TYPE{'DHCPDISCOVER'} ) {
        $summary .= " from $dhcp_ref->{'chaddr'}";

    } elsif ( $message_type == $MESSAGE_TYPE{'DHCPREQUEST'} || $message_type == $MESSAGE_TYPE{'DHCPINFORM'} ) {
        $summary .= " from $dhcp_ref->{'ciaddr'} ($dhcp_ref->{'chaddr'})";
    }

    if ($dhcp_ref->{'giaddr'} !~ /^0\.0\.0\.0$/) {
        $summary .= ", relayed via $dhcp_ref->{'giaddr'}";
    }

    return $summary;
}

=item _decode_dhcp_option82

Parses Relay Agent Information (option 82) and add information understood to the dhcp hashref.
Relay Agent Information is defined in RFC3046.

On cisco, option 82 can be populated on the layer 3 switch when relaying by entering the following commands:

    conf t
    ip dhcp relay information option

=cut
sub _decode_dhcp_option82 {
    my ($dhcp_ref) = @_;

    my %sub_opt_82;
    my @option82 = @{$dhcp_ref->{'options'}{'82'}};
    while ( @option82 ) {
        my $subopt = shift( @option82 );
        my $len = shift( @option82 );

        while ($len) {
            my $val = shift( @option82 );
            push( @{ $sub_opt_82{$subopt} }, $val );
            $len--;
        }
    }

    # stripping option82 arrayref and pushing an hashref instead with raw = options 82 array ref
    $dhcp_ref->{'options'}{'82'} = { 
        '_raw' => $dhcp_ref->{'options'}{'82'},
        '_subopts' => \%sub_opt_82,
    };
    if ( defined( $sub_opt_82{'1'} ) ) {

        # TODO not sure this is the good stuff
        my ( $vlan, $module, $port ) = unpack('nCC', pack("C*", @{$sub_opt_82{'1'}}));
        $dhcp_ref->{'options'}{'82'}{'vlan'} = $vlan;
        $dhcp_ref->{'options'}{'82'}{'module'} = $module;
        $dhcp_ref->{'options'}{'82'}{'port'} = $port;
    }

    if ( defined( $sub_opt_82{'2'} ) ) {
        $dhcp_ref->{'options'}{'82'}{'switch'} = clean_mac( unpack("H*", pack("C*", @{$sub_opt_82{'2'}})) );
    }

}

=back

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

1;
