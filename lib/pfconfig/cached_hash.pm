package pfconfig::cached_hash;

=head1 NAME

pfconfig::cached_hash

=cut

=head1 DESCRIPTION

pfconfig::cached_hash

This module serves as an interface to create a hash that
will proxy the access to it's attributes to the pfconfig
service

It is used as a bridge between a pfconfig namespace element
and a hash without having a memory footprint unless when
accessing data in the hash

=cut

=head1 USAGE

This class is used with tiying

Example :
my %hash;
tie %hash, 'pfconfig::cached_hash', 'resource::default_switch';
print $hash{_ip};

This ties %hash to the namespace 'resource::default_switch' defined in
lib/pfconfig/namespaces/ and served though pfconfig

The access to the attribute _ip then generates a GET though pfconfig
that uses a UNIX socket

In order to call a method on this tied object
my @keys = tied(%hash)->keys

=cut

use strict;
use warnings;

use Tie::Hash;
use IO::Socket::UNIX qw( SOCK_STREAM );
use JSON::MaybeXS;
use List::MoreUtils qw(first_index);
use pf::log;
use pf::config::tenant;
use pfconfig::cached;
our @ISA = ( 'Tie::StdHash', 'pfconfig::cached' );

=head2 TIEHASH

Constructor of the hash

=cut

sub TIEHASH {
    my ( $class, $config, %extra ) = @_;
    my $self = bless {}, $class;
    $self->init();
    $self->set_namespace($config);
    $self->{"_scoped_by_tenant_id"} = $extra{tenant_id_scoped};
    $self->{"_control_file_path"} = pfconfig::util::control_file_path($self->{_namespace});
    $self->{element_socket_method} = "hash_element";
    return $self;
}

=head2 FETCH

Access an element by key in the hash
Will serve it from it's subcache (per process) if it has it and it's still valid
Other than that it proxies the call to pfconfig

=cut

sub FETCH {
    my ( $self, $key ) = @_;
    my $logger = $self->logger;
    unless ( defined($key) ) {
        my $caller = ( caller(1) )[3];
        $logger->error("Accessing hash $self->{_namespace} with undef key. Caller : $caller.");
        return undef;
    }

    if ($self->{_scoped_by_tenant_id}) {
        my $tenant_id = pf::config::tenant::get_tenant();
        if( defined $self->{_internal_elements}{$tenant_id}{$key}) {
            return  $self->{_internal_elements}{$tenant_id}{$key}
        }
    } elsif (defined( $self->{_internal_elements}{$key} )) {
        return $self->{_internal_elements}{$key};
    }

    my $result = $self->compute_from_subcache($key, sub {
        my $reply = $self->_get_from_socket("$self->{_namespace};$key");
        my $result = defined($reply) ? $reply->{element} : undef;
    });

    return $result;
}

=head2 keys

Added method that can be called on the underlying object of the tied hash
Will do 1 call to fetch all the keys of the hash instead of using the next key method
Call it using tied(%hash)->keys

=cut

sub keys {
    my ($self) = @_;
    my $logger = $self->logger;

    my $keys = $self->compute_from_subcache("__PFCONFIG_HASH_KEYS__", sub {
        return $self->_get_from_socket( $self->{_namespace}, "keys" );
    });

    return @$keys;
}

=head2 FIRSTKEY

Get the first key of the hash
Proxies to pfconfig

=cut

sub FIRSTKEY {
    my ($self) = @_;
    my $logger = $self->logger;

    return $self->compute_from_subcache("__PFCONFIG_FIRST_KEY__", sub {
        my $first_key = $self->_get_from_socket( $self->{_namespace}, "next_key", ( last_key => undef ) );
        return $first_key ? $first_key->{next_key} : undef;
    });
}

=head2 FIRSTKEY

Get the next key of the hash
Proxies to pfconfig

=cut

sub NEXTKEY {
    my ( $self, $last_key ) = @_;
    my $logger = $self->logger;

    return $self->compute_from_subcache("__PFCONFIG_NEXT_KEY_${last_key}__", sub {
        return $self->_get_from_socket( $self->{_namespace}, "next_key", ( last_key => $last_key ) )->{next_key};
    });
}

=head2 STORE

Set a value in the hash
Stores it without any saving capability

=cut

sub STORE {
    my ( $self, $key, $value ) = @_;
    my $logger = $self->logger;
    if ($self->{_scoped_by_tenant_id}) {
        my $tenant_id = pf::config::tenant::get_tenant();
        $self->{_internal_elements}{$tenant_id}{$key} = $value;
    } else {
        $self->{_internal_elements}{$key} = $value;
    }
}

=head2 STORE

Check if a key exists in the hash
Proxies to pfconfig

=cut

sub EXISTS {
    my ( $self, $key ) = @_;
    return undef unless defined $key;
    return $self->compute_from_subcache("__PFCONFIG_KEY_EXISTS_${key}__", sub {
        my $reply =  $self->_get_from_socket( $self->{_namespace}, "key_exists", ( search => $key ) );
        return defined $reply ? $reply->{result} : undef;
    });
}

=head2 all

Method to fetch the whole namespace in one single call
Use as a replacement of \%hash when there are a lot of keys
Call it using tied(%hash)->all

=cut

sub all {
    my ( $self ) = @_;
    my $result = $self->compute_from_subcache("__PFCONFIG_ALL__", sub {
        my $reply = $self->_get_from_socket("$self->{_namespace}");
        my $result = defined($reply) ? $reply->{element} : undef;
    });

    return $result;
}

=head2 values

Added method that can be called on the underlying object of the tied hash
Will return all the values of the hash. Mostly for internal use
Call it using tied(%hash)->values

=cut

sub values {
    my ( $self ) = @_;
    my @keys = $self->keys;
    my @values;
    foreach my $key (@keys){
        push @values, $self->FETCH($key);
    }
    return @values;
}

=head2 search

Used to search for an element in our hash that has a specific value in one of it's field

Ex (%h is us) :
my %h = {
  'test' => {'result' => '2'},
  'test2' => {'result' => 'success'}
}

Searching for field result with value 'success' would return the value of test2

This has to be called on the underlying object of the tied hash
Call it using tied(%hash)->search('result', 'success')

=cut

sub search {
    my ($self, $field, $value ) = @_;
    my $elements = $self->compute_from_subcache("__PFCONFIG_HASH_SEARCH_${field}_${value}__", sub {
        my @elements = grep { exists $_->{$field} && defined $_->{$field} && $_->{$field} eq $value  } $self->values;
        return \@elements;
    });
    return @$elements;
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

