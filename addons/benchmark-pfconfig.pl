#!/usr/bin/perl

use lib '/usr/local/pf/lib';

use pfconfig::timeme;

$pfconfig::timeme::VERBOSE = 0;

use Memory::Usage;

my $mem_usage = Memory::Usage->new;

$mem_usage->record("initializing the cache");

my %switches;
pfconfig::timeme::timeme("loading the tied switch config", sub {
  use pfconfig::cached_hash;
  tie %switches, 'pfconfig::cached_hash', 'config::Switch';
}, 1);

$mem_usage->record("getting the switch");

my $obj = tied(%switches);
pfconfig::timeme::time_me_x("loading a switch", 1000, sub {
  $obj->_get_from_socket("config::Switch;127.0.0.1");
}, 1);


## we make the tied hash process exit so we can profile it
#my $socket = tied(%switches)->get_socket();
#
#print $socket "exit\n";

$mem_usage->dump();


#my @keys = tied(%switches)->keys;
#my $size = @keys;
#pfconfig::timeme::time_me_x("Accessing registration vlan on a switch though pfconfig", 1, sub {
#  my $rand = int(rand($size));
#  my $reg = $switches{$keys[$rand]}{registrationVlan};
#  print $reg."\n"
#}, 1 );

#my %switches;
#pfconfig::timeme::timeme("loading the configStore", sub {
#  use pf::ConfigStore::Switch;
#  use pf::config::cached;
#  %switches = %pf::ConfigStore::Switch::SwitchConfig;
#}, 1);
#
#pfconfig::timeme::time_me_x("Accessing registration on a switch though ConfigStore", 100000, sub {
#  pf::config::cached::ReloadConfigs();
#  my $rand = int(rand($size));
#  my $reg = $switches{$keys[$rand]}{registrationVlan};
#}, 1 );
