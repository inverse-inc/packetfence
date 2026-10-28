#!/usr/bin/perl

=head1 NAME

PushACLs

=head1 DESCRIPTION

unit test for the Push ACLs of pf::Switch::Meraki::MS: the ACLs of a role
become the Layer 3 firewall rules of the group policy named after the role,
and Filter-Id names a group policy that exists

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

use Test::More tests => 30;
use Test::MockModule;
use pf::Switch::Meraki::MS;
use pf::Switch::Meraki::MS_v15;

#This test will running last
use Test::NoWarnings;

my %args = (id => 'test', ip => '1.1.1.1', SNMPUseConnector => "N", radiusDeauthUseConnector => "N");
my $switch = pf::Switch::Meraki::MS_v15->new({%args, UsePushACLs => 'Y'});
my $no_push = pf::Switch::Meraki::MS_v15->new({%args});

ok($switch->supportsPushACLs, "the MS modules support Push ACLs");
ok($switch->usePushACLs, "Push ACLs is enabled on the switch");

# the role ACLs are read for the push through getRoleAccessListByName
sub rules {
    my ($acl) = @_;
    local $switch->{_aclsForPush} = 1;
    return $switch->acl_chewer($acl, 'testrole');
}

sub rule {
    my ($policy, $protocol, $port, $cidr, $comment) = @_;
    return { policy => $policy, protocol => $protocol, destPort => $port, destCidr => $cidr, comment => $comment };
}

my $implicit_deny = rule('deny', 'any', 'any', 'any', 'PacketFence role testrole: implicit deny');

is_deeply(
    rules("permit tcp any host 10.0.0.1 eq 443"),
    [rule('allow', 'tcp', '443', '10.0.0.1/32', 'PacketFence role testrole: permit tcp any host 10.0.0.1 eq 443'), $implicit_deny],
    "a host becomes a /32, the port is kept, the rules end with a deny of everything"
);

is_deeply(
    rules("permit udp any 10.1.0.0 0.0.255.255 range 1000 2000\ndeny ip any any"),
    [
        rule('allow', 'udp', '1000-2000', '10.1.0.0/16', 'PacketFence role testrole: permit udp any 10.1.0.0 0.0.255.255 range 1000 2000'),
        rule('deny', 'any', 'any', 'any', 'PacketFence role testrole: deny ip any any'),
    ],
    "a wildcard becomes a prefix, a range a port range, an explicit deny all is not doubled"
);

is_deeply(
    rules("permit tcp any host 10.0.0.1 eq www\npermit udp any any eq domain\npermit ip any any"),
    [
        rule('allow', 'tcp', '80', '10.0.0.1/32', 'PacketFence role testrole: permit tcp any host 10.0.0.1 eq www'),
        rule('allow', 'udp', '53', 'any', 'PacketFence role testrole: permit udp any any eq domain'),
        rule('allow', 'any', 'any', 'any', 'PacketFence role testrole: permit ip any any'),
    ],
    "service names become port numbers, a final permit all is kept as is"
);

is_deeply(
    rules("permit icmp any any\npermit tcp any any"),
    [
        rule('allow', 'icmp', 'any', 'any', 'PacketFence role testrole: permit icmp any any'),
        rule('allow', 'tcp', 'any', 'any', 'PacketFence role testrole: permit tcp any any'),
        $implicit_deny,
    ],
    "a protocol without a port matches any port, a permit of one protocol is not a permit of everything"
);

is_deeply(
    rules("permit tcp any host 10.0.0.1 eq 443\npermit tcp any host 10.0.0.1 eq 443 dscp ef"),
    [rule('allow', 'tcp', '443', '10.0.0.1/32', 'PacketFence role testrole: permit tcp any host 10.0.0.1 eq 443'), $implicit_deny],
    "a permit the rules cannot express is skipped"
);

# what a group policy rule cannot match: a permit is skipped, alone it leaves a
# deny of everything, never no rule at all

my $deny_all = [rule('deny', 'any', 'any', 'any', 'PacketFence role testrole: deny ip any any')];

is_deeply(rules("permit ip host 10.1.1.1 any"), $deny_all, "a source address is not dropped into a permit from any");
is_deeply(rules("permit udp any eq 53 any"), $deny_all, "a source port is not dropped");
is_deeply(rules("permit tcp any any gt 1024"), $deny_all, "gt is not turned into eq or dropped");
is_deeply(rules("permit tcp any any established"), $deny_all, "TCP flags are not dropped");
is_deeply(rules("permit icmp any any echo"), $deny_all, "an ICMP type is not dropped");
is_deeply(rules("permit 47 any any"), $deny_all, "a protocol a rule cannot match is not sent as any");
is_deeply(rules("permit tcp any any eq nosuchservice"), $deny_all, "a port without a number is not dropped");
is_deeply(rules("permit ip any 10.0.0.0 0.255.0.255"), $deny_all, "a non contiguous mask is not sent as a prefix");
is_deeply(rules("accept any any"), $deny_all, "ACLs that cannot be parsed deny everything");

is_deeply(
    rules("deny tcp any any gt 1024\npermit ip any any"),
    $deny_all,
    "a deny that cannot be expressed ends the rules with a deny of everything"
);

is_deeply(
    rules("out|permit tcp any any eq 443\npermit udp any any eq 53"),
    [rule('allow', 'udp', '53', 'any', 'PacketFence role testrole: permit udp any any eq 53'), $implicit_deny],
    "the out ACLs are not pushed: the rules filter the traffic the client sends"
);

is_deeply(
    rules("out|permit tcp any any eq 443"),
    [rule('allow', 'any', 'any', 'any', 'PacketFence role testrole: no in ACL')],
    "a role with out ACLs only does not restrict the traffic the client sends"
);

is($switch->pushAclsName('guest', 'in'), 'guest', "the group policy is named after the role");
is($switch->pushAclsName('guest', 'out'), undef, "no out group policy");

is($switch->acl_chewer("permit tcp any any", 'testrole'), "permit tcp any any", "outside of the push the ACLs are returned as they are");

# getRoleAccessListByName (the push) gives the rules of the roles of roles.conf

{
    my $dal = Test::MockModule->new('pf::dal::switch_observability_acls');
    $dal->mock(remove_items => sub { 1 });
    $dal->mock(upsert => sub { 1 });
    is_deeply(
        $switch->getRoleAccessListByName('r4'),
        [rule('allow', 'tcp', 'any', 'any', 'PacketFence role r4: permit tcp any any'), rule('deny', 'any', 'any', 'any', 'PacketFence role r4: implicit deny')],
        "getRoleAccessListByName gives the rules of the group policy"
    );
    is($switch->getRoleAccessListByName('normal'), undef, "a role without ACLs gets no group policy");
}

# Filter-Id: the switch drops the traffic of a client whose Filter-Id matches no
# group policy, so a role without ACLs (no group policy) gets no Filter-Id

is_deeply([$switch->returnRoleAttributes('r4')], ['Filter-Id', 'r4'], "Push ACLs: Filter-Id names the group policy of a role with ACLs");
is_deeply([$switch->returnRoleAttributes('normal')], [], "Push ACLs: no Filter-Id for a role without ACLs");
is_deeply([$switch->returnRoleAttributes('manual-group-policy')], ['Filter-Id', 'manual-group-policy'], "Push ACLs: a value that is not a role is sent as is");
is_deeply([$no_push->returnRoleAttributes('normal')], ['Filter-Id', 'normal'], "without Push ACLs the role is sent unchanged");

{
    my $disabled = pf::Switch::Meraki::MS->new({%args, UsePushACLs => 'Y', r4AccessListEnabled => 'N'});
    is_deeply([$disabled->returnRoleAttributes('r4')], [], "Push ACLs: no Filter-Id for a role whose ACLs are disabled on the switch, its group policy is deleted");
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
