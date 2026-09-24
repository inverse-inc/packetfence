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

use Test::More tests => 31;
use pf::Switch::Huawei::S5735;
use pf::Switch::Huawei::S5710;

#This test will running last
use Test::NoWarnings;

my $switch = pf::Switch::Huawei::S5735->new({ id => 'test', ip => '1.1.1.1', SNMPUseConnector => "N", radiusDeauthUseConnector => "N" });

# acl_chewer: ACLs that translate to an HW-Data-Filter rule

is(
    $switch->acl_chewer("permit tcp any host 192.168.40.10 eq 443", 'testrole'),
    "permit tcp dst 192.168.40.10/32 443\n",
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
    $switch->acl_chewer("permit gre any host 10.0.0.1", 'testrole'),
    "",
    "a protocol with no HW-Data-Filter keyword is dropped"
);

is(
    $switch->acl_chewer("permit tcp any host 10.0.0.1 range 80 443", 'testrole'),
    "",
    "a port range is dropped, only eq is supported"
);

is(
    $switch->acl_chewer("permit tcp any host 10.0.0.1 gt 1024", 'testrole'),
    "",
    "a port operator other than eq is dropped"
);

is(
    $switch->acl_chewer("permit ip any 10.0.0.0 0.0.255.0", 'testrole'),
    "",
    "a non contiguous wildcard mask has no prefix length and is dropped"
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
