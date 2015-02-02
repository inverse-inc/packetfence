package zicache::zihash;

use Tie::Hash;
use IO::Socket::UNIX qw( SOCK_STREAM );
use JSON;
use zicache::timeme;
use List::MoreUtils qw(first_index);
use Data::Dumper;
our @ISA = 'Tie::StdHash';

# constructor of the tied hash
sub TIEHASH {
  my ($class, $config) = @_;
  my $self = bless {}, $class;

  $self{"_namespace"} = $config;

  return $self;
}

# helper to build socket
sub get_socket {
  my $socket_path = '/usr/local/pf/var/run/config.sock';
  $socket = IO::Socket::UNIX->new(
     Type => SOCK_STREAM,
     Peer => $socket_path,
  );
  return $socket;
}

# accessor of the hash
sub FETCH {
  my ($self, $key) = @_;

  return $self{_internal_elements}{$key} if $self{_internal_elements}{$key};

  my $result = $self->_get_from_socket("$self{_namespace};$key");

  return $result;
}

sub FIRSTKEY {
  my ($self) = @_;
  
  my @keys = @{$self->_get_from_socket($self{_namespace}, "keys")};

  return $keys[0];
}

sub FIRSTKEY {
  my ($self) = @_;
  return $self->_get_from_socket($self{_namespace}, "next_key", (last_key => undef))->{next_key};
}

sub NEXTKEY {
  my ($self, $last_key) = @_;
  return $self->_get_from_socket($self{_namespace}, "next_key", (last_key => $last_key))->{next_key};
}

# setter of the hash
# stores it in the hash without any saving capabilities.
sub STORE {
  my( $self, $key, $value ) = @_;
  
  $self{_internal_elements} = {} unless(defined($self{_internal_elements}));

  $self{_internal_elements}{$key} = $value;
}

sub _get_from_socket {
  my ($self, $what, $method, %additionnal_info) = @_;

  $method = $method || "element";

  my %info = ((method => $method, key => $what), %additionnal_info);
  my $payload = encode_json(\%info);

  my $socket;
  
  # we need the connection to the cachemaster
  until($socket){
    $socket = $self->get_socket();
    last if($socket);
    print STDERR "Failed to connect to config service, retrying\n";
    select(undef, undef, undef, 0.1);
  }
     
  # we ask the cachemaster for our namespaced key
  my $line;
  zicache::timeme::timeme('socket fetching', sub {
    print $socket "$payload\n";
    chomp( $line = <$socket> );
  });

  # it returns it as a json hash - maybe not the best choice but it works
  my $result;
  zicache::timeme::timeme('decoding the socket result', sub {
    $result = decode_json($line) if $line;
  });

  return $result
}

1;
