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

my %CSDefault_Config = %pf::ConfigStore::config::Default_Config;

my %NewDefault_Config;
tie %NewDefault_Config, 'pfconfig::cached_hash', 'config::PfDefault';

foreach my $key (keys %CSDefault_Config){
  my $old = $CSDefault_Config{$key};
  my $new = $NewDefault_Config{$key};
  my ($ok, $stack) = Test::Deep::cmp_details($old, $new);
  ok($ok, "Default config $key matches in old and new store");
  print "$key ".Test::Deep::deep_diag($stack) unless $ok;
}

my %CSDoc_Config = %pf::ConfigStore::config::Doc_Config;

my %NewDoc_Config;
tie %NewDoc_Config, 'pfconfig::cached_hash', 'config::Documentation';

foreach my $key (keys %CSDoc_Config){
  my $old = $CSDoc_Config{$key};
  my $new = $NewDoc_Config{$key};
#  print "old : ".Dumper($old->{description})."\n";
#  print "new : ".Dumper($new->{description})."\n";
  my ($ok, $stack) = Test::Deep::cmp_details($old, $new);
  ok($ok, "Doc config $key matches in old and new store");
  print "$key ".Test::Deep::deep_diag($stack) unless $ok;
}

my %CSConfig = %pf::ConfigStore::config::Config;

my %NewConfig;
tie %NewConfig, 'pfconfig::cached_hash', 'config::Pf';

foreach my $key (keys %CSConfig){
  my $old = $CSConfig{$key};
  my $new = $NewConfig{$key};
  my ($ok, $stack) = Test::Deep::cmp_details($old, $new);
  ok($ok, "PF config $key matches in old and new store");
  print "$key ".Test::Deep::deep_diag($stack) unless $ok;
}

use_ok('pf::admin_roles');
my %CSConfigAdminRoles = %pf::admin_roles::ADMIN_ROLES;

my %NewConfigAdminRoles;
tie %NewConfigAdminRoles, 'pfconfig::cached_hash', 'config::AdminRoles';

foreach my $key (keys %CSConfigAdminRoles){
  my $old = $CSConfigAdminRoles{$key};
  my $new = $NewConfigAdminRoles{$key};
  my ($ok, $stack) = Test::Deep::cmp_details($old, $new);
  ok($ok, "Admin roles config $key matches in old and new store");
  print "$key ".Test::Deep::deep_diag($stack) unless $ok;
}

my %CSConfigFirewallSSO = %pf::ConfigStore::config::ConfigFirewallSSO;

my %NewConfigFirewallSSO;
tie %NewConfigFirewallSSO, 'pfconfig::cached_hash', 'config::Firewall_SSO';

foreach my $key (keys %CSConfigFirewallSSO){
  my $old = $CSConfigFirewallSSO{$key};
  my $new = $NewConfigFirewallSSO{$key};
  my ($ok, $stack) = Test::Deep::cmp_details($old, $new);
  ok($ok, "Firewall SSO config $key matches in old and new store");
  print "$key ".Test::Deep::deep_diag($stack) unless $ok;
}


done_testing();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

