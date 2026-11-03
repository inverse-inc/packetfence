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

use Test::More tests => 30;

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

# A deleted interface is not kept as an unmanaged one: its stanza and auto entry are dropped
my $removed = pfappserver::Model::Config::System::Debian::merge_interfaces_config($generated, $merged, [qw(bond0 eth0 eth2)], [qw(br0)]);
my $removed_items = normalize($removed);
ok(!$removed_items->{iface}{'br0 inet'}, 'stanza of a removed interface is dropped') or diag($removed);
ok(!(grep { $_ eq 'br0' } @{$removed_items->{auto}}), 'auto entry of a removed interface is dropped');
is_deeply($removed_items->{iface}{'eth9 inet'}, ['iface eth9 inet dhcp'], 'the other unmanaged interfaces are kept');

# An interface both managed and removed stays managed
my $managed_removed = pfappserver::Model::Config::System::Debian::merge_interfaces_config($generated, $merged, [qw(bond0 eth0 eth2)], [qw(eth0)]);
is($managed_removed, $merged, 'a managed interface is not removed');

# Comments are kept with what they describe
my $commented = <<'EOT';
# Generated by the installer, edited by hand

# The loopback network interface
auto lo
iface lo inet loopback

# Uplink bond
auto bond0
iface bond0 inet static
    address 10.0.0.5
    netmask 255.255.255.0
    # jumbo frames for the storage network
    mtu 9000

# Lab bridge, do not remove
auto br0
iface br0 inet static
    address 172.16.0.1
    netmask 255.255.0.0
#iface br1 inet manual
EOT
my $commented_merged = pfappserver::Model::Config::System::Debian::merge_interfaces_config($generated, $commented, [qw(bond0 eth0 eth2)]);
like($commented_merged, qr/\A# Generated by the installer, edited by hand\n\n/, 'the header of the file stays at the top') or diag($commented_merged);
like($commented_merged, qr/# The loopback network interface\niface lo inet loopback\n/, 'the comment of the auto line of an interface goes with its stanza');
like($commented_merged, qr/# Uplink bond\niface bond0 inet static\n/, 'the comment of a managed interface is kept before its generated stanza');
like($commented_merged, qr/\n    # jumbo frames for the storage network\n    mtu 9000\n/, 'a comment inside a stanza stays in it');
like($commented_merged, qr/# Lab bridge, do not remove\niface br0 inet static\n/, 'the comment of an unmanaged stanza is kept');
like($commented_merged, qr/\n#iface br1 inet manual\n$/, 'a commented out stanza at the end is kept');
is(pfappserver::Model::Config::System::Debian::merge_interfaces_config($generated, $commented_merged, [qw(bond0 eth0 eth2)]), $commented_merged, 'merging with comments is idempotent');

# No address from PacketFence (inet manual): an existing dhcp stanza is not replaced
my $dhcp = pfappserver::Model::Config::System::Debian::merge_interfaces_config(
    "auto lo\niface lo inet loopback\n\nauto eth9\niface eth9 inet manual\n",
    "auto eth9\niface eth9 inet dhcp\n    dns-search example.com\n",
    [qw(eth9)],
);
is_deeply(normalize($dhcp)->{iface}{'eth9 inet'}, ['iface eth9 inet dhcp', 'dns-search example.com'], 'a dhcp stanza is kept when PacketFence only brings the interface up') or diag($dhcp);

# Interfaces defined by the included files (ex: cloud-init)
{
    require File::Temp;
    my $dir = File::Temp::tempdir(CLEANUP => 1);
    mkdir("$dir/interfaces.d");
    mkdir("$dir/extra");
    for my $file (["interfaces.d/50-cloud-init", "auto eth0\niface eth0 inet dhcp\n"], ["extra/vlans", "iface eth0.10 inet manual\n"], ["extra/ignored.bak", "iface eth5 inet dhcp\n"]) {
        open(my $fh, '>', "$dir/$file->[0]") or die $!;
        print $fh $file->[1];
        close($fh);
    }
    my $found = pfappserver::Model::Config::System::Debian::interfaces_in_sourced_files("source interfaces.d/*\nsource-directory $dir/extra\n", "$dir/");
    is($found->{eth0}, "$dir/interfaces.d/50-cloud-init", 'an interface of a sourced file is found, relative to the configuration directory');
    is($found->{'eth0.10'}, "$dir/extra/vlans", 'an interface of a file in a source-directory is found');
    ok(!exists $found->{eth5}, 'source-directory skips the file names that ifupdown skips');
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
