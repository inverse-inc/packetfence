#!/usr/bin/perl

=head1 NAME

Auditlogs

=cut

=head1 DESCRIPTION

unit test for RadiusAuditLogs

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';
use pf::dal::radius_audit_log;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}
#run tests
use Test::More tests => 92;
use Test::Mojo;
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

#truncate the radius_audit_log table
pf::dal::radius_audit_log->remove_items();

#unittest (empty)
$t->get_ok('/api/v1/radius_audit_logs' => json => { })
  ->json_is('/items', []) 
  ->status_is(200);

#insert known data
my %values = (
    tenant_id                => '1',
    mac                      => '00:01:02:03:04:05',
    ip                       => 'test ip',
    computer_name            => 'test computer_name', 
    user_name                => 'test user_name',
    stripped_user_name       => 'test stripped_user_name',
    realm                    => 'test realm',
    event_type               => 'test event_type',
    switch_id                => 'test switch_id',
    switch_mac               => 'test switch_mac',
    switch_ip_address        => 'test switch_ip_address',
    radius_source_ip_address => 'test radius_source_ip_address',
    called_station_id        => 'test called_station_id',
    calling_station_id       => 'test calling_station_id',
    nas_port_type            => 'test nas_port_type',
    ssid                     => 'test ssid',
    nas_port_id              => 'test nas_port_id',
    ifindex                  => 'test ifindex',
    nas_port                 => 'test nas_port',
    connection_type          => 'test connection_type',
    nas_ip_address           => 'test nas_ip_address',
    nas_identifier           => 'test nas_identifier',
    auth_status              => 'test auth_status',
    reason                   => 'test reason',
    auth_type                => 'test auth_type',
    eap_type                 => 'test eap_type',
    role                     => 'test role',
    node_status              => 'test node_status',
    profile                  => 'test profile',
    source                   => 'test source',
    auto_reg                 => '1',
    is_phone                 => '1',
    pf_domain                => 'test pf_domain',
    uuid                     => 'test uuid',
    radius_request           => 'test radius_request', 
    radius_reply             => 'test radius_reply',
);
#my $status = pf::dal::radius_audit_log->create(\%values);
$t->post_ok('/api/v1/radius_audit_logs' => json => \%values)
  ->status_is(201);

$t->get_ok('/api/v1/radius_audit_logs' => json => { })
  ->json_is('/items/0/tenant_id', $values{tenant_id})
  ->json_is('/items/0/mac', $values{mac})
  ->json_is('/items/0/ip', $values{ip})
  ->json_is('/items/0/computer_name', $values{computer_name})
  ->json_is('/items/0/user_name', $values{user_name})
  ->json_is('/items/0/stripped_user_name', $values{stripped_user_name})
  ->json_is('/items/0/realm', $values{realm})
  ->json_is('/items/0/event_type', $values{event_type})
  ->json_is('/items/0/switch_id', $values{switch_id})
  ->json_is('/items/0/switch_mac', $values{switch_mac})
  ->json_is('/items/0/switch_ip_address', $values{switch_ip_address})
  ->json_is('/items/0/radius_source_ip_address', $values{radius_source_ip_address})
  ->json_is('/items/0/called_station_id', $values{called_station_id})
  ->json_is('/items/0/calling_station_id', $values{calling_station_id})
  ->json_is('/items/0/nas_port_type', $values{nas_port_type})
  ->json_is('/items/0/ssid', $values{ssid})
  ->json_is('/items/0/nas_port_id', $values{nas_port_id})
  ->json_is('/items/0/ifindex', $values{ifindex})
  ->json_is('/items/0/nas_port', $values{nas_port})
  ->json_is('/items/0/connection_type', $values{connection_type})
  ->json_is('/items/0/nas_ip_address', $values{nas_ip_address})
  ->json_is('/items/0/nas_identifier', $values{nas_identifier})
  ->json_is('/items/0/auth_status', $values{auth_status})
  ->json_is('/items/0/reason', $values{reason})
  ->json_is('/items/0/auth_type', $values{auth_type})
  ->json_is('/items/0/eap_type', $values{eap_type})
  ->json_is('/items/0/role', $values{role})
  ->json_is('/items/0/node_status', $values{node_status})
  ->json_is('/items/0/profile', $values{profile})
  ->json_is('/items/0/source', $values{source})
  ->json_is('/items/0/auto_reg', $values{auto_reg})
  ->json_is('/items/0/is_phone', $values{is_phone})
  ->json_is('/items/0/pf_domain', $values{pf_domain})
  ->json_is('/items/0/uuid', $values{uuid})
  ->json_is('/items/0/radius_request', $values{radius_request})
  ->json_is('/items/0/radius_reply', $values{radius_reply})
  ->json_is('/items/0/request_time', undef) 
  ->status_is(200);

my $id = $t->tx->res->json->{items}[0]{id};

#run unittest, use $id
$t->get_ok("/api/v1/radius_audit_log/$id")
  ->json_is('/item/id', $id)
  ->json_is('/item/tenant_id', $values{tenant_id})
  ->json_is('/item/mac', $values{mac})
  ->json_is('/item/ip', $values{ip})
  ->json_is('/item/computer_name', $values{computer_name})
  ->json_is('/item/user_name', $values{user_name})
  ->json_is('/item/stripped_user_name', $values{stripped_user_name})
  ->json_is('/item/realm', $values{realm})
  ->json_is('/item/event_type', $values{event_type})
  ->json_is('/item/switch_id', $values{switch_id})
  ->json_is('/item/switch_mac', $values{switch_mac})
  ->json_is('/item/switch_ip_address', $values{switch_ip_address})
  ->json_is('/item/radius_source_ip_address', $values{radius_source_ip_address})
  ->json_is('/item/called_station_id', $values{called_station_id})
  ->json_is('/item/calling_station_id', $values{calling_station_id})
  ->json_is('/item/nas_port_type', $values{nas_port_type})
  ->json_is('/item/ssid', $values{ssid})
  ->json_is('/item/nas_port_id', $values{nas_port_id})
  ->json_is('/item/ifindex', $values{ifindex})
  ->json_is('/item/nas_port', $values{nas_port})
  ->json_is('/item/connection_type', $values{connection_type})
  ->json_is('/item/nas_ip_address', $values{nas_ip_address})
  ->json_is('/item/nas_identifier', $values{nas_identifier})
  ->json_is('/item/auth_status', $values{auth_status})
  ->json_is('/item/reason', $values{reason})
  ->json_is('/item/auth_type', $values{auth_type})
  ->json_is('/item/eap_type', $values{eap_type})
  ->json_is('/item/role', $values{role})
  ->json_is('/item/node_status', $values{node_status})
  ->json_is('/item/profile', $values{profile})
  ->json_is('/item/source', $values{source})
  ->json_is('/item/auto_reg', $values{auto_reg})
  ->json_is('/item/is_phone', $values{is_phone})
  ->json_is('/item/pf_domain', $values{pf_domain})
  ->json_is('/item/uuid', $values{uuid})
  ->json_is('/item/radius_request', $values{radius_request})
  ->json_is('/item/radius_reply', $values{radius_reply})
  ->json_is('/item/request_time', undef)
  ->status_is(200);
  
#truncate the radius_audit_log table
#pf::dal::radius_audit_log->remove_items();

$t->delete_ok("/api/v1/radius_audit_log/$id")
  ->status_is(200);
  
$t->delete_ok("/api/v1/radius_audit_log/$id")
  ->status_is(404);
  
#unittest (empty)
$t->get_ok('/api/v1/radius_audit_logs' => json => { })
  ->json_is('/items', []) 
  ->status_is(200);

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
