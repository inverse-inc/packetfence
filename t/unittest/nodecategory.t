#!/usr/bin/perl

=head1 NAME

nodecategory

=head1 DESCRIPTION

unit test for nodecategory

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

use Test::More tests => 2;

#This test will running last
use Test::NoWarnings;
use pf::nodecategory;

is_deeply(
    [
    pf::nodecategory::_order_nodecategory_config(
        {
            v1 => { max_nodes_per_pid => 0},
            v2 => { parent => "v1", acls => [qw(a b)]},
            v3 => { parent => "v2", max_nodes_per_pid => 1},
            v4 => { parent => "v3", acls => [qw(c d)], include_parent_acls => "enabled"},
            v5 => { parent => "v4"},
            v6 => { parent => "v7"},
            v7 => { parent => "v6"},
            v8 => { parent => "v6"},
        }
    )]
    ,
    [
        [v1 => {max_nodes_per_pid => 0}],
        [v2 => { parent => "v1", acls => [qw(a b)] }],
        [v3 => { parent => "v2", max_nodes_per_pid => 1}],
        [v4 => { parent => "v3", acls => [qw(c d)], include_parent_acls => "enabled"} ],
        [v5 => { parent => "v4"}]
    ],
);

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
