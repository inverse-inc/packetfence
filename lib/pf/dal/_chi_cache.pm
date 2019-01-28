package pf::dal::_chi_cache;

=head1 NAME

pf::dal::_chi_cache - pf::dal implementation for the table chi_cache

=cut

=head1 DESCRIPTION

pf::dal::_chi_cache

pf::dal implementation for the table chi_cache

=cut

use strict;
use warnings;

###
### pf::dal::_chi_cache is auto generated any change to this file will be lost
### Instead change in the pf::dal::chi_cache module
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
        key
        value
        expires_at
    );

    %DEFAULTS = (
        key => '',
        value => undef,
        expires_at => undef,
    );

    @INSERTABLE_FIELDS = qw(
        key
        value
        expires_at
    );

    %FIELDS_META = (
        key => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        value => {
            type => 'LONGBLOB',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        expires_at => {
            type => 'DOUBLE',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
    );

    @PRIMARY_KEYS = qw(
        key
    );

    @COLUMN_NAMES = qw(
        chi_cache.key
        chi_cache.value
        chi_cache.expires_at
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of chi_cache

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 table_field_names

Field names of chi_cache

=cut

sub table_field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of chi_cache

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "chi_cache" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `chi_cache` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row chi_cache

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for chi_cache

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for chi_cache

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for chi_cache

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
