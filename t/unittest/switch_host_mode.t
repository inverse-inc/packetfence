#!/usr/bin/perl

=head1 NAME

switch_host_mode

=head1 DESCRIPTION

Unit tests for the per-switch C<host_mode> parameter:
  - pf::Switch::getHostMode / isMultiAuthPort defaults and parsing
  - pf::SwitchFactory::getSwitchConfig lookup through switch ranges
  - pf::locationlog::_is_multi_auth_switchport lookup
  - pf::Switch::wiredReevaluationDeauthTechniques selection on a multi-auth port

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 39;
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
# pf::SwitchFactory::getSwitchConfig
#
# The locationlog stores the switch IP, which is not the switches.conf key when
# the switch is matched through a range: the lookup must resolve ranges.
# ----------------------------------------------------------------------------

{
    my ($switch_id, $switch_config) = pf::SwitchFactory::getSwitchConfig('172.16.8.41');
    is($switch_id, '172.16.8.41',
        'getSwitchConfig returns the section id of a switch configured by IP');
    is($switch_config->{host_mode}, $HOST_MODE_MULTI_AUTH,
        'getSwitchConfig returns that section configuration');

    # 172.16.43.0/24 is nested in 172.16.0.0/16: the most specific range must win.
    ($switch_id, $switch_config) = pf::SwitchFactory::getSwitchConfig('172.16.43.5');
    is($switch_id, '172.16.43.0/24',
        'getSwitchConfig resolves an IP to the most specific switch range covering it');
    is($switch_config->{host_mode}, $HOST_MODE_MULTI_AUTH,
        'the range configuration carries its host_mode');

    is_deeply([pf::SwitchFactory::getSwitchConfig('10.255.255.1')], [],
        'getSwitchConfig returns nothing for an IP outside every range');
    is_deeply([pf::SwitchFactory::getSwitchConfig(undef)], [],
        'getSwitchConfig returns nothing without an identifier');

    # Several identifiers: section names win over ranges, and the matched one is returned.
    my $matched;
    ($switch_id, $switch_config, $matched) = pf::SwitchFactory::getSwitchConfig(undef, '', '172.16.43.5', '172.16.8.41');
    is($switch_id, '172.16.8.41',
        'getSwitchConfig prefers an identifier that is a section name over one covered by a range');
    is($matched, '172.16.8.41', 'getSwitchConfig returns the identifier that matched');
    ($switch_id, undef, $matched) = pf::SwitchFactory::getSwitchConfig('no.such.switch', '172.16.43.5');
    is($switch_id, '172.16.43.0/24', 'getSwitchConfig falls back on the ranges for the remaining identifiers');
    is($matched, '172.16.43.5', 'getSwitchConfig returns the IP that matched the range');

    my $switch = pf::SwitchFactory->instantiate('172.16.43.5');
    ok($switch && $switch->isMultiAuthPort(),
        'a switch instantiated through the range is multi-auth');
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
    ok(pf::locationlog::_is_multi_auth_switchport('172.16.43.5'),
        '_is_multi_auth_switchport resolves an IP through a multi-auth switch range');
}

# ----------------------------------------------------------------------------
# pf::Switch::wiredReevaluationDeauthTechniques
#
# pf::api::ReAssignVlan uses it so that a multi-auth port gets a CoA/Disconnect
# scoped to one endpoint through its Calling-Station-Id instead of a port bounce.
# ----------------------------------------------------------------------------

{
    # single-host: the configured deauthMethod is honoured as is
    my $switch = pf::SwitchFactory->instantiate('172.16.8.28');
    $switch->{_deauthMethod} = $SNMP::SNMP;
    my ($method, $technique) = $switch->wiredReevaluationDeauthTechniques($WIRED_802_1X, 1);
    is($method, $SNMP::SNMP, 'single-host switch keeps its configured SNMP deauth method');
    is($technique, 'dot1xPortReauthenticate',
        'single-host switch uses the port-wide dot1xPortReauthenticate');

    # multi-auth: RADIUS is forced whatever the configured deauthMethod
    $switch = pf::SwitchFactory->instantiate('172.16.8.41');
    $switch->{_deauthMethod} = $SNMP::SNMP;
    ($method, $technique) = $switch->wiredReevaluationDeauthTechniques($WIRED_802_1X, 1);
    is($method, $SNMP::RADIUS, 'multi-auth switch overrides the SNMP deauth method with RADIUS');
    is($technique, 'deauthenticateMacRadius',
        'wired 802.1X on a multi-auth switch uses the per-session deauthenticateMacRadius');

    ($method, $technique) = $switch->wiredReevaluationDeauthTechniques($WIRED_MAC_AUTH, 1);
    is($method, $SNMP::RADIUS, 'multi-auth switch uses RADIUS for wired MAC auth too');
    is($technique, 'deauthenticateMacRadius',
        'wired MAC auth on a multi-auth switch uses the per-session deauthenticateMacRadius');

    # multi-auth without a RADIUS shared secret: no CoA/Disconnect can be sent, so the
    # configured method is kept instead of silently failing in radiusDisconnect.
    {
        local $switch->{_radiusSecret} = '';
        ($method, $technique) = $switch->wiredReevaluationDeauthTechniques($WIRED_802_1X, 1);
        is($method, $SNMP::SNMP,
            'multi-auth switch without a RADIUS shared secret keeps its configured deauth method');
        is($technique, 'dot1xPortReauthenticate',
            'the fallback without a shared secret is the port-wide technique');
    }

    # multi-auth on a module without a RADIUS technique: the module default is used.
    # pf::Switch::wiredeauthTechniques only knows the SNMP techniques.
    {
        no warnings 'redefine';
        local *pf::Switch::Cisco::Cisco_IOS_15_0::wiredeauthTechniques = \&pf::Switch::wiredeauthTechniques;
        ($method, $technique) = $switch->wiredReevaluationDeauthTechniques($WIRED_802_1X, 1);
        is($method, $SNMP::SNMP,
            'multi-auth switch without a RADIUS technique falls back on the module default');
        is($technique, 'dot1xPortReauthenticate',
            'the fallback is the port-wide technique');

        # ... and when the module has no technique at all, nothing is returned rather
        # than an undef method name for pf::api::ReAssignVlan to call.
        is_deeply([$switch->wiredReevaluationDeauthTechniques($WIRED_802_1X | 0x1000000, 1)], [],
            'no technique for the connection type returns an empty list');
    }
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
