#!/usr/bin/perl

=head1 NAME

QX_S

=cut

=head1 DESCRIPTION

unit test for pf::Switch::NEC::QX_S

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 24;
use pf::constants;
use pf::config qw($WIRED_802_1X $WIRED_MAC_AUTH);
use pf::Switch::constants;
use pf::Switch::NEC::QX_S;

#This test will running last
use Test::NoWarnings;

my $switch = pf::Switch::NEC::QX_S->new({ id => 'test', ip => '1.1.1.1', SNMPUseConnector => "N", radiusDeauthUseConnector => "N" });

# wiredeauthTechniques: RADIUS deauthentication resolves to a real method

for my $type ([$WIRED_MAC_AUTH, 'MAC authentication'], [$WIRED_802_1X, '802.1X']) {
    my ($method, $sub) = $switch->wiredeauthTechniques($SNMP::RADIUS, $type->[0]);
    is($sub, 'deauthenticateMacRadius', "$type->[1] deauthenticates with a RADIUS Disconnect-Request");
}

ok($switch->can('deauthenticateMacRadius'), "the deauthentication method is implemented");

# deauthenticateMacRadius: the Disconnect-Request is sent for the endpoint MAC

{
    my @disconnect;
    no warnings qw(redefine once);
    local *pf::Switch::NEC::QX_S::radiusDisconnect = sub { my ($self, @args) = @_; @disconnect = @args; return 1 };
    ok($switch->deauthenticateMacRadius(1, '02:4e:45:43:44:01'), "deauthentication reports the Disconnect-Request result");
    is_deeply(\@disconnect, ['02:4e:45:43:44:01'], "the Disconnect-Request is for the endpoint MAC");
}

# acl_chewer: Cisco ACL lines translated into Comware advanced ACL rules for PushACLs

sub chew { my ($acl) = @_; return $switch->acl_chewer($acl, 'testrole') }

is(chew("permit tcp any host 10.0.0.1 eq 443"), "rule permit tcp destination 10.0.0.1 0 destination-port eq 443\n", "host destination and eq port");
is(chew("permit ip 10.1.0.0 0.0.255.255 10.2.0.0 0.0.0.255"), "rule permit ip source 10.1.0.0 0.0.255.255 destination 10.2.0.0 0.0.0.255\n", "source and destination wildcards");
is(chew("permit tcp any any range 100 200"), "rule permit tcp destination-port range 100 200\n", "a port range");
is(chew("permit udp any eq bootpc any eq bootps"), "rule permit udp source-port eq 68 destination-port eq 67\n", "Cisco port names become port numbers");
is(chew("permit 47 any any"), "rule permit 47\n", "a protocol number is kept");
is(chew("deny ip any any"), "rule deny ip\n", "deny any any");
is(chew("in|permit ip any host 8.8.8.8\nout|permit ip host 8.8.8.8 any"), "in|rule permit ip destination 8.8.8.8 0\nout|rule permit ip source 8.8.8.8 0\n", "the direction prefix is kept for the in and out ACLs");

# a qualifier the rule does not carry would widen a permit: the line is skipped

foreach my $acl (
    "permit tcp any any established",
    "permit icmp any any echo",
    "permit ip any any dscp ef",
    "permit ip any any fragments",
    "permit ip any any precedence 5",
    "permit ip any any time-range work",
    "permit ip any 10.0.0.0 0.255.0.255",
) {
    is(chew("$acl\npermit ip any host 8.8.8.8"), "rule permit ip destination 8.8.8.8 0\n", "skipped, never widened: $acl");
}

# a deny that cannot be translated ends the ACLs of its direction with a deny all

is(
    chew("permit udp any any eq 53\ndeny tcp any any established\npermit ip any any"),
    "rule permit udp destination-port eq 53\nrule deny ip\n",
    "the permit after an untranslatable deny does not allow what it blocks"
);
is(
    chew("out|deny ip any any dscp ef\nout|permit ip any any\npermit ip any host 8.8.8.8"),
    "out|rule deny ip\nrule permit ip destination 8.8.8.8 0\n",
    "an outbound cut does not touch the inbound ACLs"
);

# a direction whose lines were all skipped is denied everything, not sent nothing

is(chew("permit tcp any any established"), "rule deny ip\n", "a role whose ACLs are all skipped is denied everything");
is(chew("#permit ip any any\nremark nothing"), "", "a role without any ACL line still gets no ACL");

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
