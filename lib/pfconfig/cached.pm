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
use JSON;
use pfconfig::timeme;
use Data::Dumper;
use pfconfig::log;

my $_socket = 0;

# helper to build socket
sub get_socket {
    my ($self) = @_;

    my $socket;
    my $socket_path = '/usr/local/pf/var/pfconfig.sock';
    $socket = IO::Socket::UNIX->new(
       Type => SOCK_STREAM,
       Peer => $socket_path,
    );

    return $socket;
}

sub init {
    my ($self) = @_;
    $self->{element_socket_method} = "override-me";


}

sub get_from_subcache {
    my ($self, $key) = @_;
    if(defined($self->{_subcache}{$key})){
      my $valid = $self->is_valid();
      if($valid){
        return $self->{_subcache}{$key}; 
      }
      else{
        $self->{_subcache} = {};
        $self->{memorized_at} = time;
        return undef;
      }
    }
    return undef;
}

sub set_in_subcache {
    my ($self, $key, $result) = @_;

    $self->{memorized_at} = time unless $self->{memorized_at};
    $self->{_subcache} = {} unless $self->{_subcache};
    $self->{_subcache}{$key} = $result;

} 


sub _get_from_socket {
  my ($self, $what, $method, %additionnal_info) = @_;
  my $logger = get_logger;

  $method = $method || $self->{element_socket_method};

  my %info;
  my $payload;
  %info = ((method => $method, key => $what), %additionnal_info);
  $payload = encode_json(\%info);

  my $socket;
  
  # we need the connection to the cachemaster
  until($socket){
    $socket = $self->get_socket();
    last if($socket);
    $logger->error("Failed to connect to config service, retrying");
    print STDERR "Failed to connect to config service, retrying";
    select(undef, undef, undef, 0.1);
  }
     
  # we ask the cachemaster for our namespaced key
  my $line;
  print $socket "$payload\n";
  chomp( $line = <$socket> );

  # it returns it as a json hash - maybe not the best choice but it works
  my $result;
  if($line && $line ne "undef"){
    $result = decode_json($line);
  }
  else {
    $result = undef;
  }

  return $result
}

# helper to know if the raw memory cache is still valid
sub is_valid {
  my ($self) = @_;
  my $what = $self->{_namespace};
  #my $logger = get_logger;
  my $control_file;
  $control_file = $what;
  my $file_timestamp = (stat("/usr/local/pf/var/".$control_file."-control"))[9];

  unless(defined($file_timestamp)){
    #$logger->warn("Filesystem timestamp is not set for $what. Considering memory as invalid.");
    return 0;
  }

  my $memory_timestamp = $self->{memorized_at} || time;
  #$logger->trace("Control file has timestamp $file_timestamp and memory has timestamp $memory_timestamp for key $what");
  # if the timestamp of the file is after the one we have in memory
  # then we are expired
  if ($memory_timestamp > $file_timestamp){
    #$logger->trace("Memory configuration is still valid for key $what in local cached_hash");
    return 1;
  }
  else{
    #$logger->info("Memory configuration is not valid anymore for key $what in local cached_hash");
    return 0;
  }
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

