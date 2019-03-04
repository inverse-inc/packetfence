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
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::node;
use Test::More tests => 14;

#This test will running last
use Test::NoWarnings;

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

