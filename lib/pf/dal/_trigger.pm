package pf::dal::_trigger;

=head1 NAME

pf::dal::_trigger - pf::dal implementation for the table trigger

=cut

=head1 DESCRIPTION

pf::dal::_trigger

pf::dal implementation for the table trigger

=cut

use strict;
use warnings;

###
### pf::dal::_trigger is auto generated any change to this file will be lost
### Instead change in the pf::dal::trigger module
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
        vid
        tid_start
        tid_end
        type
        whitelisted_categories
    );

    %DEFAULTS = (
        vid => '',
        tid_start => '',
        tid_end => '',
        type => '',
        whitelisted_categories => '',
    );

    @INSERTABLE_FIELDS = qw(
        vid
        tid_start
        tid_end
        type
        whitelisted_categories
    );

    %FIELDS_META = (
        vid => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        tid_start => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        tid_end => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        type => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        whitelisted_categories => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
    );

    @PRIMARY_KEYS = qw(
        vid
        tid_start
        tid_end
        type
    );

    @COLUMN_NAMES = qw(
        trigger.vid
        trigger.tid_start
        trigger.tid_end
        trigger.type
        trigger.whitelisted_categories
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of trigger

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 field_names

Field names of trigger

=cut

sub field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of trigger

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "trigger" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `trigger` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row trigger

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for trigger

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for trigger

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for trigger

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
