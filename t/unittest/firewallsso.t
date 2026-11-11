#!/usr/bin/perl

=head1 NAME

firewallsso

=head1 DESCRIPTION

unit test for the VPN role cache of pf::firewallsso and the VPN accounting (#8671)

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 12;
use pf::firewallsso;

#This test will running last
use Test::NoWarnings;

# A VPN session has no MAC address: the role given to the user when it was
# authorized is kept for the firewall SSO of its accounting
pf::firewallsso::cache_vpn_role('10.0.0.1', 'Testuser', 'vpn-users');
is(pf::firewallsso::vpn_role('10.0.0.1', 'testuser'), 'vpn-users', "role of the VPN user");
is(pf::firewallsso::vpn_role('10.0.0.1', 'TESTUSER'), 'vpn-users', "the user name is not case sensitive");
is(pf::firewallsso::vpn_role('10.0.0.2', 'testuser'), undef, "the role is per VPN (NAS)");

pf::firewallsso::cache_vpn_role('10.0.0.1', 'nobody', undef);
is(pf::firewallsso::vpn_role('10.0.0.1', 'nobody'), undef, "no role, nothing cached");

pf::firewallsso::cache_vpn_role('10.0.0.1', 'Testuser', 'guest');
is(pf::firewallsso::vpn_role('10.0.0.1', 'testuser'), 'guest', "a new authorization replaces the role");

# pf::api::vpn_accounting: the Stop of a session sends the role it started with
{
    package FakeClient;
    sub new { bless {}, shift }
    sub notify { my ($self, $method, %args) = @_; push @main::NOTIFIED, \%args }
}
our @NOTIFIED;
{
    require pf::api;
    no warnings qw(redefine once);
    local *pf::client::getClient = sub { FakeClient->new };
    local *pf::config::ConfigFirewallSSO = { fortigate => { sso_on_accounting => 'enabled' } };
    my %request = ('User-Name' => 'vpnuser', 'Framed-IP-Address' => '10.212.134.200', 'NAS-IP-Address' => '10.0.0.1', 'Acct-Session-Id' => "session$$");
    # Acct-Status-Type: 1 Start, 2 Stop, 3 Interim-Update
    pf::firewallsso::cache_vpn_role('10.0.0.1', 'vpnuser', 'staff');
    pf::api->vpn_accounting({ %request, 'Acct-Status-Type' => 1 });
    is_deeply([ @{$NOTIFIED[-1]}{qw(method role)} ], ['Update', 'staff'], "the Start sends the role of the user");

    pf::firewallsso::cache_vpn_role('10.0.0.1', 'vpnuser', 'guest');
    pf::api->vpn_accounting({ %request, 'Acct-Status-Type' => 3 });
    is($NOTIFIED[-1]{role}, 'guest', "an interim update sends the current role");

    pf::api->vpn_accounting({ %request, 'Acct-Status-Type' => 2 });
    is_deeply([ @{$NOTIFIED[-1]}{qw(method role)} ], ['Stop', 'staff'], "the Stop sends the role the session started with");
    pf::api->vpn_accounting({ %request, 'Acct-Status-Type' => 2 });
    is($NOTIFIED[-1]{role}, 'guest', "once the session is stopped, its role is forgotten");

    pf::api->vpn_accounting({ %request, 'Acct-Session-Id' => "unknown$$", 'Acct-Status-Type' => 2 });
    is($NOTIFIED[-1]{role}, 'guest', "the Stop of a session not seen before sends the current role");

    pf::api->vpn_accounting({ %request, 'Acct-Session-Id' => undef, 'Acct-Status-Type' => 2 });
    is($NOTIFIED[-1]{role}, 'guest', "without a session id, the current role is sent");
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
