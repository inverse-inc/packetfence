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

use Test::More tests => 12;
use pf::Switch;

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

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=cut
