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

use Test::More tests => 9;

#This test will running last
use Test::NoWarnings;
use Test::Mojo;

my $header = 'X-PacketFence-Admin-Roles';
my $t = Test::Mojo->new('pf::UnifiedApi');

$t->get_ok('/api/v1/current_user/allowed_node_bypass_roles' => {$header => 'Node Manager Allowed Roles'})
    ->status_is(200)
    ->json_is({
            status => 200,
          'items' => [
                       {
                         'category_id' => '8',
                         'notes' => undef,
                         'include_parent_acls' => 'false',
                         'fingerbank_dynamic_access_list' => 'false',
                         'inherit_web_auth_url' => undef,
                         'inherit_role' => undef,
                         'max_nodes_per_pid' => '0',
                         'acls' => 'accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any',
                         'name' => 'acls_error1',
                         'inherit_vlan' => undef
                       },
                       {
                         'fingerbank_dynamic_access_list' => 'false',
                         'inherit_web_auth_url' => undef,
                         'inherit_role' => undef,
                         'notes' => undef,
                         'include_parent_acls' => 'false',
                         'category_id' => '9',
                         'inherit_vlan' => undef,
                         'name' => 'acls_error2',
                         'acls' => 'accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any',
                         'max_nodes_per_pid' => '0'
                       },
                       {
                         'name' => 'custom1',
                         'inherit_vlan' => undef,
                         'max_nodes_per_pid' => '0',
                         'acls' => '',
                         'fingerbank_dynamic_access_list' => 'false',
                         'inherit_web_auth_url' => undef,
                         'inherit_role' => undef,
                         'category_id' => '10',
                         'notes' => undef,
                         'include_parent_acls' => 'false'
                       },
                       {
                         'inherit_vlan' => undef,
                         'name' => 'default',
                         'acls' => '',
                         'max_nodes_per_pid' => '0',
                         'inherit_web_auth_url' => undef,
                         'inherit_role' => undef,
                         'fingerbank_dynamic_access_list' => 'false',
                         'include_parent_acls' => 'false',
                         'notes' => 'Placeholder role/category, feel free to edit',
                         'category_id' => '1'
                       },
                       {
                         'inherit_vlan' => undef,
                         'name' => 'gaming',
                         'acls' => '',
                         'max_nodes_per_pid' => '0',
                         'fingerbank_dynamic_access_list' => 'false',
                         'inherit_web_auth_url' => undef,
                         'inherit_role' => undef,
                         'notes' => 'Gaming devices',
                         'include_parent_acls' => 'false',
                         'category_id' => '3'
                       },
                       {
                         'acls' => '',
                         'max_nodes_per_pid' => '0',
                         'inherit_vlan' => undef,
                         'name' => 'guest',
                         'include_parent_acls' => 'false',
                         'notes' => 'Guests',
                         'category_id' => '2',
                         'inherit_web_auth_url' => undef,
                         'inherit_role' => undef,
                         'fingerbank_dynamic_access_list' => 'false'
                       },
                       {
                         'name' => 'macDetection',
                         'inherit_vlan' => undef,
                         'max_nodes_per_pid' => '0',
                         'acls' => '',
                         'inherit_role' => undef,
                         'inherit_web_auth_url' => undef,
                         'fingerbank_dynamic_access_list' => 'false',
                         'category_id' => '11',
                         'include_parent_acls' => 'false',
                         'notes' => undef
                       },
                       {
                         'acls' => '',
                         'max_nodes_per_pid' => '0',
                         'inherit_vlan' => undef,
                         'name' => 'Machine',
                         'include_parent_acls' => 'false',
                         'notes' => 'Machine role',
                         'category_id' => '6',
                         'inherit_web_auth_url' => undef,
                         'inherit_role' => undef,
                         'fingerbank_dynamic_access_list' => 'false'
                       },
                       {
                         'fingerbank_dynamic_access_list' => 'false',
                         'inherit_web_auth_url' => undef,
                         'inherit_role' => undef,
                         'notes' => undef,
                         'include_parent_acls' => 'false',
                         'category_id' => '12',
                         'inherit_vlan' => undef,
                         'name' => 'normal',
                         'acls' => '',
                         'max_nodes_per_pid' => '0'
                       },
                       {
                         'acls' => '',
                         'max_nodes_per_pid' => '0',
                         'inherit_vlan' => undef,
                         'name' => 'r1',
                         'notes' => undef,
                         'include_parent_acls' => 'false',
                         'category_id' => '13',
                         'fingerbank_dynamic_access_list' => 'false',
                         'inherit_role' => undef,
                         'inherit_web_auth_url' => undef
                       },
                       {
                         'category_id' => '14',
                         'include_parent_acls' => 'false',
                         'notes' => undef,
                         'inherit_web_auth_url' => undef,
                         'inherit_role' => undef,
                         'fingerbank_dynamic_access_list' => 'false',
                         'max_nodes_per_pid' => '0',
                         'acls' => '',
                         'name' => 'r2',
                         'inherit_vlan' => undef
                       },
                       {
                         'max_nodes_per_pid' => '0',
                         'acls' => 'permit tcp any any',
                         'name' => 'r3',
                         'inherit_vlan' => undef,
                         'category_id' => '15',
                         'include_parent_acls' => 'false',
                         'notes' => undef,
                         'inherit_web_auth_url' => undef,
                         'inherit_role' => undef,
                         'fingerbank_dynamic_access_list' => 'false'
                       },
                       {
                         'include_parent_acls' => 'false',
                         'notes' => undef,
                         'category_id' => '16',
                         'inherit_web_auth_url' => undef,
                         'inherit_role' => undef,
                         'fingerbank_dynamic_access_list' => 'false',
                         'acls' => 'permit tcp any any',
                         'max_nodes_per_pid' => '0',
                         'inherit_vlan' => undef,
                         'name' => 'r4'
                       },
                       {
                         'max_nodes_per_pid' => '0',
                         'acls' => 'permit tcp any any',
                         'name' => 'r5',
                         'inherit_vlan' => undef,
                         'category_id' => '17',
                         'include_parent_acls' => 'false',
                         'notes' => undef,
                         'inherit_role' => undef,
                         'inherit_web_auth_url' => undef,
                         'fingerbank_dynamic_access_list' => 'false'
                       },
                       {
                         'acls' => '',
                         'max_nodes_per_pid' => '0',
                         'inherit_vlan' => undef,
                         'name' => 'REJECT',
                         'include_parent_acls' => 'false',
                         'notes' => 'Reject role (Used to block access)',
                         'category_id' => '5',
                         'inherit_web_auth_url' => undef,
                         'inherit_role' => undef,
                         'fingerbank_dynamic_access_list' => 'false'
                       },
                       {
                         'acls' => '',
                         'max_nodes_per_pid' => '0',
                         'inherit_vlan' => undef,
                         'name' => 'User',
                         'include_parent_acls' => 'false',
                         'notes' => 'User role',
                         'category_id' => '7',
                         'inherit_role' => undef,
                         'inherit_web_auth_url' => undef,
                         'fingerbank_dynamic_access_list' => 'false'
                       },
                       {
                         'name' => 'voice',
                         'inherit_vlan' => undef,
                         'max_nodes_per_pid' => '0',
                         'acls' => '',
                         'fingerbank_dynamic_access_list' => 'false',
                         'inherit_role' => undef,
                         'inherit_web_auth_url' => undef,
                         'category_id' => '4',
                         'notes' => 'VoIP devices',
                         'include_parent_acls' => 'false'
                       }
                     ]
    });


$t->get_ok('/api/v1/current_user/allowed_node_bypass_vlans' => {$header => 'Node Manager Allowed Bypass Vlans'})
    ->json_is({
        items =>[
            {vlan => "89"},
            {vlan => "90"}
        ],
        status => 200,
        disable_bypass_vlan => 0
    });

$t->get_ok('/api/v1/current_user/allowed_node_roles' => {$header => 'Node Manager Disallowed Roles'})
    ->status_is(200)
    ->json_is({
          'items' => [
                       {
                         'acls' => 'accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any',
                         'inherit_role' => undef,
                         'max_nodes_per_pid' => '0',
                         'inherit_web_auth_url' => undef,
                         'category_id' => '8',
                         'name' => 'acls_error1',
                         'fingerbank_dynamic_access_list' => 'false',
                         'inherit_vlan' => undef,
                         'include_parent_acls' => 'false',
                         'notes' => undef
                       },
                       {
                         'inherit_role' => undef,
                         'acls' => 'accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any
accept any any',
                         'max_nodes_per_pid' => '0',
                         'inherit_web_auth_url' => undef,
                         'category_id' => '9',
                         'name' => 'acls_error2',
                         'fingerbank_dynamic_access_list' => 'false',
                         'inherit_vlan' => undef,
                         'include_parent_acls' => 'false',
                         'notes' => undef
                       },
                       {
                         'fingerbank_dynamic_access_list' => 'false',
                         'inherit_vlan' => undef,
                         'include_parent_acls' => 'false',
                         'notes' => undef,
                         'inherit_role' => undef,
                         'acls' => '',
                         'max_nodes_per_pid' => '0',
                         'inherit_web_auth_url' => undef,
                         'category_id' => '10',
                         'name' => 'custom1'
                       },
                       {
                         'category_id' => '3',
                         'name' => 'gaming',
                         'max_nodes_per_pid' => '0',
                         'acls' => '',
                         'inherit_role' => undef,
                         'inherit_web_auth_url' => undef,
                         'include_parent_acls' => 'false',
                         'inherit_vlan' => undef,
                         'notes' => 'Gaming devices',
                         'fingerbank_dynamic_access_list' => 'false'
                       },
                       {
                         'category_id' => '11',
                         'name' => 'macDetection',
                         'acls' => '',
                         'inherit_role' => undef,
                         'max_nodes_per_pid' => '0',
                         'inherit_web_auth_url' => undef,
                         'inherit_vlan' => undef,
                         'include_parent_acls' => 'false',
                         'notes' => undef,
                         'fingerbank_dynamic_access_list' => 'false'
                       },
                       {
                         'fingerbank_dynamic_access_list' => 'false',
                         'notes' => 'Machine role',
                         'include_parent_acls' => 'false',
                         'inherit_vlan' => undef,
                         'inherit_web_auth_url' => undef,
                         'max_nodes_per_pid' => '0',
                         'acls' => '',
                         'inherit_role' => undef,
                         'name' => 'Machine',
                         'category_id' => '6'
                       },
                       {
                         'acls' => '',
                         'inherit_role' => undef,
                         'max_nodes_per_pid' => '0',
                         'inherit_web_auth_url' => undef,
                         'category_id' => '12',
                         'name' => 'normal',
                         'fingerbank_dynamic_access_list' => 'false',
                         'inherit_vlan' => undef,
                         'include_parent_acls' => 'false',
                         'notes' => undef
                       },
                       {
                         'fingerbank_dynamic_access_list' => 'false',
                         'notes' => undef,
                         'include_parent_acls' => 'false',
                         'inherit_vlan' => undef,
                         'inherit_web_auth_url' => undef,
                         'max_nodes_per_pid' => '0',
                         'inherit_role' => undef,
                         'acls' => '',
                         'name' => 'r1',
                         'category_id' => '13'
                       },
                       {
                         'include_parent_acls' => 'false',
                         'inherit_vlan' => undef,
                         'notes' => undef,
                         'fingerbank_dynamic_access_list' => 'false',
                         'category_id' => '14',
                         'name' => 'r2',
                         'max_nodes_per_pid' => '0',
                         'acls' => '',
                         'inherit_role' => undef,
                         'inherit_web_auth_url' => undef
                       },
                       {
                         'name' => 'r3',
                         'category_id' => '15',
                         'inherit_web_auth_url' => undef,
                         'max_nodes_per_pid' => '0',
                         'acls' => 'permit tcp any any',
                         'inherit_role' => undef,
                         'notes' => undef,
                         'include_parent_acls' => 'false',
                         'inherit_vlan' => undef,
                         'fingerbank_dynamic_access_list' => 'false'
                       },
                       {
                         'fingerbank_dynamic_access_list' => 'false',
                         'include_parent_acls' => 'false',
                         'inherit_vlan' => undef,
                         'notes' => undef,
                         'max_nodes_per_pid' => '0',
                         'acls' => 'permit tcp any any',
                         'inherit_role' => undef,
                         'inherit_web_auth_url' => undef,
                         'category_id' => '16',
                         'name' => 'r4'
                       },
                       {
                         'fingerbank_dynamic_access_list' => 'false',
                         'notes' => undef,
                         'inherit_vlan' => undef,
                         'include_parent_acls' => 'false',
                         'inherit_web_auth_url' => undef,
                         'inherit_role' => undef,
                         'acls' => 'permit tcp any any',
                         'max_nodes_per_pid' => '0',
                         'name' => 'r5',
                         'category_id' => '17'
                       },
                       {
                         'acls' => '',
                         'inherit_role' => undef,
                         'max_nodes_per_pid' => '0',
                         'inherit_web_auth_url' => undef,
                         'category_id' => '5',
                         'name' => 'REJECT',
                         'fingerbank_dynamic_access_list' => 'false',
                         'inherit_vlan' => undef,
                         'include_parent_acls' => 'false',
                         'notes' => 'Reject role (Used to block access)'
                       },
                       {
                         'inherit_web_auth_url' => undef,
                         'inherit_role' => undef,
                         'acls' => '',
                         'max_nodes_per_pid' => '0',
                         'name' => 'User',
                         'category_id' => '7',
                         'fingerbank_dynamic_access_list' => 'false',
                         'notes' => 'User role',
                         'inherit_vlan' => undef,
                         'include_parent_acls' => 'false'
                       },
                       {
                         'include_parent_acls' => 'false',
                         'inherit_vlan' => undef,
                         'notes' => 'VoIP devices',
                         'fingerbank_dynamic_access_list' => 'false',
                         'category_id' => '4',
                         'name' => 'voice',
                         'max_nodes_per_pid' => '0',
                         'inherit_role' => undef,
                         'acls' => '',
                         'inherit_web_auth_url' => undef
                       }
                     ],
          'status' => 200
        });
#use pf::Dumper;pf::Dumper::revert();print Dumper($t->tx->res->json());

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
