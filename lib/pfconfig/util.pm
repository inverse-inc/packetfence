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
use pf::Sereal qw(sereal_decode_safe);
use Readonly;
use JSON::MaybeXS qw(encode_json);
use pfconfig::config;
use pf::k8s;

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

=head2 max_connect_times

How many times a client tries to reach pfconfig, 0.1 second apart, before
giving up. Longer while a package upgrade is in progress.

=cut

sub max_connect_times {
    return (-f $pfconfig::constants::UPGRADE_IN_PROCESS_PATH)
      ? $pfconfig::constants::UPGRADE_IN_PROCESS_MAX_CONNECT_TIMES
      : $pfconfig::constants::MAX_CONNECT_TIMES;
}

sub _connect_socket {
    my ($config, %opts) = @_;
    my ($socket, $error);
    if ($config->get_proto() eq "tcp") {
        ($socket, $error) = connect_tcp(
            host => ($opts{tcp_host} // $config->section('general')->{tcp_host}),
            port => ($opts{tcp_port} // $config->section('general')->{tcp_port}),
            timeout => ($opts{tcp_timeout} // 5),
        );
    }
    else {
        $socket = IO::Socket::UNIX->new(
            Type => SOCK_STREAM,
            Peer => $pfconfig::constants::SOCKET_PATH,
        );
        $error = "$!";
    }
    die "cannot connect to the server: $error\n" unless $socket;
    return $socket;
}

=head2 fetch_decode_socket

Send a request to pfconfig and decode its reply.

A connection can be accepted and then closed without a reply, e.g. by the
proxy in front of a pfconfig that isn't accepting connections at that moment.

By default the request is sent once and an empty reply dies with a clear
message. A caller whose request can safely be sent more than once passes
C<< retry_empty_reply => 1 >>: the request is then sent again, 0.1 second
apart, up to C<max_times> times (default: max_connect_times, the same budget
pfconfig::cached uses for the configuration reads).

A failed connection dies right away in both cases.

=cut

sub fetch_decode_socket {
    my ($payload, %opts) = @_;

    my $config = $pfconfig::config::INI_CONFIG;
    my $max_times = $opts{retry_empty_reply} ? ($opts{max_times} // max_connect_times()) : 1;
    $max_times = 1 if $max_times < 1;
    my $logger = get_logger;

    for my $times (1 .. $max_times) {
        my $socket = _connect_socket($config, %opts);
        my $response = fetch_socket($socket, $payload);
        close($socket);
        if (defined($response) && length($response)) {
            $logger->info("pfconfig replied after $times tries") if $times > 1;
            return sereal_decode_safe($response);
        }

        if ($times < $max_times) {
            $logger->warn("pfconfig closed the connection without replying, retrying") if $times == 1;
            select(undef, undef, undef, 0.1);
        }
    }

    die "pfconfig closed the connection without replying"
      . ($max_times > 1 ? " ($max_times tries)" : "") . "\n";
}

=head2 socket_expire

Ask pfconfig to expire a namespace (__all__ by default).
Expiring twice only rebuilds the same data, so an empty reply is retried.

=cut

sub socket_expire {
    my (%opts) = @_;
    my $namespace = $opts{namespace} // "__all__";
    my $light = $opts{light} // 0;
    my $payload = {
        method => "expire",
        namespace => $namespace,
        light => $light,
    };

    my $response = pfconfig::util::fetch_decode_socket(encode_json($payload), retry_empty_reply => 1, %opts);
    return ($response->{status} // "") eq "OK.";
}

=head2 socket_pull_expire

Ask pfconfig to pull the git storage and expire.
Each request forks a git pull in pfconfig, so it is never sent twice: an
empty reply dies and the caller decides what to do.

=cut

sub socket_pull_expire {
    my (%opts) = @_;
    my $namespace = $opts{namespace} // "__all__";
    my $light = $opts{light} // 0;
    my $payload = {
        method => "pull_expire",
        light => $light,
        namespace => $namespace,
    };
    my $response = pfconfig::util::fetch_decode_socket(encode_json($payload), %opts, retry_empty_reply => 0);
    return ($response->{status} // "") eq "accepted";
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

=head2 connect_tcp

Connect to pfconfig over TCP.

When pfconfig isn't listening, the kernel can pick its port as the local port
and connect the socket to itself: that socket would then hold the port and
pfconfig couldn't bind it anymore. Such a socket is closed.

Returns the socket, or undef and the error.

=cut

sub connect_tcp {
    my (%args) = @_;
    my $socket = IO::Socket::INET->new(
        PeerHost => $args{host},
        PeerPort => $args{port},
        Proto => "tcp",
        (defined($args{timeout}) ? (Timeout => $args{timeout}) : ()),
    );
    return (undef, "$!") unless $socket;
    if ($socket->sockhost eq $socket->peerhost && $socket->sockport == $socket->peerport) {
        $socket->close();
        return (undef, "the connection is connected to itself");
    }
    return ($socket);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
