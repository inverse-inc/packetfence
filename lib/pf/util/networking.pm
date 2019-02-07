package pf::util::networking;
=head1 NAME

pf::util::networking

=cut

=head1 DESCRIPTION

pf::util::networking

=cut

use strict;
use warnings;
use Errno qw(EINTR EAGAIN);
use Socket qw(SOL_SOCKET SO_RCVTIMEO SO_SNDTIMEO);
use Exporter qw(import);

our @EXPORT_OK = qw(syswrite_all sysread_all send_data_with_length read_data_with_length set_write_timeout set_read_timeout);

=head2 syswrite_all

A wrapper around syswrite to ensure all bytes are written to a socket

=cut

sub syswrite_all {
    my ($socket,$buffer) = @_;
    my $bytes_to_send = length $buffer;
    my $offset = 0;
    my $total_written = 0;
    while ($bytes_to_send) {
        my $bytes_sent = syswrite($socket, $buffer, $bytes_to_send, $offset);
        unless (defined $bytes_sent) {
            next if $! == EINTR;
            last;
        }
        return $offset unless $bytes_sent;
        $offset += $bytes_sent;
        $bytes_to_send -= $bytes_sent;
    }
    return $offset;
}

=head2 sysread_all

A wrapper around sysread to ensure all bytes are read from a socket

=cut


sub sysread_all {
    my $socket = $_[0];
    our $buf;
    local *buf = \$_[1];    # alias
    my $bytes_to_read = $_[2];
    my $offset = 0;
    $buf = '';
    while($bytes_to_read) {
        my $bytes_read = sysread($socket,$buf,$bytes_to_read,$offset);
        unless (defined $bytes_read) {
            next if $! == EINTR;
            last;
        }
        return $offset unless $bytes_read;
        $bytes_to_read -= $bytes_read;
        $offset += $bytes_read;
    }
    return $offset;
}

=head2 send_data_with_length

=cut

sub send_data_with_length {
    my ($socket,$data) = @_;
    #Packing data with 32 bit little endian int as it length
    my $packed_data = pack("V/a*",$data);
    my $bytes_to_send = length $packed_data;
    my $bytes_sent = syswrite_all($socket, $packed_data);
    if(defined $bytes_sent && $bytes_sent > 4) {
        #substracting the four bytes appended to the begining
        $bytes_sent -= 4;
    }
    return $bytes_sent;
}

=head2 read_data_with_length

=cut

sub read_data_with_length {
    my $socket = $_[0];
    sysread_all($socket,my $length_buf, 4);
    my $length = unpack("V",$length_buf);
    return sysread_all($socket, $_[1], $length);
}

=head2 set_read_timeout

set read timeout for a socket

=cut

sub set_read_timeout {
    my ($socket, $timeout) = @_;
    return set_socket_timeout($socket, SO_RCVTIMEO, $timeout);
}

=head2 set_write_timeout

set write timeout for a socket

=cut

sub set_write_timeout {
    my ($socket, $timeout) = @_;
    return set_socket_timeout($socket, SO_SNDTIMEO, $timeout);
}

=head2 set_socket_timeout

set a timeout for a socket

=cut

sub set_socket_timeout {
    my ($socket, $type, $timeout) = @_;
    my $seconds  = int($timeout);
    my $useconds = int( 1_000_000 * ( $timeout - $seconds ) );
    $timeout  = pack( 'l!l!', $seconds, $useconds );
    $socket->setsockopt( SOL_SOCKET, $type, $timeout )
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

1;

