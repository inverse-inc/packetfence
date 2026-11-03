#!/usr/bin/perl

=head1 NAME

MS

=head1 DESCRIPTION

unit test for the VoIP detection of pf::Switch::Meraki::MS (#7236)

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

use Test::More tests => 42;
use pf::Switch::Meraki::MS;
use pf::Switch::Meraki::MS_v15;

#This test will running last
use Test::NoWarnings;

# CISCO-CDP-MIB cdpCacheTable of a Meraki MS (issue #7236 SNMP walk):
# three Cisco IP phones on ports 13, 15 and 17, a Catalyst on port 28
my $CDP = '1.3.6.1.4.1.9.9.23.1.2.1.1';
my %walk = (
    "$CDP.6.13.0" => 'SEPE8EDF3AA8846',
    "$CDP.6.15.1" => 'SEP689CE2E63A37',
    "$CDP.6.17.2" => 'SEPBCC493A5ED8F',
    "$CDP.6.28.3" => 'Redacted',
    "$CDP.9.13.0" => '0x00000490',
    "$CDP.9.15.1" => '0x00000490',
    "$CDP.9.17.2" => '0x00000490',
    "$CDP.9.28.3" => '0x00000028',
);

{
    package FakeSNMPSession;
    sub new { bless {}, shift }
    sub error { undef }
    sub _cmp {
        my @a = split /\./, $_[0];
        my @b = split /\./, $_[1];
        while (@a && @b) {
            my $c = shift(@a) <=> shift(@b);
            return $c if $c;
        }
        return @a <=> @b;
    }
    sub get_next_request {
        my ($self, %args) = @_;
        my ($oid) = @{$args{-varbindlist}};
        my ($next) = grep { _cmp($_, $oid) > 0 } sort { _cmp($a, $b) } keys %walk;
        return defined $next ? { $next => $walk{$next} } : undef;
    }
    sub get_request {
        my ($self, %args) = @_;
        my ($oid) = @{$args{-varbindlist}};
        return exists $walk{$oid} ? { $oid => $walk{$oid} } : undef;
    }
}

for my $class (qw(pf::Switch::Meraki::MS pf::Switch::Meraki::MS_v15)) {
    ok($class->supportsCdp, "$class supports CDP");
}

my $switch = pf::Switch::Meraki::MS_v15->new({ id => '10.0.0.1', ip => '10.0.0.1', VoIPEnabled => 'Y' });
$switch->{_sessionRead} = FakeSNMPSession->new;

is_deeply([$switch->getPhonesCDPAtIfIndex(13)], ['e8:ed:f3:aa:88:46'], "phone found on port 13");
is_deeply([$switch->getPhonesCDPAtIfIndex(15)], ['68:9c:e2:e6:3a:37'], "phone found on port 15");
is_deeply([$switch->getPhonesCDPAtIfIndex(28)], [], "a switch neighbor is not a phone");
is_deeply([$switch->getPhonesCDPAtIfIndex(14)], [], "no neighbor on port 14");
is_deeply([$switch->getPhonesDPAtIfIndex(17)], ['bc:c4:93:a5:ed:8f'], "getPhonesDPAtIfIndex uses CDP");

# Only a found phone is cached: the switch lists the CDP neighbor minutes after
# the port comes up, after the first RADIUS request of the phone
$switch->{_VoIPDHCPDetect} = 'N';
my $cache = $switch->cache_distributed;
my $laptop = '00:11:22:33:44:14';
$cache->remove("10.0.0.1-SNMP-isPhoneAtIfIndex-14-$laptop");
ok(!$switch->isPhoneAtIfIndex($laptop, 14), "a device without CDP entry is not a phone");
ok(!defined($cache->get("10.0.0.1-SNMP-isPhoneAtIfIndex-14-$laptop")), "the miss is not cached");
$cache->remove("10.0.0.1-SNMP-isPhoneAtIfIndex-13-e8:ed:f3:aa:88:46");
ok($switch->isPhoneAtIfIndex('e8:ed:f3:aa:88:46', 13), "the phone of port 13 is found");
ok($cache->get("10.0.0.1-SNMP-isPhoneAtIfIndex-13-e8:ed:f3:aa:88:46"), "the found phone is cached");

# A device that is not a phone is authenticated again, in case its CDP entry was not there yet
$cache->remove("10.0.0.1-CDP-recheck-$laptop");
ok($switch->_cdpRecheck({ mac => $laptop, ifIndex => 14, isPhone => 0 }), "first answer: authenticate again later");
ok($switch->_cdpRecheck({ mac => $laptop, ifIndex => 14, isPhone => 0 }), "link flap right after: authenticate again later");
$cache->set("10.0.0.1-CDP-recheck-$laptop", time() - 301);
ok($switch->_cdpRecheck({ mac => $laptop, ifIndex => 14, isPhone => 0 }), "5 minutes later, CDP may still be late: authenticate again later");
$cache->set("10.0.0.1-CDP-recheck-$laptop", time() - 901);
ok(!$switch->_cdpRecheck({ mac => $laptop, ifIndex => 14, isPhone => 0 }), "after 15 minutes: still not a phone, regular answer");
ok(!$switch->_cdpRecheck({ mac => 'e8:ed:f3:aa:88:46', ifIndex => 13, isPhone => 1 }), "no recheck for a phone");

$switch->{_VoIPEnabled} = 'N';
is_deeply([$switch->getPhonesCDPAtIfIndex(13)], [], "nothing when VoIP is disabled");

# A switch that does not answer SNMP (SNMP disabled in the Meraki dashboard) is
# probed once, then not queried again for 10 minutes: no RADIUS request waits
# for the SNMP timeout, and no re-authentication is asked for
my $probes = 0;
{
    no warnings qw(redefine once);
    *t::MS_no_snmp::connectRead = sub { $probes++; return 0 };
    @t::MS_no_snmp::ISA = ('pf::Switch::Meraki::MS_v15');
}
my $no_snmp = t::MS_no_snmp->new({ id => '10.0.0.2', ip => '10.0.0.2', VoIPEnabled => 'Y', VoIPDHCPDetect => 'N' });
$cache->remove("10.0.0.2-CDP-snmp-unreachable");
$cache->remove("10.0.0.2-CDP-recheck-$laptop");
is_deeply([$no_snmp->getPhonesCDPAtIfIndex(13)], [], "no phone when the switch does not answer SNMP");
is($probes, 1, "the switch is probed once");
ok($cache->get("10.0.0.2-CDP-snmp-unreachable"), "the failure is remembered");
ok(!$no_snmp->isPhoneAtIfIndex($laptop, 14), "the next lookup is not a phone");
ok(!$no_snmp->_cdpRecheck({ mac => $laptop, ifIndex => 14, isPhone => 0 }), "no re-authentication when the switch does not answer SNMP");
is($probes, 1, "the switch is not probed again");

# connectRead succeeds from its cached sysLocation, but the switch no longer
# answers: the CDP request times out
{
    package FakeTimeoutSNMPSession;
    sub new { bless { calls => 0 }, shift }
    sub get_next_request { $_[0]{calls}++; return undef }
    sub get_request { $_[0]{calls}++; return undef }
    sub error { 'No response from remote host "10.0.0.3"' }
}
my $timeout_session = FakeTimeoutSNMPSession->new;
my $stale = pf::Switch::Meraki::MS_v15->new({ id => '10.0.0.3', ip => '10.0.0.3', VoIPEnabled => 'Y', VoIPDHCPDetect => 'N' });
$stale->{_sessionRead} = $timeout_session;
$cache->remove("10.0.0.3-CDP-snmp-unreachable");
$cache->remove("10.0.0.3-CDP-recheck-$laptop");
is_deeply([$stale->getPhonesCDPAtIfIndex(14)], [], "no phone when the CDP request times out");
ok($cache->get("10.0.0.3-CDP-snmp-unreachable"), "the timeout is remembered");
my $calls = $timeout_session->{calls};
ok(!$stale->isPhoneAtIfIndex($laptop, 14), "the next lookup is not a phone");
is($timeout_session->{calls}, $calls, "the switch is not queried again");
ok(!$stale->_cdpRecheck({ mac => $laptop, ifIndex => 14, isPhone => 0 }), "no re-authentication after a timeout");

# "Use SNMP" disabled on the switch: no probe, no warning, nothing remembered
my $snmp_off_probes = 0;
{
    no warnings qw(redefine once);
    *t::MS_snmp_off::connectRead = sub { $snmp_off_probes++; return pf::Switch::connectRead(@_) };
    @t::MS_snmp_off::ISA = ('pf::Switch::Meraki::MS_v15');
}
my $snmp_off = t::MS_snmp_off->new({ id => '10.0.0.4', ip => '10.0.0.4', VoIPEnabled => 'Y', VoIPDHCPDetect => 'N', useSNMP => 'N' });
$cache->remove("10.0.0.4-CDP-snmp-unreachable");
{
    my @warnings;
    no warnings qw(redefine once);
    local *pf::Switch::Meraki::MS::_snmpUnreachable = sub { push @warnings, $_[1] };
    is_deeply([$snmp_off->getPhonesCDPAtIfIndex(13)], [], "no phone when Use SNMP is disabled");
    ok(!$snmp_off->_cdpRecheck({ mac => $laptop, ifIndex => 14, isPhone => 0 }), "no re-authentication when Use SNMP is disabled");
    is($snmp_off_probes, 0, "the switch is not probed when Use SNMP is disabled");
    is(scalar(@warnings), 0, "no 'does not answer SNMP' warning when Use SNMP is disabled");
}

# returnRadiusAccessAccept: the recheck attributes, and the RADIUS filter
# evaluated once over the complete reply
{
    use pf::radius::constants;
    my $filter_calls = 0;
    my $parent_reply;
    no warnings qw(redefine once);
    local *pf::access_filter::radius::test = sub { $filter_calls++; return undef };
    local *pf::Switch::returnRadiusAccessAccept = sub {
        my ($self, $args) = @_;
        $filter_calls++ unless $args->{'unfiltered'};
        return [ $RADIUS::RLM_MODULE_OK, %{ $parent_reply // {} } ];
    };
    $switch->{_VoIPEnabled} = 'Y';
    my %args = (mac => $laptop, ifIndex => 14, isPhone => 0, user_role => 'default', vlan => 1);

    $cache->remove("10.0.0.1-CDP-recheck-$laptop");
    $filter_calls = 0;
    my ($status, %reply) = @{ $switch->returnRadiusAccessAccept({ %args }) };
    is($reply{'Session-Timeout'}, pf::Switch::Meraki::MS::CDP_RECHECK_TIMEOUT(), "a device that is not a phone yet is authenticated again later");
    is($reply{'Termination-Action'}, 1, "without the port going down (Termination-Action RADIUS-Request)");
    is($filter_calls, 1, "the RADIUS filter is evaluated once");

    $filter_calls = 0;
    ($status, %reply) = @{ $switch->returnRadiusAccessAccept({ %args, mac => 'e8:ed:f3:aa:88:46', ifIndex => 13, isPhone => 1 }) };
    ok(!exists $reply{'Session-Timeout'} && !exists $reply{'Termination-Action'}, "a phone gets the regular answer");
    is($filter_calls, 1, "the RADIUS filter is evaluated once for a phone");

    $cache->remove("10.0.0.1-CDP-recheck-$laptop");
    $parent_reply = { 'Session-Timeout' => 600 };
    ($status, %reply) = @{ $switch->returnRadiusAccessAccept({ %args }) };
    is($reply{'Session-Timeout'}, 600, "a Session-Timeout already in the reply is kept");
    ok(!exists $reply{'Termination-Action'}, "and no Termination-Action is added to it");
    $parent_reply = undef;

    $cache->remove("10.0.0.1-CDP-recheck-$laptop");
    $filter_calls = 0;
    ($status, %reply) = @{ $switch->returnRadiusAccessAccept({ %args, unfiltered => 1 }) };
    is($filter_calls, 0, "a caller that filters itself gets an unfiltered reply");
    ok(exists $reply{'Session-Timeout'}, "with the recheck attributes");
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
