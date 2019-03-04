package pf::dal::_password;

=head1 NAME

pf::dal::_password - pf::dal implementation for the table password

=cut

=head1 DESCRIPTION

pf::dal::_password

pf::dal implementation for the table password

=cut

use strict;
use warnings;

###
### pf::dal::_password is auto generated any change to this file will be lost
### Instead change in the pf::dal::password module
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
        tenant_id
        pid
        password
        valid_from
        expiration
        access_duration
        access_level
        category
        sponsor
        unregdate
        login_remaining
    );

    %DEFAULTS = (
        tenant_id => '1',
        pid => '',
        password => '',
        valid_from => '0000-00-00 00:00:00',
        expiration => '',
        access_duration => undef,
        access_level => 'NONE',
        category => undef,
        sponsor => '0',
        unregdate => '0000-00-00 00:00:00',
        login_remaining => undef,
    );

    @INSERTABLE_FIELDS = qw(
        tenant_id
        pid
        password
        valid_from
        expiration
        access_duration
        access_level
        category
        sponsor
        unregdate
        login_remaining
    );

    %FIELDS_META = (
        tenant_id => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        pid => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        password => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        valid_from => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        expiration => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        access_duration => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        access_level => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        category => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        sponsor => {
            type => 'TINYINT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        unregdate => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        login_remaining => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
    );

    @PRIMARY_KEYS = qw(
        tenant_id
        pid
    );

    @COLUMN_NAMES = qw(
        password.tenant_id
        password.pid
        password.password
        password.valid_from
        password.expiration
        password.access_duration
        password.access_level
        password.category
        password.sponsor
        password.unregdate
        password.login_remaining
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of password

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 table_field_names

Field names of password

=cut

sub table_field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of password

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "password" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `password` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row password

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for password

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for password

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for password

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
