package pfconfig::cached;

=head1 NAME

pfconfig::cached

=cut

=head1 DESCRIPTION

pfconfig::cached

This module serves as an interface to create a cached resource that
will proxy the access to it's attributes to the pfconfig
service

It is used as a bridge between a pfconfig namespace element
and a tied element without having a memory footprint unless when
accessing data in the element

=cut

=head1 USAGE

This class is abstract and should be a superclass of an object
that implements Tied

=cut

use strict;
use warnings;

use IO::Socket::UNIX qw( SOCK_STREAM );
use JSON::MaybeXS;
use pf::log;
use pfconfig::util qw($undef_element normalize_namespace_query);
use pf::config::tenant;
use pfconfig::constants;
use Sereal::Decoder qw(sereal_decode_with_object);
use Time::HiRes qw(stat time);
use pf::Sereal qw($DECODER);
use bytes;


=head2 new

Creates the object but shouldn't be used since it's made as an interface to use pfconfig

=cut

sub new {
    my ($class, @args) = @_;
    my $self = bless {}, $class;

    $self->init(@args);

    return $self;
}

=head2 get_socket

Method that gives an IO::Socket to communicate with pfconfig

=cut

sub get_socket {
    my ($self) = @_;

    my $socket;
    my $socket_path = $pfconfig::constants::SOCKET_PATH;
    $socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => $socket_path,
    );

    return $socket;
}

=head2 init

Method called during the initialisation process
Should set element_socket_method

=cut

sub init {
    my ($self) = @_;
    $self->{element_socket_method} = "override-me";

}

=head2 get_from_subcache

Tries to get an element from the subcache (per process)
It also checks if the subcache is still valid
It will return undef if it's not there or invalid

=cut

sub get_from_subcache {
    my ( $self, $key ) = @_;
    if ( defined( $self->{_subcache}{$key} ) ) {
        my $valid = $self->is_valid();
        if ($valid) {
            if ($self->{_scoped_by_tenant_id}) {
                my $tenant_id = pf::config::tenant::get_tenant();
                return $self->{_subcache}{$tenant_id}{$key};
            } else {
                return $self->{_subcache}{$key};
            }
        }
        else {
            $self->{_subcache}    = {};
            $self->{memorized_at} = time;
            return undef;
        }
    }
    return undef;
}

=head2 get_from_subcache

Sets an element in the subcache so it can be reused across accesses

=cut

sub set_in_subcache {
    my ($self, $key, $result) = @_;
    $self->{memorized_at} //= time;
    if ($self->{_scoped_by_tenant_id}) {
        my $tenant_id = pf::config::tenant::get_tenant();
        $self->{_subcache}{$tenant_id}{$key} = $result;
    } else {
        $self->{_subcache}{$key} = $result;
    }
}

=head2 compute_from_subcache

Get an element of the subcache or compute it's value and store it in the subcache

=cut

sub compute_from_subcache {
    my ($self, $key, $on_miss) = @_;

    my $subcache_value = $self->get_from_subcache($key);
    if (defined($subcache_value) && ref($subcache_value) eq "pfconfig::undef_element") {
        return undef;
    } elsif (defined($subcache_value)) {
        return $subcache_value;
    }

    my $result = $on_miss->();
    if (defined($result)) {
        $self->set_in_subcache($key, $result);
    } else {
        $self->set_in_subcache($key, $undef_element);
    }

    return $result;
}

=head2 _get_from_socket

Method that gets a key from pfconfig
Will wait for the connection if pfconfig is not alive
Will send a JSON payload for the request
Will receive the amount of lines of the reply then the reply as a Sereal string

=cut

sub _get_from_socket {
    my ( $self, $what, $method, %additionnal_info ) = @_;
    my $logger = $self->logger;

    $method = $method || $self->{element_socket_method};

    my %info;
    my $payload;
    %info = ( ( method => $method, key => $what, tenant_id => pf::config::tenant::get_tenant() ), %additionnal_info );
    $payload = encode_json( \%info );

    my $socket;

    my $failed_once = 0;
    my $times       = 0;

    # we need the connection to the cachemaster
    until ($socket) {
        $socket = $self->get_socket();
        if ($socket) {

            # we want to show a success message if we failed at least once
            print "Connected to config service successfully for namespace $self->{_namespace}"
                if $failed_once;
            last;
        }
        my $message
            = "["
            . time
            . "] Failed to connect to config service for namespace $self->{_namespace}, retrying";
        $failed_once = 1;
        $times += 1;
        $logger->error($message);
        print STDERR "$message\n";
        select( undef, undef, undef, 0.1 );
        die("Cannot connect to service pfconfig!") if ( $times >= 600 );
    }

    my $response = pfconfig::util::fetch_socket($socket, $payload);

    # it returns it as a sereal hash
    my $result;
    if ( $response && $response ne "undef\n" ) {
        eval { $result = sereal_decode_with_object($DECODER, $response); };
        if ($@) {
            print STDERR $@;
            print STDERR "$what $response";
        }
    }
    else {
        $result = undef;
    }

    return $result;
}

=head2 is_valid

Method that is used to determine if the object has been refreshed in pfconfig
Uses the control files in var/control and the memorized_at hash to know if a namespace has expired

=cut

sub is_valid {
    my ($self)         = @_;
    my $logger         = $self->logger;
    my $what           = $self->{_namespace};
    my $control_file   = $self->{_control_file_path};
    my $file_timestamp = (  stat($control_file) )[9];

    unless ( defined($file_timestamp) ) {
        $logger->warn("Filesystem timestamp is not set for $what. Considering memory as invalid.");
        return 0;
    }

    my $memory_timestamp = $self->{memorized_at} // 0;

#$logger->trace("Control file has timestamp $file_timestamp and memory has timestamp $memory_timestamp for key $what");
# if the timestamp of the file is after the one we have in memory
# then we are expired
    if ( $memory_timestamp >= $file_timestamp ) {
        $logger->trace( sub { "Memory configuration is still valid for key $what in local cached_hash" });
        return 1;
    }
    else {
            $logger->debug("Memory configuration is not valid anymore for key $what in local cached_hash");
        return 0;
    }
}

sub logger {
    my ($self) = @_;
    return $self->{logger} if defined $self->{logger};
    $self->{logger} = get_logger(ref($self) || $self);
    return $self->{logger};
}

=head2 set_namespace

Set the namespace of this object while normalizing it if needed

=cut

sub set_namespace {
    my ($self, $namespace) = @_;
    $self->{_namespace} = normalize_namespace_query($namespace);
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

