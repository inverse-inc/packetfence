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
use pfconfig::util;
use Sereal::Decoder;

sub new {
  my ($class) = @_;
  my $self = bless {}, $class;

  $self->init();

  return $self;
}

# helper to build socket
sub get_socket {
    my ($self) = @_;

    my $socket;
    my $socket_path = pfconfig::util::socket_path();
    $socket = IO::Socket::UNIX->new(
       Type => SOCK_STREAM,
       Peer => $socket_path,
    );

    return $socket;
}

sub init {
    my ($self) = @_;
    $self->{element_socket_method} = "override-me";

    $self->{decoder} = Sereal::Decoder->new;

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
  
  my $failed_once = 0;
  # we need the connection to the cachemaster
  until($socket){
    $socket = $self->get_socket();
    if($socket){
      # we want to show a success message if we failed at least once
      print "Connected to config service successfully for namespace $self->{_namespace}" if $failed_once;
      last;
    }
    my $message = "[".time."] Failed to connect to config service for namespace $self->{_namespace}, retrying";
    $failed_once = 1;
    $logger->error($message);
    print STDERR "$message\n";
    select(undef, undef, undef, 0.1);
  }
     
  # we ask the cachemaster for our namespaced key
  print $socket "$payload\n";
  
  # this will give us the line length to read
  chomp( my $count = <$socket> );
  
  my $line;
  my $line_read = 0;
  my $response = '';
  while($line_read < $count){
    chomp($line = <$socket>);
    $response .= $line."\n";
    $line_read += 1;
  }

  # it returns it as a sereal hash
  my $result;
  if($response && $response ne "undef\n"){
    eval { 
      $result = $self->{decoder}->decode($response);
    };
    if ($@){
      print STDERR $@;
      print STDERR "$what $response";
    }
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
  my $control_file = pfconfig::util::control_file_path($what);
  my $file_timestamp = (stat($control_file))[9] ;

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

