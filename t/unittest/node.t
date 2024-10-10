#!/usr/bin/perl

=head1 NAME

pf::node

=cut

=head1 DESCRIPTION

unit tests for pf::node

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

use pf::node;
use pf::constants::node qw($NODE_DISCOVERED_TRIGGER_DELAY);
use pf::locationlog;
use pf::security_event qw(security_event_view_last_closed);
use Utils;
use pf::constants::config qw($WIRELESS_802_1X);
use Test::More tests => 21;

#This test will running last
use Test::NoWarnings;

{
    no warnings qw(redefine);
    local $pf::dal::node::TRIGGER_NODE_DISCOVERED = 1;
    our $triggered = 0;
    local *pf::dal::node::_trigger_node_discovered = sub {
        $triggered = 1;
    };
    my $mac = Utils::test_mac();
    ok (node_add_simple($mac), "$mac added");
    ok ($triggered, "node discovered triggered for $mac");
}

{
    no warnings qw(redefine);
    our $triggered = 0;
    local *pf::dal::node::_trigger_node_discovered = sub {
        $triggered = 1;
    };
    my $mac = Utils::test_mac();
    ok (node_add_simple($mac), "$mac added");
    ok (!$triggered, "node discovered not triggered for $mac");
}

is ("reg",pf::node::_cleanup_status_value("reg"),"Expecting reg");

is ("pending",pf::node::_cleanup_status_value("pending"),"Expecting pending");

is ("unreg",pf::node::_cleanup_status_value("unreg"),"Expecting unreg");

is ("unreg",pf::node::_cleanup_status_value("this is complete garbage"),"Expecting unreg when garbage is put in");

is ("unreg",pf::node::_cleanup_status_value(undef),"Expecting unreg when a status of 'undef' is put in");

my $node_mac = "ff:ee:ff:ee:ff:ee";

ok (node_modify($node_mac, category => "guest"), "creating $node_mac");

my $node = node_view($node_mac);

ok ($node, "$node_mac saved to database");

is ($node->{category}, "guest", "Proper category saved");

ok (node_modify($node_mac, category => "gaming"), "updating name category $node_mac to gaming");

$node = node_view($node_mac);

is ($node->{category}, "gaming", "Proper category saved");

ok (node_modify($node_mac, category_id => 4), "updating name category $node_mac to voice using the id");

$node = node_view($node_mac);

is ($node->{category_id}, 4, "Proper category saved");

ok (node_modify($node_mac, category_id => 4), "Not changing anything");


{
    my $mac = Utils::test_mac();
    ok (node_modify($mac, category => "guest"), "creating $mac");
    my ($res, $msg) = pf::node::_can_delete($mac);
    ok ($res, "Can remove $mac");
    locationlog_synchronize(
        "192.168.0.1",
        "192.168.0.1",
        "00:22:33:44:55:66",
        "12",
        "12",
        $mac,
        "yes",
        $WIRELESS_802_1X,
        "",
        "bob",
        "BOBBY",
        "bob",
        "NULL",
        "default",
        "",
    );
    ($res, $msg) = pf::node::_can_delete($mac);
    ok (!$res, "Cannot remove $mac");
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

