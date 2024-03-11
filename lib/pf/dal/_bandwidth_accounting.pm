package pf::dal::_bandwidth_accounting;

=head1 NAME

pf::dal::_bandwidth_accounting - pf::dal implementation for the table bandwidth_accounting

=cut

=head1 DESCRIPTION

pf::dal::_bandwidth_accounting

pf::dal implementation for the table bandwidth_accounting

=cut

use strict;
use warnings;

###
### pf::dal::_bandwidth_accounting is auto generated any change to this file will be lost
### Instead change in the pf::dal::bandwidth_accounting module
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
        node_id
        unique_session_id
        time_bucket
        source_type
        in_bytes
        out_bytes
        mac
        last_updated
        total_bytes
    );

    %DEFAULTS = (
        node_id => '',
        unique_session_id => '',
        time_bucket => '',
        source_type => '',
        in_bytes => '',
        out_bytes => '',
        mac => '',
        total_bytes => undef,
    );

    @INSERTABLE_FIELDS = qw(
        node_id
        unique_session_id
        time_bucket
        source_type
        in_bytes
        out_bytes
        mac
    );

    %FIELDS_META = (
        node_id => {
            type => 'BIGINT',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        unique_session_id => {
            type => 'BIGINT',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        time_bucket => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        source_type => {
            type => 'ENUM',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
            enums_values => {
                'net_flow' => 1,
                'radius' => 1,
            },
        },
        in_bytes => {
            type => 'BIGINT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        out_bytes => {
            type => 'BIGINT',
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
        last_updated => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        total_bytes => {
            type => 'BIGINT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
    );

    @PRIMARY_KEYS = qw(
        node_id
        time_bucket
        unique_session_id
    );

    @COLUMN_NAMES = qw(
        bandwidth_accounting.node_id
        bandwidth_accounting.unique_session_id
        bandwidth_accounting.time_bucket
        bandwidth_accounting.source_type
        bandwidth_accounting.in_bytes
        bandwidth_accounting.out_bytes
        bandwidth_accounting.mac
        bandwidth_accounting.last_updated
        bandwidth_accounting.total_bytes
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of bandwidth_accounting

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 table_field_names

Field names of bandwidth_accounting

=cut

sub table_field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of bandwidth_accounting

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "bandwidth_accounting" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `bandwidth_accounting` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row bandwidth_accounting

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for bandwidth_accounting

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for bandwidth_accounting

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for bandwidth_accounting

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
