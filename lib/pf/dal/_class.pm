package pf::dal::_class;

=head1 NAME

pf::dal::_class - pf::dal implementation for the table class

=cut

=head1 DESCRIPTION

pf::dal::_class

pf::dal implementation for the table class

=cut

use strict;
use warnings;

###
### pf::dal::_class is auto generated any change to this file will be lost
### Instead change in the pf::dal::class module
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
        security_event_id
        description
        auto_enable
        max_enables
        grace_period
        window
        vclose
        priority
        template
        max_enable_url
        redirect_url
        button_text
        enabled
        vlan
        target_category
        delay_by
        external_command
    );

    %DEFAULTS = (
        security_event_id => '',
        description => 'none',
        auto_enable => 'Y',
        max_enables => '0',
        grace_period => '',
        window => '0',
        vclose => undef,
        priority => '',
        template => undef,
        max_enable_url => undef,
        redirect_url => undef,
        button_text => undef,
        enabled => 'N',
        vlan => undef,
        target_category => undef,
        delay_by => '0',
        external_command => undef,
    );

    @INSERTABLE_FIELDS = qw(
        security_event_id
        description
        auto_enable
        max_enables
        grace_period
        window
        vclose
        priority
        template
        max_enable_url
        redirect_url
        button_text
        enabled
        vlan
        target_category
        delay_by
        external_command
    );

    %FIELDS_META = (
        security_event_id => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        description => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        auto_enable => {
            type => 'CHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        max_enables => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        grace_period => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        window => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        vclose => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        priority => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        template => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        max_enable_url => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        redirect_url => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        button_text => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        enabled => {
            type => 'CHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        vlan => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        target_category => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        delay_by => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        external_command => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
    );

    @PRIMARY_KEYS = qw(
        security_event_id
    );

    @COLUMN_NAMES = qw(
        class.security_event_id
        class.description
        class.auto_enable
        class.max_enables
        class.grace_period
        class.window
        class.vclose
        class.priority
        class.template
        class.max_enable_url
        class.redirect_url
        class.button_text
        class.enabled
        class.vlan
        class.target_category
        class.delay_by
        class.external_command
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of class

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 table_field_names

Field names of class

=cut

sub table_field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of class

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "class" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `class` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row class

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for class

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for class

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for class

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
