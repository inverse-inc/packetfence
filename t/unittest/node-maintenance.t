#!/usr/bin/perl

=head1 NAME

node-maintenance

=head1 DESCRIPTION

unit test for node-maintenance

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 8;

#This test will running last
use Test::NoWarnings;
use pf::node qw(node_add_simple node_modify nodes_maintenance node_view node_register);
use pf::error qw(is_error);
use pf::security_event qw(security_event_view_open);
use Utils;
use pf::api;

#This is the first test
ok (1 == 1,"Yes 1 does equals 1");

#This is the second test
ok (1 != 2,"No 1 does not equals 2");

{
    my $mac1 = Utils::test_mac();
    my $pid1 = Utils::test_pid();
    my $mac2 = Utils::test_mac();
    my $pid2 = Utils::test_pid();

    my ($status, $sth) = pf::dal->db_execute('SELECT DATE_ADD(NOW(), INTERVAL 1 DAY), DATE_SUB(NOW(), INTERVAL 11 HOUR )');
    if (is_error($status)) {
        BAIL_OUT("Cannot connect to the database");
    }

    my ($unreg_date1, $unreg_date2) = $sth->fetchrow_array;

    $sth->finish;

    node_add_simple($mac1);
    node_register($mac1, $pid1,  auto_registered => 1, category_id => 1, unreg_date => $unreg_date1);
    node_modify($mac1, unregdate => $unreg_date1);
    my $node1 = node_view($mac1);
    ok(defined $node1, "$mac1 created");

    node_add_simple($mac2);
    node_register($mac2, $pid2, auto_registered => 1, category_id => 1);
    node_modify($mac2, unregdate => $unreg_date2);
    my $node2 = node_view($mac2);
    ok(defined $node2, "$mac2 created");
    local $pf::client::CURRENT_CLIENT = "pf::api::local";

    nodes_maintenance();
    $node1 = node_view($mac1);
    is($node1->{status}, "reg", "$mac1 still reg");

    $node2 = node_view($mac2);
    is($node2->{status}, "unreg", "$mac2 is set to unreg");
    my @events = security_event_view_open($mac2);
    ok(scalar @events, "security event opened");
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

