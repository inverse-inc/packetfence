#!/usr/bin/perl

=head1 NAME

push_acls_vlan_role

=head1 DESCRIPTION

The Access-Accept of the Aruba modules carries the VLAN and the role together:
a reply that returns a VLAN used to be rebuilt from the VLAN alone, which
dropped the role, the pushed role with Push ACLs (#9648). With Push ACLs the
reply names the role of the Role Map (pf-role-<role>, as the push creates it on
the controller), and no role without a mapping.

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

use Test::More tests => 17;
use pf::access_filter::radius;
use pf::Switch::Aruba;
use pf::Switch::Aruba::Controller_200;
use pf::Switch::Aruba::Mobility_Master;

#This test will running last
use Test::NoWarnings;

# Minimal connection profile, for the DPSK check of the Aruba reply
{
    package StubProfile;
    sub new { bless {}, shift }
    our $AUTOLOAD;
    sub AUTOLOAD { return 0 }
    sub DESTROY { }
}

# No RADIUS filter rule: only the reply of the module is tested
{
    no warnings 'redefine';
    *pf::access_filter::radius::test = sub { return undef };
}

my $mac = '02:91:35:00:00:02';
my %base_args = (
    id => '10.9.9.10', ip => '10.9.9.10',
    SNMPUseConnector => 'N', radiusDeauthUseConnector => 'N',
    RoleMap => 'Y', VlanMap => 'Y',
);

sub reply_of {
    my ($class, $switch_args, %request) = @_;
    my $switch = $class->new({ %base_args, %$switch_args });
    my $reply = $switch->returnRadiusAccessAccept({
        mac => $mac,
        user_role => 'r4',
        connection_type => 4096,
        radius_request => {},
        node_info => { mac => $mac, bypass_acls => undef },
        switch => $switch,
        profile => StubProfile->new,
        ssid => 'test',
        %request,
    });
    my ($status, %attributes) = @$reply;
    return ($switch, \%attributes);
}

# With Push ACLs the reply names the role the Role Map maps the PacketFence role
# to (pf-role-<role>, the role the push creates on the controller), and no
# role without a mapping
my %map = (roles => { r4 => 'pf-role-r4' });
foreach my $class ('pf::Switch::Aruba::Controller_200', 'pf::Switch::Aruba::Mobility_Master') {
    my ($switch, $reply) = reply_of($class, { UsePushACLs => 'Y', %map }, vlan => 10);
    is($reply->{ $switch->returnRoleAttribute }, 'pf-role-r4', "$class with Push ACLs and a VLAN: the mapped role is named");
    is($reply->{'Tunnel-Private-Group-ID'}, '10', "$class with Push ACLs and a VLAN: the VLAN is returned");
    ($switch, $reply) = reply_of($class, { UsePushACLs => 'Y', %map });
    is($reply->{ $switch->returnRoleAttribute }, 'pf-role-r4', "$class with Push ACLs and no VLAN: the mapped role is named");
    ($switch, $reply) = reply_of($class, { UsePushACLs => 'Y' }, vlan => 10);
    ok(!exists $reply->{ $switch->returnRoleAttribute }, "$class with Push ACLs and no Role Map entry: no role is named");
    is($reply->{'Tunnel-Private-Group-ID'}, '10', "$class with Push ACLs and no Role Map entry: the VLAN is still returned");
    ($switch, $reply) = reply_of($class, { UsePushACLs => 'Y', %map }, node_info => { mac => $mac, bypass_acls => 'permit ip any host 10.99.99.99' });
    is($reply->{ $switch->returnRoleAttribute }, 'pf-role-r4', "$class with Push ACLs: the bypass ACLs cannot be sent, the mapped role stays named");
}

# Without Push ACLs the role of the Role Map is sent next to the VLAN, as before
{
    my ($switch, $reply) = reply_of('pf::Switch::Aruba', { roles => { r4 => 'mapped-r4' } }, vlan => 10);
    is($reply->{ $switch->returnRoleAttribute }, 'mapped-r4', "Aruba without Push ACLs: the role of the Role Map is named");
    is($reply->{'Tunnel-Private-Group-ID'}, '10', "Aruba without Push ACLs: the VLAN is returned with it");
    ($switch, $reply) = reply_of('pf::Switch::Aruba', {}, vlan => 10);
    ok(!exists $reply->{ $switch->returnRoleAttribute }, "Aruba without Push ACLs and no Role Map entry: no role is named");
    ($switch, $reply) = reply_of('pf::Switch::Aruba', { roles => { r4 => 'mapped-r4' }, VlanMap => 'N' }, vlan => 10);
    ok(!exists $reply->{'Tunnel-Private-Group-ID'}, "Aruba with the VLAN Map off: no VLAN is returned");
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

