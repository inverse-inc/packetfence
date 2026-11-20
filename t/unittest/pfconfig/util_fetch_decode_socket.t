#!/usr/bin/perl

=head1 NAME

util_fetch_decode_socket

=head1 DESCRIPTION

pfconfig::util::fetch_decode_socket when pfconfig closes the connection
without replying: the request is sent again instead of handing an empty reply
to the Sereal decoder.

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use test_paths;
}

use Test::More tests => 7;
use Test::NoWarnings;

use File::Temp qw(tempdir);
use IO::Socket::UNIX;
use JSON::MaybeXS qw(encode_json);
use POSIX ();
use Sereal::Encoder qw(sereal_encode_with_object);
use pf::Sereal qw($ENCODER_FREEZER);
use pf::util::networking qw(send_data_with_length);
use pfconfig::config;
use pfconfig::constants;
use pfconfig::util;

# The test server listens on a unix socket, whatever the configured protocol
{
    no warnings 'redefine';
    *pfconfig::config::get_proto = sub { "unix" };
}

my $dir = tempdir( CLEANUP => 1 );
my $server_count = 0;

=head2 start_server

Start a pfconfig stand-in that closes its first $drops connections without
replying, then replies to every request with its status and the number of
connections it received so far. Returns its pid.

=cut

sub start_server {
    my ($drops) = @_;
    my $path = "$dir/pfconfig-" . ( ++$server_count ) . ".sock";
    my $listener = IO::Socket::UNIX->new(
        Type   => SOCK_STREAM,
        Local  => $path,
        Listen => 10,
    ) or die "Can't create the test server socket: $!\n";
    $pfconfig::constants::SOCKET_PATH = $path;

    my $pid = fork();
    die "Can't fork: $!\n" unless defined $pid;
    if ( $pid == 0 ) {
        my $connections = 0;
        while ( my $socket = $listener->accept ) {
            $connections++;
            my $line = <$socket>;
            if ( $connections > $drops ) {
                my $reply = { status => "OK.", connections => $connections };
                send_data_with_length( $socket, sereal_encode_with_object( $ENCODER_FREEZER, $reply ) );
            }
            close($socket);
        }
        POSIX::_exit(0);
    }
    close($listener);
    return $pid;
}

sub stop_server {
    my ($pid) = @_;
    kill 'TERM', $pid;
    waitpid( $pid, 0 );
}

my $payload = encode_json( { method => "expire", namespace => "config::Pf", light => 1 } );

my $pid = start_server(0);
is_deeply(
    pfconfig::util::fetch_decode_socket($payload),
    { status => "OK.", connections => 1 },
    "A reply is decoded on the first try"
);
stop_server($pid);

$pid = start_server(2);
is_deeply(
    pfconfig::util::fetch_decode_socket($payload),
    { status => "OK.", connections => 3 },
    "The request is sent again when the connection is closed without a reply"
);
stop_server($pid);

$pid = start_server(1);
ok(
    pfconfig::util::socket_expire( namespace => "config::Pf", light => 1 ),
    "socket_expire succeeds when the first connection is closed without a reply"
);
stop_server($pid);

{
    local $pfconfig::constants::MAX_EMPTY_REPLY_TIMES = 3;
    $pid = start_server(1000);
    my $result = eval { pfconfig::util::fetch_decode_socket($payload) };
    like(
        $@,
        qr/^pfconfig closed the connection without replying \(3 tries\)$/,
        "Dies with a clear message when pfconfig never replies"
    );
    is( $result, undef, "Nothing is returned when pfconfig never replies" );
    stop_server($pid);
}

$pfconfig::constants::SOCKET_PATH = "$dir/nothing-listens-here.sock";
eval { pfconfig::util::fetch_decode_socket($payload) };
like( $@, qr/^cannot connect to the server: /, "Still dies right away when the connection fails" );

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
