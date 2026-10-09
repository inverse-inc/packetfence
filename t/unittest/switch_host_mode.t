#!/usr/bin/perl

=head1 NAME

switch_host_mode

=head1 DESCRIPTION

Unit tests for the per-switch C<host_mode> parameter:
  - pf::Switch::getHostMode / isMultiAuthPort defaults and parsing
  - pf::SwitchFactory::getSwitchConfig lookup through switch ranges
  - pf::locationlog::_is_multi_auth_switchport lookup
  - pf::Switch::wiredReevaluationDeauthTechnique selection on a multi-auth port
  - pf::locationlog::locationlog_synchronize keeping one entry per endpoint on a multi-auth port

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 47;
use Test::NoWarnings;

use pf::SwitchFactory;
use pf::locationlog;
use pf::Switch::constants;
use pf::constants::switch qw($HOST_MODE_SINGLE_HOST $HOST_MODE_MULTI_HOST $HOST_MODE_MULTI_AUTH);
use pf::config qw($WIRED_802_1X $WIRED_MAC_AUTH $VOIP $NO_VOIP);
use Utils;

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
# pf::Switch::wiredReevaluationDeauthTechnique
#
# pf::api::ReAssignVlan uses it so that a multi-auth port gets a CoA/Disconnect
# scoped to one endpoint through its Calling-Station-Id instead of a port bounce.
# ----------------------------------------------------------------------------

{
    # single-host: the configured deauthMethod is honoured as is
    my $switch = pf::SwitchFactory->instantiate('172.16.8.28');
    $switch->{_deauthMethod} = $SNMP::SNMP;
    is($switch->wiredReevaluationDeauthTechnique($WIRED_802_1X), 'dot1xPortReauthenticate',
        'single-host switch keeps its configured SNMP method: port-wide dot1xPortReauthenticate');

    # multi-auth: RADIUS is forced whatever the configured deauthMethod
    $switch = pf::SwitchFactory->instantiate('172.16.8.41');
    ok($switch->hasRadiusSecret(), 'the multi-auth test switch has a RADIUS shared secret');
    $switch->{_deauthMethod} = $SNMP::SNMP;
    is($switch->wiredReevaluationDeauthTechnique($WIRED_802_1X), 'deauthenticateMacRadius',
        'wired 802.1X on a multi-auth switch overrides SNMP with the per-session deauthenticateMacRadius');
    is($switch->wiredReevaluationDeauthTechnique($WIRED_MAC_AUTH), 'deauthenticateMacRadius',
        'wired MAC auth on a multi-auth switch uses the per-session deauthenticateMacRadius too');

    # multi-auth without a RADIUS shared secret: no CoA/Disconnect can be sent, so the
    # configured method is kept instead of silently failing in radiusDisconnect.
    {
        local $switch->{_radiusSecret} = '';
        ok(!$switch->hasRadiusSecret(), 'an empty radiusSecret counts as no shared secret');
        is($switch->wiredReevaluationDeauthTechnique($WIRED_802_1X), 'dot1xPortReauthenticate',
            'multi-auth switch without a RADIUS shared secret keeps its configured port-wide technique');
    }

    # multi-auth on a module without a RADIUS technique: the module default is used.
    # pf::Switch::wiredeauthTechniques only knows the SNMP techniques.
    {
        no warnings 'redefine';
        local *pf::Switch::Cisco::Cisco_IOS_15_0::wiredeauthTechniques = \&pf::Switch::wiredeauthTechniques;
        is($switch->wiredReevaluationDeauthTechnique($WIRED_802_1X), 'dot1xPortReauthenticate',
            'multi-auth switch without a RADIUS technique falls back on the module default');

        # ... and when the module has no technique at all, undef is returned rather
        # than an undef method name for pf::api::ReAssignVlan to call.
        is($switch->wiredReevaluationDeauthTechnique($WIRED_802_1X | 0x1000000), undef,
            'no technique for the connection type returns undef');
    }
}

# ----------------------------------------------------------------------------
# pf::locationlog::locationlog_synchronize
#
# Two endpoints with different roles on the same port: on a multi-auth switch
# both keep their open entry, on a multi-host switch the second closes the first.
# ----------------------------------------------------------------------------

{
    my $ifIndex = 10000 + int(rand(10000));

    my $sync = sub {
        my ($switch, $mac, $role, $voip_status, $multi_auth) = @_;
        return pf::locationlog::locationlog_synchronize(
            $switch, $switch, undef, $ifIndex, 10, $mac, $voip_status, $WIRED_802_1X,
            undef, $mac, undef, undef, undef, $role, undef, $switch, $multi_auth,
        );
    };

    # multi-auth, host mode passed by the caller as pf::Switch::synchronize_locationlog does
    my $mac1 = Utils::test_mac();
    my $mac2 = Utils::test_mac();
    ok($sync->('172.16.8.41', $mac1, 'default', $NO_VOIP, 1), "synchronized $mac1 on the multi-auth switch");
    ok($sync->('172.16.8.41', $mac2, 'guest', $NO_VOIP, 1), "synchronized $mac2 on the same port");
    my @open = pf::locationlog::locationlog_view_open_switchport_no_VoIP('172.16.8.41', $ifIndex);
    is_deeply([sort map { $_->{mac} } @open], [sort $mac1, $mac2],
        'both endpoints keep an open locationlog entry on the multi-auth port');

    # multi-auth, host mode resolved from the switch configuration (RPC path)
    my $mac3 = Utils::test_mac();
    ok($sync->('172.16.8.41', $mac3, 'voice', $NO_VOIP, undef), "synchronized $mac3 without the host mode");
    @open = pf::locationlog::locationlog_view_open_switchport_no_VoIP('172.16.8.41', $ifIndex);
    is(scalar @open, 3, 'the host mode is resolved from the configuration when the caller does not pass it');

    # a VoIP status change replaces the endpoint's own entry
    ok($sync->('172.16.8.41', $mac1, 'default', $VOIP, 1), "synchronized $mac1 again as a phone");
    my $entry = pf::locationlog::locationlog_view_open_mac($mac1);
    is($entry->{voip}, $VOIP, 'the VoIP status change is recorded on the multi-auth port');
    @open = pf::locationlog::locationlog_view_open_switchport_no_VoIP('172.16.8.41', $ifIndex);
    is(scalar @open, 2, 'the other endpoints are left untouched');

    # multi-host: the second endpoint with another role closes the first
    my $mac4 = Utils::test_mac();
    my $mac5 = Utils::test_mac();
    ok($sync->('172.16.8.42', $mac4, 'default', $NO_VOIP, 0), "synchronized $mac4 on the multi-host switch");
    ok($sync->('172.16.8.42', $mac5, 'guest', $NO_VOIP, 0), "synchronized $mac5 on the same port");
    @open = pf::locationlog::locationlog_view_open_switchport_no_VoIP('172.16.8.42', $ifIndex);
    is_deeply([map { $_->{mac} } @open], [$mac5],
        'only the last endpoint keeps an open locationlog entry on the multi-host port');
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
