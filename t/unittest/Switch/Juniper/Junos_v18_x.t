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

use Test::More tests => 27;
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

# acl_chewer: ACLs the VSA cannot represent are dropped rather than mistranslated

is(
    $switch->acl_chewer("permit ip host 10.1.1.1 any", 'testrole'),
    "",
    "there is no source address match condition so the term is dropped"
);

is(
    $switch->acl_chewer("permit tcp any any range 100 200", 'testrole'),
    "",
    "only the eq port operator can be represented"
);

is(
    $switch->acl_chewer("permit tcp any any gt 1024", 'testrole'),
    "",
    "the gt port operator is dropped"
);

is(
    $switch->acl_chewer("permit ip any 10.0.0.0 0.255.0.255", 'testrole'),
    "",
    "a non contiguous wildcard mask has no prefix length so the term is dropped"
);

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
    [],
    "an ACL that cannot be expressed is dropped, never sent malformed"
);

is_deeply(
    [$switch->_switchingFilterTerms("\n   \npermit ip any host 8.8.8.8\n", 'testrole')],
    ["Match Destination-ip 8.8.8.8 Action allow"],
    "blank lines are ignored"
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
