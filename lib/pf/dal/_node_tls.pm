package pf::dal::_node_tls;

=head1 NAME

pf::dal::_node_tls - pf::dal implementation for the table node_tls

=cut

=head1 DESCRIPTION

pf::dal::_node_tls

pf::dal implementation for the table node_tls

=cut

use strict;
use warnings;

###
### pf::dal::_node_tls is auto generated any change to this file will be lost
### Instead change in the pf::dal::node_tls module
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
        mac
        TLSCertSerial
        TLSCertExpiration
        TLSCertValidSince
        TLSCertSubject
        TLSCertIssuer
        TLSCertCommonName
        TLSCertSubjectAltNameEmail
        TLSClientCertSerial
        TLSClientCertExpiration
        TLSClientCertValidSince
        TLSClientCertSubject
        TLSClientCertIssuer
        TLSClientCertCommonName
        TLSClientCertSubjectAltNameEmail
        TLSClientCertX509v3ExtendedKeyUsage
        TLSClientCertX509v3SubjectKeyIdentifier
        TLSClientCertX509v3AuthorityKeyIdentifier
        TLSClientCertX509v3ExtendedKeyUsageOID
    );

    %DEFAULTS = (
        mac => '',
        TLSCertSerial => undef,
        TLSCertExpiration => undef,
        TLSCertValidSince => undef,
        TLSCertSubject => undef,
        TLSCertIssuer => undef,
        TLSCertCommonName => undef,
        TLSCertSubjectAltNameEmail => undef,
        TLSClientCertSerial => undef,
        TLSClientCertExpiration => undef,
        TLSClientCertValidSince => undef,
        TLSClientCertSubject => undef,
        TLSClientCertIssuer => undef,
        TLSClientCertCommonName => undef,
        TLSClientCertSubjectAltNameEmail => undef,
        TLSClientCertX509v3ExtendedKeyUsage => undef,
        TLSClientCertX509v3SubjectKeyIdentifier => undef,
        TLSClientCertX509v3AuthorityKeyIdentifier => undef,
        TLSClientCertX509v3ExtendedKeyUsageOID => undef,
    );

    @INSERTABLE_FIELDS = qw(
        mac
        TLSCertSerial
        TLSCertExpiration
        TLSCertValidSince
        TLSCertSubject
        TLSCertIssuer
        TLSCertCommonName
        TLSCertSubjectAltNameEmail
        TLSClientCertSerial
        TLSClientCertExpiration
        TLSClientCertValidSince
        TLSClientCertSubject
        TLSClientCertIssuer
        TLSClientCertCommonName
        TLSClientCertSubjectAltNameEmail
        TLSClientCertX509v3ExtendedKeyUsage
        TLSClientCertX509v3SubjectKeyIdentifier
        TLSClientCertX509v3AuthorityKeyIdentifier
        TLSClientCertX509v3ExtendedKeyUsageOID
    );

    %FIELDS_META = (
        mac => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        TLSCertSerial => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSCertExpiration => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSCertValidSince => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSCertSubject => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSCertIssuer => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSCertCommonName => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSCertSubjectAltNameEmail => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSClientCertSerial => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSClientCertExpiration => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSClientCertValidSince => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSClientCertSubject => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSClientCertIssuer => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSClientCertCommonName => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSClientCertSubjectAltNameEmail => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSClientCertX509v3ExtendedKeyUsage => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSClientCertX509v3SubjectKeyIdentifier => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSClientCertX509v3AuthorityKeyIdentifier => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        TLSClientCertX509v3ExtendedKeyUsageOID => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
    );

    @PRIMARY_KEYS = qw(
        mac
    );

    @COLUMN_NAMES = qw(
        node_tls.mac
        node_tls.TLSCertSerial
        node_tls.TLSCertExpiration
        node_tls.TLSCertValidSince
        node_tls.TLSCertSubject
        node_tls.TLSCertIssuer
        node_tls.TLSCertCommonName
        node_tls.TLSCertSubjectAltNameEmail
        node_tls.TLSClientCertSerial
        node_tls.TLSClientCertExpiration
        node_tls.TLSClientCertValidSince
        node_tls.TLSClientCertSubject
        node_tls.TLSClientCertIssuer
        node_tls.TLSClientCertCommonName
        node_tls.TLSClientCertSubjectAltNameEmail
        node_tls.TLSClientCertX509v3ExtendedKeyUsage
        node_tls.TLSClientCertX509v3SubjectKeyIdentifier
        node_tls.TLSClientCertX509v3AuthorityKeyIdentifier
        node_tls.TLSClientCertX509v3ExtendedKeyUsageOID
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of node_tls

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 table_field_names

Field names of node_tls

=cut

sub table_field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of node_tls

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "node_tls" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `node_tls` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row node_tls

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for node_tls

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for node_tls

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for node_tls

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
