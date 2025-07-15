#!/usr/bin/perl

=head1 NAME

CurrentUser

=head1 DESCRIPTION

unit test for CurrentUser

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 6;

#This test will running last
use Test::NoWarnings;
use Test::Mojo;

my $header = 'X-PacketFence-Admin-Roles';
my $t = Test::Mojo->new('pf::UnifiedApi');

$t->get_ok('/api/v1/current_user/allowed_node_bypass_roles' => {$header => 'Node Manager Allowed Roles'})
    ->status_is(200)
    ->json_is({
            status => 200,
            items => [
                    {
                      'name' => 'default',
                      'inherit_web_auth_url' => undef,
                      'fingerbank_dynamic_access_list' => 'disabled',
                      'max_nodes_per_pid' => '0',
                      'inherit_vlan' => undef,
                      'inherit_role' => undef,
                      'category_id' => '1',
                      'notes' => 'Placeholder role/category, feel free to edit',
                      'include_parent_acls' => 'disabled',
                      'acls' => ''
                    },
                    {
                      'acls' => '',
                      'notes' => 'Guests',
                      'include_parent_acls' => 'disabled',
                      'inherit_vlan' => undef,
                      'category_id' => '2',
                      'inherit_role' => undef,
                      'fingerbank_dynamic_access_list' => 'disabled',
                      'max_nodes_per_pid' => '0',
                      'inherit_web_auth_url' => undef,
                      'name' => 'guest'
                    }
            ],
    });

$t->get_ok('/api/v1/current_user/allowed_node_bypass_vlans' => {$header => 'Node Manager Allowed Bypass Vlans'})->json_is({items=>[{vlan => "89"},{vlan => "90"}] , status => 200});

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2025 Inverse inc.

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

