package pf::dal::_tenant_code;

=head1 NAME

pf::dal::_tenant_code - pf::dal implementation for the table tenant_code

=cut

=head1 DESCRIPTION

pf::dal::_tenant_code

pf::dal implementation for the table tenant_code

=cut

use strict;
use warnings;

###
### pf::dal::_tenant_code is auto generated any change to this file will be lost
### Instead change in the pf::dal::tenant_code module
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
        code
        tenant_id
        switch_ip
    );

    %DEFAULTS = (
        code => '',
        tenant_id => '',
        switch_ip => '',
    );

    @INSERTABLE_FIELDS = qw(
        code
        tenant_id
        switch_ip
    );

    %FIELDS_META = (
        code => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        tenant_id => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        switch_ip => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
    );

    @PRIMARY_KEYS = qw(
        code
    );

    @COLUMN_NAMES = qw(
        tenant_code.code
        tenant_code.tenant_id
        tenant_code.switch_ip
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of tenant_code

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 field_names

Field names of tenant_code

=cut

sub field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of tenant_code

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "tenant_code" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `tenant_code` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row tenant_code

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for tenant_code

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for tenant_code

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for tenant_code

=cut

sub get_meta {
    return \%FIELDS_META;
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
