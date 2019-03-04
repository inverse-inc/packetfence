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
use pf::util::networking qw(syswrite_all sysread_all read_data_with_length);
use pfconfig::constants;
use pfconfig::undef_element;
use pf::log;
use pfconfig::constants;
use IO::Socket::UNIX;
use Sereal::Decoder;
use Readonly;

our @EXPORT_OK = qw(
    is_type_inline
    $undef_element
    normalize_namespace_query
);

Readonly our $undef_element => pfconfig::undef_element->new;

sub fetch_socket {
    use bytes;
    my ($socket, $payload) = @_;

    # The line below will log any request to pfconfig for debugging purposes
    # As the logging cost even in trace is high, it's commented out
    #get_logger->info("Doing request to pfconfig with payload : '$payload'");

    # we ask the cachemaster for our namespaced key
    $payload .= "\n";
    my $bytes_sent = syswrite_all($socket,$payload);
    read_data_with_length($socket,my $sereal_buffer);
    ## Match all bytes to always untaint
    $sereal_buffer =~ /\A^(.*)\z/ms;
    return $1;
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

=head2 normalize_namespace_query

Method that normalizes a namespace query

=cut

sub normalize_namespace_query {
    my ($ns) = @_;
    
    # Normalize all namespaces to end with parentheses without arguments if its not already overlayed
    # Can't use is_overlayed_namespace since it requires args to be between the parentheses
    if($ns !~ /\)$/) {
        $ns .= "()";
    }
    
    return $ns;
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

