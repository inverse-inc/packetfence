package pf::dal::_person;

=head1 NAME

pf::dal::_person - pf::dal implementation for the table person

=cut

=head1 DESCRIPTION

pf::dal::_person

pf::dal implementation for the table person

=cut

use strict;
use warnings;

###
### pf::dal::_person is auto generated any change to this file will be lost
### Instead change in the pf::dal::person module
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
        firstname
        lastname
        email
        telephone
        company
        address
        notes
        sponsor
        anniversary
        birthday
        gender
        lang
        nickname
        cell_phone
        work_phone
        title
        building_number
        apartment_number
        room_number
        custom_field_1
        custom_field_2
        custom_field_3
        custom_field_4
        custom_field_5
        custom_field_6
        custom_field_7
        custom_field_8
        custom_field_9
        portal
        source
        psk
        potd
    );

    %DEFAULTS = (
        tenant_id => '1',
        pid => '',
        firstname => undef,
        lastname => undef,
        email => undef,
        telephone => undef,
        company => undef,
        address => undef,
        notes => undef,
        sponsor => undef,
        anniversary => undef,
        birthday => undef,
        gender => undef,
        lang => undef,
        nickname => undef,
        cell_phone => undef,
        work_phone => undef,
        title => undef,
        building_number => undef,
        apartment_number => undef,
        room_number => undef,
        custom_field_1 => undef,
        custom_field_2 => undef,
        custom_field_3 => undef,
        custom_field_4 => undef,
        custom_field_5 => undef,
        custom_field_6 => undef,
        custom_field_7 => undef,
        custom_field_8 => undef,
        custom_field_9 => undef,
        portal => undef,
        source => undef,
        psk => undef,
        potd => 'no',
    );

    @INSERTABLE_FIELDS = qw(
        tenant_id
        pid
        firstname
        lastname
        email
        telephone
        company
        address
        notes
        sponsor
        anniversary
        birthday
        gender
        lang
        nickname
        cell_phone
        work_phone
        title
        building_number
        apartment_number
        room_number
        custom_field_1
        custom_field_2
        custom_field_3
        custom_field_4
        custom_field_5
        custom_field_6
        custom_field_7
        custom_field_8
        custom_field_9
        portal
        source
        psk
        potd
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
        firstname => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        lastname => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        email => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        telephone => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        company => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        address => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        notes => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        sponsor => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        anniversary => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        birthday => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        gender => {
            type => 'CHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        lang => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        nickname => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        cell_phone => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        work_phone => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        title => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        building_number => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        apartment_number => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        room_number => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        custom_field_1 => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        custom_field_2 => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        custom_field_3 => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        custom_field_4 => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        custom_field_5 => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        custom_field_6 => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        custom_field_7 => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        custom_field_8 => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        custom_field_9 => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        portal => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        source => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        psk => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        potd => {
            type => 'ENUM',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
            enums_values => {
                'no' => 1,
                'yes' => 1,
            },
        },
    );

    @PRIMARY_KEYS = qw(
        tenant_id
        pid
    );

    @COLUMN_NAMES = qw(
        person.tenant_id
        person.pid
        person.firstname
        person.lastname
        person.email
        person.telephone
        person.company
        person.address
        person.notes
        person.sponsor
        person.anniversary
        person.birthday
        person.gender
        person.lang
        person.nickname
        person.cell_phone
        person.work_phone
        person.title
        person.building_number
        person.apartment_number
        person.room_number
        person.custom_field_1
        person.custom_field_2
        person.custom_field_3
        person.custom_field_4
        person.custom_field_5
        person.custom_field_6
        person.custom_field_7
        person.custom_field_8
        person.custom_field_9
        person.portal
        person.source
        person.psk
        person.potd
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of person

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 table_field_names

Field names of person

=cut

sub table_field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of person

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "person" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `person` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row person

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for person

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for person

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for person

=cut

sub get_meta {
    return \%FIELDS_META;
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
