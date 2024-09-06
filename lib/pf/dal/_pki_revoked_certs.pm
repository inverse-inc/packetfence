package pf::dal::_pki_revoked_certs;

=head1 NAME

pf::dal::_pki_revoked_certs - pf::dal implementation for the table pki_revoked_certs

=cut

=head1 DESCRIPTION

pf::dal::_pki_revoked_certs

pf::dal implementation for the table pki_revoked_certs

=cut

use strict;
use warnings;

###
### pf::dal::_pki_revoked_certs is auto generated any change to this file will be lost
### Instead change in the pf::dal::pki_revoked_certs module
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
        ca_id
        ca_name
        street_address
        organisation
        organisational_unit
        country
        state
        locality
        postal_code
        key
        cert
        profile_id
        profile_name
        valid_until
        not_before
        date
        serial_number
        dns_names
        ip_addresses
        revoked
        crl_reason
        subject
    );

    %DEFAULTS = (
        created_at => undef,
        updated_at => undef,
        deleted_at => undef,
        cn => undef,
        mail => undef,
        ca_id => undef,
        ca_name => undef,
        street_address => undef,
        organisation => undef,
        organisational_unit => undef,
        country => undef,
        state => undef,
        locality => undef,
        postal_code => undef,
        key => undef,
        cert => undef,
        profile_id => undef,
        profile_name => undef,
        valid_until => undef,
        not_before => undef,
        serial_number => undef,
        dns_names => undef,
        ip_addresses => undef,
        revoked => undef,
        crl_reason => undef,
        subject => undef,
    );

    @INSERTABLE_FIELDS = qw(
        created_at
        updated_at
        deleted_at
        cn
        mail
        ca_id
        ca_name
        street_address
        organisation
        organisational_unit
        country
        state
        locality
        postal_code
        key
        cert
        profile_id
        profile_name
        valid_until
        not_before
        serial_number
        dns_names
        ip_addresses
        revoked
        crl_reason
        subject
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
        ca_id => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        ca_name => {
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
        postal_code => {
            type => 'VARCHAR',
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
        profile_id => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        profile_name => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        valid_until => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        not_before => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        date => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        serial_number => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        dns_names => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        ip_addresses => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        revoked => {
            type => 'TIMESTAMP',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        crl_reason => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        subject => {
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
        pki_revoked_certs.id
        pki_revoked_certs.created_at
        pki_revoked_certs.updated_at
        pki_revoked_certs.deleted_at
        pki_revoked_certs.cn
        pki_revoked_certs.mail
        pki_revoked_certs.ca_id
        pki_revoked_certs.ca_name
        pki_revoked_certs.street_address
        pki_revoked_certs.organisation
        pki_revoked_certs.organisational_unit
        pki_revoked_certs.country
        pki_revoked_certs.state
        pki_revoked_certs.locality
        pki_revoked_certs.postal_code
        pki_revoked_certs.key
        pki_revoked_certs.cert
        pki_revoked_certs.profile_id
        pki_revoked_certs.profile_name
        pki_revoked_certs.valid_until
        pki_revoked_certs.not_before
        pki_revoked_certs.date
        pki_revoked_certs.serial_number
        pki_revoked_certs.dns_names
        pki_revoked_certs.ip_addresses
        pki_revoked_certs.revoked
        pki_revoked_certs.crl_reason
        pki_revoked_certs.subject
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of pki_revoked_certs

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 table_field_names

Field names of pki_revoked_certs

=cut

sub table_field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of pki_revoked_certs

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "pki_revoked_certs" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `pki_revoked_certs` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row pki_revoked_certs

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for pki_revoked_certs

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for pki_revoked_certs

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for pki_revoked_certs

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
