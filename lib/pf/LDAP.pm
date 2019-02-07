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
use pf::util::networking qw(set_write_timeout set_read_timeout);
use POSIX::AtFork;
use pf::Authentication::constants qw($DEFAULT_LDAP_READ_TIMEOUT $DEFAULT_LDAP_WRITE_TIMEOUT);
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

=head2 log_error_msg

log_error_msg

=cut

sub log_error_msg {
    my ($msg) = @_;
    my $logger = get_logger;
    if ($msg) {
        my $error_text = $msg->server_error;
        if ($error_text) {
            $logger->error( "Error binding: '$error_text'");
        } else {
            $logger->warn( "binding:'" . $msg->error() . "'" );
        }
    } else {
        $logger->error("Error binding: 'Unknown error'");
    }
    return;
}

=head2 bind

Perform a bind using the ldap credentials
On success it return the ldap connect
On failure it closes the connection and return undef

=cut

sub bind {
    my ( $self, $ldap, $credentials ) = @_;
    my $msg = $ldap->bind(@$credentials);
    if (!defined $msg || $msg->is_error) {
        $ldap->unbind;
        $ldap->disconnect;
        log_error_msg($msg);
        return undef;
    }
    get_logger->trace("Successful bind");;
    return $ldap;
}

=head2 expire_if

Checks to see if the the LDAP connection is still alive by doing a bind

=cut

sub expire_if {
    my ($class, $object, $driver, $credentials) = @_;
    my $logger = get_logger;
    $logger->info("LDAP testing connection");
    my $ldap = $class->bind($object->value, $credentials);
    return 0 if $ldap;
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
        $logger->error("Error connecting to $server:$args->{port} using encryption $encryption");
        return undef;
    }
    $logger->trace(sub {"Connected to $server:$args->{port} using encryption $encryption"});
    if ($encryption eq TLS) {
        my $msg = $ldap->start_tls;
        if ($msg->is_error) {
            $logger->error("Error starting tls for $server:$args->{port}");
            log_error_msg($msg);
            $ldap->unbind;
            $ldap->disconnect;
            return undef;
        }
    }
    my $read_timeout = delete $args->{read_timeout} // $DEFAULT_LDAP_READ_TIMEOUT;
    my $write_timeout = delete $args->{write_timeout} // $DEFAULT_LDAP_WRITE_TIMEOUT;
    my $socket = $ldap->{net_ldap_socket};
    set_read_timeout($socket, $read_timeout);
    set_write_timeout($socket, $write_timeout);
    return $class->bind($ldap, $credentials);
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
