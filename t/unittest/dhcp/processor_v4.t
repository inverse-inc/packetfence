#!/usr/bin/perl

=head1 NAME

processor_v4

=head1 DESCRIPTION

unit test for processor_v4

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 3;
use pf::dhcp::processor_v4;
use pf::node;
use pf::util;
use pf::api;
use pf::api::local;

#This test will running last
use Test::NoWarnings;

my $mac = random_mac();

while (node_exist($mac)) {
    my $mac = random_mac();
}

my $computername = "bob";
my $new_computername = "bobette";
my $apiClient = pf::api::local->new();

ok(!pf::dhcp::processor_v4::do_hostname_change_detection($mac, $computername, $apiClient), "node does not exists");
node_modify($mac, computername => $computername);
ok(!pf::dhcp::processor_v4::do_hostname_change_detection($mac, $computername, $apiClient), "computername did not change");
ok(pf::dhcp::processor_v4::do_hostname_change_detection($mac, $new_computername, $apiClient), "computername did change");
my @violations = pf::violation::violation_view_open($mac);
ok (scalar @violations, "A violation was added");

sub random_mac {
    clean_mac( unpack("H*",pack("S", int(rand(65536)))) . unpack("H*",pack("L",$$)));
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

