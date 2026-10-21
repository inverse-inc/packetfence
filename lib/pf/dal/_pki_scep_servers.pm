package pf::dal::_pki_scep_servers;

=head1 NAME

pf::dal::_pki_scep_servers - pf::dal implementation for the table pki_scep_servers

=cut

=head1 DESCRIPTION

pf::dal::_pki_scep_servers

pf::dal implementation for the table pki_scep_servers

=cut

use strict;
use warnings;

###
### pf::dal::_pki_scep_servers is auto generated any change to this file will be lost
### Instead change in the pf::dal::pki_scep_servers module
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
        created_at
        updated_at
        deleted_at
        name
        url
        shared_secret
    );

    %DEFAULTS = (
        created_at => undef,
        updated_at => undef,
        deleted_at => undef,
        name => undef,
        url => undef,
        shared_secret => undef,
    );

    @INSERTABLE_FIELDS = qw(
        created_at
        updated_at
        deleted_at
        name
        url
        shared_secret
    );

    %FIELDS_META = (
        id => {
            type => 'BIGINT',
            is_auto_increment => 1,
            is_primary_key => 1,
            is_nullable => 0,
        },
        created_at => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        updated_at => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        deleted_at => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        name => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        url => {
            type => 'LONGTEXT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        shared_secret => {
            type => 'LONGTEXT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
    );

    @PRIMARY_KEYS = qw(
        id
    );

    @COLUMN_NAMES = qw(
        pki_scep_servers.id
        pki_scep_servers.created_at
        pki_scep_servers.updated_at
        pki_scep_servers.deleted_at
        pki_scep_servers.name
        pki_scep_servers.url
        pki_scep_servers.shared_secret
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of pki_scep_servers

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 table_field_names

Field names of pki_scep_servers

=cut

sub table_field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of pki_scep_servers

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "pki_scep_servers" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `pki_scep_servers` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row pki_scep_servers

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for pki_scep_servers

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for pki_scep_servers

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for pki_scep_servers

=cut

sub get_meta {
    return \%FIELDS_META;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
