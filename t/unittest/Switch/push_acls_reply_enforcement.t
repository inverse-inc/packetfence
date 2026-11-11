#!/usr/bin/perl

=head1 NAME

push_acls_reply_enforcement

=head1 DESCRIPTION

With Push ACLs, the Access-Accept names the pushed role instead of carrying the
ACLs of the role, unless the reply carries an access list that replaces them
(the bypass ACLs of the node). Whatever the module, the reply must still
enforce something: the role it names, or the ACLs it carries. A reply with
neither leaves the device unrestricted.

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
use Test::MockModule;
use pf::access_filter::radius;
use pf::Switch;
use pf::Switch::Cisco::ASA;
use pf::Switch::Cisco::Cisco_IOS_12_x;
use pf::Switch::Cisco::Cisco_IOS_15_5;

#This test will running last
use Test::NoWarnings;

# Minimal connection profile, for the modules that ask it about DPSK
{
    package StubProfile;
    sub new { bless {}, shift }
    our $AUTOLOAD;
    sub AUTOLOAD { return 0 }
    sub DESTROY { }
}

# No database and no RADIUS filter rule: only the reply of the module is tested
my $observability = Test::MockModule->new('pf::dal::switch_observability_acls');
$observability->mock('remove_items', sub { 1 });
$observability->mock('new', sub { bless {}, 'pf::dal::switch_observability_acls' });
$observability->mock('upsert', sub { 1 });
my $switch_mock = Test::MockModule->new('pf::Switch');
$switch_mock->mock('node_view', sub { undef });
{
    no warnings 'redefine';
    *pf::access_filter::radius::test = sub { return undef };
}

my $mac = '02:91:35:00:00:01';
my $bypass = 'permit ip any host 10.99.99.99';

my %push_args = (
    id => '10.9.9.9', ip => '10.9.9.9',
    SNMPUseConnector => 'N', radiusDeauthUseConnector => 'N',
    UsePushACLs => 'Y', RoleMap => 'Y', AccessListMap => 'Y', VlanMap => 'Y',
);

sub reply_of {
    my ($class, $switch_args, %request) = @_;
    my $switch = $class->new({ %push_args, %$switch_args });
    my $reply = $switch->returnRadiusAccessAccept({
        mac => $mac,
        user_role => 'r4',
        vlan => 10,
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

# Every value of the reply, the lists of AV-pairs flattened
sub reply_values {
    my ($attributes) = @_;
    return join("\n", map { ref($_) eq 'ARRAY' ? @$_ : $_ } values %$attributes);
}

# The role attribute names the role, or its pushed ACL (r4.in on Cisco)
sub names_role {
    my ($switch, $attributes, $role) = @_;
    my $value = $attributes->{ $switch->returnRoleAttribute };
    return defined($value) && $value =~ /^\Q$role\E(?:\.(?:in|out))?$/;
}

# Controls: without bypass ACLs the pushed role is named, so the checks below
# can see a role
{
    my ($switch, $attributes) = reply_of('pf::Switch::Cisco::ASA', {});
    ok(names_role($switch, $attributes, 'r4'), "control: ASA without bypass ACLs names the pushed role");
    ($switch, $attributes) = reply_of('pf::Switch::Cisco::Cisco_IOS_12_x', {}, compute_acl => 0);
    ok(names_role($switch, $attributes, 'r4'), "control: Cisco_IOS_12_x without bypass ACLs names the pushed role");
}

# Cisco ASA outside the VPN path: the default returnRadiusAccessAccept of
# pf::Switch never adds the access list, while replyAccessListReplacesRole
# guesses it does from the Access List Map
{
    my ($switch, $attributes) = reply_of('pf::Switch::Cisco::ASA', {}, node_info => { mac => $mac, bypass_acls => $bypass });
    ok(
        names_role($switch, $attributes, 'r4') || reply_values($attributes) =~ /10\.99\.99\.99/,
        "ASA: a node with bypass ACLs gets the role or the bypass ACLs (got: "
            . join(', ', sort keys %$attributes) . ")"
    );
}

# A caller passing compute_acl => FALSE to a module that only sends the
# ACLs when compute_acl is set: Cisco_IOS_15_5 does it and sends them itself,
# Cisco_IOS_12_x does not
{
    my ($switch, $attributes) = reply_of('pf::Switch::Cisco::Cisco_IOS_15_5', {}, node_info => { mac => $mac, bypass_acls => $bypass });
    ok(reply_values($attributes) =~ /10\.99\.99\.99/, "Cisco_IOS_15_5: compute_acl off, the module still sends the bypass ACLs itself");
    ($switch, $attributes) = reply_of('pf::Switch::Cisco::Cisco_IOS_12_x', {}, node_info => { mac => $mac, bypass_acls => $bypass }, compute_acl => 0);
    ok(
        names_role($switch, $attributes, 'r4') || reply_values($attributes) =~ /10\.99\.99\.99/,
        "Cisco_IOS_12_x with compute_acl off: the reply names the role or carries the bypass ACLs (got: "
            . join(', ', sort keys %$attributes) . ")"
    );
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
