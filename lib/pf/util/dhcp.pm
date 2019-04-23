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
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(decompose_dhcp decode_dhcp dhcp_message_type_to_string dhcp_summary make_pcap_filter);
}

use NetPacket::Ethernet;
use NetPacket::IP;
use NetPacket::UDP;
use Readonly;

use pf::util qw(int2ip clean_mac);
use pf::option82 qw(get_switch_from_option82);

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
    my $option82 = $dhcp_ref->{'options'}{'82'};
    my %sub_opt_82;
    my @options = @$option82;
    while ( @options ) {
        my $subopt = shift( @options );
        my $len = shift( @options );
        while ($len) {
            my $val = shift( @options );
            push( @{ $sub_opt_82{$subopt} }, $val );
            $len--;
        }
    }
    my %new_option = (
        '_raw' => $option82,
        '_subopts' => \%sub_opt_82,
    );

    # stripping option82 arrayref and pushing an hashref instead with raw = options 82 array ref
    $dhcp_ref->{'options'}{'82'} = \%new_option;
    if ( defined( $sub_opt_82{'1'} ) ) {
        _decode_dhcp_option82_suboption1(\%new_option, $sub_opt_82{'1'});
    }

    if ( defined( $sub_opt_82{'2'} ) ) {
        _decode_dhcp_option82_suboption2(\%new_option, $sub_opt_82{'2'});
    }

}

=item _decode_dhcp_option82_suboption1

Decode the dhcp option82 sub option1

Reference http://mincebert.blogspot.ca/2013/09/dhcp-option-82-cisco-switches-and.html

=cut

#TODO move the responsibility of parsing this to the switch
#As this is cisco specific

sub _decode_dhcp_option82_suboption1 {
    my ($option, $sub_option) = @_;
    my ($type, $length, @chars) = @$sub_option;
    my $data = pack("C*", @chars);
    if ($type == 0) {
        @{$option}{qw(vlan module port)} = unpack("nCC", $data);
    }
    elsif ($type == 1) {
        $option->{circuit_id_string} = $data;
    }
    else {
	# Last resort fallback - use the whole option (if it only contains printable characters) as circuit id string
	my $s = pack("C*", @$sub_option);
	if ($s =~ /\p{XPosixPrint}/) {
	    $option->{circuit_id_string} = $s;
	}
    }
}

=item _decode_dhcp_option82_suboption2

Decode the dhcp option82 sub option2

Reference http://mincebert.blogspot.ca/2013/09/dhcp-option-82-cisco-switches-and.html

=cut

#TODO move the responsibility of parsing this to the switch
#As this is cisco specific

sub _decode_dhcp_option82_suboption2 {
    my ($option, $sub_option) = @_;
    my ($type, $length, @chars) = @$sub_option;
    my $data = pack("C*", @chars);
    if ($type == 0) {
        $option->{switch} = clean_mac(unpack("H*", $data));
        $option->{switch_id} =  get_switch_from_option82($option->{switch});
    }
    elsif ($type == 1) {
        $option->{host} = $data;
    }
    else {
	# Last resort fallback - use the whole option (if it only contains printable characters) as host
	my $s = pack("C*", @$sub_option);
	if ($s =~ /\p{XPosixPrint}/) {
	    $option->{host} = $s;
	}
    }
}

=item make_pcap_filter

create the pcap filter from the supported DHCP Messages Type

=cut

sub make_pcap_filter {
    my (@types) = @_;
    #listen to all if no types are provided
    return "udp and (port 67 or port 68 or port 546 or port 547 or port 767)" unless @types;
    for my $type (@types) {
       die "Unknown message type $type" unless exists $MESSAGE_TYPE{$type} && defined $MESSAGE_TYPE{$type};
    }
    my $type_filter = join(" or ",map { sprintf("(udp[250:1] = 0x%x)",$MESSAGE_TYPE{$_}) } @types);
    return "((port 67 or port 68 or port 767) and ( $type_filter )) or (port 546 or port 547)";
}

=back

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

1;
