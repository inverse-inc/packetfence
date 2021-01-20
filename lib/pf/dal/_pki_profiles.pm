package pf::dal::_pki_profiles;

=head1 NAME

pf::dal::_pki_profiles - pf::dal implementation for the table pki_profiles

=cut

=head1 DESCRIPTION

pf::dal::_pki_profiles

pf::dal implementation for the table pki_profiles

=cut

use strict;
use warnings;

###
### pf::dal::_pki_profiles is auto generated any change to this file will be lost
### Instead change in the pf::dal::pki_profiles module
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
        ca_id
        ca_name
        validity
        key_type
        key_size
        digest
        key_usage
        extended_key_usage
        p12_mail_password
        p12_mail_subject
        p12_mail_from
        p12_mail_header
        p12_mail_footer
        scep_enabled
        scep_challenge_password
        scep_allow_renewal
    );

    %DEFAULTS = (
        created_at => undef,
        updated_at => undef,
        deleted_at => undef,
        name => undef,
        ca_id => undef,
        ca_name => undef,
        validity => undef,
        key_type => undef,
        key_size => undef,
        digest => undef,
        key_usage => undef,
        extended_key_usage => undef,
        p12_mail_password => undef,
        p12_mail_subject => undef,
        p12_mail_from => undef,
        p12_mail_header => undef,
        p12_mail_footer => undef,
        scep_enabled => undef,
        scep_challenge_password => undef,
        scep_allow_renewal => undef,
    );

    @INSERTABLE_FIELDS = qw(
        created_at
        updated_at
        deleted_at
        name
        ca_id
        ca_name
        validity
        key_type
        key_size
        digest
        key_usage
        extended_key_usage
        p12_mail_password
        p12_mail_subject
        p12_mail_from
        p12_mail_header
        p12_mail_footer
        scep_enabled
        scep_challenge_password
        scep_allow_renewal
    );

    %FIELDS_META = (
        id => {
            type => 'BIGINT',
            is_auto_increment => 1,
            is_primary_key => 1,
            is_nullable => 0,
        },
        created_at => {
            type => 'TIMESTAMP',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        updated_at => {
            type => 'TIMESTAMP',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        deleted_at => {
            type => 'TIMESTAMP',
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
        validity => {
            type => 'INT',
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
        p12_mail_password => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        p12_mail_subject => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        p12_mail_from => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        p12_mail_header => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        p12_mail_footer => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        scep_enabled => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        scep_challenge_password => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        scep_allow_renewal => {
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
        pki_profiles.id
        pki_profiles.created_at
        pki_profiles.updated_at
        pki_profiles.deleted_at
        pki_profiles.name
        pki_profiles.ca_id
        pki_profiles.ca_name
        pki_profiles.validity
        pki_profiles.key_type
        pki_profiles.key_size
        pki_profiles.digest
        pki_profiles.key_usage
        pki_profiles.extended_key_usage
        pki_profiles.p12_mail_password
        pki_profiles.p12_mail_subject
        pki_profiles.p12_mail_from
        pki_profiles.p12_mail_header
        pki_profiles.p12_mail_footer
        pki_profiles.scep_enabled
        pki_profiles.scep_challenge_password
        pki_profiles.scep_allow_renewal
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of pki_profiles

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 table_field_names

Field names of pki_profiles

=cut

sub table_field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of pki_profiles

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "pki_profiles" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `pki_profiles` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row pki_profiles

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for pki_profiles

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for pki_profiles

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for pki_profiles

=cut

sub get_meta {
    return \%FIELDS_META;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
