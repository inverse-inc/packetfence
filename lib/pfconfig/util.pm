package pfconfig::util;

=head1 NAME

pfconfig::util

=cut

=head1 DESCRIPTION

pfconfig::util

Utilities function for pfconfig

=cut

use strict;
use warnings;
use base qw(Exporter);
use pf::constants::config qw(%NET_INLINE_TYPES);
use pfconfig::constants;
use pfconfig::undef_element;
use pfconfig::log;
use pfconfig::constants;
use IO::Socket::UNIX;
use Sereal::Decoder;
use Readonly;

our @EXPORT_OK = qw(
    is_type_inline
    $undef_element
);

Readonly our $undef_element => pfconfig::undef_element->new;

sub fetch_socket {
    use bytes;
    my ($socket, $payload) = @_;

    # The line below will log any request to pfconfig for debugging purposes
    # As the logging cost even in trace is high, it's commented out
    #pfconfig::log::get_logger->info("Doing request to pfconfig with payload : '$payload'");

    # we ask the cachemaster for our namespaced key
    print $socket "$payload\n";

    #Get the first for bytes to find out the length of the sereal buffer
    my $bytes_to_read = 4;
    my $buffer = '';
    my $offset = 0;
    while($bytes_to_read) {
        my $bytes_read = $socket->sysread($buffer,$bytes_to_read,$offset);
        $bytes_to_read -= $bytes_read;
        $offset += $bytes_read;
    }
    #Unpack it into an integer
    $bytes_to_read = unpack("V",$buffer);
    $offset = 0;
    $buffer = '';
    #Get the rest of the sereal buffer
    while($bytes_to_read) {
        my $bytes_read = $socket->sysread($buffer,$bytes_to_read,$offset);
        $bytes_to_read -= $bytes_read;
        $offset += $bytes_read;
    }
    return $buffer;
}

sub fetch_decode_socket {
    my ($payload) = @_;

    my $socket;
    my $socket_path = $pfconfig::constants::SOCKET_PATH;
    $socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => $socket_path,
    );

    my $decoder = Sereal::Decoder->new;
    my $response = fetch_socket($socket, $payload);
    return $decoder->decode($response);

}

sub parse_namespace {
    my ($namespace) = @_;
    my $args;
    my @args_list = ();
    if($namespace =~ /([(]{1}.*[)]{1})$/){
        $args = $1;

        my $quoted_args = quotemeta($args);
        $namespace =~ s/$quoted_args$//;

        $args =~ s/^[(]{1}//;
        $args =~ s/[)]{1}$//;
        @args_list = split(',', $args);
    }
    return ($namespace, @args_list);
}

=head2 control_file_path

Returns the control file path for a namespace

=cut

sub control_file_path {
    my ($namespace) = @_;
    return "$pfconfig::constants::CONTROL_FILE_DIR/" . $namespace . "-control";
}

=head2 is_type_inline

=cut

sub is_type_inline {
    my ($type) = @_;
    return exists $NET_INLINE_TYPES{$type};
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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

