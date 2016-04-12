#!/usr/bin/perl

=head1 NAME

merged_list

=cut

=head1 DESCRIPTION

merged_list

=cut

use strict;
use warnings;
# pf core libs
use lib '/usr/local/pf/lib';

BEGIN {
    use lib qw(/usr/local/pf/t);
    use File::Spec::Functions qw(catfile catdir rel2abs);
    use File::Basename qw(dirname);
    use setup_test_config;
}
use Test::More tests => 10;

use Test::NoWarnings;
use Test::Exception;
use NetAddr::IP;
use List::MoreUtils qw(any);

use_ok('pf::firewallsso');
use_ok('pf::factory::firewallsso');
use_ok('pf::config');

ok((any { $_->contains(NetAddr::IP->new("172.20.0.1")) } @{$pf::config::ConfigFirewallSSO{testfw}{networks}}),
    "Networks in firewalls config are detecting if they contain an IP");

ok((any { $_->contains(NetAddr::IP->new("192.168.0.50")) } @{$pf::config::ConfigFirewallSSO{testfw}{networks}}),
    "Networks in firewalls config are detecting if they contain an IP");

ok(!(any { $_->contains(NetAddr::IP->new("1.2.3.4")) } @{$pf::config::ConfigFirewallSSO{testfw}{networks}}),
    "Networks in firewalls config are detecting if they don't contain an IP");

ok((@{$pf::config::ConfigFirewallSSO{testfw2}{networks}} == 0),
    "Firewall with no network attribute set should give an empty networks array");

my $firewallsso = pf::factory::firewallsso->new("testfw");
ok($firewallsso->should_sso("172.20.0.1", "00:11:22:33:44:55"),
    "IP belonging to the firewall SSO networks should pass should_sso");

ok(!($firewallsso->should_sso("1.2.3.4", "00:11:22:33:44:55")),
    "IP not belonging to the firewall SSO networks should'nt pass should_sso");

$firewallsso = pf::factory::firewallsso->new("testfw2");
ok($firewallsso->should_sso("172.20.0.1", "00:11:22:33:44:55"),
    "firewall sso with no networks defined should pass should_sso");

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


