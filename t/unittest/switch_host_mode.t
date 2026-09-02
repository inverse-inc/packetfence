#!/usr/bin/perl

=head1 NAME

switch_host_mode

=head1 DESCRIPTION

Unit tests for the per-switch C<host_mode> parameter:
  - pf::Switch::getHostMode / isMultiAuthPort defaults and parsing
  - pf::locationlog::_is_multi_auth_switchport lookup
  - deauthentication technique resolution on a multi-auth port

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 21;
use Test::NoWarnings;

use pf::SwitchFactory;
use pf::locationlog;
use pf::Switch::constants;
use pf::constants::switch qw($HOST_MODE_SINGLE_HOST $HOST_MODE_MULTI_HOST $HOST_MODE_MULTI_AUTH);
use pf::config qw($WIRED_802_1X $WIRED_MAC_AUTH);

# ----------------------------------------------------------------------------
# pf::Switch::getHostMode / isMultiAuthPort
# ----------------------------------------------------------------------------

{
    # No host_mode set anywhere: the switches.conf.defaults value applies.
    my $switch = pf::SwitchFactory->instantiate('172.16.8.28');
    ok(defined $switch, 'instantiated switch 172.16.8.28');
    is($switch->getHostMode(), $HOST_MODE_SINGLE_HOST,
        'host_mode defaults to single-host when not set');
    ok(!$switch->isMultiAuthPort(),
        'isMultiAuthPort is false on a single-host switch');
}

{
    my $switch = pf::SwitchFactory->instantiate('172.16.8.42');
    ok(defined $switch, 'instantiated switch 172.16.8.42');
    is($switch->getHostMode(), $HOST_MODE_MULTI_HOST,
        'host_mode=multi-host is read from switches.conf');
    ok(!$switch->isMultiAuthPort(),
        'isMultiAuthPort is false on a multi-host switch: only the first endpoint authenticates');
}

{
    my $switch = pf::SwitchFactory->instantiate('172.16.8.41');
    ok(defined $switch, 'instantiated switch 172.16.8.41');
    is($switch->getHostMode(), $HOST_MODE_MULTI_AUTH,
        'host_mode=multi-auth is read from switches.conf');
    ok($switch->isMultiAuthPort(),
        'isMultiAuthPort is true on a multi-auth switch');
}

# ----------------------------------------------------------------------------
# pf::locationlog::_is_multi_auth_switchport
# ----------------------------------------------------------------------------

{
    ok(pf::locationlog::_is_multi_auth_switchport('172.16.8.41'),
        '_is_multi_auth_switchport is true for a multi-auth switch');
    ok(!pf::locationlog::_is_multi_auth_switchport('172.16.8.42'),
        '_is_multi_auth_switchport is false for a multi-host switch');
    ok(!pf::locationlog::_is_multi_auth_switchport('172.16.8.28'),
        '_is_multi_auth_switchport is false for a single-host switch');
    ok(!pf::locationlog::_is_multi_auth_switchport(undef),
        '_is_multi_auth_switchport is false when no switch is given');
    ok(!pf::locationlog::_is_multi_auth_switchport('no.such.switch'),
        '_is_multi_auth_switchport is false for an unknown switch');
    ok(pf::locationlog::_is_multi_auth_switchport(undef, '172.16.8.41'),
        '_is_multi_auth_switchport falls back on the next identifier');
}

# ----------------------------------------------------------------------------
# Deauthentication technique on a multi-auth port
#
# pf::api::ReAssignVlan forces $SNMP::RADIUS when the switch is in multi-auth so
# that the CoA/Disconnect is scoped to one endpoint through its
# Calling-Station-Id instead of bouncing the whole port.
# ----------------------------------------------------------------------------

{
    my $switch = pf::SwitchFactory->instantiate('172.16.8.41');

    my ($method, $technique) = $switch->wiredeauthTechniques($SNMP::RADIUS, $WIRED_802_1X);
    is($method, $SNMP::RADIUS, 'wired 802.1X deauth resolves to RADIUS when asked for it');
    is($technique, 'deauthenticateMacRadius',
        'wired 802.1X RADIUS deauth is the per-session deauthenticateMacRadius');

    ($method, $technique) = $switch->wiredeauthTechniques($SNMP::RADIUS, $WIRED_MAC_AUTH);
    is($method, $SNMP::RADIUS, 'wired MAC auth deauth resolves to RADIUS when asked for it');
    is($technique, 'deauthenticateMacRadius',
        'wired MAC auth RADIUS deauth is the per-session deauthenticateMacRadius');

    # Sanity: the SNMP technique this replaces is the port-wide one.
    (undef, $technique) = $switch->wiredeauthTechniques($SNMP::SNMP, $WIRED_802_1X);
    is($technique, 'dot1xPortReauthenticate',
        'the SNMP technique it replaces is the port-wide dot1xPortReauthenticate');
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
