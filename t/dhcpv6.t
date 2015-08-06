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
use pf::util::dhcp;
use Net::Pcap qw(pcap_open_offline pcap_loop);
use bytes;

my $filename = '/usr/local/pf/t/data/dhcpv6cap.pcapng';
my $err      = '';

my $pcap = pcap_open_offline($filename, \$err)
  or die "Can't read '$filename': $err\n";

our $count;
my $data = \$count;

my $value = pcap_loop($pcap, -1, \&process_packet, $data);

sub process_packet {
    my ($user_data, $header, $packet) = @_;
    my ($eth_obj, $ip_obj, $udp_obj, $dhcp) = decompose_dhcpv6($packet);
    $$user_data++;
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

