#!/usr/bin/perl

=head1 NAME

pfconfig::cached_hash

=cut

=head1 DESCRIPTION

pfconfig::cached_hash

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use setup_test_config;
}

use Test::More tests => 21;                      # last test to print

use Test::NoWarnings;
use List::MoreUtils qw(uniq);

my %SwitchConfig;
tie %SwitchConfig, 'pfconfig::cached_hash', 'config::Switch';
tie my $management_network, 'pfconfig::cached_scalar', "interfaces::management_network";

##
# Test FETCH
my $aruba = $SwitchConfig{"10.0.0.6"};
ok(defined($aruba),
  "Fetched switch is defined");
is($aruba->{type}, "Aruba",
  "Type of fetched switch is right");

my $cisco = $SwitchConfig{"10.0.0.5"};
ok(defined($cisco),
  "Fetched switch is defined");
is($cisco->{"SNMPAuthPasswordTrap"}, "authpwdread",
  "SNMPAuthPasswordTrap of fetched switch is right");

my $inexistant = $SwitchConfig{"1.2.3.4"};
ok(!defined($inexistant),
  "Fetching an inexisting switch gives undef");

##
# Test exists

ok(exists($SwitchConfig{default}), "default switch exists");
ok(exists($SwitchConfig{"127.0.0.1"}), "127.0.0.1 switch exists");
ok(!exists($SwitchConfig{zammit}), "zammit switch doesn't exists");

##
# Test keys and KEYS


my $SWITCH_COUNT = 25;

my @extra_switches;

push @extra_switches, $management_network->tag('vip') if $management_network->tag('vip');
push @extra_switches, $management_network->tag('ip')  if $management_network->tag('ip');

@extra_switches = uniq @extra_switches;

$SWITCH_COUNT += @extra_switches;

my @keys = tied(%SwitchConfig)->keys();

is(@keys, $SWITCH_COUNT,
    "Right number of keys returned");

is(ref(\@keys), 'ARRAY',
    "Type of hash keys is ARRAY");

@keys = keys %SwitchConfig;

is(@keys, $SWITCH_COUNT,
    "Right number of keys returned");

is(ref(\@keys), 'ARRAY',
    "Type of hash keys is ARRAY");

##
# Test values
my @values = tied(%SwitchConfig)->values();

is(@values, $SWITCH_COUNT,
    "Right number of values returned");

is(ref(\@values), 'ARRAY',
    "Type of hash values is ARRAY");

##
# Test search
my @search = tied(%SwitchConfig)->search("type", "Aruba");
is(@search, 4,
    "Search yielded the right amount of data");
foreach my $element (@search){
    is($element->{type}, "Aruba",
        "Type of searched element is right");
}

##
# Test undefined values

ok(!defined($SwitchConfig{zammit}), 'Undefined switch comes up as undefined');

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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


