#!/usr/bin/perl
#
=head1 NAME

x -

=cut

=head1 DESCRIPTION

x

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use Net::Pcap qw(pcap_open_offline pcap_loop);
use NetPacket::Ethernet;
use NetPacket::IPv6;
use NetPacket::UDP;

my $filename = '/usr/local/pf/t/data/dhcpv6cap.pcapng';
my $err = '';

my $pcap = pcap_open_offline($filename, \$err)
    or die "Can't read '$filename': $err\n";

my $data;

my $value = pcap_loop($pcap, -1, \&process_packet, $data );

print "$value\n";
use DDP;

use constant SOLICIT             => 1;
use constant ADVERTISE           => 2;
use constant REQUEST             => 3;
use constant CONFIRM             => 4;
use constant RENEW               => 5;
use constant REBIND              => 6;
use constant REPLY               => 7;
use constant RELEASE             => 8;
use constant DECLINE             => 9;
use constant RECONFIGURE         => 10;
use constant INFORMATION_REQUEST => 11;
use constant RELAY_FORW          => 12;
use constant RELAY_REPL          => 13;

sub process_packet {
    my ($user_data, $header, $packet) = @_;
    my $eth_obj = NetPacket::Ethernet->decode($packet);
    my $ip_obj = NetPacket::IPv6->decode($eth_obj->{'data'}) or die "NetPacket::IP->decode";
    my $udp_obj = NetPacket::UDP->decode($ip_obj->{'data'}) or die "NetPacket::UDP->decode";
    my ($type, $tid,) = unpack("Ca3", $udp_obj->{data});
    print "$type\n";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

