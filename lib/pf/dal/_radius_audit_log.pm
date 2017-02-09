package pf::dal::_radius_audit_log;

=head1 NAME

pf::dal::_radius_audit_log -

=cut

=head1 DESCRIPTION

pf::dal::_radius_audit_log -

=cut

use strict;
use warnings;

use base qw(pf::dal);

our @FIELD_NAMES;
our @INSERTABLE_FIELDS;
our @PRIMARY_KEYS;
our %DEFAULTS;
our %FIELDS_META;

BEGIN {
    @FIELD_NAMES = qw(
        profile
        radius_request
        nas_identifier
        node_status
        uuid
        id
        nas_port
        mac
        eap_type
        is_phone
        auto_reg
        nas_port_id
        auth_type
        event_type
        reason
        user_name
        nas_ip_address
        switch_mac
        role
        ssid
        radius_source_ip_address
        request_time
        ifindex
        source
        ip
        nas_port_type
        switch_id
        created_at
        radius_reply
        realm
        calling_station_id
        called_station_id
        stripped_user_name
        auth_status
        computer_name
        pf_domain
        connection_type
        switch_ip_address
    );

    %DEFAULTS = (
        profile => undef,
        radius_request => undef,
        nas_identifier => undef,
        node_status => undef,
        uuid => undef,
        nas_port => undef,
        mac => '',
        eap_type => undef,
        is_phone => undef,
        auto_reg => undef,
        nas_port_id => undef,
        auth_type => undef,
        event_type => undef,
        reason => undef,
        user_name => undef,
        nas_ip_address => undef,
        switch_mac => undef,
        role => undef,
        ssid => undef,
        radius_source_ip_address => undef,
        request_time => undef,
        ifindex => undef,
        source => undef,
        ip => undef,
        nas_port_type => undef,
        switch_id => undef,
        radius_reply => undef,
        realm => undef,
        calling_station_id => undef,
        called_station_id => undef,
        stripped_user_name => undef,
        auth_status => undef,
        computer_name => undef,
        pf_domain => undef,
        connection_type => undef,
        switch_ip_address => undef,
    );

    @INSERTABLE_FIELDS = qw(
        profile
        radius_request
        nas_identifier
        node_status
        uuid
        nas_port
        mac
        eap_type
        is_phone
        auto_reg
        nas_port_id
        auth_type
        event_type
        reason
        user_name
        nas_ip_address
        switch_mac
        role
        ssid
        radius_source_ip_address
        request_time
        ifindex
        source
        ip
        nas_port_type
        switch_id
        radius_reply
        realm
        calling_station_id
        called_station_id
        stripped_user_name
        auth_status
        computer_name
        pf_domain
        connection_type
        switch_ip_address
    );

    %FIELDS_META = (
        profile => {
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
        nas_identifier => {
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
        uuid => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        id => {
            type => 'INT',
            is_auto_increment => 1,
            is_primary_key => 1,
            is_nullable => 0,
        },
        nas_port => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        mac => {
            type => 'CHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        eap_type => {
            type => 'VARCHAR',
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
        auto_reg => {
            type => 'CHAR',
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
        auth_type => {
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
        reason => {
            type => 'TEXT',
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
        nas_ip_address => {
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
        role => {
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
        radius_source_ip_address => {
            type => 'VARCHAR',
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
        ifindex => {
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
        ip => {
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
        switch_id => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        created_at => {
            type => 'TIMESTAMP',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        radius_reply => {
            type => 'TEXT',
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
        calling_station_id => {
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
        stripped_user_name => {
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
        computer_name => {
            type => 'VARCHAR',
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
        connection_type => {
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
    );

    @PRIMARY_KEYS = qw(
        id
    );
}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

sub _defaults {
    return {%DEFAULTS};
}

sub field_names {
    return [@FIELD_NAMES];
}

sub primary_keys {
    return [@PRIMARY_KEYS];
}

sub table { "radius_audit_log" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM radius_audit_log WHERE $where;";
};

sub _find_one_sql {
    return $FIND_SQL;
}

sub _updateable_fields {
    return [@FIELD_NAMES];
}

sub _inserteable_fields {
    return [@INSERTABLE_FIELDS];
}

sub get_meta {
    return \%FIELDS_META;
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
