package pf::dal::_locationlog_history;

=head1 NAME

pf::dal::_locationlog_history - pf::dal implementation for the table locationlog_history

=cut

=head1 DESCRIPTION

pf::dal::_locationlog_history

pf::dal implementation for the table locationlog_history

=cut

use strict;
use warnings;

###
### pf::dal::_locationlog_history is auto generated any change to this file will be lost
### Instead change in the pf::dal::locationlog_history module
###

use base qw(pf::dal);

our @FIELD_NAMES;
our @INSERTABLE_FIELDS;
our @PRIMARY_KEYS;
our %DEFAULTS;
our %FIELDS_META;
our @COLUMN_NAMES;

BEGIN {
    @FIELD_NAMES = qw(
        id
        mac
        switch
        port
        vlan
        role
        connection_type
        connection_sub_type
        dot1x_username
        ssid
        start_time
        end_time
        switch_ip
        switch_ip_int
        switch_mac
        stripped_user_name
        realm
        session_id
        ifDesc
        voip
    );

    %DEFAULTS = (
        mac => undef,
        switch => '',
        port => '',
        vlan => undef,
        role => undef,
        connection_type => '',
        connection_sub_type => undef,
        dot1x_username => '',
        ssid => '',
        start_time => '0000-00-00 00:00:00',
        end_time => '0000-00-00 00:00:00',
        switch_ip => undef,
        switch_ip_int => undef,
        switch_mac => undef,
        stripped_user_name => undef,
        realm => undef,
        session_id => undef,
        ifDesc => undef,
        voip => 'no',
    );

    @INSERTABLE_FIELDS = qw(
        mac
        switch
        port
        vlan
        role
        connection_type
        connection_sub_type
        dot1x_username
        ssid
        start_time
        end_time
        switch_ip
        switch_mac
        stripped_user_name
        realm
        session_id
        ifDesc
        voip
    );

    %FIELDS_META = (
        id => {
            type => 'BIGINT',
            is_auto_increment => 1,
            is_primary_key => 1,
            is_nullable => 0,
        },
        mac => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        switch => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        port => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        vlan => {
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
        connection_type => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        connection_sub_type => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        dot1x_username => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        ssid => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        start_time => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        end_time => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        switch_ip => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        switch_ip_int => {
            type => 'INT',
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
        session_id => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        ifDesc => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        voip => {
            type => 'ENUM',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
            enums_values => {
                'no' => 1,
                'yes' => 1,
            },
        },
    );

    @PRIMARY_KEYS = qw(
        id
    );

    @COLUMN_NAMES = qw(
        locationlog_history.id
        locationlog_history.mac
        locationlog_history.switch
        locationlog_history.port
        locationlog_history.vlan
        locationlog_history.role
        locationlog_history.connection_type
        locationlog_history.connection_sub_type
        locationlog_history.dot1x_username
        locationlog_history.ssid
        locationlog_history.start_time
        locationlog_history.end_time
        locationlog_history.switch_ip
        locationlog_history.switch_ip_int
        locationlog_history.switch_mac
        locationlog_history.stripped_user_name
        locationlog_history.realm
        locationlog_history.session_id
        locationlog_history.ifDesc
        locationlog_history.voip
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of locationlog_history

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 table_field_names

Field names of locationlog_history

=cut

sub table_field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of locationlog_history

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "locationlog_history" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `locationlog_history` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row locationlog_history

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for locationlog_history

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for locationlog_history

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for locationlog_history

=cut

sub get_meta {
    return \%FIELDS_META;
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
