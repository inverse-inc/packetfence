#!/usr/bin/perl

=head1 NAME

site_network

=head1 DESCRIPTION

unit test for pf::connector::site_network

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 31;
use Test::NoWarnings;

my %NO_DHCP = ((map { $_ => '' } qw(dhcp_start dhcp_end dhcp_default_lease_time dhcp_max_lease_time dns gateway domain_name)), dns_server => 'disabled');

use pf::connector::site_network qw(
    parse_interface_line format_interface interface_name
    parse_route_line format_route
    expand_site_network flatten_site_network
);

is_deeply(
    parse_interface_line("eth0.100 10.10.100.1/24"),
    { parent => 'eth0', vlan => 100, cidr => '10.10.100.1/24', dhcp => 'disabled', %NO_DHCP },
    "parse a VLAN interface line"
);

is_deeply(
    parse_interface_line("  ens192.4094   192.168.1.1/30  "),
    { parent => 'ens192', vlan => 4094, cidr => '192.168.1.1/30', dhcp => 'disabled', %NO_DHCP },
    "surrounding whitespace is ignored"
);

my $dhcp_line = "eth0.100 10.10.100.1/24 dhcp start=10.10.100.10 end=10.10.100.250 lease=300 max_lease=600 dns=8.8.8.8,8.8.4.4 gateway=10.10.100.254 domain=site.example";
my $dhcp_if = {
    parent => 'eth0', vlan => 100, cidr => '10.10.100.1/24', dhcp => 'enabled', dns_server => 'disabled',
    dhcp_start => '10.10.100.10', dhcp_end => '10.10.100.250',
    dhcp_default_lease_time => '300', dhcp_max_lease_time => '600',
    dns => '8.8.8.8,8.8.4.4', gateway => '10.10.100.254', domain_name => 'site.example',
};
is_deeply(parse_interface_line($dhcp_line), $dhcp_if, "dhcp flag and scope words");
is(format_interface($dhcp_if), $dhcp_line, "format dhcp scope, round trip");
is(parse_interface_line("eth0.100 10.10.100.1/24 bogus"), undef, "unknown flag");
is(parse_interface_line("eth0.100 10.10.100.1/24 dhcp bogus=1"), undef, "unknown key");
is_deeply(
    parse_interface_line("eth0.100 10.10.100.1/24 dhcp start=10.10.100.10 end=10.10.100.20"),
    { %$dhcp_if, dhcp_start => '10.10.100.10', dhcp_end => '10.10.100.20', dhcp_default_lease_time => '', dhcp_max_lease_time => '', dns => '', gateway => '', domain_name => '' },
    "absent scope words are empty"
);
is(format_interface({ %$dhcp_if, dhcp => 'disabled' }), "eth0.100 10.10.100.1/24", "scope words are dropped when dhcp is disabled");
is_deeply(
    parse_interface_line("eth0.100 10.10.100.1/24 dns"),
    { parent => 'eth0', vlan => 100, cidr => '10.10.100.1/24', dhcp => 'disabled', %NO_DHCP, dns_server => 'enabled' },
    "dns flag alone (bare word, not the dns= scope key)"
);
is(format_interface({ %$dhcp_if, dns_server => 'enabled' }), "eth0.100 10.10.100.1/24 dhcp dns start=10.10.100.10 end=10.10.100.250 lease=300 max_lease=600 dns=8.8.8.8,8.8.4.4 gateway=10.10.100.254 domain=site.example", "format with both flags");

is(parse_interface_line("eth0 10.10.100.1/24"), undef, "no vlan tag in the name");
is(parse_interface_line("eth0.100"), undef, "missing address");
is(parse_interface_line(""), undef, "empty line");
is(parse_interface_line(undef), undef, "undef line");

is(format_interface({ parent => 'eth0', vlan => 100, cidr => '10.10.100.1/24' }), "eth0.100 10.10.100.1/24", "format an interface");
is(interface_name({ parent => 'bond0', vlan => 7 }), "bond0.7", "interface name");

is_deeply(
    parse_route_line("10.20.0.0/16 via 10.10.100.254 dev eth0.100"),
    { destination => '10.20.0.0/16', gateway => '10.10.100.254', interface => 'eth0.100' },
    "route with gateway and interface"
);

is_deeply(
    parse_route_line("192.168.50.0/24 dev eth0.101"),
    { destination => '192.168.50.0/24', gateway => '', interface => 'eth0.101' },
    "route with interface only"
);

is_deeply(
    parse_route_line("10.30.0.0/16 via 10.10.100.254"),
    { destination => '10.30.0.0/16', gateway => '10.10.100.254', interface => '' },
    "route with gateway only"
);

is(parse_route_line("10.30.0.0/16 via"), undef, "dangling keyword");
is(parse_route_line("10.30.0.0/16 gw 1.2.3.4"), undef, "unknown keyword");

is(format_route({ destination => '10.20.0.0/16', gateway => '10.10.100.254', interface => 'eth0.100' }), "10.20.0.0/16 via 10.10.100.254 dev eth0.100", "format a full route");
is(format_route({ destination => '192.168.50.0/24', gateway => '', interface => 'eth0.101' }), "192.168.50.0/24 dev eth0.101", "format a dev-only route");
is(format_route({ destination => '10.30.0.0/16', gateway => '10.10.100.254' }), "10.30.0.0/16 via 10.10.100.254", "format a via-only route");

# expand: array of lines (ConfigStore) and newline string (pfconfig) both work
my $cfg = {
    interfaces => ["eth0.100 10.10.100.1/24", "garbage", "eth0.101 10.10.101.1/24"],
    routes     => "10.20.0.0/16 via 10.10.100.254 dev eth0.100\n\n192.168.50.0/24 dev eth0.101",
};
expand_site_network($cfg);
is_deeply(
    $cfg->{interfaces},
    [
        { parent => 'eth0', vlan => 100, cidr => '10.10.100.1/24', dhcp => 'disabled', %NO_DHCP },
        { parent => 'eth0', vlan => 101, cidr => '10.10.101.1/24', dhcp => 'disabled', %NO_DHCP },
    ],
    "expand interfaces from an array, dropping unparseable lines"
);
is_deeply(
    $cfg->{routes},
    [
        { destination => '10.20.0.0/16', gateway => '10.10.100.254', interface => 'eth0.100' },
        { destination => '192.168.50.0/24', gateway => '', interface => 'eth0.101' },
    ],
    "expand routes from a newline separated string, skipping blank lines"
);

my $empty = {};
expand_site_network($empty);
is_deeply($empty, { interfaces => [], routes => [] }, "missing keys expand to empty lists");

# flatten: round trip, and empty lists remove the key
flatten_site_network($cfg);
is_deeply($cfg->{interfaces}, ["eth0.100 10.10.100.1/24", "eth0.101 10.10.101.1/24"], "flatten interfaces");
is_deeply($cfg->{routes}, ["10.20.0.0/16 via 10.10.100.254 dev eth0.100", "192.168.50.0/24 dev eth0.101"], "flatten routes");

my $none = { interfaces => [], routes => ["10.0.0.0/8 dev eth0"] };
flatten_site_network($none);
ok(!defined $none->{interfaces} && exists $none->{interfaces}, "empty list flattens to undef so the key is deleted from the section");

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
