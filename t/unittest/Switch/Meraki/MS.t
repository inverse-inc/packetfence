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

use Test::More tests => 18;
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
