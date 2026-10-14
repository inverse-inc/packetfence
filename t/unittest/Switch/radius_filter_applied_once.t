#!/usr/bin/perl

=head1 NAME

radius_filter_applied_once

=head1 DESCRIPTION

The returnRadiusAccessAccept RADIUS filter must be evaluated exactly once per
Access-Accept, including for switch modules whose parent class also applies it
(#9135: every answer of the matching rule, e.g. the Cisco-AVPair ACLs, was
added twice)

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

use pf::access_filter::radius;

# child => parent, both overriding returnRadiusAccessAccept and applying the filter
my @classes = qw(
    pf::Switch::Cisco::Cisco_IOS_12_x
    pf::Switch::Cisco::Cisco_IOS_15_5
    pf::Switch::Cisco::Cisco_WLC_AireOS
    pf::Switch::Cisco::Cisco_WLC_IOS_XE
    pf::Switch::HP::AOS_Switch_v16_X
    pf::Switch::Aruba::2930M
    pf::Switch::Aruba::ArubaOS_Switch_16_x
    pf::Switch::Aruba::ArubaOS_CX_10_x
    pf::Switch::Aruba::5400
    pf::Switch::Hostapd
    pf::Switch::OpenWiFi
    pf::Switch::Ruckus::SmartZone
    pf::Switch::Ruckus::Unleashed
);

# Modules that answer by themselves only with external portal enforcement, and
# otherwise leave the answer, and the filter, to their parent
my @portal_classes = qw(
    pf::Switch::AeroHIVE::AP
    pf::Switch::Fortinet::FortiGate
    pf::Switch::Meraki::MR
    pf::Switch::Mojo
    pf::Switch::Xirrus
);

use Test::More;
plan tests => scalar(@classes) + 2 * scalar(@portal_classes) + 1;
use Test::NoWarnings;

# Minimal connection profile: the wireless modules ask it about DPSK
{
    package StubProfile;
    sub new { bless {}, shift }
    our $AUTOLOAD;
    sub AUTOLOAD { return 0 }
    sub DESTROY { }
}

my $calls = 0;
{
    no warnings 'redefine';
    *pf::access_filter::radius::test = sub { $calls++; return undef };
}

sub filter_calls {
    my ($class, $switch_args, %node_info) = @_;
    eval "require $class; 1" or die $@;
    my $switch = $class->new({
        id => '10.9.9.9', ip => '10.9.9.9',
        SNMPUseConnector => 'N', radiusDeauthUseConnector => 'N',
        %$switch_args,
    });
    $calls = 0;
    eval {
        $switch->returnRadiusAccessAccept({
            mac => '02:91:35:00:00:01',
            user_role => 'default',
            vlan => 1,
            connection_type => 4096,
            radius_request => {},
            node_info => \%node_info,
            switch => $switch,
            profile => StubProfile->new,
            ssid => 'test',
        });
    };
    diag($@) if $@;
    return $calls;
}

for my $class (@classes) {
    is(filter_calls($class, {}), 1, "$class evaluates the returnRadiusAccessAccept filter once");
}

# No role mapping: the role is irrelevant here
my %portal_switch_args = (RoleMap => 'N');
for my $class (@portal_classes) {
    is(filter_calls($class, \%portal_switch_args), 1, "$class evaluates the returnRadiusAccessAccept filter once");
}

{
    no warnings qw(redefine once);
    local *pf::Switch::externalPortalEnforcement = sub { 1 };
    local *pf::security_event::security_event_view_top = sub { undef };
    for my $class (@portal_classes) {
        is(
            filter_calls($class, \%portal_switch_args, status => 'reg', unregdate => '0000-00-00 00:00:00'),
            1,
            "$class evaluates the returnRadiusAccessAccept filter once with external portal enforcement"
        );
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
