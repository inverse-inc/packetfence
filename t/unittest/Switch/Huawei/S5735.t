#!/usr/bin/perl

=head1 NAME

S5735

=cut

=head1 DESCRIPTION

unit test for S5735

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

use Test::More tests => 56;
use pf::Switch::Huawei::S5735;
use pf::Switch::Huawei::S5710;
use pf::config qw($WIRED_802_1X $WIRED_MAC_AUTH);
use pf::Switch::constants;

#This test will running last
use Test::NoWarnings;

my $switch = pf::Switch::Huawei::S5735->new({ id => 'test', ip => '1.1.1.1', SNMPUseConnector => "N", radiusDeauthUseConnector => "N" });

# acl_chewer: ACLs that translate to an HW-Data-Filter rule

is(
    $switch->acl_chewer("permit tcp any host 192.0.2.10 eq 443", 'testrole'),
    "permit tcp dst 192.0.2.10/32 443\n",
    "protocol, host destination and port become one rule"
);

is(
    $switch->acl_chewer("permit udp any any eq 53", 'testrole'),
    "permit udp dst any 53\n",
    "an any destination still emits the keyword when it carries a port"
);

is(
    $switch->acl_chewer("permit ip any host 8.8.8.8", 'testrole'),
    "permit dst 8.8.8.8/32\n",
    "the ip protocol matches anything so it emits no protocol keyword"
);

is(
    $switch->acl_chewer("permit ip any 10.0.0.0 0.0.0.255", 'testrole'),
    "permit dst 10.0.0.0/24\n",
    "a wildcard mask becomes a prefix length"
);

is(
    $switch->acl_chewer("permit ip host 10.1.1.1 host 10.2.2.2", 'testrole'),
    "permit src 10.1.1.1/32 dst 10.2.2.2/32\n",
    "source and destination are both carried in one rule"
);

is(
    $switch->acl_chewer("permit icmp any any", 'testrole'),
    "permit icmp\n",
    "an any to any rule keeps only the protocol"
);

is(
    $switch->acl_chewer("deny ip any any", 'testrole'),
    "deny\n",
    "a deny any any rule is the bare action"
);

is(
    $switch->acl_chewer("permit ip any any", 'testrole'),
    "permit\n",
    "a permit any any rule is the bare action"
);

is(
    $switch->acl_chewer("permit tcp host 10.0.0.1 eq 1024 host 10.0.0.2 eq 80", 'testrole'),
    "permit tcp src 10.0.0.1/32 1024 dst 10.0.0.2/32 80\n",
    "a port binds to the address it follows on both sides"
);

is(
    $switch->acl_chewer("permit igmp any host 224.0.0.1", 'testrole'),
    "permit igmp dst 224.0.0.1/32\n",
    "igmp has a keyword"
);

is(
    $switch->acl_chewer("permit tcp any host 10.0.0.1 eq 80\npermit tcp any host 10.0.0.1 eq 443", 'testrole'),
    "permit tcp dst 10.0.0.1/32 80\npermit tcp dst 10.0.0.1/32 443\n",
    "every line of a multi line access list is translated"
);

is(
    $switch->acl_chewer("in|permit ip any host 10.0.0.1", 'testrole'),
    "permit dst 10.0.0.1/32\n",
    "an explicit inbound direction is accepted"
);

# acl_chewer: ACLs that cannot be represented are dropped rather than sent in a
# form the switch could refuse, because one bad rule voids the whole access list

is(
    $switch->acl_chewer("out|permit ip any host 10.0.0.1", 'testrole'),
    "",
    "an outbound ACL is dropped: the attribute only filters traffic from the endpoint"
);

is(
    $switch->acl_chewer("permit gre any host 10.0.0.1\npermit ip any host 10.0.0.9", 'testrole'),
    "permit dst 10.0.0.9/32\n",
    "a protocol with no HW-Data-Filter keyword is dropped"
);

is(
    $switch->acl_chewer("permit tcp any host 10.0.0.1 range 80 443\npermit ip any host 10.0.0.9", 'testrole'),
    "permit dst 10.0.0.9/32\n",
    "a port range is dropped, only eq is supported"
);

is(
    $switch->acl_chewer("permit tcp any host 10.0.0.1 gt 1024\npermit ip any host 10.0.0.9", 'testrole'),
    "permit dst 10.0.0.9/32\n",
    "a port operator other than eq is dropped"
);

is(
    $switch->acl_chewer("permit ip any 10.0.0.0 0.0.255.0\npermit ip any host 10.0.0.9", 'testrole'),
    "permit dst 10.0.0.9/32\n",
    "a non contiguous wildcard mask has no prefix length and is dropped"
);

is(
    $switch->acl_chewer("permit tcp any any established\npermit ip any host 10.0.0.9", 'testrole'),
    "permit dst 10.0.0.9/32\n",
    "TCP flags have no keyword, dropping only the flag would permit every TCP packet"
);

is(
    $switch->acl_chewer("permit icmp any any echo\npermit ip any host 10.0.0.9", 'testrole'),
    "permit dst 10.0.0.9/32\n",
    "an ICMP type has no keyword, dropping only the type would permit every ICMP packet"
);

# Qualifiers the parser reads without returning them: the entry of
# "permit ip any any dscp ef" is the one of "permit ip any any"

is(
    $switch->acl_chewer("permit ip any any dscp ef\npermit ip any host 10.0.0.9", 'testrole'),
    "permit dst 10.0.0.9/32\n",
    "a permit on a DSCP value is dropped, not sent as a permit of everything"
);

is(
    $switch->acl_chewer("permit ip any any time-range work", 'testrole'),
    "deny\n",
    "a role whose only permit is on a time range is denied everything"
);

is(
    $switch->acl_chewer("deny tcp any host 10.0.0.1 eq 80 fragments\npermit ip any any", 'testrole'),
    "deny\n",
    "a deny of fragments cuts the access list"
);

# ACLs the parser cannot read: it returns no entry at all

is(
    $switch->acl_chewer("permit ip any host 10.0.0.9\npermit ip any any ttl eq 5", 'testrole'),
    "deny\n",
    "ACLs that cannot be parsed deny everything instead of sending no rule"
);

is_deeply(
    [$switch->_dataFilterRules("permit ip any host 10.0.0.9\npermit ip any any ttl eq 5\npermit ip any any", 'testrole')],
    ['$1 permit dst 10.0.0.9/32', '$2 deny'],
    "a line that cannot be parsed ends the access list with the catch all"
);

# acl_chewer: a deny that cannot be represented ends the access list with the
# catch all, skipping it would let the rules after it allow what it blocks

is(
    $switch->acl_chewer("permit udp any any eq 53\ndeny tcp any any gt 1024\npermit ip any any", 'testrole'),
    "permit udp dst any 53\ndeny\n",
    "a deny with a port operator other than eq cuts the access list"
);

is(
    $switch->acl_chewer("deny tcp any any established\npermit ip any any", 'testrole'),
    "deny\n",
    "a deny with TCP flags cuts the access list"
);

is(
    $switch->acl_chewer("out|deny ip any host 10.0.0.1\npermit ip any host 10.0.0.9", 'testrole'),
    "permit dst 10.0.0.9/32\n",
    "an outbound deny is only dropped, the attribute never enforces it"
);

# acl_chewer: a role whose ACLs are all dropped is denied everything, sending
# no rule at all would leave the endpoint unrestricted

is(
    $switch->acl_chewer("permit tcp any any gt 1024", 'testrole'),
    "deny\n",
    "a role whose ACLs are all dropped gets the catch all deny"
);

is(
    $switch->acl_chewer("#permit ip any any", 'testrole'),
    "",
    "a role without any ACL entry still gets no access list"
);

# _dataFilterRules: numbering, the catch all, and the rule budget

is_deeply(
    [$switch->_dataFilterRules("permit tcp any host 10.0.0.1 eq 80\n", 'testrole')],
    ['$1 permit tcp dst 10.0.0.1/32 80', '$2 deny'],
    "rules are numbered from 1 and the implicit deny is spelled out"
);

is_deeply(
    [$switch->_dataFilterRules("permit ip any host 10.0.0.1\npermit ip any host 10.0.0.2\n", 'testrole')],
    ['$1 permit dst 10.0.0.1/32', '$2 permit dst 10.0.0.2/32', '$3 deny'],
    "numbering follows the order the access list was written in"
);

is_deeply(
    [$switch->_dataFilterRules("out|permit ip any host 10.0.0.1\npermit ip any host 10.0.0.2\n", 'testrole')],
    ['$1 permit dst 10.0.0.2/32', '$2 deny'],
    "a dropped rule leaves the numbering contiguous"
);

is_deeply(
    [$switch->_dataFilterRules("permit gre any any\n", 'testrole')],
    ['$1 deny'],
    "an access list that is entirely untranslatable denies rather than opens up"
);

is_deeply(
    [$switch->_dataFilterRules($switch->acl_chewer("permit udp any any eq 53\ndeny tcp any any gt 1024\npermit ip any any", 'testrole'), 'testrole')],
    ['$1 permit udp dst any 53', '$2 deny'],
    "a role access list cut by acl_chewer ends with a single catch all"
);

is_deeply(
    [$switch->_dataFilterRules($switch->acl_chewer("permit tcp any any gt 1024", 'testrole'), 'testrole')],
    ['$1 deny'],
    "a role whose ACLs are all dropped reaches the switch as the catch all only"
);

# A line that did not go through acl_chewer arrives here in Cisco syntax: it is
# translated line by line and the cut has to happen here too.
is_deeply(
    [$switch->_dataFilterRules("permit udp any any eq 53\ndeny tcp any any gt 1024\npermit ip any any\n", 'testrole')],
    ['$1 permit udp dst any 53', '$2 deny'],
    "raw Cisco syntax stops at a deny that cannot be represented"
);

is_deeply(
    [$switch->_dataFilterRules("permit tcp any any gt 1024\npermit ip any host 10.0.0.9\n", 'testrole')],
    ['$1 permit dst 10.0.0.9/32', '$2 deny'],
    "raw Cisco syntax only skips a permit that cannot be represented"
);

is_deeply(
    [$switch->_dataFilterRules('$7 permit dst 10.0.0.1/32', 'testrole')],
    ['$1 permit dst 10.0.0.1/32', '$2 deny'],
    "a rule already in the switch syntax is renumbered, not translated"
);

is_deeply(
    [$switch->_dataFilterRules("permit dst 10.0.0.1/32", 'testrole')],
    ['$1 permit dst 10.0.0.1/32', '$2 deny'],
    "an unnumbered rule in the switch syntax is accepted and numbered"
);

{
    my $acl = "permit ip any host 10.0.0.1\n" x 100;
    my @rules = $switch->_dataFilterRules($acl, 'testrole');
    is(
        scalar(@rules),
        pf::Switch::Huawei::S5735::DATA_FILTER_RULES_LIMIT(),
        "an oversized access list is capped at the rule budget"
    );
    is($rules[-1], '$' . scalar(@rules) . ' deny', "the catch all survives the cap");
}

# The capability belongs to this model: the S5710 targets V200 platforms where
# HW-Data-Filter has never been tested.

ok($switch->supportsAccessListBasedEnforcement, "S5735 supports access list based enforcement");
ok(
    !pf::Switch::Huawei::S5710->supportsAccessListBasedEnforcement,
    "S5710 does not claim access list based enforcement"
);

# deauthenticateMacRadius: the Disconnect-Request names the endpoint by MAC

{
    my $production = pf::Switch::Huawei::S5735->new({ id => 'test', ip => '1.1.1.1', mode => 'production', SNMPUseConnector => "N", radiusDeauthUseConnector => "N" });
    my @disconnect;
    no warnings qw(redefine once);
    local *pf::Switch::Huawei::S5735::radiusDisconnect = sub { my ($self, @args) = @_; @disconnect = @args; return 1 };
    ok($production->deauthenticateMacRadius('02:48:57:45:49:01'), "deauthentication reports the Disconnect-Request result");
    is($disconnect[0], '02:48:57:45:49:01', "the Disconnect-Request is for the endpoint MAC");
    is_deeply(
        $disconnect[1],
        { 'Calling-Station-Id' => '02-48-57-45-49-01' },
        "the session is identified by Calling-Station-Id only, never by a possibly stale Acct-Session-Id"
    );
}

# Blank lines and comments ('!') are ignored, they don't turn the role into a deny all
is(
    $switch->acl_chewer("permit tcp any host 192.0.2.10 eq 443\n\n   \n!\n! comment\r\n\r\npermit udp any any eq 53", 'testrole'),
    $switch->acl_chewer("permit tcp any host 192.0.2.10 eq 443\npermit udp any any eq 53", 'testrole'),
    "blank and comment lines are ignored"
);

# wiredeauthTechniques: 802.1X and MAB sessions are both disconnected over RADIUS,
# the SNMP reauthentication of 802.1X ports needs an ifIndex the switch never sends

for my $connection_type ($WIRED_802_1X, $WIRED_MAC_AUTH) {
    is_deeply(
        [$switch->wiredeauthTechniques(undef, $connection_type)],
        [$SNMP::RADIUS, 'deauthenticateWiredMacRadius'],
        "wired connection type $connection_type is deauthenticated with a Disconnect-Request"
    );
}

is_deeply(
    [$switch->wiredeauthTechniques($SNMP::SNMP, $WIRED_802_1X)],
    [$SNMP::RADIUS, 'deauthenticateWiredMacRadius'],
    "an SNMP deauthentication method falls back to RADIUS"
);

{
    my @deauth;
    no warnings qw(redefine once);
    local *pf::Switch::Huawei::S5735::deauthenticateMacRadius = sub { my ($self, @args) = @_; @deauth = @args; return 1 };
    ok($switch->deauthenticateWiredMacRadius(10001, '02:48:57:45:49:01'), "the wired entry point reports the deauthentication result");
    is_deeply(\@deauth, ['02:48:57:45:49:01'], "the wired entry point disconnects the endpoint MAC, not the ifIndex");
}

# returnRadiusAccessAccept: the access list of the role reaches the reply as Huawei-Data-Filter

{
    my $acl_switch = pf::Switch::Huawei::S5735->new({ id => 'test', ip => '1.1.1.1', AccessListMap => 'Y', VlanMap => 'Y', SNMPUseConnector => "N", radiusDeauthUseConnector => "N" });
    no warnings qw(redefine once);
    local *pf::Switch::Huawei::S5735::handleRadiusDeny = sub { return undef };
    local *pf::Switch::Huawei::S5735::getAccessListByName = sub {
        my ($self, $role) = @_;
        return $role eq 'testrole' ? "permit tcp any host 192.0.2.10 eq 443\npermit udp any any eq 53" : undef;
    };
    my ($status, %reply) = @{$acl_switch->returnRadiusAccessAccept({ user_role => 'testrole', mac => '02:48:57:45:49:01', vlan => 100, connection_type => $WIRED_802_1X })};
    is($status, $RADIUS::RLM_MODULE_OK, "the Access-Accept is returned");
    is_deeply(
        $reply{'Huawei-Data-Filter'},
        ['$1 permit tcp dst 192.0.2.10/32 443', '$2 permit udp dst any 53', '$3 deny'],
        "the access list of the role is added as numbered Huawei-Data-Filter rules"
    );
    ($status, %reply) = @{$acl_switch->returnRadiusAccessAccept({ user_role => 'otherrole', mac => '02:48:57:45:49:01', vlan => 100, connection_type => $WIRED_802_1X })};
    ok(!exists $reply{'Huawei-Data-Filter'}, "a role without access list gets no Huawei-Data-Filter");
}
