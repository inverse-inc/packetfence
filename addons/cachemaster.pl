
use strict;

use IO::Socket::UNIX qw( SOCK_STREAM SOMAXCONN );
use JSON;
use zicache::zicache;
use Data::Dumper;
use Time::HiRes;
use zicache::timeme;
use Switch;
use List::MoreUtils qw(first_index);
$zicache::timeme::VERBOSE = 1;

my $socket_path = '/usr/local/pf/var/run/config.sock';
unlink($socket_path);

my $listner = IO::Socket::UNIX->new(
   Type   => SOCK_STREAM,
   Local  => $socket_path,
   Listen => SOMAXCONN,
)
   or die("Can't create server socket: $!\n");

my $cache = zicache::zicache->new;

while(1) {
  my $socket = $listner->accept()
     or die("Can't accept connection: $!\n");
  eval {
    chomp( my $line = <$socket> );

    my $query = decode_json($line);

    #print Dumper($query);

    # we support hash namespaced queries
    # where 
    #  - line = 'config' return the whole config hash
    #  - line = 'config;value' return the value in the config hash

    switch ($query->{method}) {
      case 'element' { get_element($query, $socket) }
      case 'keys' { get_keys($query, $socket) }
      case 'next_key' { get_next_key($query, $socket) }
    }


  };
  if($@){
      print STDERR $@;
      print $socket undef;
  }
}

sub get_from_cache {
    my ($what) = @_;
    my $elem;
    # let's get the top namespace element
    zicache::timeme::timeme('get all config in cache', sub {
      $elem = $cache->get_cache($what);
    });

    return $elem;
}

sub get_element {
    my ($query, $socket) = @_;

    my @keys = split ';', $query->{key};
  
    my $elem = get_from_cache($keys[0]);

    if($elem){
      my $json_elem;
      # if we want a subnamespace we handle it here
      if($keys[1]){
        my $sub_elem = $elem->{$keys[1]} || {};
        $json_elem = encode_json($sub_elem);
      }
      # we want the whole namespace
      else {
        $json_elem = encode_json($elem);
      }
      print $socket $json_elem;
    }
    # sh*t happens
    else{
      print STDERR "Unknown key in cache $query->{key} \n";
      print $socket encode_json({});
    }
}

sub get_keys {
    my ($query, $socket) = @_;

    my $elem = get_from_cache($query->{key});

    if($elem){
      my @keys = keys(%{$elem});

      my $json_elem = encode_json(\@keys);

      print $socket $json_elem;

    }
    else{
      print STDERR "Unknown key in cache $query->{key} \n";
      print $socket encode_json([]);
    }
}

sub get_next_key {
  my ($query, $socket) = @_;

  my $elem = get_from_cache($query->{key});

  if($elem){
    my @keys = keys(%{$elem});

    my $last_key = $query->{last_key};

    my $next_key;
    unless($last_key){
      $next_key = $keys[0];
    }
    else{
      my $last_index;
      zicache::timeme::timeme('find last index', sub {
        $last_index = first_index { $_ eq $last_key} @keys ;
      });
      print "last_index $last_index";

      if($last_index >= scalar @keys){
        $next_key = undef;
      }

      $next_key = $keys[$last_index+1];
    }
    my $json_elem = encode_json({next_key => $next_key});
    print $socket $json_elem;

  }
  else{
    print STDERR "Unknown key in cache $query->{key} \n";
    print $socket encode_json({next_key => undef});
  }

}
