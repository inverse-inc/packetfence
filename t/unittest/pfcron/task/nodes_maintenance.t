#!/usr/bin/perl

=head1 NAME

nodes_maintenance

=cut

=head1 DESCRIPTION

unit test for nodes_maintenance

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 5;

#This test will running last
use Test::NoWarnings;

use pf::pfcron::task::nodes_maintenance;
use pf::dal::node;
use pf::dal::person;
use pf::dal::password;
use pf::dal::node;
use pf::error qw(is_success);

test_nodes_maintenance();

sub test_nodes_maintenance {
    my $test_mac1 = "ff:ff:ff:ff:ff:fd";
    my $test_mac2 = "ff:ff:ff:ff:ff:fc";

    pf::dal::node->remove_by_id(
        {
            mac => [$test_mac1, $test_mac2]
        }
    );

    create_node($test_mac1, status  => "reg",unregdate => \[ 'NOW() - INTERVAL ? MINUTE', 10 ]);
    create_node($test_mac2, status  => "reg",unregdate => \[ 'NOW() + INTERVAL ? MINUTE', 10 ]);
    run_task();
    test_status($test_mac1, 'unreg');
    test_status($test_mac2, 'reg');
}


sub test_status {
    my ($mac, $node_status) = @_;
    my ( $status, $node ) = pf::dal::node->find(
        {
            mac => $mac,
        }
    );

    is( $node->{status}, $node_status, "node is set to $node_status $node->{mac}");

}

sub run_task {
    my $task = pf::pfcron::task::nodes_maintenance->new(
        {
            status   => "enabled",
            id       => 'test',
            interval => 0,
            type     => 'nodes_maintenance',
        }
    );

    $task->run();
}

sub create_node {
    my ($mac, @args) = @_;
    my $status = pf::dal::node->create(
        {
            mac => $mac,
            @args
        }
    );

    ok( is_success($status), "Created test node $mac" );
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
