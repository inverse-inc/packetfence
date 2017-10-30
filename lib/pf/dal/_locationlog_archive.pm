package pf::dal::_locationlog_archive;

=head1 NAME

pf::dal::_locationlog_archive - pf::dal implementation for the table locationlog_archive

=cut

=head1 DESCRIPTION

pf::dal::_locationlog_archive

pf::dal implementation for the table locationlog_archive

=cut

use strict;
use warnings;

###
### pf::dal::_locationlog_archive is auto generated any change to this file will be lost
### Instead change in the pf::dal::locationlog_archive module
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
    );

    %DEFAULTS = (
        tenant_id => '1',
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
        switch_mac => undef,
        stripped_user_name => undef,
        realm => undef,
        session_id => undef,
        ifDesc => undef,
    );

    @INSERTABLE_FIELDS = qw(
        tenant_id
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
    );

    @PRIMARY_KEYS = qw(
        id
    );

    @COLUMN_NAMES = qw(
        locationlog_archive.id
        locationlog_archive.tenant_id
        locationlog_archive.mac
        locationlog_archive.switch
        locationlog_archive.port
        locationlog_archive.vlan
        locationlog_archive.role
        locationlog_archive.connection_type
        locationlog_archive.connection_sub_type
        locationlog_archive.dot1x_username
        locationlog_archive.ssid
        locationlog_archive.start_time
        locationlog_archive.end_time
        locationlog_archive.switch_ip
        locationlog_archive.switch_mac
        locationlog_archive.stripped_user_name
        locationlog_archive.realm
        locationlog_archive.session_id
        locationlog_archive.ifDesc
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of locationlog_archive

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 field_names

Field names of locationlog_archive

=cut

sub field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of locationlog_archive

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "locationlog_archive" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `locationlog_archive` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row locationlog_archive

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for locationlog_archive

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for locationlog_archive

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for locationlog_archive

=cut

sub get_meta {
    return \%FIELDS_META;
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
