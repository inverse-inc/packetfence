#!/usr/bin/perl

=head1 NAME

get_network_type

=head1 DESCRIPTION

unit test for get_network_type

=cut

use strict;
use warnings;
#

our @tests;
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
    @tests = (
        { in => $pf::constants::config::NET_TYPE_DNS_ENFORCEMENT, out => $pf::constants::config::NET_TYPE_DNS_ENFORCEMENT},
        { in => $pf::constants::config::NET_TYPE_VLAN_REG, out => $pf::constants::config::NET_TYPE_VLAN_REG},
        { in => 'isolation', out => $pf::constants::config::NET_TYPE_VLAN_ISOL},
        { in => 'registration', out => $pf::constants::config::NET_TYPE_VLAN_REG},
        { in => $pf::constants::config::NET_TYPE_VLAN_ISOL, out => $pf::constants::config::NET_TYPE_VLAN_ISOL},
        { in => $pf::constants::config::NET_TYPE_INLINE, out => $pf::constants::config::NET_TYPE_INLINE},
        { in => $pf::constants::config::NET_TYPE_INLINE_L2, out => $pf::constants::config::NET_TYPE_INLINE},
        { in => $pf::constants::config::NET_TYPE_INLINE_L3, out => $pf::constants::config::NET_TYPE_INLINE},
        { in => $pf::constants::config::NET_TYPE_OTHER, out => $pf::constants::config::NET_TYPE_OTHER},
        { in => undef, out => undef},
        { in => "Garbasge", out => undef},
        { in => uc($pf::constants::config::NET_TYPE_DNS_ENFORCEMENT), out => $pf::constants::config::NET_TYPE_DNS_ENFORCEMENT},
        { in => uc($pf::constants::config::NET_TYPE_VLAN_REG), out => $pf::constants::config::NET_TYPE_VLAN_REG},
        { in => 'ISOLATION', out => $pf::constants::config::NET_TYPE_VLAN_ISOL},
        { in => 'REGISTRATION', out => $pf::constants::config::NET_TYPE_VLAN_REG},
        { in => uc($pf::constants::config::NET_TYPE_VLAN_ISOL), out => $pf::constants::config::NET_TYPE_VLAN_ISOL},
        { in => uc($pf::constants::config::NET_TYPE_INLINE), out => $pf::constants::config::NET_TYPE_INLINE},
        { in => uc($pf::constants::config::NET_TYPE_INLINE_L2), out => $pf::constants::config::NET_TYPE_INLINE},
        { in => uc($pf::constants::config::NET_TYPE_INLINE_L3), out => $pf::constants::config::NET_TYPE_INLINE},
        { in => uc($pf::constants::config::NET_TYPE_OTHER), out => $pf::constants::config::NET_TYPE_OTHER},
    );
}

use pf::constants::config;
use pfconfig::namespaces::config::Network;
#This test will running last
use Test::NoWarnings;
use Test::More tests => scalar @tests + 1;


for my $t (@tests) {
    is(
        pfconfig::namespaces::config::Network::get_network_type($t->{in}),
        $t->{out},
    );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

