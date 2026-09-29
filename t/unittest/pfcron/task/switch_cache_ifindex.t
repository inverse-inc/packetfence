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

use Test::More tests => 8;
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

# the switches of the test configuration whose module caches an SNMP table for the ifIndex lookup
my %expected;
foreach my $id (keys %pf::SwitchFactory::SwitchConfig) {
    next if $id !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ || $id eq '127.0.0.1';
    my $switch = pf::SwitchFactory->instantiate($id) or next;
    $expected{$id} = 1 if $switch->can('refreshIfIndexCache') != pf::Switch->can('refreshIfIndexCache');
}
ok(scalar(keys %expected) > 0, 'the test configuration has switches with an ifIndex cache');

my %refreshed;
{
    no warnings qw(redefine once);
    local *pf::Switch::Cisco::Cisco_IOS::refreshIfIndexCache = sub { $refreshed{ $_[0]{_id} } = 1; 1 };
    local *pf::Switch::Cisco::Cisco_IOS_12_x::refreshIfIndexCache = sub { $refreshed{ $_[0]{_id} } = 1; 1 };
    local *pf::Switch::Arista::AristaSwitch::refreshIfIndexCache = sub { $refreshed{ $_[0]{_id} } = 1; 1 };
    local *pf::Switch::ArubaSwitch::refreshIfIndexCache = sub { $refreshed{ $_[0]{_id} } = 1; 1 };
    local *pf::Switch::ThreeCom::refreshIfIndexCache = sub { $refreshed{ $_[0]{_id} } = 1; 1 };
    local *pf::Switch::Cisco::Catalyst_4500::refreshIfIndexCache = sub { $refreshed{ $_[0]{_id} } = 1; 1 };
    $task->run();
}
is_deeply(\%refreshed, { map { $_ => 1 } grep { my $s = pf::SwitchFactory->instantiate($_); !$s->isa('pf::Switch::Cisco::SG300') } keys %expected }, 'every switch with an ifIndex cache is refreshed, and only those');

is(pf::pfcron::task::switch_cache_ifindex::refresh_switch('no.such.switch'), 0, 'an unknown switch is a failure');

# refreshCachedSNMPTable stores the walk under the key cachedSNMPTable reads
{
    package t::FakeSession;
    sub new { bless { calls => 0 }, shift }
    sub get_table { my ($self, %a) = @_; $self->{calls}++; return { "$a{-baseoid}.9" => "GigabitEthernet1/0/$self->{calls}" } }
    package t::FakeCache;
    sub new { bless { store => {} }, shift }
    sub set { my ($self, $k, $v) = @_; $self->{store}{$k} = $v }
    sub compute { my ($self, $k, $o, $sub) = @_; $self->{store}{$k} //= $sub->(); $self->{store}{$k} }
    package t::Switch;
    our @ISA = ('pf::Switch::Cisco::Cisco_IOS');
    my $cache = t::FakeCache->new;
    sub cache_distributed { $cache }
    sub connectRead { 1 }
}
my $session = t::FakeSession->new;
my $switch = bless { _id => '192.0.2.13', _sessionRead => $session }, 't::Switch';
is($switch->getIfIndexByNasPortId('GigabitEthernet1/0/1'), 9, 'first lookup walks the table');
ok($switch->refreshIfIndexCache, 'refresh succeeds');
is($session->{calls}, 2, 'the refresh walks again even though the entry is cached');
is_deeply([keys %{ t::Switch::cache_distributed()->{store} }], ['192.0.2.13-' . encode_json([-baseoid => '1.3.6.1.2.1.2.2.1.2'])], 'the refresh writes the entry getIfIndexByNasPortId reads');

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
