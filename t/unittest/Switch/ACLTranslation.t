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

use Test::More tests => 243;
use Test::MockModule;
use Data::Dumper;
use pf::Switch;
use pf::Switch::Aruba::ArubaOS_CX_10_x;
use pf::Switch::Arista::AristaSwitch;
use pf::Switch::HP::AOS_Switch_v16_X;
use pf::Switch::Cisco::Cisco_IOS_12_x;
use pf::Switch::Cisco::Cisco_IOS_15_5;
use pf::Switch::Fortinet::FortiSwitchOS_v7_x;
use pf::Switch::Dell::N1500;
use pf::Switch::Aruba::Controller_200;
use pf::Switch::Aruba::Mobility_Master;
use pf::Switch::Cisco::Cisco_WLC_AireOS;
use pf::Switch::Cisco::ASA;

#This test will running last
use Test::NoWarnings;

my %args = (id => 'test', ip => '1.1.1.1', SNMPUseConnector => "N", radiusDeauthUseConnector => "N");
my $aruba = pf::Switch::Aruba::ArubaOS_CX_10_x->new({%args});
my $arista = pf::Switch::Arista::AristaSwitch->new({%args});
my $aos = pf::Switch::HP::AOS_Switch_v16_X->new({%args});
my $cisco = pf::Switch::Cisco::Cisco_IOS_15_5->new({%args});
my $forti = pf::Switch::Fortinet::FortiSwitchOS_v7_x->new({%args});
my $dell = pf::Switch::Dell::N1500->new({%args});
my $controller = pf::Switch::Aruba::Controller_200->new({%args});
my $mobility = pf::Switch::Aruba::Mobility_Master->new({%args});
my $aireos_push = pf::Switch::Cisco::Cisco_WLC_AireOS->new({%args, UsePushACLs => 'Y'});
# Mobility Master only formats for the push: its chewer gives an arrayref
my $mobility_push = pf::Switch::Aruba::Mobility_Master->new({%args, UsePushACLs => 'Y'});

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
    is(chew($s, "permit icmp any any echo"), ($s == $aruba ? "in|permit in icmp from any to any icmptypes 8\n" : $s == $arista ? "in|permit in 1 from any to any icmptypes 8\n" : deny_all($s)), "$name: an ICMP type is sent as icmptypes, or not dropped into a permit of all ICMP");
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
is(chew($cisco, "permit tcp any any established"), "in|permit tcp any any established\n", "Cisco: TCP flags are sent");
is(chew($cisco, "permit ip any 10.0.0.0 0.255.0.255"), "in|permit ip any 10.0.0.0 0.255.0.255\n", "Cisco: a non contiguous wildcard is sent as is");
is(chew($cisco, "permit ip host 10.1.1.1 any"), deny_all($cisco), "Cisco: a source address is not replaced by the endpoint");
is(chew($cisco, "permit udp any eq 53 any"), deny_all($cisco), "Cisco: a source port is not dropped");
is(chew($cisco, "permit icmp any any echo"), "in|permit icmp any any echo\n", "Cisco: the ICMP type is sent");
is(chew($cisco, "deny icmp any any echo-reply\npermit ip any any"), "in|deny icmp any any echo-reply\nin|permit ip any any\n", "Cisco: a deny on an ICMP type is sent, the ACLs after it are kept");
is(chew($cisco, "permit icmp any any 8"), "in|permit icmp any any 8\n", "Cisco: a numeric ICMP type is sent");
is(chew($cisco, "permit icmp any any 3 1"), "in|permit icmp any any 3 1\n", "Cisco: the ICMP type and code are sent");
is(chew($cisco, "deny icmp any any 3 1\npermit ip any any"), "in|deny icmp any any 3 1\nin|permit ip any any\n", "Cisco: a deny on an ICMP type with a code is sent, the ACLs after it are kept");

# ICMP types: the parser drops the code of a numeric qualifier, format_acl
# restores it from the line so "3 1" never matches every code of type 3
is_deeply([pf::Switch->aclIcmpType('echo')], [8], "an ICMP message name gives its type");
is_deeply([pf::Switch->aclIcmpType('host-unreachable')], [3, 1], "an ICMP message name gives its type and code");
is_deeply([pf::Switch->aclIcmpType('3 1')], [3, 1], "a numeric ICMP qualifier gives its type and code");
is_deeply([pf::Switch->aclIcmpType('no-such-message')], [], "an unknown ICMP message gives nothing");
{
    my ($acl_ref) = $cisco->format_acl("permit icmp any any 3 1");
    is($acl_ref->{packetfence}{entries}[0]{icmp_qualifier}, "3 1", "format_acl keeps the ICMP code the parser drops");
}
is(chew($aruba, "permit icmp any host 10.0.0.1 echo"), "in|permit in icmp from any to 10.0.0.1 icmptypes 8\n", "Aruba CX: the ICMP type is sent as icmptypes");
is(chew($aruba, "permit icmp any any host-unreachable"), deny_all($aruba), "Aruba CX: icmptypes has no ICMP code, a message with one is skipped");
is(chew($aruba, "permit icmp any any 3 1"), deny_all($aruba), "Aruba CX: a numeric ICMP code is skipped, not sent as every code of the type");
is(chew($arista, "permit icmp any host 10.0.0.1 echo-reply"), "in|permit in 1 from any to 10.0.0.1 icmptypes 0\n", "Arista: the ICMP type is sent as icmptypes");
is(chew($arista, "permit icmp any any 3 1"), deny_all($arista), "Arista: icmptypes has no ICMP code, a line with one is skipped");
is(chew($dell, "permit icmp any host 10.0.0.1 echo"), "in|permit icmp any host 10.0.0.1 icmp-type 8\n", "Dell: the ICMP type is sent as icmp-type, the switch does not parse the message names");
is(chew($dell, "permit icmp any any 3 1"), "in|permit icmp any any icmp-type 3 icmp-code 1\n", "Dell: the ICMP type and code are sent");
# The parser drops whatever follows the ICMP type: only a log keyword may
ok(!defined $cisco->untranslatableIcmpTrailer("permit icmp any any echo log", "echo"), "ICMP trailer: a log keyword after the type is accepted");
ok(defined $cisco->untranslatableIcmpTrailer("permit icmp any any 3 1 ttl 5", "3 1"), "ICMP trailer: a code followed by another keyword is refused");
ok(defined $cisco->untranslatableIcmpTrailer("permit icmp any any echo extra", "echo"), "ICMP trailer: an unknown word after the type is refused");
ok(!defined $cisco->untranslatableIcmpTrailer("permit icmp host 10.0.0.3 any 3", "3"), "ICMP trailer: the type is found after the addresses, not in them");
ok(!defined $cisco->untranslatableIcmpTrailer("permit icmp 10.0.0.0 0.0.0.255 any echo", "echo"), "ICMP trailer: an address with a wildcard is skipped");
ok(defined $cisco->untranslatableIcmpTrailer("permit icmp any any", "echo"), "ICMP trailer: a type that is not where expected is refused");
ok(!defined $cisco->untranslatableIcmpTrailer("permit icmp any any 3 1", "3 1"), "ICMP trailer: a code restored by format_acl is part of the qualifier");
ok(defined $cisco->untranslatableIcmpTrailer("permit icmp any any 3 1", "3"), "ICMP trailer: a code that was not restored is refused");

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

is($aruba->untranslatablePushAcl({ source => {}, destination => {}, tcp_flags => 'established' }) // '', "the TCP flags are not sent ('established')", "Aruba CX push: TCP flags");
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

# Object groups: the parser gives a hash in place of the protocol or of an
# address, which cannot be sent as is
foreach my $switch ($aruba, $cisco) {
    is(chew($switch, "permit object-group foo any any"), deny_all($switch), ref($switch).": a permit on a service object group is skipped, not sent as a broken line");
    is(chew($switch, "permit tcp object-group SRC any eq 80\npermit ip any any"), chew($switch, "permit ip any any"), ref($switch).": a permit from a network object group is skipped");
    is(chew($switch, "deny tcp any object-group DST\npermit ip any any"), deny_all($switch), ref($switch).": a deny to a network object group ends the ACLs with a deny all");
}
foreach my $switch ($controller, $mobility_push, $aireos_push) {
    local $aireos_push->{_aclsForPush} = 1;
    local $mobility_push->{_aclsForPush} = 1;
    unlike(Dumper(chew($switch, "permit object-group foo any any\npermit tcp any host 10.0.0.1 eq 443")), qr/HASH\(/, ref($switch).": an object group is never sent as a stringified reference");
}

# Aruba controllers and the AireOS push: TCP flags cannot be sent, and dropping
# them would widen the ACL. A permit with them is skipped, a deny with them ends
# the ACLs with a deny all instead of letting the ACLs after it through
foreach my $switch ($controller, $aireos_push) {
    local $aireos_push->{_aclsForPush} = 1;
    is(chew($switch, "permit tcp any any established\npermit udp any any eq 53"), chew($switch, "permit udp any any eq 53"), ref($switch).": a permit with TCP flags is skipped");
    is(chew($switch, "deny tcp any any established\npermit ip any any"), deny_all($switch), ref($switch).": a deny with TCP flags ends the ACLs with a deny all");
}
foreach my $switch ($controller, $mobility_push) {
    # Mobility Master gives an arrayref: compare structures
    local $mobility_push->{_aclsForPush} = 1;
    is_deeply(chew($switch, "permit udp any eq 53 any\npermit udp any any eq 53"), chew($switch, "permit udp any any eq 53"), ref($switch).": a permit with a source port is skipped, not sent without it");
    is_deeply(chew($switch, "deny icmp any any echo\npermit ip any any"), deny_all($switch), ref($switch).": a deny on an ICMP type ends the ACLs with a deny all, not a deny of all ICMP");
    is_deeply(chew($switch, "permit tcp any any gt 1024\npermit tcp any any eq 443"), chew($switch, "permit tcp any any eq 443"), ref($switch).": gt is not turned into one port");
}
like(chew($controller, "permit tcp any any range 100 200"), qr/100-200/, "Aruba Controller: a range is sent");
like(chew($controller, "permit tcp any any eq www"), qr/ 80\s*$/m, "Aruba Controller: a Cisco port name becomes its number");
is(chew($controller, "permit ip any 10.0.0.0 0.255.0.255\npermit tcp any any eq 443"), chew($controller, "permit tcp any any eq 443"), "Aruba Controller: a non contiguous mask is skipped instead of dying");
is(chew($controller, "permit nos any any\npermit tcp any any eq 443"), chew($controller, "permit tcp any any eq 443"), "Aruba Controller: a protocol without a number is skipped");
is(chew($controller, "deny udp any any eq www\npermit ip any any"), deny_all($controller), "Aruba Controller: a port name the protocol does not know ends the ACLs with a deny all");
is($cisco->aclPortNumber('www', 'tcp(6)'), 80, "aclPortNumber: a name of the parsed protocol");
is($cisco->aclPortNumber('www', 'udp'), undef, "aclPortNumber: a name the protocol does not know");
is($cisco->aclPortNumber('443', 6), 443, "aclPortNumber: a number is kept");
{
    local $aireos_push->{_aclsForPush} = 1;
    is(chew($aireos_push, "permit tcp any any range 8000 8010\npermit tcp any any eq 443"), chew($aireos_push, "permit tcp any any eq 443"), "AireOS push: a port range is skipped, not pushed without a port");
    is(chew($aireos_push, "deny icmp any any echo\npermit ip any any"), deny_all($aireos_push), "AireOS push: a deny on an ICMP type ends the ACLs with a deny all");
    like(chew($aireos_push, "permit tcp any gt 1024 any"), qr/^acl rule source port range testrole 1 1025 65535$/m, "AireOS push: gt on the source port is a computed range up to 65535, not '1024+1'");
    is(chew($aireos_push, "permit ip any 10.0.0.0 0.255.0.255\npermit tcp any any eq 443"), chew($aireos_push, "permit tcp any any eq 443"), "AireOS push: a non contiguous mask is skipped, not pushed as a bogus mask");
    is(chew($aireos_push, "permit nos any any\npermit tcp any any eq 443"), chew($aireos_push, "permit tcp any any eq 443"), "AireOS push: a protocol the rule does not know is skipped, not pushed as any");
    like(chew($aireos_push, "permit tcp any any lt 1024"), qr/^acl rule destination port range testrole 1 1 1023$/m, "AireOS push: lt on the destination port is a computed range");
    like(chew($aireos_push, "permit tcp any any eq www"), qr/^acl rule destination port range testrole 1 80 80$/m, "AireOS push: a Cisco port name becomes its number");
    # A gt or lt that leaves no port would be pushed as an empty range (65536
    # 65535, 1 0) that the controller refuses or misapplies
    my $port_entry = sub {
        my ($action, $port) = @_;
        my $any = { ipv4_addr => '0.0.0.0', wildcard => '255.255.255.255' };
        return { action => $action, protocol => 'tcp(6)', source => {%$any}, destination => {%$any, port => $port} };
    };
    ok(defined $aireos_push->_untranslatablePushAcl($port_entry->('deny', 'gt 65535')), "AireOS push: gt 65535 leaves no port");
    ok(defined $aireos_push->_untranslatablePushAcl($port_entry->('deny', 'lt 1')), "AireOS push: lt 1 leaves no port");
    ok(defined $aireos_push->_untranslatablePushAcl($port_entry->('deny', 'lt 0')), "AireOS push: lt 0 leaves no port");
    ok(defined $aireos_push->_untranslatablePushAcl($port_entry->('permit', 'eq 70000')), "AireOS push: a port above 65535 is refused");
    ok(!defined $aireos_push->_untranslatablePushAcl($port_entry->('permit', 'gt 65534')), "AireOS push: gt 65534 is the port 65535");
    ok(!defined $aireos_push->_untranslatablePushAcl($port_entry->('permit', 'lt 2')), "AireOS push: lt 2 is the port 1");
    is(chew($aireos_push, "deny tcp any any gt 65535\npermit ip any any"), deny_all($aireos_push), "AireOS push: a deny on gt 65535 ends the ACLs with a deny all");
    is(chew($aireos_push, "permit tcp any any lt 1\npermit tcp any any eq 443"), chew($aireos_push, "permit tcp any any eq 443"), "AireOS push: a permit on lt 1 is skipped, not pushed as the range 1 0");
    {
        my $permit_443 = chew($aireos_push, "permit tcp any any eq 443");
        is(chew($aireos_push, "permit tcp any any gt 65535\npermit tcp any any eq 443"), $permit_443, "AireOS push: gt 65535 is skipped, not pushed as the range 65536 65535");
        is(chew($aireos_push, "permit tcp any any lt 1\npermit tcp any any eq 443"), $permit_443, "AireOS push: lt 1 is skipped, not pushed as the range 1 0");
        is(chew($aireos_push, "permit tcp any any lt 0\npermit tcp any any eq 443"), $permit_443, "AireOS push: lt 0 is skipped, not pushed as the range 1 -1");
        is(chew($aireos_push, "deny tcp any any gt 65535\npermit ip any any"), deny_all($aireos_push), "AireOS push: a deny on gt 65535 ends the ACLs with a deny all");
        like(chew($aireos_push, "permit 47 any any"), qr/^acl rule protocol testrole 1 47$/m, "AireOS push: a numeric protocol is pushed as its number, not refused");
        like(chew($aireos_push, "permit ospf any any"), qr/^acl rule protocol testrole 1 (?:89|ospf)$/m, "AireOS push: a protocol name with a number is pushed, not refused");
    }
}

# Dell N1500: a numeric ICMP type, a type 0 and a code 0 are sent (the check
# used to read only the code of aclIcmpType)
{
    is(chew($dell, "permit icmp any any 8"), "in|permit icmp any any icmp-type 8\n", "Dell: a numeric ICMP type is sent");
    is(chew($dell, "permit icmp any any 0"), "in|permit icmp any any icmp-type 0\n", "Dell: the numeric ICMP type 0 is sent");
    is(chew($dell, "permit icmp any any 3 0"), "in|permit icmp any any icmp-type 3 icmp-code 0\n", "Dell: an ICMP code of 0 is sent");
    is(chew($dell, "permit icmp any host 10.0.0.1 8"), "in|permit icmp any host 10.0.0.1 icmp-type 8\n", "Dell: a numeric ICMP type without a code to a host has no icmp-code");
}
is(pf::Switch->aclIcmpMatch('host-unreachable', 'icmp-type', 'icmp-code'), 'icmp-type 3 icmp-code 1', "ICMP match: the type and code with their keywords");
is(pf::Switch->aclIcmpMatch('8', 'icmp-type', 'icmp-code'), 'icmp-type 8', "ICMP match: no code keyword without a code");
is(pf::Switch->aclIcmpMatch('echo-reply', 'icmptypes'), 'icmptypes 0', "ICMP match: the type 0");
is(pf::Switch->aclIcmpMatch('3 1'), '3 1', "ICMP match: the numbers alone without keywords");
is(pf::Switch->aclIcmpMatch('no-such-message', 'icmptypes'), '', "ICMP match: nothing for an unknown message");
is(chew($dell, "permit icmp any any echo-reply"), "in|permit icmp any any icmp-type 0\n", "Dell: an ICMP message of type 0 is sent");
is(chew($dell, "permit icmp any any net-unreachable"), "in|permit icmp any any icmp-type 3 icmp-code 0\n", "Dell: an ICMP message with code 0 is sent");
is($dell->_untranslatableAcl({ source => { ipv4_addr => '0.0.0.0' }, destination => { ipv4_addr => '0.0.0.0', wildcard => '255.255.255.255' }, icmp_qualifier => 'no-such-message' }) // '', "the ICMP message 'no-such-message' is unknown", "Dell: an unknown ICMP message is still refused");

{
    local $mobility_push->{_aclsForPush} = 1;
    is_deeply(
        $mobility_push->acl_chewer("deny tcp any any established\npermit ip any any", 'testrole'),
        $mobility_push->acl_chewer("deny ip any any", 'testrole'),
        "Aruba Mobility Master: a deny with TCP flags ends the ACLs with a deny all"
    );
}

# Arista push: the EOS ACL takes the ICMP type like Cisco
{
    my $arista_push = pf::Switch::Arista::AristaSwitch->new({%args, UsePushACLs => 'Y'});
    local $arista_push->{_aclsForPush} = 1;
    is($arista_push->acl_chewer("permit icmp any any echo-reply", 'testrole'), "10 permit icmp any any 0\n", "Arista push: the ICMP type is sent as its number");
    is($arista_push->acl_chewer("permit icmp any host 10.0.0.1 3 1", 'testrole'), "10 permit icmp any host 10.0.0.1 3 1\n", "Arista push: the ICMP type and code are sent");
    is($arista_push->acl_chewer("permit icmp any any dod-net-prohibited", 'testrole'), "10 permit icmp any any 3 9\n", "Arista push: a Cisco message name is pushed as its type and code, which EOS takes");
    ok(defined $arista_push->_untranslatablePushAcl({ source => {}, destination => {}, icmp_qualifier => 'no-such-message' }), "Arista push: an unknown ICMP message is refused");
}

like(pf::Switch::untranslatableAclQualifier($aruba, { action => 'permit', protocol => { object_group_service => 'foo' }, source => {}, destination => {} }) // '', qr/object group 'foo'/, "the protocol object group is named in the reason");
is(pf::Switch::untranslatableAclQualifier($aruba, { action => 'permit', protocol => 'ip()', source => undef, destination => $any }), "the source has no address", "an entry without an address hash is rejected, not formatted as any");
is($cisco->untranslatableTcpFlags({ tcp_flags => 'established' }), "the TCP flags are not sent ('established')", "untranslatableTcpFlags: the flags are named in the reason");
ok(!defined $cisco->untranslatableTcpFlags({}), "untranslatableTcpFlags: no flags, no reason");
like(pf::Switch::untranslatableAclQualifier($aruba, { action => 'permit', protocol => 'tcp(6)', source => { object_group_network => 'SRC' }, destination => { ipv4_addr => '0.0.0.0', wildcard => '255.255.255.255' } }) // '', qr/source is not an IPv4 address/, "the address object group is named in the reason");

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

# getAccessListByName records what it sends: keep the tests off the database
my $dal = Test::MockModule->new('pf::dal::switch_observability_acls');
$dal->mock(remove_items => sub { 1 });
$dal->mock(upsert => sub { 1 });

{
    my %push_args = (%args, UsePushACLs => 'enabled');
    foreach my $switch (
        [pf::Switch::Aruba::ArubaOS_CX_10_x->new({%push_args}), 'Aruba CX', qr/^in\|1 permit tcp any any/m],
        [pf::Switch::Arista::AristaSwitch->new({%push_args}), 'Arista', qr/^10 permit tcp any any/m],
    ) {
        my ($s, $name, $push_format) = @$switch;
        like($s->getRoleAccessListByName('r4') // '', $push_format, "$name: getRoleAccessListByName gives the push format");
        like($s->acl_chewer("permit tcp any any", 'r4') // '', qr/permit in/, "$name: outside of the push, the RADIUS format");
    }

    # Mobility Master builds a structure for the push: the observability table
    # stores its JSON, not a stringified reference (the upsert died on it)
    my $stored;
    $dal->mock(new => sub { my ($class, $args) = @_; $stored = $args->{acls}; return bless {}, $class });
    ok(defined $mobility_push->getRoleAccessListByName('r4'), "Mobility Master: the role ACLs are built for the push");
    ok(!ref $stored && $stored =~ /^\[\{/, "Mobility Master: the observability table gets the JSON of the pushed ACLs");
    $dal->unmock('new');
}

# The Push ACLs setting alone does not make an ACL a pushed one: a RADIUS reply
# (the bypass ACLs of a node, a role the push does not know) still carries the
# Cisco ACL from any that the switch applies to the endpoint
{
    my $cisco_push = pf::Switch::Cisco::Cisco_IOS_15_5->new({%args, UsePushACLs => 'Y'});
    is($cisco_push->acl_chewer("permit ip host 10.1.1.1 any\npermit ip any any", 'r4'), chew($cisco, "permit ip any any"), "Cisco with Push ACLs: outside of the push, a source address is still skipped, not sent in a RADIUS reply");
    {
        local $cisco_push->{_aclsForPush} = 1;
        is($cisco_push->acl_chewer("permit ip host 10.1.1.1 any", 'r4'), "in|permit ip host 10.1.1.1 any\n", "Cisco with Push ACLs: the push keeps the source address");
    }
    like($aireos_push->acl_chewer("permit tcp any host 10.0.0.1 eq 443", 'r4') // '', qr/^in\|permit tcp any host 10\.0\.0\.1 eq 443$/m, "AireOS with Push ACLs: outside of the push, the Cisco ACL of a RADIUS reply, not the acl commands");
    {
        local $aireos_push->{_aclsForPush} = 1;
        like($aireos_push->acl_chewer("permit tcp any host 10.0.0.1 eq 443", 'r4') // '', qr/^acl create r4$/m, "AireOS with Push ACLs: the push gives the acl commands");
    }
}

# The bypass ACLs of a node are written in Cisco syntax like the ACLs of a
# role: they go through acl_chewer too, so every switch, Cisco included, gets
# them translated like the ACLs of a role
{
    my $mac = '02:00:5e:ac:1b:01';
    # The bypass ACLs of the node, read through node_view without a database
    my $node_acls;
    my $node_mock = Test::MockModule->new('pf::Switch');
    $node_mock->mock('node_view', sub { defined($node_acls) ? { mac => $mac, bypass_acls => $node_acls } : undef });
    my $bypass = "permit tcp any any eq 80\ndeny ip any any";
    $node_acls = $bypass;
    is($aruba->getAccessListByName('r4', $mac), chew($aruba, $bypass), "Aruba CX: the bypass ACLs of the node are translated like the ACLs of a role");
    like($aruba->getAccessListByName('r4', $mac), qr/^(?:in\|)?permit in tcp from any to any 80$/m, "Aruba CX: the bypass ACLs are in the NAS-Filter-Rule syntax, not in Cisco syntax");
    is($cisco->getAccessListByName('r4', $mac), chew($cisco, $bypass), "Cisco: the bypass ACLs of the node are translated like the ACLs of a role");
    $node_acls = undef;
    is($aruba->getAccessListByName('r4', $mac), chew($aruba, "permit tcp any any"), "without bypass ACLs the ACLs of the role are sent");

    # With Push ACLs the ACLs of a role are in the switch configuration and the
    # reply only names the role, but the bypass ACLs of a node and the access
    # list of the switch entry are not pushed: they are still sent in the reply
    my $cisco_push = pf::Switch::Cisco::Cisco_IOS_15_5->new({%args, UsePushACLs => 'Y'});
    is($cisco_push->getAccessListByName('r4', $mac), undef, "Cisco with Push ACLs: the ACLs of a role are not sent in the reply, they are pushed");
    $node_acls = $bypass;
    is($cisco_push->getAccessListByName('r4', $mac), chew($cisco, $bypass), "Cisco with Push ACLs: the bypass ACLs of the node are sent in the reply, from any");
    $node_acls = undef;

    # The reply names the pushed role only with the Role Map: without it the
    # reply carries the ACLs of the role, or the device would get no ACL at all.
    # Cisco ASA never had the Push ACLs guard of the other Cisco modules and
    # used to get them in its VPN reply
    my $asa_push = pf::Switch::Cisco::ASA->new({%args, UsePushACLs => 'Y', RoleMap => 'N'});
    is($asa_push->getAccessListByName('r4', $mac), chew($asa_push, "permit tcp any any"), "ASA with Push ACLs and no Role Map: the ACLs of the role are sent, nothing names the pushed role");
    my $asa_push_role = pf::Switch::Cisco::ASA->new({%args, UsePushACLs => 'Y', RoleMap => 'Y'});
    is($asa_push_role->getAccessListByName('r4', $mac), undef, "ASA with Push ACLs and the Role Map: the reply names the pushed role, its ACLs are not sent");
    my $cisco_push_norole = pf::Switch::Cisco::Cisco_IOS_15_5->new({%args, UsePushACLs => 'Y', RoleMap => 'N', AccessListMap => 'Y'});
    is($cisco_push_norole->getAccessListByName('r4', $mac), chew($cisco, "permit tcp any any"), "Cisco with Push ACLs and no Role Map: the ACLs of the role are sent");
    is($cisco_push_norole->replyAccessListReplacesRole({ user_role => 'r4', mac => $mac, node_info => bless({ bypass_acls => $bypass }, 'pf::dal::node') }), 0, "Cisco with Push ACLs and no Role Map: no pushed role named, none to replace");
    my $cisco_push_entry = pf::Switch::Cisco::Cisco_IOS_15_5->new({%args, UsePushACLs => 'Y', access_lists => { r4 => "permit udp any eq 68 any" }});
    is($cisco_push_entry->getAccessListByName('r4', $mac), "permit udp any eq 68 any", "Cisco with Push ACLs: the access list of the switch entry is sent in the reply");

    # The reply names the pushed role unless it carries an access list that
    # replaces its ACLs: the decision follows what _getAccessListByName sends
    my $cisco_map = pf::Switch::Cisco::Cisco_IOS_15_5->new({%args, UsePushACLs => 'Y', AccessListMap => 'Y'});
    my $req = sub { { user_role => 'r4', mac => $mac, node_info => bless({ bypass_acls => $_[0] }, 'pf::dal::node') } };
    is($cisco_map->replyAccessListReplacesRole($req->($bypass)), 1, "Cisco with Push ACLs: the bypass ACLs of the node replace the pushed role");
    is($cisco_map->replyAccessListReplacesRole($req->(undef)), 0, "Cisco with Push ACLs: without them the pushed role is named");
    is($cisco_map->replyAccessListReplacesRole($req->("remark nothing to send")), 0, "Cisco with Push ACLs: bypass ACLs that translate to nothing leave the pushed role named");
    is($cisco_push->replyAccessListReplacesRole($req->($bypass)), 0, "Cisco with Push ACLs and no Access List Map: no access list in the reply, the pushed role is named");
    my $cisco_map_entry = pf::Switch::Cisco::Cisco_IOS_15_5->new({%args, UsePushACLs => 'Y', AccessListMap => 'Y', access_lists => { r4 => "permit udp any eq 68 any" }});
    is($cisco_map_entry->replyAccessListReplacesRole($req->(undef)), 1, "Cisco with Push ACLs: the access list of the switch entry replaces the pushed role");
    my $controller_push = pf::Switch::Aruba::Controller_200->new({%args, UsePushACLs => 'Y', AccessListMap => 'Y'});
    is($controller_push->replyAccessListReplacesRole($req->($bypass)), 0, "Aruba Controller with Push ACLs: the ACLs are only pushed, the role stays named whatever the node has");

    # The role is only dropped for an access list the module adds to this
    # reply: where it cannot, the bypass ACLs of the node are not supported
    # with Push ACLs (they cannot be pushed) and the pushed role stays named
    my $asa_map = pf::Switch::Cisco::ASA->new({%args, UsePushACLs => 'Y', AccessListMap => 'Y'});
    is($asa_map->replyAccessListReplacesRole($req->($bypass)), 0, "ASA with Push ACLs: the default reply carries no access list, the pushed role stays named");
    {
        local $asa_map->{_authorizeVPN} = 1;
        is($asa_map->replyAccessListReplacesRole($req->($bypass)), 1, "ASA with Push ACLs: the VPN reply carries the bypass ACLs, they replace the pushed role");
    }
    my $ios12_map = pf::Switch::Cisco::Cisco_IOS_12_x->new({%args, UsePushACLs => 'Y', AccessListMap => 'Y'});
    is($ios12_map->replyAccessListReplacesRole({ %{$req->($bypass)}, compute_acl => 1 }), 1, "Cisco_IOS_12_x with Push ACLs: the reply computing the ACLs carries the bypass ACLs");
    is($ios12_map->replyAccessListReplacesRole({ %{$req->($bypass)}, compute_acl => 0 }), 0, "Cisco_IOS_12_x with Push ACLs: a reply not computing the ACLs keeps the pushed role named");

    # The reply decides whether the bypass ACLs replace the pushed role before
    # the module sends them: both get them from one translation of the node of
    # the request, without a node_view
    {
        my ($calls, $views) = (0, 0);
        my $orig = \&pf::Switch::_getAccessListByName;
        $node_mock->mock('_getAccessListByName', sub { $calls++; $orig->(@_) });
        $node_mock->mock('node_view', sub { $views++; undef });
        my $request = $req->($bypass);
        is($cisco_map->replyAccessListReplacesRole($request), 1, "one request: the bypass ACLs replace the pushed role");
        is($cisco_map->getAccessListByName('r4', $mac, undef, $request), chew($cisco, $bypass), "one request: the module sends the same bypass ACLs");
        is($calls, 1, "one request: the access list is translated once");
        is($views, 0, "one request: the node of the request is used, no node_view");
        $node_mock->unmock('_getAccessListByName');
        $node_mock->mock('node_view', sub { defined($node_acls) ? { mac => $mac, bypass_acls => $node_acls } : undef });
    }

    # Bypass ACLs that translate to nothing (an out| line on a switch without
    # out ACLs) send no access list, and the ACLs of the role are not used in
    # their place: the bypass ACLs replace them
    $node_acls = "out|permit ip any host 10.0.0.1";
    my $nothing = $cisco->getAccessListByName('r4', $mac);
    ok(!defined($nothing) || $nothing eq '', "Cisco: bypass ACLs that translate to nothing send no access list, not the ACLs of the role");
    $nothing = $aruba->getAccessListByName('r4', $mac);
    ok(!defined($nothing) || $nothing eq '', "Aruba CX: bypass ACLs that translate to nothing send no access list, not the ACLs of the role");
    $node_acls = undef;
    is($cisco_map->replyAccessListReplacesRole($req->("out|permit ip any host 10.0.0.1")), 0, "Cisco with Push ACLs: bypass ACLs that translate to nothing leave the pushed role named");

    # An out| line is only kept for the push: in a RADIUS reply a switch
    # without out ACLs skips it, Push ACLs enabled or not
    is($cisco_push->acl_chewer("out|deny ip any host 10.0.0.1\npermit ip any any", 'r4'), chew($cisco, "permit ip any any"), "Cisco with Push ACLs: outside of the push an out| line is skipped like without Push ACLs");
    {
        local $cisco_push->{_aclsForPush} = 1;
        like($cisco_push->acl_chewer("out|deny ip any host 10.0.0.1\npermit ip any any", 'r4'), qr/^out\|deny ip any host 10\.0\.0\.1$/m, "Cisco with Push ACLs: the push keeps the out| line");
    }
    is($cisco->nodeBypassAcls({ bypass_acls => "permit ip any any\n" }), "permit ip any any", "nodeBypassAcls: the bypass ACLs of a node without their trailing newline");
    is($cisco->nodeBypassAcls({ bypass_acls => " \n" }), undef, "nodeBypassAcls: blank bypass ACLs are none");
    is($cisco->nodeBypassAcls(undef), undef, "nodeBypassAcls: no node is none");
    is($cisco->nodeBypassAcls(bless({ bypass_acls => "permit ip any any" }, 'pf::dal::node')), "permit ip any any", "nodeBypassAcls: the node_info of a RADIUS request is a pf::dal::node object");

    # The source of a per-user ACL is the endpoint itself: a Cisco switch does
    # not apply an ACL with another source. A permit with one is skipped, a
    # deny with one ends the ACLs with a deny all
    $node_acls = "deny ip host 10.1.1.1 any\npermit ip any any";
    is($aruba->getAccessListByName('r4', $mac), deny_all($aruba), "Aruba CX: a bypass deny with a source address denies everything");
    is($cisco->getAccessListByName('r4', $mac), deny_all($cisco), "Cisco: a bypass deny with a source address denies everything rather than letting the permit after it through");
    $node_acls = "permit ip 10.0.0.0 0.0.0.255 any\npermit ip any any";
    is($aruba->getAccessListByName('r4', $mac), chew($aruba, "permit ip any any"), "Aruba CX: a bypass permit with a source address is skipped, the other lines are sent");
    is($cisco->getAccessListByName('r4', $mac), chew($cisco, "permit ip any any"), "Cisco: a bypass permit with a source address is skipped, the other lines are sent");
    $node_acls = undef;

    # An object group names an object of the switch that the parser cannot
    # resolve: never sent as a broken line
    $node_acls = "permit object-group foo any any";
    is($aruba->getAccessListByName('r4', $mac), deny_all($aruba), "Aruba CX: a bypass ACL on an object group denies everything rather than sending a broken line");
    is($cisco->getAccessListByName('r4', $mac), deny_all($cisco), "Cisco: a bypass ACL on an object group denies everything rather than sending a broken line");
    $node_acls = undef;

    # ACLs the parser cannot read (in the native syntax of the switch) are
    # denied everything, like the ACLs of a role, never sent as written
    my $native = "permit in tcp from any to any 80";
    $node_acls = $native;
    is($aruba->getAccessListByName('r4', $mac), deny_all($aruba), "Aruba CX: bypass ACLs the parser cannot read deny everything");
    $node_acls = undef;

    # The access list of the switch entry is sent as the administrator wrote it,
    # in the syntax of the switch: it does not go through acl_chewer
    my $entry = pf::Switch::Aruba::ArubaOS_CX_10_x->new({%args, access_lists => { r4 => $native }});
    is($entry->getAccessListByName('r4', $mac), $native, "Aruba CX: the access list of the switch entry is sent as written, in the syntax of the switch");
    my $cisco_entry = pf::Switch::Cisco::Cisco_IOS_15_5->new({%args, access_lists => { r4 => "permit udp any eq 68 any" }});
    is($cisco_entry->getAccessListByName('r4', $mac), "permit udp any eq 68 any", "Cisco: the access list of the switch entry is sent as written, not filtered like the ACLs of a role");
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
