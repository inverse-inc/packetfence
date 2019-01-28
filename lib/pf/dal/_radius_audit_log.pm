package pf::dal::_radius_audit_log;

=head1 NAME

pf::dal::_radius_audit_log - pf::dal implementation for the table radius_audit_log

=cut

=head1 DESCRIPTION

pf::dal::_radius_audit_log

pf::dal implementation for the table radius_audit_log

=cut

use strict;
use warnings;

###
### pf::dal::_radius_audit_log is auto generated any change to this file will be lost
### Instead change in the pf::dal::radius_audit_log module
###

use base qw(pf::dal);

use Role::Tiny::With;
with qw(pf::dal::roles::has_tenant_id);

our @FIELD_NAMES;
our @INSERTABLE_FIELDS;
our @PRIMARY_KEYS;
our %DEFAULTS;
our %FIELDS_META;
our @COLUMN_NAMES;

BEGIN {
    @FIELD_NAMES = qw(
        id
        tenant_id
        created_at
        mac
        ip
        computer_name
        user_name
        stripped_user_name
        realm
        event_type
        switch_id
        switch_mac
        switch_ip_address
        radius_source_ip_address
        called_station_id
        calling_station_id
        nas_port_type
        ssid
        nas_port_id
        ifindex
        nas_port
        connection_type
        nas_ip_address
        nas_identifier
        auth_status
        reason
        auth_type
        eap_type
        role
        node_status
        profile
        source
        auto_reg
        is_phone
        pf_domain
        uuid
        radius_request
        radius_reply
        request_time
    );

    %DEFAULTS = (
        tenant_id => '1',
        mac => '',
        ip => undef,
        computer_name => undef,
        user_name => undef,
        stripped_user_name => undef,
        realm => undef,
        event_type => undef,
        switch_id => undef,
        switch_mac => undef,
        switch_ip_address => undef,
        radius_source_ip_address => undef,
        called_station_id => undef,
        calling_station_id => undef,
        nas_port_type => undef,
        ssid => undef,
        nas_port_id => undef,
        ifindex => undef,
        nas_port => undef,
        connection_type => undef,
        nas_ip_address => undef,
        nas_identifier => undef,
        auth_status => undef,
        reason => undef,
        auth_type => undef,
        eap_type => undef,
        role => undef,
        node_status => undef,
        profile => undef,
        source => undef,
        auto_reg => undef,
        is_phone => undef,
        pf_domain => undef,
        uuid => undef,
        radius_request => undef,
        radius_reply => undef,
        request_time => undef,
    );

    @INSERTABLE_FIELDS = qw(
        tenant_id
        mac
        ip
        computer_name
        user_name
        stripped_user_name
        realm
        event_type
        switch_id
        switch_mac
        switch_ip_address
        radius_source_ip_address
        called_station_id
        calling_station_id
        nas_port_type
        ssid
        nas_port_id
        ifindex
        nas_port
        connection_type
        nas_ip_address
        nas_identifier
        auth_status
        reason
        auth_type
        eap_type
        role
        node_status
        profile
        source
        auto_reg
        is_phone
        pf_domain
        uuid
        radius_request
        radius_reply
        request_time
    );

    %FIELDS_META = (
        id => {
            type => 'INT',
            is_auto_increment => 1,
            is_primary_key => 1,
            is_nullable => 0,
        },
        tenant_id => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        created_at => {
            type => 'TIMESTAMP',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        mac => {
            type => 'CHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        ip => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        computer_name => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        user_name => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        stripped_user_name => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        realm => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        event_type => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        switch_id => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        switch_mac => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        switch_ip_address => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        radius_source_ip_address => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        called_station_id => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        calling_station_id => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        nas_port_type => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        ssid => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        nas_port_id => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        ifindex => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        nas_port => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        connection_type => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        nas_ip_address => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        nas_identifier => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        auth_status => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        reason => {
            type => 'TEXT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        auth_type => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        eap_type => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        role => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        node_status => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        profile => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        source => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        auto_reg => {
            type => 'CHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        is_phone => {
            type => 'CHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        pf_domain => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        uuid => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        radius_request => {
            type => 'TEXT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        radius_reply => {
            type => 'TEXT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        request_time => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
    );

    @PRIMARY_KEYS = qw(
        id
    );

    @COLUMN_NAMES = qw(
        radius_audit_log.id
        radius_audit_log.tenant_id
        radius_audit_log.created_at
        radius_audit_log.mac
        radius_audit_log.ip
        radius_audit_log.computer_name
        radius_audit_log.user_name
        radius_audit_log.stripped_user_name
        radius_audit_log.realm
        radius_audit_log.event_type
        radius_audit_log.switch_id
        radius_audit_log.switch_mac
        radius_audit_log.switch_ip_address
        radius_audit_log.radius_source_ip_address
        radius_audit_log.called_station_id
        radius_audit_log.calling_station_id
        radius_audit_log.nas_port_type
        radius_audit_log.ssid
        radius_audit_log.nas_port_id
        radius_audit_log.ifindex
        radius_audit_log.nas_port
        radius_audit_log.connection_type
        radius_audit_log.nas_ip_address
        radius_audit_log.nas_identifier
        radius_audit_log.auth_status
        radius_audit_log.reason
        radius_audit_log.auth_type
        radius_audit_log.eap_type
        radius_audit_log.role
        radius_audit_log.node_status
        radius_audit_log.profile
        radius_audit_log.source
        radius_audit_log.auto_reg
        radius_audit_log.is_phone
        radius_audit_log.pf_domain
        radius_audit_log.uuid
        radius_audit_log.radius_request
        radius_audit_log.radius_reply
        radius_audit_log.request_time
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of radius_audit_log

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 table_field_names

Field names of radius_audit_log

=cut

sub table_field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of radius_audit_log

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "radius_audit_log" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `radius_audit_log` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row radius_audit_log

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for radius_audit_log

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for radius_audit_log

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for radius_audit_log

=cut

sub get_meta {
    return \%FIELDS_META;
}
 
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
