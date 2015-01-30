package zicache::zihash;

use Tie::Hash;
use IO::Socket::UNIX qw( SOCK_STREAM );
use JSON;
use zicache::timeme;
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
  my $socket_path = '/tmp/zicache';
  $socket = IO::Socket::UNIX->new(
     Type => SOCK_STREAM,
     Peer => $socket_path,
  );
  return $socket;
}

# accessor of the hash
sub FETCH {
  my ($self, $key) = @_;

  return $self{$key} if $self{$key};

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
    print $socket "$self{_namespace};$key\n";
    chomp( $line = <$socket> );
  });

  # it returns it as a json hash - maybe not the best choice but it works
  my $result;
  zicache::timeme::timeme('decoding the socket result', sub {
    $result = decode_json($line) if $line;
  });

  return $result;
}

# setter of the hash
# does nothing now
sub STORE {
  my( $self, $key, $value ) = @_;
  $self{$key} = $value;
}

1;
