#
# IPv6.pm
# NetPacket::IPv6
#
# Decode Internet Protocol v6 packet header.
#
# References:
# RFC2460 - IPv6 Specification
#
# Copyright (c) 2003-2009 Joel Knight <knight.joel@gmail.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
#
# $jwk: IPv6.pm,v 1.15 2009/03/01 19:12:03 jwk Exp $

package NetPacket::IPv6;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use NetPacket;

my $myclass;
BEGIN {
    $myclass = __PACKAGE__;
    $VERSION = "0.43.0";
}
sub Version () { "$myclass v$VERSION" }

BEGIN {
    @ISA = qw(Exporter NetPacket);

    @EXPORT = qw( );

    @EXPORT_OK = qw(
		ipv6_strip
		IP_PROTO_IPV6 IP_PROTO_ICMPV6
		IP_VERSION_IPv6 IPV6_VERSION
		IPV6_MAXPACKET
    );

    %EXPORT_TAGS = (
    ALL         => [@EXPORT, @EXPORT_OK],
    protos      => [qw(IP_PROTO_IPV6 IP_PROTO_ICMPV6)],
    versions    => [qw(IP_VERSION_IPv6 IPV6_VERSION)],
    strip       => [qw(ipv6_strip)],
);

}

# possible 'next-header' values
use constant IP_PROTO_IPV6   => 41;		# IPv6
use constant IP_PROTO_ICMPV6 => 58;		# ICMPv6

use constant IP_VERSION_IPv6 => 6;
use constant IPV6_VERSION => IP_VERSION_IPv6;

# size of the ipv6 header in bytes
use constant IPV6_HDRLEN => 40;

# maximum ipv6 packet size in bytes
use constant IPV6_MAXPACKET => 65535 + IPV6_HDRLEN;

# convert 4, 32-bit integers to a hex string with every two bytes
# separated by a colon
sub int_to_hexstr {
	my @int = @_;

	my @n;
	foreach my $i (0..3) {
		push @n, (($int[$i] & 0xffff0000) >> 16);
		push @n, ($int[$i] & 0x0000ffff);
	}

	return sprintf("%x:%x:%x:%x:%x:%x:%x:%x", @n[0..7]);
}

# convert a string of 8, 16-bit hex numbers to 4, 32-bit integers
sub hexstr_to_int {
	my @n = split m/:/, $_[0];

	my @int;
	foreach my $i (0,2,4,6) {
		my $h = hex $n[$i];
		my $l = hex $n[$i+1];
		my $int;
		$int = $l & 0x0000ffff;
		$int = $int | (($h << 16 ) & 0xffff0000);
		push @int, $int;
	}
	
	return @int;
}

# decode ipv6 header, return a NetPacket::IPv6 object
sub decode {
	my $class = shift;
	my ($pkt, $parent, @rest) = @_;
	my $self = {};

	# Class fields

	$self->{_parent} = $parent;
	$self->{_frame} = $pkt;

	# Decode packet

	if (defined $pkt) {
		my ($tmp, @src, @dst);
		
		($tmp, $self->{plen}, $self->{nxt}, $self->{hlim}, @src[0..3], 
			@dst[0..3], $self->{data}) = unpack('NncCNNNNNNNNa*', $pkt);

		$self->{ver} = ($tmp & 0xf0000000) >> 28;
		$self->{class} = ($tmp & 0x0ff00000) >> 20;
		$self->{flow} = ($tmp & 0x000fffff);

		$self->{src_ip} = int_to_hexstr(@src);
		$self->{dest_ip} = int_to_hexstr(@dst);
	}

	bless ($self, $class);
	return $self;
}

undef &ipv6_strip;           # Create alias
*ipv6_strip = \&strip;

# return the data portion of an ipv6 packet
sub strip {
	my ($pkt, @rest) = @_;

	my $ipv6_obj = NetPacket::IPv6->decode($pkt);
	return $ipv6_obj->{data};
}   

# reverse the decoding process and return the raw, encoded packet.
# take into account any member data that may have changed.
sub encode {
	my $class = shift;
	my $self = shift;

	$self->{plen} = length $self->{data};

	my $tmp;
	$tmp = $self->{flow} & 0x000fffff;
	$tmp = $tmp | (($self->{class} << 20) & 0x0ff00000);
	$tmp = $tmp | (($self->{ver} << 28) & 0xf0000000);

	my @src = hexstr_to_int($self->{src_ip});
	my @dst = hexstr_to_int($self->{dest_ip});

	my $packet = pack('NncCNNNNNNNNa*', $tmp, $self->{plen},
		$self->{nxt}, $self->{hlim}, @src[0..3], @dst[0..3],
		$self->{data});

	return($packet);
}

1;

__END__


=head1 NAME

C<NetPacket::IPv6> - Assembling and disassembling IPv6 (Internet
Protocol Version 6) packets.

=head1 SYNOPSIS

  use NetPacket::IPv6;

  $ip6_obj = NetPacket::IPv6->decode($raw_pkt);
  $ip6_pkt = NetPacket::IPv6->encode();
  $ip6_data = NetPacket::IPv6::strip($raw_pkt);

=head1 DESCRIPTION

C<NetPacket::IPv6> provides a set of routines for assembling and
disassembling IPv6 (Internet Protocol Version 6) packets.  

=head2 Methods

=over

=item C<NetPacket::IPv6-E<gt>decode([RAW PACKET])>

Decode the raw packet data given and return an object containing
instance data.  This method will quite happily decode garbage input. It
is the responsibility of the programmer to ensure valid packet data is
passed to this method.

=item C<NetPacket::IPv6-E<gt>encode()>

Return an IPv6 packet encoded with the instance data specified. This
will infer the packet length automatically from the payload length.

=back

=head2 Functions

=over

=item C<NetPacket::IPv6::strip([RAW PACKET])>

Return the encapsulated data (or payload) contained in the IPv6
packet.  This data is suitable to be used as input for other
C<NetPacket::*> modules.

This function is equivalent to creating an object using the
C<decode()> constructor and returning the C<data> field of that
object.

=back

=head2 Instance data

The instance data for the C<NetPacket::IPv6> object consists of
the following fields.

=over

=item ver

The IPv6 version number of this packet. This must always be 6.

=item class

The IPv6 traffic class.

=item flow

The IPv6 flow label.

=item plen

The payload length. This is the length of the payload (data); it does
not include the length of the packet header.

=item nxt

The next header. This field identifies the type of header that follows
the IPv6 header. It uses the same values as the IPv4 C<protocol> header.

=item hlim

The hop limit. Each router that handles the packet will decrement this
field by 1. Once the field reaches 0, the packet is discarded. Similar
to the C<TTL> field in the IPv4 header.

=item src_ip

The source IPv6 address. The address is expressed as a colon-separated
hex string. Leading zeros within the hex numbers are removed.

=item dest_ip

The destination IPv6 address. The address is expressed as a
colon-separated hex string. Leading zeros within the hex numbers are
removed.

=item data

The encapsulated data (payload).

=back

=head2 Exports

=over

=item default

none

=item exportable

Protocols:

  IP_PROTO_IPV6 IP_PROTO_ICMPV6 

IPv6 version number:

  IP_VERSION_IPv6 IPV6_VERSION

Maximum IPv6 packet size:

  IPV6_MAXPACKET 

Strip function:

  ipv6_strip

=item tags

The following tags can be used to export certain items:

=over

=item C<:protos>

IP_PROTO_IPV6 IP_PROTO_ICMPV6

=item C<:versions>

IP_VERSION_IPv6 IPV6_VERSION

=item C<:strip>

The function C<ipv6_strip>

=item C<:ALL>

All the above exportable items

=back

=back

=head1 EXAMPLE

The following prints the source and destination IPv6 address along 
with the value of the C<next header> field.

  #!/usr/bin/perl -w

  use strict;
  use Net::PcapUtils;
  use NetPacket::Ethernet qw(:strip);
  use NetPacket::IPv6;

  sub process_pkt {
      my ($user, $hdr, $pkt) = @_;

      my $ip6_obj = NetPacket::IPv6->decode(eth_strip($pkt));
      print("$ip6_obj->{src_ip} -> $ip6_obj->{dest_ip} ");
      print("$ip6_obj->{nxt}\n");
  }

  Net::PcapUtils::loop(\&process_pkt, FILTER => 'ip6');

=head1 TODO

Nothing at this time.

=head1 COPYRIGHT

Copyright (c) 2003, 2004 Joel Knight <knight.joel@gmail.com>

Permission to use, copy, modify, and distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

=head1 AUTHOR

Joel Knight E<lt>knight.joel@gmail.comE<gt>

=cut

