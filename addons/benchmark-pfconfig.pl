#!/usr/bin/perl

use lib '/usr/local/pf/lib';

use pfconfig::timeme;

$pfconfig::timeme::VERBOSE = 0;

my %switches;
pfconfig::timeme::timeme("loading the tied switch config", sub {
  use pfconfig::cached_hash;
  tie %switches, 'pfconfig::cached_hash', 'config::Switch';
}, 1);
my @keys = tied(%switches)->keys;
my $size = @keys;
pfconfig::timeme::time_me_x("Accessing registration vlan on a switch though pfconfig", 100000, sub {
  my $rand = int(rand($size));
  my $reg = $switches{$keys[$rand]}{registrationVlan};
}, 1 );

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
