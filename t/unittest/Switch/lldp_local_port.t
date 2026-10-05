#!/usr/bin/perl

=head1 NAME

lldp_local_port

=head1 DESCRIPTION

ifIndexToLldpLocalPort maps an ifIndex to its LLDP local port number, and the
lldpLocPortTable walks work over every SNMP version.

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 11;
use Test::NoWarnings;
use pf::Switch;

my $DESC = '1.0.8802.1.1.2.1.3.7.1.4';
my $ID   = '1.0.8802.1.1.2.1.3.7.1.3';

{
    package t::FakeSession;
    sub new { my ($class) = @_; bless { calls => [] }, $class }
    sub get_table {
        my ($self, %args) = @_;
        push @{$self->{calls}}, \%args;
        return { "$args{-baseoid}.1" => 'x' };
    }
    package t::FakeCache;
    sub new { bless {}, shift }
    sub compute { my ($self, $key, $sub) = @_; return $sub->() }
    package t::Switch;
    our @ISA = ('pf::Switch');
    sub connectRead { 1 }
    sub cache_distributed { t::FakeCache->new }
    sub getIfDesc { $_[0]{t_ifdesc}{$_[1]} // '' }
    sub getIfName { $_[0]{t_ifname}{$_[1]} // '' }
}

sub fake_switch {
    my (%args) = @_;
    return bless { _id => '192.0.2.1', _ip => '192.0.2.1', %args }, 't::Switch';
}

sub with_tables {
    my ($desc, $id) = @_;
    no warnings qw(redefine once);
    *t::Switch::getLldpLocPortDesc = sub { $desc };
    *t::Switch::getLldpLocPortId   = sub { $id };
}

# Cisco IOS: lldpLocPortDesc carries ifDescr
with_tables({ "$DESC.1" => 'GigabitEthernet1/0/1', "$DESC.2" => 'GigabitEthernet1/0/2' }, { "$ID.1" => 'Gi1/0/1', "$ID.2" => 'Gi1/0/2' });
my $cisco = fake_switch(t_ifdesc => { 10 => 'GigabitEthernet1/0/2' }, t_ifname => { 10 => 'Gi1/0/2' });
is($cisco->ifIndexToLldpLocalPort(10), 2, 'port found by its description (Cisco)');

# Arista EOS: lldpLocPortDesc is the interface description set by the admin
with_tables({ "$DESC.1" => 'Lab endpoint', "$DESC.2" => '' }, { "$ID.1" => 'Ethernet1', "$ID.2" => 'Ethernet2' });
my $arista = fake_switch(t_ifdesc => { 1 => 'Ethernet1' }, t_ifname => { 1 => 'Ethernet1' });
is($arista->ifIndexToLldpLocalPort(1), 1, 'port found by its port ID when the description is the admin one (Arista)');

# ifDescr matches nothing, ifName matches the port ID
with_tables({ "$DESC.7" => 'uplink' }, { "$ID.7" => 'ge-0/0/7' });
my $by_name = fake_switch(t_ifdesc => { 507 => 'ge-0/0/7.0 logical' }, t_ifname => { 507 => 'ge-0/0/7' });
is($by_name->ifIndexToLldpLocalPort(507), 7, 'port found by ifName');

# Port 3 is described as "Ethernet4": the description table is ambiguous for Ethernet4
with_tables({ "$DESC.3" => 'Ethernet4', "$DESC.4" => 'Ethernet4' }, { "$ID.3" => 'Ethernet3', "$ID.4" => 'Ethernet4' });
my $clash = fake_switch(t_ifdesc => { 4 => 'Ethernet4' }, t_ifname => { 4 => 'Ethernet4' });
is($clash->ifIndexToLldpLocalPort(4), 4, 'an ambiguous description falls back to the port ID');

with_tables({ "$DESC.1" => 'Lab endpoint' }, { "$ID.1" => 'Ethernet1' });
my $unknown = fake_switch(t_ifdesc => { 9 => 'Ethernet9' }, t_ifname => { 9 => 'Ethernet9' });
is($unknown->ifIndexToLldpLocalPort(9), undef, 'unknown port returns undef');

my $noname = fake_switch();
is($noname->ifIndexToLldpLocalPort(9), undef, 'no ifDescr nor ifName returns undef');

with_tables(undef, undef);
is($arista->ifIndexToLldpLocalPort(1), undef, 'failed walks return undef');

# The walks: max-repetitions only where SNMP has get-bulk
{
    no warnings 'redefine';
    delete $t::Switch::{getLldpLocPortDesc};
    delete $t::Switch::{getLldpLocPortId};
}
for my $version ('1', '2c', '3') {
    my $session = t::FakeSession->new;
    my $switch = fake_switch(_SNMPVersion => $version, _sessionRead => $session);
    $switch->getLldpLocPortDesc;
    $switch->getLldpLocPortId;
    my @calls = @{$session->{calls}};
    my @walked = map { $_->{-baseoid} } @calls;
    my @bulk = map { exists $_->{-maxrepetitions} ? 1 : 0 } @calls;
    my $expected_bulk = $version eq '1' ? [0, 0] : [1, 1];
    my $label = $version eq '1' ? 'no max-repetitions on SNMPv1' : "max-repetitions on SNMPv$version";
    is_deeply([\@walked, \@bulk], [[$DESC, $ID], $expected_bulk], $label);
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
