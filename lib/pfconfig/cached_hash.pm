package pfconfig::cached_hash;

use strict;
use warnings;

use Tie::Hash;
use IO::Socket::UNIX qw( SOCK_STREAM );
use JSON;
use pfconfig::timeme;
use List::MoreUtils qw(first_index);
use Data::Dumper;
use pf::log;
our @ISA = 'Tie::StdHash';

# constructor of the tied hash
sub TIEHASH {
  my ($class, $config) = @_;
  my $self = bless {}, $class;

  $self->{"_namespace"} = $config;

  return $self;
}

# helper to build socket
sub get_socket {
  my $logger = get_logger;
  my $socket_path = '/usr/local/pf/var/run/config.sock';
  my $socket = IO::Socket::UNIX->new(
     Type => SOCK_STREAM,
     Peer => $socket_path,
  );
  return $socket;
}

# accessor of the hash
sub FETCH {
  my ($self, $key) = @_;
  my $logger = get_logger;

  return $self->{_internal_elements}{$key} if $self->{_internal_elements}{$key};

  my $result = $self->_get_from_socket("$self->{_namespace};$key");

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
  return $self->_get_from_socket($self->{_namespace}, "next_key", (last_key => undef))->{next_key};
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

sub _get_from_socket {
  my ($self, $what, $method, %additionnal_info) = @_;
  my $logger = get_logger;

  $method = $method || "element";

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
    $result = decode_json($line) if $line;
  });

  return $result
}

1;
