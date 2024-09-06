package pf::dal::_pki_cas;

=head1 NAME

pf::dal::_pki_cas - pf::dal implementation for the table pki_cas

=cut

=head1 DESCRIPTION

pf::dal::_pki_cas

pf::dal implementation for the table pki_cas

=cut

use strict;
use warnings;

###
### pf::dal::_pki_cas is auto generated any change to this file will be lost
### Instead change in the pf::dal::pki_cas module
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
        cn
        mail
        organisation
        organisational_unit
        country
        state
        locality
        street_address
        postal_code
        key_type
        key_size
        digest
        key_usage
        extended_key_usage
        days
        key
        cert
        issuer_key_hash
        issuer_name_hash
        ocsp_url
        serial_number
    );

    %DEFAULTS = (
        created_at => undef,
        updated_at => undef,
        deleted_at => undef,
        cn => undef,
        mail => undef,
        organisation => undef,
        organisational_unit => undef,
        country => undef,
        state => undef,
        locality => undef,
        street_address => undef,
        postal_code => undef,
        key_type => undef,
        key_size => undef,
        digest => undef,
        key_usage => undef,
        extended_key_usage => undef,
        days => undef,
        key => undef,
        cert => undef,
        issuer_key_hash => undef,
        issuer_name_hash => undef,
        ocsp_url => undef,
        serial_number => '1',
    );

    @INSERTABLE_FIELDS = qw(
        created_at
        updated_at
        deleted_at
        cn
        mail
        organisation
        organisational_unit
        country
        state
        locality
        street_address
        postal_code
        key_type
        key_size
        digest
        key_usage
        extended_key_usage
        days
        key
        cert
        issuer_key_hash
        issuer_name_hash
        ocsp_url
        serial_number
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
        cn => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        mail => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        organisation => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        organisational_unit => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        country => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        state => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        locality => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        street_address => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        postal_code => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        key_type => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        key_size => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        digest => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        key_usage => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        extended_key_usage => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        days => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        key => {
            type => 'LONGTEXT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        cert => {
            type => 'LONGTEXT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        issuer_key_hash => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        issuer_name_hash => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        ocsp_url => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        serial_number => {
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
        pki_cas.id
        pki_cas.created_at
        pki_cas.updated_at
        pki_cas.deleted_at
        pki_cas.cn
        pki_cas.mail
        pki_cas.organisation
        pki_cas.organisational_unit
        pki_cas.country
        pki_cas.state
        pki_cas.locality
        pki_cas.street_address
        pki_cas.postal_code
        pki_cas.key_type
        pki_cas.key_size
        pki_cas.digest
        pki_cas.key_usage
        pki_cas.extended_key_usage
        pki_cas.days
        pki_cas.key
        pki_cas.cert
        pki_cas.issuer_key_hash
        pki_cas.issuer_name_hash
        pki_cas.ocsp_url
        pki_cas.serial_number
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of pki_cas

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 table_field_names

Field names of pki_cas

=cut

sub table_field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of pki_cas

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "pki_cas" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `pki_cas` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row pki_cas

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for pki_cas

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for pki_cas

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for pki_cas

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
