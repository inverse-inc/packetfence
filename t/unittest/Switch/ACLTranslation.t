#!/usr/bin/perl

=head1 NAME

ACLTranslation

=cut

=head1 DESCRIPTION

unit test for the translation of role ACLs into switch ACLs: an ACL the switch
format cannot express must never widen the role

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

use Test::More tests => 100;
use Test::MockModule;
use pf::Switch;
use pf::Switch::Aruba::ArubaOS_CX_10_x;
use pf::Switch::Arista::AristaSwitch;
use pf::Switch::HP::AOS_Switch_v16_X;
use pf::Switch::Cisco::Cisco_IOS_15_5;
use pf::Switch::Fortinet::FortiSwitchOS_v7_x;
use pf::Switch::Dell::N1500;

#This test will running last
use Test::NoWarnings;

my %args = (id => 'test', ip => '1.1.1.1', SNMPUseConnector => "N", radiusDeauthUseConnector => "N");
my $aruba = pf::Switch::Aruba::ArubaOS_CX_10_x->new({%args});
my $arista = pf::Switch::Arista::AristaSwitch->new({%args});
my $aos = pf::Switch::HP::AOS_Switch_v16_X->new({%args});
my $cisco = pf::Switch::Cisco::Cisco_IOS_15_5->new({%args});
my $forti = pf::Switch::Fortinet::FortiSwitchOS_v7_x->new({%args});
my $dell = pf::Switch::Dell::N1500->new({%args});

sub chew {
    my ($switch, $acl) = @_;
    return $switch->acl_chewer($acl, 'testrole') // '';
}

# What a switch gets when none of the ACLs of a role can be sent: a deny of
# everything, in the format of the module, never no ACL at all, which would
# leave the device unrestricted.
sub deny_all {
    my ($switch) = @_;
    return chew($switch, "deny ip any any");
}

# NAS-Filter-Rule: what can be expressed

is(chew($aruba, "permit tcp any host 10.0.0.1 eq 443"), "in|permit in tcp from any to 10.0.0.1 443\n", "Aruba CX: eq port");
is(chew($arista, "permit tcp any host 10.0.0.1 eq 443"), "in|permit in 6 from any to 10.0.0.1 443\n", "Arista: eq port");
is(chew($aos, "permit tcp any host 10.0.0.1 eq 443"), "in|permit in tcp from any to 10.0.0.1 443\n", "AOS: the destination port is sent, it used to be dropped");
is(chew($aruba, "permit tcp any any range 100 200"), "in|permit in tcp from any to any 100-200\n", "Aruba CX: a range becomes a port range");

# NAS-Filter-Rule: a permit that cannot be expressed is skipped. Alone, it leaves
# nothing to send, so the role is denied everything rather than unrestricted.

is(
    chew($aruba, "permit tcp any any gt 1024"),
    "in|deny in ip from any to any \n",
    "Aruba CX: a role whose ACLs are all skipped is denied everything, not sent no ACL"
);

foreach my $switch ([$aruba, 'Aruba CX'], [$arista, 'Arista'], [$aos, 'AOS']) {
    my ($s, $name) = @$switch;
    is(chew($s, "permit ip host 10.1.1.1 any"), deny_all($s), "$name: a source address is not dropped into a permit from any");
    is(chew($s, "permit udp any eq 53 any"), deny_all($s), "$name: a source port is not dropped into a permit of every port");
    is(chew($s, "permit tcp any any gt 1024"), deny_all($s), "$name: gt is not turned into eq or dropped");
    is(chew($s, "permit icmp any any echo"), deny_all($s), "$name: an ICMP type is not dropped into a permit of all ICMP");
    is(
        chew($s, "permit tcp any any established\npermit ip any host 8.8.8.8"),
        chew($s, "permit ip any host 8.8.8.8"),
        "$name: only the permit that cannot be expressed is skipped"
    );
}

is(chew($arista, "permit tcp any any range 100 200"), deny_all($arista), "Arista: a range is not sent as two bare ports");

# NAS-Filter-Rule: a deny that cannot be expressed ends the ACLs with a deny all

is(
    chew($aruba, "permit udp any any eq 53\ndeny ip host 10.1.1.1 any\npermit ip any any"),
    "in|permit in udp from any to any 53\nin|deny in ip from any to any \n",
    "Aruba CX: the permit after the deny does not allow what it blocks"
);
is(
    chew($arista, "deny tcp any any established\npermit ip any any"),
    "in|deny in ip from any to any \n",
    "Arista: a deny with TCP flags ends the ACLs with a deny all"
);
is(
    chew($aos, "deny udp any eq 53 any\npermit ip any any"),
    "in|deny in ip from any to any \n",
    "AOS: a deny with a source port ends the ACLs with a deny all"
);

# a non contiguous mask has no prefix length, it used to kill the translation

foreach my $switch ([$aruba, 'Aruba CX'], [$arista, 'Arista'], [$aos, 'AOS'], [$forti, 'FortiSwitch']) {
    my ($s, $name) = @$switch;
    is(chew($s, "permit ip any 10.0.0.0 0.255.0.255"), deny_all($s), "$name: a non contiguous mask is skipped instead of dying");
}

is($cisco->aclWildcardIsContiguous('0.0.0.255'), 1, "a wildcard is contiguous");
is($cisco->aclWildcardIsContiguous('255.255.255.0'), 1, "a netmask is contiguous");
is($cisco->aclWildcardIsContiguous('0.0.0.0'), 1, "a host mask is contiguous");
is($cisco->aclWildcardIsContiguous('255.255.255.255'), 1, "an any mask is contiguous");
is($cisco->aclWildcardIsContiguous('0.255.0.255'), 0, "0.255.0.255 is not contiguous");

# Cisco: Cisco syntax, the source is sent as any and replaced by the endpoint

is(chew($cisco, "permit tcp any host 10.0.0.1 eq 443"), "in|permit tcp any host 10.0.0.1 eq 443\n", "Cisco: host and port");
is(chew($cisco, "permit tcp any any gt 1024"), "in|permit tcp any any gt 1024\n", "Cisco: port operators are sent");
is(chew($cisco, "permit tcp any any established"), "in|permit tcp any any  established\n", "Cisco: TCP flags are sent");
is(chew($cisco, "permit ip any 10.0.0.0 0.255.0.255"), "in|permit ip any 10.0.0.0 0.255.0.255\n", "Cisco: a non contiguous wildcard is sent as is");
is(chew($cisco, "permit ip host 10.1.1.1 any"), deny_all($cisco), "Cisco: a source address is not replaced by the endpoint");
is(chew($cisco, "permit udp any eq 53 any"), deny_all($cisco), "Cisco: a source port is not dropped");
is(chew($cisco, "permit icmp any any echo"), deny_all($cisco), "Cisco: an ICMP type is not dropped");
is(chew($cisco, "deny ip host 10.1.1.1 any\npermit ip any any"), "in|deny ip any any\n", "Cisco: a deny that cannot be sent ends the ACLs with a deny all");

# FortiSwitch: NAS-Filter-Rule with the source address

is(chew($forti, "permit ip host 10.1.1.1 any"), "permit in ip from 10.1.1.1/32 to any\n", "FortiSwitch: the source address is sent");
is(chew($forti, "permit tcp any any range 100 200"), "permit in tcp from any to any 100-200\n", "FortiSwitch: a range becomes a port range");
is(chew($forti, "permit tcp any any gt 1024"), deny_all($forti), "FortiSwitch: gt is not turned into eq");
is(chew($forti, "permit tcp any any neq 22"), deny_all($forti), "FortiSwitch: neq is not turned into eq");
is(chew($forti, "permit udp any eq 53 any"), deny_all($forti), "FortiSwitch: a source port is not dropped");
is(chew($forti, "deny tcp any any established\npermit ip any any"), "deny in ip from any to any\n", "FortiSwitch: a deny with TCP flags ends the ACLs with a deny all");

# Dell N1500: only a destination host is sent

is(chew($dell, "permit tcp any host 10.0.0.1 eq 443"), "in|permit tcp any host 10.0.0.1 eq 443\n", "Dell N1500: the direction has its separator, the line used to be dropped");
is(chew($dell, "permit ip any 10.0.0.0 0.0.0.255"), deny_all($dell), "Dell N1500: a network is not turned into a host");
is(chew($dell, "permit ip host 10.1.1.1 any"), deny_all($dell), "Dell N1500: a source address is not dropped");
is(chew($dell, "permit tcp any any established"), deny_all($dell), "Dell N1500: TCP flags are not dropped");
is(chew($dell, "deny ip any 10.0.0.0 0.0.0.255\npermit ip any any"), "in|deny ip any any \n", "Dell N1500: a deny of a network ends the ACLs with a deny all");
is_deeply(
    [$dell->returnAccessListAttribute(101, "in|permit tcp any host 10.0.0.1 eq 443")],
    [1, "ip:inacl#101=permit tcp any host 10.0.0.1 eq 443"],
    "Dell N1500: the attribute carries the ACL, it used to be ip:inacl#101 alone"
);

# push ACLs carry the full Cisco syntax, only what is not sent is filtered

is($aruba->untranslatablePushAcl({ source => {}, destination => {}, tcp_flags => 'established' }) // '', "TCP flags are not supported ('established')", "Aruba CX push: TCP flags");
is($aruba->untranslatablePushAcl({ source => { port => 'eq 53' }, destination => {} }) // '', "the source port is not sent", "Aruba CX push: source port");
ok(!defined $aruba->untranslatablePushAcl({ source => {}, destination => { port => 'range 100 200' } }), "Aruba CX push: the destination port is sent as is");
ok(!defined $arista->_untranslatablePushAcl({ source => {}, destination => {}, tcp_flags => 'established' }), "Arista push: TCP flags are sent");

# filterUntranslatableAcls: the cut only applies to the direction of the deny

my $any = { ipv4_addr => '0.0.0.0', wildcard => '255.255.255.255' };
my ($entries, @direction) = pf::Switch::filterUntranslatableAcls(
    $aruba,
    { packetfence => { entries => [
        { action => 'deny',   protocol => 'tcp(6)', source => $any, destination => $any, bad => 1 },
        { action => 'permit', protocol => 'ip()',   source => $any, destination => $any },
        { action => 'permit', protocol => 'ip()',   source => $any, destination => $any },
    ] } },
    ['out', 'out', 'in'],
    'testrole',
    sub { $_[0]->{bad} ? 'bad' : undef },
);
is_deeply(
    [map { "$direction[$_] $entries->[$_]{action} $entries->[$_]{protocol}" } 0 .. $#$entries],
    ['out deny ip()', 'in permit ip()'],
    "an outbound cut drops the outbound ACLs after it and keeps the inbound ones"
);

($entries, @direction) = pf::Switch::filterUntranslatableAcls(
    $aruba,
    { packetfence => { entries => [
        { action => 'permit', protocol => 'tcp(6)', source => $any, destination => $any, bad => 1 },
        { action => 'permit', protocol => 'ip()',   source => $any, destination => $any },
        { action => 'permit', protocol => 'tcp(6)', source => $any, destination => $any, bad => 1 },
    ] } },
    ['in', 'out', 'in'],
    'testrole',
    sub { $_[0]->{bad} ? 'bad' : undef },
);
is_deeply(
    [map { "$direction[$_] $entries->[$_]{action} $entries->[$_]{protocol}" } 0 .. $#$entries],
    ['out permit ip()', 'in deny ip()'],
    "a direction whose ACLs were all skipped is denied everything, the other direction is kept"
);

($entries, @direction) = pf::Switch::filterUntranslatableAcls(
    $aruba,
    { packetfence => { entries => [
        { action => 'permit', protocol => 'tcp(6)', source => $any, destination => $any, bad => 1 },
        { action => 'permit', protocol => 'ip()',   source => $any, destination => $any },
    ] } },
    ['in', 'in'],
    'testrole',
    sub { $_[0]->{bad} ? 'bad' : undef },
);
is_deeply(
    [map { "$direction[$_] $entries->[$_]{action} $entries->[$_]{protocol}" } 0 .. $#$entries],
    ['in permit ip()'],
    "a direction that keeps an ACL gets no extra deny, the switch denies the rest"
);

($entries, @direction) = pf::Switch::filterUntranslatableAcls(
    $aruba,
    { packetfence => { entries => [
        { sequence_number => undef, evaluate => 'evaluate' },
        { action => 'permit', protocol => 'ip()', source => $any, destination => $any },
    ] } },
    ['in', 'in'],
    'testrole',
    sub { undef },
);
is_deeply(
    [map { "$direction[$_] $entries->[$_]{action} $entries->[$_]{protocol}" } 0 .. $#$entries],
    ['in permit ip()'],
    "an entry without action (evaluate) is skipped without warning, the ACLs after it are kept"
);

($entries, @direction) = pf::Switch::filterUntranslatableAcls($aruba, { packetfence => { entries => [] } }, [], 'testrole', sub { undef });
is_deeply($entries, [], "a role without ACLs gets none");

# Qualifiers the parser reads without returning them: the entry of
# "permit ip any any dscp ef" is the one of "permit ip any any"

foreach my $switch ($aruba, $arista, $aos, $cisco, $forti, $dell) {
    is(chew($switch, "permit ip any any dscp ef"), deny_all($switch), ref($switch).": a permit on a DSCP value is skipped, not sent as a permit of everything");
}
is(
    chew($aruba, "permit ip any any precedence 5\npermit tcp any host 10.0.0.1 eq 443\npermit ip any any time-range work"),
    "in|permit in tcp from any to 10.0.0.1 443\n",
    "Aruba CX: the permits on a precedence and a time range are skipped, the others are kept"
);
is(
    chew($aruba, "deny tcp any host 10.0.0.1 eq 80 fragments\npermit ip any any"),
    deny_all($aruba),
    "Aruba CX: a deny of fragments cuts the ACLs, the permit after it is not sent"
);
is(pf::Switch::untranslatableAclQualifier($aruba, { sequence_number => undef, evaluate => 'evaluate' }), "the ACL is not a permit or a deny", "an evaluate entry is not translated");

# ACLs the parser cannot read: it returns no entry at all

foreach my $switch ($aruba, $arista, $aos, $cisco, $forti, $dell) {
    is(chew($switch, "permit tcp any host 10.0.0.1 eq 443\npermit ip any any ttl eq 5"), deny_all($switch), ref($switch).": ACLs that cannot be parsed deny everything instead of sending nothing");
}

# Blank lines, whitespace-only lines and comments ('!') are ignored by the
# parser: they must not make the role a deny all, nor shift the direction of
# the ACLs after them (a CRLF blank line is a lone carriage return)
foreach my $switch ($aruba, $arista, $aos, $cisco, $forti, $dell) {
    is(
        chew($switch, "permit tcp any host 10.0.0.1 eq 443\n\n   \n!\n! comment\r\n\r\npermit ip any any"),
        chew($switch, "permit tcp any host 10.0.0.1 eq 443\npermit ip any any"),
        ref($switch).": blank and comment lines are ignored"
    );
}
{
    my ($acl_ref, @direction) = $aruba->format_acl("permit ip any host 10.0.0.1\n\n!\npermit ip any host 10.0.0.2");
    is(scalar(@direction), scalar(@{ $acl_ref->{packetfence}{entries} // [] }), "format_acl returns one direction per parsed ACL");
}

# An address 0.0.0.0 with another mask than any (host 0.0.0.0) is not sent as any
foreach my $switch ($aruba, $arista, $aos, $cisco, $forti, $dell) {
    is(
        chew($switch, "permit udp host 0.0.0.0 any eq 67\npermit udp any any eq 53"),
        chew($switch, "permit udp any any eq 53"),
        ref($switch).": host 0.0.0.0 as the source is skipped, not sent as any"
    );
}
is(
    chew($aruba, "permit ip any host 0.0.0.0\npermit udp any any eq 53"),
    chew($aruba, "permit udp any any eq 53"),
    "host 0.0.0.0 as the destination is skipped, not sent as any"
);

# A NAS-Filter-Rule takes a protocol number: a protocol without one is not sent as ip
foreach my $switch ($aruba, $arista, $aos, $forti) {
    is(
        chew($switch, "permit nos any any\npermit udp any any eq 53"),
        chew($switch, "permit udp any any eq 53"),
        ref($switch).": a protocol without a number (nos) is skipped, not sent as any protocol"
    );
}

# Push ACLs: the role ACLs read by getRoleAccessListByName (the Ansible push) are
# in the switch configuration format, the same role in a RADIUS reply is not.
# acl_chewer used to tell them apart by its caller and never saw the push one.

{
    my $dal = Test::MockModule->new('pf::dal::switch_observability_acls');
    $dal->mock(remove_items => sub { 1 });
    $dal->mock(upsert => sub { 1 });
    my %push_args = (%args, UsePushACLs => 'enabled');
    foreach my $switch (
        [pf::Switch::Aruba::ArubaOS_CX_10_x->new({%push_args}), 'Aruba CX', qr/^in\|1 permit tcp any any/m],
        [pf::Switch::Arista::AristaSwitch->new({%push_args}), 'Arista', qr/^10 permit tcp any any/m],
    ) {
        my ($s, $name, $push_format) = @$switch;
        like($s->getRoleAccessListByName('r4') // '', $push_format, "$name: getRoleAccessListByName gives the push format");
        like($s->acl_chewer("permit tcp any any", 'r4') // '', qr/permit in/, "$name: outside of the push, the RADIUS format");
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
