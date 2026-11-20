#!/usr/bin/perl

=head1 NAME

switch_observability_reply_acls

=head1 DESCRIPTION

Unit test for pf::Switch::observabilityAclsFromReply: extracting the ACLs that
actually reached the switch from an assembled RADIUS reply, per platform. This
is the correctness-critical, DB-free part of recording switch ACL observability
from the wire instead of from the computed role ACLs.

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 19;
use pf::Switch;
use pf::Switch::Cisco::Cisco_IOS_15_5;

# observabilityAclsFromReply / observabilityReplyAclAttributes keep no instance
# state, so a bare blessed object avoids ->new (and the DB it reaches for).
my $switch = bless {}, 'pf::Switch';

#This test will running last
use Test::NoWarnings;

is_deeply(
    [$switch->observabilityAclsFromReply({})],
    [],
    "empty reply yields no ACLs",
);

is_deeply(
    [$switch->observabilityAclsFromReply({ 'Filter-Id' => 'some_role' })],
    [],
    "Filter-Id (a role name) is not an ACL",
);

is_deeply(
    [$switch->observabilityAclsFromReply({
        'Cisco-AVPair' => [
            'shell:priv-lvl=15',
            'ip:inacl#101=permit ip any any',
            'device-traffic-class=voice',
            'ip:inacl#102=deny ip any any',
        ],
    })],
    ['ip:inacl#101=permit ip any any', 'ip:inacl#102=deny ip any any'],
    "Cisco-AVPair keeps only ip:inacl ACL entries, drops shell/device-traffic-class",
);

is_deeply(
    [$switch->observabilityAclsFromReply({
        'Cisco-AVPair' => 'ACS:CiscoSecure-Defined-ACL=#ACSACL#role-sid',
    })],
    ['ACS:CiscoSecure-Defined-ACL=#ACSACL#role-sid'],
    "Cisco-AVPair keeps a downloadable-ACL reference (scalar value)",
);

is_deeply(
    [$switch->observabilityAclsFromReply({
        'Cisco-AVPair' => 'subscriber:service-name=role-sid',
    })],
    ['subscriber:service-name=role-sid'],
    "Cisco-AVPair keeps a subscriber:service-name downloadable reference",
);

is_deeply(
    [$switch->observabilityAclsFromReply({
        'Cisco-AVPair' => ['in#101=permit ip any any', 'out#102=deny ip any any'],
    })],
    ['in#101=permit ip any any', 'out#102=deny ip any any'],
    "Cisco-AVPair keeps base-format in#/out# ACL entries",
);

is_deeply(
    [$switch->observabilityAclsFromReply({
        'Aruba-NAS-Filter-Rule' => ['permit in tcp from any to any', 'deny in ip from any to any'],
    })],
    ['permit in tcp from any to any', 'deny in ip from any to any'],
    "Aruba-NAS-Filter-Rule entries are all ACLs",
);

is_deeply(
    [$switch->observabilityAclsFromReply({ 'NAS-Filter-Rule' => 'permit in ip from any to any' })],
    ['permit in ip from any to any'],
    "NAS-Filter-Rule scalar value is an ACL",
);

is_deeply(
    [$switch->observabilityAclsFromReply({ 'HP-NAS-Filter-Rule' => ['permit in ip from any to any'] })],
    ['permit in ip from any to any'],
    "HP-NAS-Filter-Rule entries are ACLs",
);

is_deeply(
    [$switch->observabilityAclsFromReply({ 'Juniper-Switching-Filter' => ['match { ... } then accept'] })],
    ['match { ... } then accept'],
    "Juniper-Switching-Filter terms are ACLs",
);

is_deeply(
    [$switch->observabilityAclsFromReply({ 'HW-Data-Filter' => ['permit ip source any destination any'] })],
    ['permit ip source any destination any'],
    "HW-Data-Filter rules are ACLs",
);

# observabilityAclsRecord: what the row of the device holds after an
# Access-Accept, or undef when it must have no row. The recorder always drops
# the previous row of the device first, so undef never leaves a stale one.
{
    my %acl_map = (_AccessListMap => 'Y');
    my $cisco = bless { %acl_map }, 'pf::Switch::Cisco::Cisco_IOS_15_5';
    my $cisco_push = bless { %acl_map, _UsePushACLs => 'Y' }, 'pf::Switch::Cisco::Cisco_IOS_15_5';
    my $no_map = bless {}, 'pf::Switch::Cisco::Cisco_IOS_15_5';
    my $args = { mac => '00:11:22:33:44:55', user_role => 'guest' };
    my $acl_reply = { 'Cisco-AVPair' => ['ip:inacl#101=deny tcp any any eq 443'] };

    is_deeply(
        $cisco->observabilityAclsRecord($args, $acl_reply),
        { role_id => 'guest', acl_type => 'radius', acls => 'ip:inacl#101=deny tcp any any eq 443' },
        "the ACLs of the reply are recorded",
    );
    is_deeply(
        $cisco->observabilityAclsRecord($args, { 'Cisco-AVPair' => ['shell:priv-lvl=15'] }),
        { role_id => 'guest', acl_type => 'radius', acls => '' },
        "a reply without ACLs is recorded with empty acls: an access list was expected",
    );
    is($no_map->observabilityAclsRecord($args, $acl_reply), undef, "no row with the Access List Map disabled");
    is(bless({}, 'pf::Switch')->observabilityAclsRecord($args, $acl_reply), undef, "no row on a switch without access list support");
    is($cisco->observabilityAclsRecord({ %$args, user_role => '' }, $acl_reply), undef, "no row without a role");
    is($cisco_push->observabilityAclsRecord($args, { 'Cisco-AVPair' => ['subscriber:role=guest'] }), undef,
        "no row with Push ACLs when the reply only names the role: the role ACLs are in the switch configuration");
    is_deeply(
        $cisco_push->observabilityAclsRecord($args, $acl_reply),
        { role_id => 'guest', acl_type => 'radius', acls => 'ip:inacl#101=deny tcp any any eq 443' },
        "with Push ACLs, the access list a reply carries (bypass ACLs, switch entry) is recorded",
    );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=cut
