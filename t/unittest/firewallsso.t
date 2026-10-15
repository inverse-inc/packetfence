#!/usr/bin/perl

=head1 NAME

firewallsso

=head1 DESCRIPTION

unit test for the VPN role cache of pf::firewallsso (#8671)

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

use Test::More tests => 6;
use pf::firewallsso;

#This test will running last
use Test::NoWarnings;

# A VPN session has no MAC address: the role given to the user when it was
# authorized is kept for the firewall SSO of its accounting
pf::firewallsso::cache_vpn_role('10.0.0.1', 'Jbon', 'vpn-users');
is(pf::firewallsso::vpn_role('10.0.0.1', 'jbon'), 'vpn-users', "role of the VPN user");
is(pf::firewallsso::vpn_role('10.0.0.1', 'JBON'), 'vpn-users', "the user name is not case sensitive");
is(pf::firewallsso::vpn_role('10.0.0.2', 'jbon'), undef, "the role is per VPN (NAS)");

pf::firewallsso::cache_vpn_role('10.0.0.1', 'nobody', undef);
is(pf::firewallsso::vpn_role('10.0.0.1', 'nobody'), undef, "no role, nothing cached");

pf::firewallsso::cache_vpn_role('10.0.0.1', 'Jbon', 'guest');
is(pf::firewallsso::vpn_role('10.0.0.1', 'jbon'), 'guest', "a new authorization replaces the role");

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
