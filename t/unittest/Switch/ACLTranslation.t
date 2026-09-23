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

use Test::More tests => 29;
use pf::Switch;
use pf::Switch::Aruba::ArubaOS_CX_10_x;
use pf::Switch::Arista::AristaSwitch;
use pf::Switch::HP::AOS_Switch_v16_X;

#This test will running last
use Test::NoWarnings;

my %args = (id => 'test', ip => '1.1.1.1', SNMPUseConnector => "N", radiusDeauthUseConnector => "N");
my $aruba = pf::Switch::Aruba::ArubaOS_CX_10_x->new({%args});
my $arista = pf::Switch::Arista::AristaSwitch->new({%args});
my $aos = pf::Switch::HP::AOS_Switch_v16_X->new({%args});

sub chew {
    my ($switch, $acl) = @_;
    return $switch->acl_chewer($acl, 'testrole') // '';
}

# NAS-Filter-Rule: what can be expressed

is(chew($aruba, "permit tcp any host 10.0.0.1 eq 443"), "in|permit in tcp from any to 10.0.0.1 443\n", "Aruba CX: eq port");
is(chew($arista, "permit tcp any host 10.0.0.1 eq 443"), "in|permit in 6 from any to 10.0.0.1 443\n", "Arista: eq port");
is(chew($aos, "permit tcp any host 10.0.0.1 eq 443"), "in|permit in tcp from any to 10.0.0.1 443\n", "AOS: the destination port is sent, it used to be dropped");
is(chew($aruba, "permit tcp any any range 100 200"), "in|permit in tcp from any to any 100-200\n", "Aruba CX: a range becomes a port range");

# NAS-Filter-Rule: a permit that cannot be expressed is skipped

foreach my $switch ([$aruba, 'Aruba CX'], [$arista, 'Arista'], [$aos, 'AOS']) {
    my ($s, $name) = @$switch;
    is(chew($s, "permit ip host 10.1.1.1 any"), "", "$name: a source address is not dropped into a permit from any");
    is(chew($s, "permit udp any eq 53 any"), "", "$name: a source port is not dropped into a permit of every port");
    is(chew($s, "permit tcp any any gt 1024"), "", "$name: gt is not turned into eq or dropped");
    is(chew($s, "permit icmp any any echo"), "", "$name: an ICMP type is not dropped into a permit of all ICMP");
    is(
        chew($s, "permit tcp any any established\npermit ip any host 8.8.8.8"),
        chew($s, "permit ip any host 8.8.8.8"),
        "$name: only the permit that cannot be expressed is skipped"
    );
}

is(chew($arista, "permit tcp any any range 100 200"), "", "Arista: a range is not sent as two bare ports");

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
