#!/usr/bin/perl
#
use lib qw(
  /usr/local/pf/lib
  /usr/local/pf/lib_perl/lib/perl5/
);

BEGIN {
  use pfconfig::constants;
  $pfconfig::constants::SOCKET_PATH      = "/usr/local/pf/var/run/pfconfig-go.sock";
}

use pfconfig::cached_hash;
use pfconfig::cached_scalar;
use pfconfig::cached_array;

tie our %config, 'pfconfig::cached_hash', "config::FloatingDevices";
#tie our $fqdn, 'pfconfig::cached_scalar', 'resource::fqdn';
#tie our $config2, 'pfconfig::cached_scalar', 'config::Pf';
#tie our @array, 'pfconfig::cached_array', 'resource::authentication_sources';

use Data::Dumper;
print Dumper($config{"11:22:33:44:55:66"}), "\n";
print $config{"11:22:33:44:55:66"}{"ip"}, "\n";
#print tied(%config)->keys, "\n";
#{
#    local $, = "\n";
#    print keys %config;
#}
#  print $config{database}{db},"\n";
# print "$fqdn\n";
#print $config2->{database}{db},"\n";
#print Dumper($array[0]);
