#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
#    use PfFilePaths;
#    use pf::log(service => 'pfconfig');
}

use Test::More;
use Test::Deep;
use Config::IniFiles;
use pf::config::cached;
use Data::Dumper;
use Data::Compare;
use pf::file_paths;

use_ok('pf::ConfigStore::config');

use_ok('pfconfig::manager');
use_ok('pfconfig::cached_hash');

my %NewSwitchConfig;
tie %NewSwitchConfig, 'pfconfig::cached_hash', 'config::Switch';

use_ok('pf::ConfigStore::Switch');

my %CSSwitchConfig = %pf::ConfigStore::Switch::SwitchConfig;

foreach my $key (keys %CSSwitchConfig){
  my $old = $CSSwitchConfig{$key};
  my $new = $NewSwitchConfig{$key};

  # ignoring inline triggers as the new config seems to 
  # do a better job at building them
  $new->{inlineTrigger} = Test::Deep::ignore();

  my ($ok, $stack) = Test::Deep::cmp_details($old, $new);
  ok($ok, "Switch $key matches in old and new store");
  print "$key ".Test::Deep::deep_diag($stack) unless $ok;
}

# encapsultate these in subs to isolate them
sub {
  use_ok('pf::config');
  use_ok('pf::ConfigStore::config');

  my @exported = @pf::config::EXPORT;
  my @badvalues = ('%ConfigProvisioning');
  @exported = grep { !($_ ~~ @badvalues ) } @exported;
  compare_files("pf::config", "pf::ConfigStore::config", @exported);


}->();

sub {
  use_ok('pf::violation_config');
  use_ok('pf::ConfigStore::violation_config');

  my @variables = ('%Violation_Config');
  compare_files("pf::violation_config", "pf::ConfigStore::violation_config", @variables);

}->();

sub {
  use_ok('pf::admin_roles');
  use_ok('pf::ConfigStore::admin_roles');

  my @exported = @pf::admin_roles::EXPORT;
  compare_files("pf::admin_roles", "pf::ConfigStore::admin_roles", @exported);

}->();

sub {
  use_ok('pf::vlan::filter');
  use_ok('pf::ConfigStore::vlan_filters');

  my @variables = ('%ConfigVlanFilters');
  compare_files("pf::vlan::filter", "pf::ConfigStore::vlan_filters", @variables);

}->();

sub {
  use_ok('pf::authentication');
  use_ok('pf::ConfigStore::authentication');

  my @exported = (@pf::authentication::EXPORT, '%authentication_lookup', '%TYPE_TO_SOURCE');
  compare_files("pf::authentication", "pf::ConfigStore::authentication", @exported);

}->();

sub {
  use_ok('pf::ConfigStore::Provisioning');
  use_ok('pf::config');

  my $cs = pf::ConfigStore::Provisioning->new;
  my @provisioners = @{$cs->readAllIds};

  my %ConfigProvisioning = %pf::config::ConfigProvisioning;

  for my $key (@provisioners){ 
    my $old_elem = $cs->read($key);
    my $new_elem = $ConfigProvisioning{$key};
    # oses are broken in configstore
    $old_elem->{oses} = [];
    $new_elem->{oses} = [];
    my ($ok, $stack) = Test::Deep::cmp_details($old_elem, $new_elem);
    ok($ok, "$key is same in ConfigStore and new pf::config::ConfigProvisioning");
    unless($ok) {
      print "$key ".Test::Deep::deep_diag($stack);
      print "$key in configstore : ".Dumper($old_elem);
      print "$key in pf::config (new) : ".Dumper($new_elem);
    }
  }
  

}->();


sub compare_files {
  my ($file1, $file2, @variables) = @_;
  foreach my $variable (@variables){
    # we are only testing variables since we're changing the subs
    # we also don't want the pf::config::cached variables
    if($variable =~ s/^([\$@%]{1})// && !($variable =~ /^cached_.*/ )){
      my $sign = $1;
      $sign =~ s/%/\\%/;
      $sign =~ s/@/\\@/;
      my $old = $sign.$file1."::$variable";
      my $new = $sign.$file2."::$variable"; 
      my $old_elem = eval($old);
      my $new_elem = eval($new);
      my ($ok, $stack) = Test::Deep::cmp_details($old_elem, $new_elem);
      ok($ok, "$variable is same in $file1 and $file2");
      unless($ok) {
        print "$variable ".Test::Deep::deep_diag($stack);
        print "$file1 : ".Dumper(eval($old));
        print "$file2 : ".Dumper(eval($new));
      }
    }
  } 
}

#my %CSDefault_Config = %pf::ConfigStore::config::Default_Config;
#
#my %NewDefault_Config;
#tie %NewDefault_Config, 'pfconfig::cached_hash', 'config::PfDefault';
#
#foreach my $key (keys %CSDefault_Config){
#  my $old = $CSDefault_Config{$key};
#  my $new = $NewDefault_Config{$key};
#  my ($ok, $stack) = Test::Deep::cmp_details($old, $new);
#  ok($ok, "Default config $key matches in old and new store");
#  print "$key ".Test::Deep::deep_diag($stack) unless $ok;
#}
#
#my %CSDoc_Config = %pf::ConfigStore::config::Doc_Config;
#
#my %NewDoc_Config;
#tie %NewDoc_Config, 'pfconfig::cached_hash', 'config::Documentation';
#
#foreach my $key (keys %CSDoc_Config){
#  my $old = $CSDoc_Config{$key};
#  my $new = $NewDoc_Config{$key};
##  print "old : ".Dumper($old->{description})."\n";
##  print "new : ".Dumper($new->{description})."\n";
#  my ($ok, $stack) = Test::Deep::cmp_details($old, $new);
#  ok($ok, "Doc config $key matches in old and new store");
#  print "$key ".Test::Deep::deep_diag($stack) unless $ok;
#}
#
#my %CSConfig = %pf::ConfigStore::config::Config;
#
#my %NewConfig;
#tie %NewConfig, 'pfconfig::cached_hash', 'config::Pf';
#
#foreach my $key (keys %CSConfig){
#  my $old = $CSConfig{$key};
#  my $new = $NewConfig{$key};
#  my ($ok, $stack) = Test::Deep::cmp_details($old, $new);
#  ok($ok, "PF config $key matches in old and new store");
#  print "$key ".Test::Deep::deep_diag($stack) unless $ok;
#}
#
#use_ok('pf::admin_roles');
#my %CSConfigAdminRoles = %pf::admin_roles::ADMIN_ROLES;
#
#my %NewConfigAdminRoles;
#tie %NewConfigAdminRoles, 'pfconfig::cached_hash', 'config::AdminRoles';
#
#foreach my $key (keys %CSConfigAdminRoles){
#  my $old = $CSConfigAdminRoles{$key};
#  my $new = $NewConfigAdminRoles{$key};
#  my ($ok, $stack) = Test::Deep::cmp_details($old, $new);
#  ok($ok, "Admin roles config $key matches in old and new store");
#  print "$key ".Test::Deep::deep_diag($stack) unless $ok;
#}
#
#my %CSConfigFirewallSSO = %pf::ConfigStore::config::ConfigFirewallSSO;
#
#my %NewConfigFirewallSSO;
#tie %NewConfigFirewallSSO, 'pfconfig::cached_hash', 'config::Firewall_SSO';
#
#foreach my $key (keys %CSConfigFirewallSSO){
#  my $old = $CSConfigFirewallSSO{$key};
#  my $new = $NewConfigFirewallSSO{$key};
#  my ($ok, $stack) = Test::Deep::cmp_details($old, $new);
#  ok($ok, "Firewall SSO config $key matches in old and new store");
#  print "$key ".Test::Deep::deep_diag($stack) unless $ok;
#}



done_testing();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.            

=cut

