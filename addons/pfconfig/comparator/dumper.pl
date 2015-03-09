#!/usr/bin/perl

use strict;
use warnings;

use Sereal::Encoder;
use Data::Dumper;

my $BASE = $ARGV[1];
use lib $ARGV[0];

my $ENCODER = Sereal::Encoder->new;
our %configs;

sub {
  use pf::config;
  my @exported = @pf::config::EXPORT;
  my @badvalues = ('%ConfigProvisioning');
  @exported = grep { !($_ ~~ @badvalues ) } @exported;
  dump_module('pf::config', @exported);
}->();

sub {
  use pf::violation_config;

  my @variables = ('%Violation_Config');
  dump_module("pf::violation_config", @variables);

}->();

sub {
  use pf::admin_roles;

  my @exported = @pf::admin_roles::EXPORT;
  dump_module("pf::admin_roles", @exported);

}->();

sub {
  use pf::vlan::filter;

  my @variables = ('%ConfigVlanFilters');
  dump_module("pf::vlan::filter", @variables);

}->();

sub {
  use pf::authentication;

  my @exported = (@pf::authentication::EXPORT, '%authentication_lookup', '%TYPE_TO_SOURCE');
  dump_module("pf::authentication", @exported);

}->();

#sub {
#  use_ok('pf::ConfigStore::Provisioning');
#  use_ok('pf::config');
#
#  my $cs = pf::ConfigStore::Provisioning->new;
#  my @provisioners = @{$cs->readAllIds};
#
#  my %ConfigProvisioning = %pf::config::ConfigProvisioning;
#
#  for my $key (@provisioners){ 
#    my $old_elem = $cs->read($key);
#    my $new_elem = $ConfigProvisioning{$key};
#    # oses are broken in configstore
#    $old_elem->{oses} = [];
#    $new_elem->{oses} = [];
#    my ($ok, $stack) = Test::Deep::cmp_details($old_elem, $new_elem);
#    ok($ok, "$key is same in ConfigStore and new pf::config::ConfigProvisioning");
#    unless($ok) {
#      print "$key ".Test::Deep::deep_diag($stack);
#      print "$key in configstore : ".Dumper($old_elem);
#      print "$key in pf::config (new) : ".Dumper($new_elem);
#    }
#  }
#  
#
#}->();





my $output = $ENCODER->encode(\%configs);
open(my $fh, ">", "/tmp/config-comparator/$BASE.out") 
  or die "cannot open > /tmp/config-comparator/$BASE.out: $!";
print $fh $output;

sub dump_module {
  my ($file1, @variables) = @_;
  my %data;
  foreach my $variable (@variables){
    # we are only testing variables since we're changing the subs
    # we also don't want the pf::config::cached variables
    if($variable =~ s/^([\$@%]{1})// && !($variable =~ /^cached_.*/ )){
      my $sign = $1;
      $sign =~ s/%/\\%/;
      $sign =~ s/@/\\@/;
      my $name = $sign.$file1."::$variable";
      my $elem = eval($name);
      $data{$name} = $elem;
    }
  } 
  $configs{$file1} = \%data;
}
