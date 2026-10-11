#!/usr/bin/perl

=head1 NAME

System

=head1 DESCRIPTION

unit test for pfappserver::Model::Config::System::Debian merge of /etc/network/interfaces

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 15;

#This test will running last
use Test::NoWarnings;
use pfappserver::Model::Config::System;

my $existing = <<'EOT';
# The loopback network interface
auto lo
iface lo inet loopback

source /etc/network/interfaces.d/*

auto eth0
iface eth0 inet manual
    bond-master bond0

auto bond0
iface bond0 inet static
    address 10.0.0.5
    netmask 255.255.255.0
    gateway 10.0.0.1
    bond-slaves eth0
    bond-mode active-backup
    mtu 9000
    dns-nameservers 10.0.0.2

allow-hotplug eth9
iface eth9 inet dhcp

auto br0
iface br0 inet static
    address 172.16.0.1
    netmask 255.255.0.0
    bridge_ports eth3

auto eth2
iface eth2 inet static
    address 192.168.2.1
    netmask 255.255.255.0
EOT

# What interface_debian.tt generates when PacketFence manages bond0 (new IP),
# eth0 (bond member, no IP) and eth2 (IP removed)
my $generated = <<'EOT';
auto lo
iface lo inet loopback

auto bond0
 iface bond0 inet static
    address 10.0.0.6
    netmask 255.255.255.0
    gateway 10.0.0.254

auto eth0

auto eth2

EOT

my $merged = pfappserver::Model::Config::System::Debian::merge_interfaces_config($generated, $existing, [qw(bond0 eth0 eth2)]);
my $items = pfappserver::Model::Config::System::Debian::parse_interfaces_config($merged);
my %iface = map { ("$_->{name} $_->{family}" => $_) } grep { $_->{type} eq 'iface' } @$items;
my %auto = map { my $i = $_; map { ($_ => $i->{keyword}) } @{$i->{names}} } grep { $_->{type} eq 'auto' } @$items;

is_deeply($iface{'bond0 inet'}{options}, [
    'address 10.0.0.6', 'netmask 255.255.255.0', 'gateway 10.0.0.254',
    'bond-slaves eth0', 'bond-mode active-backup', 'mtu 9000', 'dns-nameservers 10.0.0.2',
], 'managed interface: generated address, existing extra options kept') or diag($merged);
is($iface{'eth0 inet'}{header}, 'iface eth0 inet manual', 'managed bond member without IP keeps its manual stanza');
is_deeply($iface{'eth0 inet'}{options}, ['bond-master bond0'], 'bond member options kept');
ok(!$iface{'eth2 inet'}, 'static stanza of a managed interface whose IP was removed is dropped');
is($iface{'br0 inet'}{header}, 'iface br0 inet static', 'unmanaged bridge kept');
is_deeply($iface{'br0 inet'}{options}, ['address 172.16.0.1', 'netmask 255.255.0.0', 'bridge_ports eth3'], 'unmanaged bridge options kept');
is($iface{'eth9 inet'}{header}, 'iface eth9 inet dhcp', 'unmanaged dhcp interface kept');
is($iface{'lo inet'}{header}, 'iface lo inet loopback', 'loopback');
is(scalar(grep { $_->{type} eq 'iface' && $_->{name} eq 'lo' } @$items), 1, 'loopback only once');
ok((grep { $_->{type} eq 'source' && $_->{line} eq 'source /etc/network/interfaces.d/*' } @$items), 'source line kept');
is_deeply([ @auto{qw(lo bond0 eth0 eth2 br0)} ], [ ('auto') x 5 ], 'auto lines of managed and unmanaged interfaces');
is($auto{eth9}, 'allow-hotplug', 'allow-hotplug of an unmanaged interface kept');

# Fresh system: no existing file, output is the generated configuration
sub normalize {
    my ($content) = @_;
    my $parsed = pfappserver::Model::Config::System::Debian::parse_interfaces_config($content);
    return {
        iface => { map { ("$_->{name} $_->{family}" => [ $_->{header}, @{$_->{options}} ]) } grep { $_->{type} eq 'iface' } @$parsed },
        auto  => [ sort map { @{$_->{names}} } grep { $_->{type} eq 'auto' } @$parsed ],
    };
}
my $fresh = pfappserver::Model::Config::System::Debian::merge_interfaces_config($generated, '', [qw(bond0 eth0 eth2)]);
is_deeply(normalize($fresh), normalize($generated), 'without an existing file the generated configuration is used as is');

# Merging twice gives the same result
my $again = pfappserver::Model::Config::System::Debian::merge_interfaces_config($generated, $merged, [qw(bond0 eth0 eth2)]);
is($again, $merged, 'merge is idempotent');

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
