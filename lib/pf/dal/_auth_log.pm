package pf::dal::_auth_log;

=head1 NAME

pf::dal::_auth_log - pf::dal implementation for the table auth_log

=cut

=head1 DESCRIPTION

pf::dal::_auth_log

pf::dal implementation for the table auth_log

=cut

use strict;
use warnings;

###
### pf::dal::_auth_log is auto generated any change to this file will be lost
### Instead change in the pf::dal::auth_log module
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
        process_name
        mac
        pid
        status
        attempted_at
        completed_at
        source
        profile
    );

    %DEFAULTS = (
        tenant_id => '1',
        process_name => '',
        mac => '',
        pid => 'default',
        status => 'incomplete',
        attempted_at => '',
        completed_at => undef,
        source => '',
        profile => undef,
    );

    @INSERTABLE_FIELDS = qw(
        tenant_id
        process_name
        mac
        pid
        status
        attempted_at
        completed_at
        source
        profile
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
        process_name => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        mac => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        pid => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        status => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        attempted_at => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        completed_at => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        source => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        profile => {
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
        auth_log.id
        auth_log.tenant_id
        auth_log.process_name
        auth_log.mac
        auth_log.pid
        auth_log.status
        auth_log.attempted_at
        auth_log.completed_at
        auth_log.source
        auth_log.profile
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of auth_log

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 table_field_names

Field names of auth_log

=cut

sub table_field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of auth_log

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "auth_log" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `auth_log` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row auth_log

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for auth_log

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for auth_log

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for auth_log

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
