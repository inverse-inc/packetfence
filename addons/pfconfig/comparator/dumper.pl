#!/usr/bin/perl

=head1 NAME

dumper.pl

=head1 SYNOPSIS

dumper.pl <codebase>

=head1 DESCRIPTION

Dumps the configuration for a codebase

No need to use it directly, use addons/pfconfig/comparator/config-comparator.sh

=cut

use strict;
use warnings;

use Data::Dumper;
use Sereal::Encoder;

unless ($ARGV[0] && $ARGV[1]){
  print "Missing arguments";
  exit;
}

my $BASE = $ARGV[1];
use lib $ARGV[0];

my $ENCODER = Sereal::Encoder->new;
our %configs;

{
  use pf::config;
  my @exported = @pf::config::EXPORT;
  my @badvalues = ('%ConfigProvisioning', '$ACCT_TIME_MODIFIER_RE', '$DEADLINE_UNIT', '$FALSE', '$TRUE', '$TIME_MODIFIER_RE', '$default_pid');
  @exported = grep { !($_ ~~ @badvalues ) } @exported;
  $configs{'pf::config'} = dump_module('pf::config', @exported);

  # we ignore categories since they're now inflated
  foreach my $firewall (keys %{$configs{'pf::config'}{'\\%pf::config::ConfigFirewallSSO'}}){
    $configs{'pf::config'}{'\\%pf::config::ConfigFirewallSSO'}{$firewall}{categories} = undef;
  }
}

{
  use pf::violation_config;

  my @variables = ('%Violation_Config');
  $configs{'pf::violation_config'} = dump_module("pf::violation_config", @variables);

}

{
  use pf::admin_roles;

  my @exported = @pf::admin_roles::EXPORT;
  my @badvalues = ('@ADMIN_ACTIONS');
  @exported = grep { !($_ ~~ @badvalues ) } @exported;
  $configs{'pf::admin_roles'} = dump_module("pf::admin_roles", @exported);

}

{
  use pf::vlan::filter;

  my @variables = ('%ConfigVlanFilters');
  $configs{'pf::vlan::filter'} = dump_module("pf::vlan::filter", @variables);

}

{
  use pf::authentication;

  my @exported = (@pf::authentication::EXPORT, '%authentication_lookup', '%TYPE_TO_SOURCE');
  $configs{'pf::authentication'} = dump_module("pf::authentication", @exported);

}

{
  use pf::SwitchFactory;

  $configs{switches} = pf::SwitchFactory->config();

}

{
  use pf::web::filter;

  my @variables = ('%ConfigApacheFilters');
  $configs{'pf::web::filter'} = dump_module("pf::web::filter", @variables);

}

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
  return \%data;
}

=back

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

