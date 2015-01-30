
use strict;

use IO::Socket::UNIX qw( SOCK_STREAM SOMAXCONN );
use JSON;
use zicache::zicache;
use Data::Dumper;
use Time::HiRes;
use zicache::timeme;
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

    # we support hash namespaced queries
    # where 
    #  - line = 'config' return the whole config hash
    #  - line = 'config;value' return the value in the config hash
    my @keys = split ';', $line;

    my $elem;
    # let's get the top namespace element
    zicache::timeme::timeme('get all config in cache', sub {
      $elem = $cache->get_cache($keys[0]);
    });

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
      print $socket encode_json({});
    }
  };
  if($@){
      print STDERR $@;
      print $socket undef;
  }
}
