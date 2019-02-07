package pfconfig::cached_array;

=head1 NAME

pfconfig::cached_hash

=cut

=head1 DESCRIPTION

pfconfig::cached_array

This module serves as an interface to create an array that
will proxy the access to it's attributes to the pfconfig
service

It is used as a bridge between a pfconfig namespace element
and an array without having a memory footprint unless when
accessing data in the array

=cut

=head1 USAGE

This class is used with tiying

Example :
my @array;
tie @array, 'pfconfig::cached_array', 'resource::authentication_sources';
print $hash{_ip};

This ties @array to the namespace 'resource::authentication_sources' defined in
lib/pfconfig/namespaces/ and served though pfconfig

The access to index 0 then generates a GET though pfconfig
that uses a UNIX socket

In order to call a method on this tied object
my $zammit = tied(%hash)->zammit

=cut

use strict;
use warnings;

use Tie::Array;
use IO::Socket::UNIX qw( SOCK_STREAM );
use JSON::MaybeXS;
use pf::log;
use pfconfig::cached;
our @ISA = ( 'Tie::Array', 'pfconfig::cached' );

=head2 TIEARRAY

Constructor of the array

=cut

sub TIEARRAY {
    my ( $class, $config, %extra ) = @_;
    my $self = bless {}, $class;
    $self->init();
    $self->set_namespace($config);
    $self->{"_scoped_by_tenant_id"} = $extra{tenant_id_scoped};
    $self->{"_control_file_path"} = pfconfig::util::control_file_path($self->{_namespace});
    $self->{element_socket_method} = "array_element";
    return $self;
}

=head2 FETCH

Access an element by index in the array
Will serve it from it's subcache (per process) if it has it and it's still valid
Other than that it proxies the call to pfconfig

=cut

sub FETCH {
    my ( $self, $index ) = @_;
    my $logger = $self->logger;

    my $result = $self->compute_from_subcache($index, sub {
      my $reply = $self->_get_from_socket("$self->{_namespace};$index");
      my $result = defined($reply) ? $reply->{element} : undef;
      return $result;
    });

    return $result;

}

=head2 FETCHSIZE

Get the size of the array
Proxies the call to pfconfig

=cut

sub FETCHSIZE {
    my ($self) = @_;
    my $logger = $self->logger;
    my $result = $self->compute_from_subcache("__PFCONFIG_ARRAY_SIZE__", sub {
        my $reply = $self->_get_from_socket( $self->{_namespace}, "array_size" );
        return defined $reply ? $reply->{size} : 0;
    });

    return $result // 0;
}

=head2 EXISTS

Check if an element exists in the array
Proxies the call to pfconfig

=cut

sub EXISTS {
    my ( $self, $index ) = @_;

    return $self->compute_from_subcache("__PFCONFIG_ARRAY_EXISTS_${index}__", sub {
        my $reply =  $self->_get_from_socket( $self->{_namespace}, "array_index_exists", ( index => $index ) );
        return defined $reply ? $reply->{result} : undef;
    });
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

