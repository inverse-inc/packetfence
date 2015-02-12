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
use JSON;
use pfconfig::timeme;
use Data::Dumper;
use pfconfig::log;
our @ISA = 'Tie::Array';

# constructor of the tied array
sub TIEARRAY {
  my ($class, $config) = @_;
  my $self = bless {}, $class;

  $self->{"_namespace"} = $config;

  return $self;
}

# helper to build socket
sub get_socket {
  my $logger = get_logger;
  my $socket_path = '/dev/shm/pfconfig.sock';
  my $socket = IO::Socket::UNIX->new(
     Type => SOCK_STREAM,
     Peer => $socket_path,
  );
  return $socket;
}

# accessor of the array
sub FETCH {
  my ($self, $index) = @_;
  my $logger = get_logger;

  my $result = $self->_get_from_socket("$self->{_namespace};$index")->{element};

  return $result;
}

sub FETCHSIZE {
  my ($self) = @_;
  my $logger = get_logger;

  my $result = $self->_get_from_socket($self->{_namespace}, "array_size")->{size};

  return $result;
}

sub _get_from_socket {
  my ($self, $what, $method, %additionnal_info) = @_;
  my $logger = get_logger;

  $method = $method || "array_element";

  my %info = ((method => $method, key => $what), %additionnal_info);
  my $payload = encode_json(\%info);

  my $socket;
  
  # we need the connection to the cachemaster
  until($socket){
    $socket = $self->get_socket();
    last if($socket);
    $logger->error("Failed to connect to config service, retrying");
    select(undef, undef, undef, 0.1);
  }
     
  # we ask the cachemaster for our namespaced key
  my $line;
  pfconfig::timeme::timeme('socket fetching', sub {
    print $socket "$payload\n";
    chomp( $line = <$socket> );
  });

  # it returns it as a json hash - maybe not the best choice but it works
  my $result;
  pfconfig::timeme::timeme('decoding the socket result', sub {
    if($line && $line ne "undef"){
      $result = decode_json($line);
    }
    else {
      return undef;
    }
  }); 

  return $result
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

