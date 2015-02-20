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
use JSON;
use pfconfig::timeme;
use List::MoreUtils qw(first_index);
use Data::Dumper;
use pfconfig::log;
use pfconfig::cached;
our @ISA = ('Tie::StdHash', 'pfconfig::cached');

# constructor of the tied hash
sub TIEHASH {
  my ($class, $config) = @_;
  my $self = bless {}, $class;

  $self->init();

  $self->{"_namespace"} = $config;

  $self->{element_socket_method} = "hash_element";


  return $self;
}

# accessor of the hash
sub FETCH {
  my ($self, $key) = @_;
  my $logger = get_logger;

  my $subcache_value;
  $subcache_value = $self->get_from_subcache($key);
  return $subcache_value if defined($subcache_value); 

  return $self->{_internal_elements}{$key} if defined($self->{_internal_elements}{$key});

  my $result;
  my $reply = $self->_get_from_socket("$self->{_namespace};$key");
  $result = defined($reply) ? $reply->{element} : undef;

  $self->set_in_subcache($key, $result);

  return $result;
}

sub keys {
  my ($self) = @_;
  my $logger = get_logger;
  
  my @keys = @{$self->_get_from_socket($self->{_namespace}, "keys")};

  return @keys;
}

sub FIRSTKEY {
  my ($self) = @_;
  my $logger = get_logger;
  my $first_key = $self->_get_from_socket($self->{_namespace}, "next_key", (last_key => undef));
  return $first_key ? $first_key->{next_key} : undef;
}

sub NEXTKEY {
  my ($self, $last_key) = @_;
  my $logger = get_logger;
  return $self->_get_from_socket($self->{_namespace}, "next_key", (last_key => $last_key))->{next_key};
}

# setter of the hash
# stores it in the hash without any saving capabilities.
sub STORE {
  my( $self, $key, $value ) = @_;
  my $logger = get_logger;
  
  $self->{_internal_elements} = {} unless(defined($self->{_internal_elements}));

  $self->{_internal_elements}{$key} = $value;
}

=back

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

