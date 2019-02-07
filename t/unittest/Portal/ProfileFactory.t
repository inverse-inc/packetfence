#!/usr/bin/perl

=head1 NAME

Test for the pf::Connection::ProfileFactory

=cut

=head1 DESCRIPTION

Test for the pf::Connection::ProfileFactory

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';

use Test::More tests => 23;
use pf::Connection::ProfileFactory;
use pf::dal::node;
use pf::ip4log;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

#This test will running last
use Test::NoWarnings;

my $profile;

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", {});
is($profile->getName, "default", "Getting the default profile");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_ip => '192.168.2.1'});
is($profile->getName, "network", "last_ip 192.168.2.1");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_switch => '192.168.1.1'});
is($profile->getName, "switch", "last_switch 192.168.1.1");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_switch => '192.168.1.3', last_port => 1});
is($profile->getName, "switch_port", "last_switch 192.168.1.3, last_port 1");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_connection_type => 'wired'});
is($profile->getName, "connection_type", "connection_type wired");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_ssid => 'SSID'});
is($profile->getName, "ssid", "SSID SSID");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_port => '2'});
is($profile->getName, "port", "port 2");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { category => 'bob'});
is($profile->getName, "node_role", "category bob");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_vlan => 5});
is($profile->getName, "vlan", "VLAN 5");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { realm => 'magic'});
is($profile->getName, "realm", "realm magic");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_uri => 'captivate'});
is($profile->getName, "uri", "last_uri captivate");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_ssid => 'ANYORALL', last_connection_type => 'simple' });
is($profile->getName, "all", "SSID ANYORALL, connection_type simple");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_ssid => 'ANYORALL'});
is($profile->getName, "any", "SSID ANYORALL");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_ssid => 'ANY'});
is($profile->getName, "any", "SSID ANY");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_switch => '192.168.1.4'});
is($profile->getName, "switches", "Last Switch 192.168.1.4");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_switch => '192.168.1.5'});
is($profile->getName, "switches", "Last Switch 192.168.1.5");

$profile = pf::Connection::ProfileFactory->instantiate(pf::dal::node->new({ last_switch => '192.168.1.5'}), {});
is($profile->getName, "switches", "Using an object instead a string");

# Test that missing last_ip parameter will be computed via a mac2ip
pf::ip4log::open("192.168.2.1", "00:11:22:33:44:55", 5);
$profile = pf::Connection::ProfileFactory->instantiate("00:11:22:33:44:55");
is($profile->getName, "network", "Last ip from mac2ip");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_switch => undef });
is($profile->getName, "last_switch_undefined", "Last switch is undefined");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_switch => 2 });
is($profile->getName, "last_switch_defined", "Last switch is defined");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_ssid => undef });
is($profile->getName, "last_ssid_undefined", "Last ssid is undefined");

$profile = pf::Connection::ProfileFactory->instantiate("00:00:00:00:00:00", { last_ssid => 2 });
is($profile->getName, "last_ssid_defined", "Last ssid is defined");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
