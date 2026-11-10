#!/usr/bin/perl

=head1 NAME

switch_cache_ifindex

=head1 DESCRIPTION

unit test for the switch_cache_ifindex pfcron task (#7380)

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 23;
use Test::NoWarnings;
use JSON::MaybeXS qw(encode_json);
use pf::pfcron::task::switch_cache_ifindex;
use pf::SwitchFactory;
use pf::Switch;

my $task = pf::pfcron::task::switch_cache_ifindex->new({
    status => "enabled",
    id     => 'test',
    type     => 'switch_cache_ifindex',
    interval => 0,
});

my $IFDESCR = [-baseoid => '1.3.6.1.2.1.2.2.1.2'];

# ----------------------------------------------------------------------------
# which modules cache a table
# ----------------------------------------------------------------------------

{
    my $sg300 = pf::SwitchFactory->instantiate('172.16.8.43');
    is_deeply([$sg300->ifIndexCacheTables], [], 'SG300 has no SNMP table to cache');
    is($sg300->refreshIfIndexCache, undef, 'refreshing SG300 is a no-op, not a failure');

    my $c4500 = pf::SwitchFactory->instantiate('172.16.8.44');
    is_deeply([$c4500->ifIndexCacheTables], [$IFDESCR], 'Catalyst 4500 caches the same ifDescr table as the other Cisco IOS modules');
    is($c4500->cachedSNMPTableKey($IFDESCR), '172.16.8.44-' . encode_json($IFDESCR), 'the cache key is the switch id and the JSON arguments');
}

# ----------------------------------------------------------------------------
# run(): every switch whose table is cached is refreshed, and only those
# ----------------------------------------------------------------------------

# the switches of the test configuration whose module caches an SNMP table for the ifIndex lookup
my %expected;
foreach my $id (keys %pf::SwitchFactory::SwitchConfig) {
    next if $id !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ || $id eq '127.0.0.1';
    my $switch = pf::SwitchFactory->instantiate($id) or next;
    my @tables = $switch->ifIndexCacheTables or next;
    $expected{$id} = 1;
    # the switch has already translated a NAS-Port-Id
    $switch->cache_distributed->set($switch->cachedSNMPTableKey($tables[0]), { "$tables[0][1].1" => 'GigabitEthernet1/0/1' });
}
ok(scalar(keys %expected) > 0, 'the test configuration has switches with an ifIndex cache');
ok($expected{'172.16.8.44'} && !$expected{'172.16.8.43'}, 'the Catalyst 4500 is one of them, the SG300 is not');

my %refreshed;
{
    no warnings qw(redefine once);
    local *pf::Switch::refreshCachedSNMPTable = sub { $refreshed{ $_[0]{_id} } = 1; 1 };
    $task->run();
}
is_deeply(\%refreshed, \%expected, 'every switch with a cached ifIndex table is refreshed, and only those');

# a switch that never translated a NAS-Port-Id is not walked
{
    my $id = (sort keys %expected)[0];
    my $switch = pf::SwitchFactory->instantiate($id);
    $switch->cache_distributed->remove($switch->cachedSNMPTableKey(($switch->ifIndexCacheTables)[0]));
    my $walked = 0;
    no warnings qw(redefine once);
    local *pf::Switch::refreshCachedSNMPTable = sub { $walked = 1; 1 };
    is(pf::pfcron::task::switch_cache_ifindex::refresh_switch($id), undef, 'a switch without a cached table is skipped');
    ok(!$walked, 'and not walked');
    delete $expected{$id};
}

is(pf::pfcron::task::switch_cache_ifindex::refresh_switch('172.16.8.43'), undef, 'a switch whose module caches nothing is skipped');
is(pf::pfcron::task::switch_cache_ifindex::refresh_switch('no.such.switch'), 0, 'an unknown switch is a failure');
{
    no warnings qw(redefine once);
    local *pf::Switch::refreshCachedSNMPTable = sub { 0 };
    is(pf::pfcron::task::switch_cache_ifindex::refresh_switch((sort keys %expected)[0]), 0, 'a failed walk is a failure');
}

# ----------------------------------------------------------------------------
# switch ranges: host addresses only, and only when process_switchranges is on
# ----------------------------------------------------------------------------

{
    my %seen;
    no warnings qw(redefine once);
    local *pf::pfcron::task::switch_cache_ifindex::refresh_switch = sub { $seen{ $_[0] } = 1; undef };

    # 192.168.184.0/21 is the only range of the test configuration not nested in another one
    my $in_range = sub { grep { /^192\.168\.(18[4-9]|19[01])\./ } sort keys %seen };

    $task->run();
    ok(!$in_range->(), 'switch ranges are left alone by default');

    %seen = ();
    $task->process_switchranges('enabled');
    $task->run();
    $task->process_switchranges('disabled');
    is(scalar $in_range->(), 2046, 'a /21 range is expanded to its 2046 host addresses');
    ok($seen{'192.168.184.1'} && $seen{'192.168.191.254'}, 'the first and last host addresses are included');
    ok(!$seen{'192.168.184.0'} && !$seen{'192.168.191.255'}, 'the network and broadcast addresses are not');
}

# ----------------------------------------------------------------------------
# refreshCachedSNMPTable stores the walk under the key cachedSNMPTable reads
# ----------------------------------------------------------------------------

{
    package t::FakeSession;
    sub new { bless { calls => 0 }, shift }
    sub get_table { my ($self, %a) = @_; $self->{calls}++; return { "$a{-baseoid}.9" => "GigabitEthernet1/0/$self->{calls}" } }
    sub error { '' }
    package t::FakeCache;
    sub new { bless { store => {} }, shift }
    sub set { my ($self, $k, $v) = @_; $self->{store}{$k} = $v }
    sub get { my ($self, $k) = @_; $self->{store}{$k} }
    sub compute { my ($self, $k, $o, $sub) = @_; $self->{store}{$k} //= $sub->(); $self->{store}{$k} }
    package t::Switch;
    our @ISA = ('pf::Switch::Cisco::Cisco_IOS');
    my $cache = t::FakeCache->new;
    sub cache_distributed { $cache }
    sub connectRead { 1 }
}
my $session = t::FakeSession->new;
my $switch = bless { _id => '192.0.2.13', _sessionRead => $session }, 't::Switch';
ok(!$switch->hasCachedIfIndexTables, 'nothing cached before the first lookup');
is($switch->getIfIndexByNasPortId('GigabitEthernet1/0/1'), 9, 'first lookup walks the table');
ok($switch->hasCachedIfIndexTables, 'the lookup cached the table');
ok($switch->refreshIfIndexCache, 'refresh succeeds');
is($session->{calls}, 2, 'the refresh walks again even though the entry is cached');
is_deeply([keys %{ t::Switch::cache_distributed()->{store} }], ['192.0.2.13-' . encode_json($IFDESCR)], 'the refresh writes the entry getIfIndexByNasPortId reads');

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
