#!/usr/bin/perl

use lib '/usr/local/pf/lib';

use pfconfig::timeme;
use pfconfig::cached_hash;

$pfconfig::timeme::VERBOSE = 0;

my %switches;
tie %switches, 'pfconfig::cached_hash', 'config::Switch';
my @keys = tied(%switches)->keys;
my $size = @keys;
pfconfig::timeme::time_me_x("Accessing registration vlan on a switch though pfconfig", 10000, sub {
  my $rand = int(rand($size));
  my $reg = $switches{$keys[$rand]}{registrationVlan};
}, 1 );

pfconfig::timeme::time_me_x("Accessing registration vlan on a switch though ConfigStore", 10000, sub {
  use pf::ConfigStore::Switch;
  my %switches = %pf::ConfigStore::Switch::SwitchConfig;
  my $rand = int(rand($size));
  my $reg = $switches{$keys[$rand]}{registrationVlan};
}, 1 );
