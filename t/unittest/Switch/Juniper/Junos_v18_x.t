#!/usr/bin/perl

=head1 NAME

Junos_v18_x

=cut

=head1 DESCRIPTION

unit test for Junos_v18_x

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

use Test::More tests => 51;
use pf::Switch::Juniper::Junos_v18_x;
use pf::Switch::Juniper::Junos;

#This test will running last
use Test::NoWarnings;

my $switch = pf::Switch::Juniper::Junos_v18_x->new({ id => 'test', ip => '1.1.1.1', SNMPUseConnector => "N", radiusDeauthUseConnector => "N" });

# acl_chewer: ACLs that translate to a Juniper-Switching-Filter term

is(
    $switch->acl_chewer("permit tcp any host 192.168.40.10 eq 443", 'testrole'),
    "Match Ip-protocol 6, Destination-ip 192.168.40.10, Destination-port 443 Action allow\n",
    "protocol, host destination and port become one term"
);

is(
    $switch->acl_chewer("permit udp any any eq 53", 'testrole'),
    "Match Ip-protocol 17, Destination-port 53 Action allow\n",
    "an any destination emits no Destination-ip condition"
);

is(
    $switch->acl_chewer("permit ip any host 8.8.8.8", 'testrole'),
    "Match Destination-ip 8.8.8.8 Action allow\n",
    "the ip protocol matches anything so it emits no Ip-protocol condition"
);

is(
    $switch->acl_chewer("permit ip any 10.0.0.0 0.0.0.255", 'testrole'),
    "Match Destination-ip 10.0.0.0/24 Action allow\n",
    "a wildcard mask becomes a prefix length"
);

is(
    $switch->acl_chewer("permit ip any 10.0.0.5 0.0.0.255", 'testrole'),
    "Match Destination-ip 10.0.0.0/24 Action allow\n",
    "the address bits the wildcard covers are cleared, as Cisco ignores them"
);

is(
    $switch->acl_chewer("permit tcp any any eq www", 'testrole'),
    "Match Ip-protocol 6, Destination-port 80 Action allow\n",
    "a Cisco TCP port name becomes its number"
);

is(
    $switch->acl_chewer("permit udp any eq bootpc any eq bootps", 'testrole'),
    "Match Ip-protocol 17, Source-port 68, Destination-port 67 Action allow\n",
    "Cisco UDP port names become their numbers, on both sides"
);

is(
    $switch->acl_chewer("deny tcp any any eq ftp-data\npermit ip any any", 'testrole'),
    "Match Ip-protocol 6, Destination-port 20 Action deny\n"
    . "Match Destination-ip 0.0.0.0/0 Action allow\n",
    "a deny on a named port is sent, it no longer cuts the filter"
);

is(
    $switch->acl_chewer("deny ip any any", 'testrole'),
    "Match Destination-ip 0.0.0.0/0 Action deny\n",
    "a catch all needs an explicit condition, Match without one is invalid grammar"
);

is(
    $switch->acl_chewer("permit udp any any eq 53\npermit tcp any host 192.168.40.10 eq 443\ndeny ip any any", 'testrole'),
    "Match Ip-protocol 17, Destination-port 53 Action allow\n"
    . "Match Ip-protocol 6, Destination-ip 192.168.40.10, Destination-port 443 Action allow\n"
    . "Match Destination-ip 0.0.0.0/0 Action deny\n",
    "each ACL line becomes its own term, in order"
);

# acl_chewer: ACLs the VSA cannot represent are dropped rather than mistranslated.
# Alone, they leave nothing to send, so the role is denied everything rather
# than left unrestricted.

my $deny_all = "Match Destination-ip 0.0.0.0/0 Action deny\n";

is(
    $switch->acl_chewer("permit ip host 10.1.1.1 any", 'testrole'),
    $deny_all,
    "there is no source address match condition so the term is dropped"
);

is(
    $switch->acl_chewer("permit tcp any any range 100 200", 'testrole'),
    $deny_all,
    "only the eq port operator can be represented"
);

is(
    $switch->acl_chewer("permit tcp any any gt 1024", 'testrole'),
    $deny_all,
    "the gt port operator is dropped"
);

is(
    $switch->acl_chewer("permit ip any 10.0.0.0 0.255.0.255", 'testrole'),
    $deny_all,
    "a non contiguous wildcard mask has no prefix length so the term is dropped"
);

is(
    $switch->acl_chewer("permit tcp any any established", 'testrole'),
    $deny_all,
    "there is no TCP flags match condition, dropping only the flag would permit every TCP packet"
);

is(
    $switch->acl_chewer("permit icmp any any echo", 'testrole'),
    $deny_all,
    "there is no ICMP type match condition, dropping only the type would permit every ICMP packet"
);

# acl_chewer: a deny that cannot be represented ends the filter with a deny all,
# skipping it would let the ACLs after it allow what it blocks

is(
    $switch->acl_chewer("permit udp any any eq 53\ndeny ip host 10.1.1.1 any\npermit ip any any", 'testrole'),
    "Match Ip-protocol 17, Destination-port 53 Action allow\n"
    . "Match Destination-ip 0.0.0.0/0 Action deny\n",
    "a deny with a source address ends the filter with a deny all"
);

is(
    $switch->acl_chewer("deny tcp any any established\npermit ip any any", 'testrole'),
    "Match Destination-ip 0.0.0.0/0 Action deny\n",
    "a deny with TCP flags ends the filter with a deny all"
);

is(
    $switch->acl_chewer("permit tcp any any established\npermit ip any host 8.8.8.8", 'testrole'),
    "Match Destination-ip 8.8.8.8 Action allow\n",
    "a permit that cannot be represented is only skipped, the ACLs after it are kept"
);

# Qualifiers the parser reads without returning them

is(
    $switch->acl_chewer("permit ip any any dscp ef\npermit ip any host 8.8.8.8", 'testrole'),
    "Match Destination-ip 8.8.8.8 Action allow\n",
    "a permit on a DSCP value is skipped, not sent as a permit of everything"
);

is(
    $switch->acl_chewer("permit ip any any time-range work", 'testrole'),
    $deny_all,
    "a role whose only permit is on a time range is denied everything"
);

is(
    $switch->acl_chewer("deny tcp any host 10.0.0.1 eq 80 fragments\npermit ip any any", 'testrole'),
    $deny_all,
    "a deny of fragments ends the filter with a deny all"
);

# ACLs the parser cannot read: it returns no entry at all

is(
    $switch->acl_chewer("permit ip any host 8.8.8.8\npermit ip any any ttl eq 5", 'testrole'),
    $deny_all,
    "ACLs that cannot be parsed deny everything instead of sending no filter"
);

is($switch->acl_chewer("", 'testrole'), "", "a role without ACLs gets no filter");

is($switch->acl_chewer("remark nothing to filter", 'testrole'), "", "a role with only a remark gets no filter");

# The direction guard is only reachable when pushACLs is enabled, since
# format_acl drops out| lines for a switch that does not support outbound ACLs.
is(
    $switch->_switchingFilterTerm(
        {
            action => 'permit',
            protocol => 'ip()',
            source => { ipv4_addr => '0.0.0.0', wildcard => '255.255.255.255' },
            destination => { ipv4_addr => '8.8.8.8', wildcard => '0.0.0.0' },
        },
        'out',
        'testrole',
    ),
    undef,
    "an outbound ACL cannot be represented, the VSA has no direction"
);

# helpers

is($switch->_aclWildcardToPrefixLen('0.0.0.0'), 32, "a zero wildcard is a /32");
is($switch->_aclWildcardToPrefixLen('0.0.0.255'), 24, "a 0.0.0.255 wildcard is a /24");
is($switch->_aclWildcardToPrefixLen('0.255.0.255'), undef, "a non contiguous wildcard has no prefix length");
is($switch->_aclProtocolNumber('tcp(6)'), 6, "the protocol number is taken from the parenthesis");
is($switch->_aclProtocolNumber('ip()'), undef, "ip matches any protocol so it has no number");
is($switch->_aclPortNumber('domain', 17), 53, "a port name is looked up for its protocol");
is($switch->_aclPortNumber('www', 17), undef, "a port name the protocol does not know has no number");
is($switch->_aclNetworkAddress('192.168.1.130', '0.0.0.63'), '192.168.1.128', "the network address clears the wildcard bits");

# _switchingFilterTerms: what actually reaches the Access-Accept

is_deeply(
    [$switch->_switchingFilterTerms("Match Destination-ip 8.8.8.8 Action allow\n", 'testrole')],
    ["Match Destination-ip 8.8.8.8 Action allow"],
    "an already chewed term is passed through untouched"
);

# _getAccessListByName returns bypass_acls and switch entry ACLs without
# running them through acl_chewer, so they arrive here in Cisco syntax.
is_deeply(
    [$switch->_switchingFilterTerms("permit ip any host 8.8.8.8\ndeny ip any any", 'testrole')],
    ["Match Destination-ip 8.8.8.8 Action allow", "Match Destination-ip 0.0.0.0/0 Action deny"],
    "raw Cisco syntax is translated rather than sent verbatim"
);

is_deeply(
    [$switch->_switchingFilterTerms("permit ip host 10.1.1.1 any", 'testrole')],
    ["Match Destination-ip 0.0.0.0/0 Action deny"],
    "an ACL that cannot be expressed is never sent malformed, and the role is denied everything rather than unrestricted"
);

is_deeply(
    [$switch->_switchingFilterTerms("\n   \npermit ip any host 8.8.8.8\n", 'testrole')],
    ["Match Destination-ip 8.8.8.8 Action allow"],
    "blank lines are ignored"
);

# The switch entry and bypass_acls path translates line by line, so the stop
# has to happen here too.
is_deeply(
    [$switch->_switchingFilterTerms("deny ip host 10.1.1.1 any\npermit ip any any", 'testrole')],
    ["Match Destination-ip 0.0.0.0/0 Action deny"],
    "raw Cisco syntax stops at a deny that cannot be represented"
);

is_deeply(
    [$switch->_switchingFilterTerms("Match Destination-ip 0.0.0.0/0 Action deny\nMatch Destination-ip 8.8.8.8 Action allow\n", 'testrole')],
    ["Match Destination-ip 0.0.0.0/0 Action deny"],
    "nothing after a deny all can match, so it is not sent"
);

# _switchingFilterBudget: the limits of the switch

my @permits = map { "Match Destination-ip 10.0.0.$_ Action allow" } (1 .. 21);

is_deeply(
    [$switch->_switchingFilterBudget([@permits[0 .. 19]], 'testrole')],
    [@permits[0 .. 19]],
    "a filter of exactly 20 match conditions is sent untouched"
);

is_deeply(
    [$switch->_switchingFilterBudget(\@permits, 'testrole')],
    [@permits[0 .. 18], "Match Destination-ip 0.0.0.0/0 Action deny"],
    "a filter over 20 match conditions is cut and ends with a deny all, making room for it"
);

my $long_permit = "Match Destination-ip 10.0.0.1, " . ("Destination-port 1, " x 12) . "Destination-port 2 Action allow";
my $long_deny = "Match Destination-ip 10.0.0.1, " . ("Destination-port 1, " x 12) . "Destination-port 2 Action deny";

is_deeply(
    [$switch->_switchingFilterBudget([$long_permit, $permits[0]], 'testrole')],
    [$permits[0]],
    "a permit over 247 characters is skipped, the terms after it are kept"
);

is_deeply(
    [$switch->_switchingFilterBudget([$permits[0], $long_deny, $permits[1]], 'testrole')],
    [$permits[0], "Match Destination-ip 0.0.0.0/0 Action deny"],
    "a deny over 247 characters ends the filter with a deny all"
);

is(
    pf::Switch::Juniper::Junos_v18_x::SWITCHING_FILTER_ATTRIBUTE_LIMIT(),
    247,
    "one attribute instance holds at most 247 characters"
);

is(
    $switch->_switchingFilterConditionCount("Match Ip-protocol 6, Destination-ip 10.0.0.1, Destination-port 443 Action deny"),
    3,
    "the switch counts match conditions, not terms"
);

is(
    $switch->_switchingFilterConditionCount("Match Destination-ip 0.0.0.0/0 Action deny"),
    1,
    "a single condition term counts as one"
);

is(
    pf::Switch::Juniper::Junos_v18_x::SWITCHING_FILTER_CONDITIONS_LIMIT(),
    20,
    "a switching filter holds at most 20 match conditions"
);

# The Juniper-Switching-Filter is only verified on this branch. The parent
# modules target non ELS platforms where multi term filters need Junos
# 15.1X53-D55 or later, and a filter the switch refuses costs the whole
# Access-Accept, so they must not claim ACL support.

ok(
    $switch->supportsAccessListBasedEnforcement,
    "Junos_v18_x supports access list based enforcement"
);

ok(
    !pf::Switch::Juniper::Junos->supportsAccessListBasedEnforcement,
    "Junos does not claim access list support, the parent platforms are untested"
);

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
