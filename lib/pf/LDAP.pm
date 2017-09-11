package pf::LDAP;

=head1 NAME

pf::LDAP - Cache LDAP connections

=cut

=head1 DESCRIPTION

pf::LDAP

=cut

use strict;
use warnings;

use pf::log;
use CHI;
use Log::Any::Adapter;
Log::Any::Adapter->set('Log4perl');
use Net::LDAP;
use Net::LDAPS;
use POSIX::AtFork;
use Socket qw(SOL_SOCKET SO_RCVTIMEO SO_SNDTIMEO);
# available encryption
use constant {
    NONE => "none",
    SSL => "ssl",
    TLS => "starttls",
};

our $DEFAULT_READ_TIMEOUT = 10;

our $DEFAULT_WRITE_TIMEOUT = 5;

our $CHI_CACHE = CHI->new(driver => 'RawMemory', datastore => {});


=head2 new

Get or create a cached ldap connection

=cut

sub new {
    my ($class, $server, %args) = @_;
    my $credentials = delete $args{credentials} // [];
    my $logger = get_logger();
    return $CHI_CACHE->compute(
        [$server, %args],
        {
            expire_if => sub { $class->expire_if(@_, $credentials)}
        },
        sub { $class->compute_connection($server, \%args, $credentials) }
    );
}

=head2 bind

Perform a bind using the ldap credentials
On success it return the ldap connect
On failure it closes the connection and return undef

=cut

sub bind {
    my ($self, $ldap, $credentials) = @_;
        my $msg = $ldap->bind(@$credentials);
        my $logger = get_logger;
        if (!defined $msg || $msg->is_error) {
            $ldap->unbind;
            $ldap->disconnect;
            $logger->error("Error binding '" . ($msg ? $msg->error() : "Unknown error" ) . "'" );
            return undef;
        }
        $logger->trace("Successful bind");
        return $ldap;
}

=head2 expire_if

Checks to see if the the LDAP connection is still alive by doing a bind

=cut

sub expire_if {
    my ($class, $object, $driver, $credentials) = @_;
    my $ldap = $class->bind($object->value, $credentials);
    return 0 if $ldap;
    my $logger = get_logger;
    $logger->warn("LDAP connection expired");
    return 1;
}

=head2 compute_connection

Create the connection for connecting to LDAP

=cut

sub compute_connection {
    my ($class, $server, $args, $credentials) = @_;
    my $encryption = delete $args->{encryption};
    my $logger = get_logger();
    my $ldap;
    if ( $encryption eq SSL ) {
        $ldap = Net::LDAPS->new($server, %$args);
    } else {
        $ldap = Net::LDAP->new($server, %$args);
    }
    unless ($ldap) {
        $logger->error();
        $logger->error("Error connecting to $server:$args->{port} using encryption $encryption");
        return undef;
    }
    $logger->trace(sub {"Connected to $server:$args->{port} using encryption $encryption"});
    if ($encryption eq TLS) {
        my $msg = $ldap->start_tls;
        if ($msg->is_error) {
            $logger->error("Error starting tls for $server:$args->{port}");
            $ldap->unbind;
            $ldap->disconnect;
            return undef;
        }
    }
    my $socket = $ldap->{net_ldap_socket};
    set_read_timeout($socket, $DEFAULT_READ_TIMEOUT);
    set_write_timeout($socket, $DEFAULT_WRITE_TIMEOUT);
    return $class->bind($ldap, $credentials);
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

=head2 CLONE

Clear the cache in a thread environment

=cut

sub CLONE {
    $CHI_CACHE->clear;
}

POSIX::AtFork->add_to_child(\&CLONE);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
