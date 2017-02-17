package pf::dal::_node_useragent;

=head1 NAME

pf::dal::_node_useragent - pf::dal implementation for the table node_useragent

=cut

=head1 DESCRIPTION

pf::dal::_node_useragent

pf::dal implementation for the table node_useragent

=cut

use strict;
use warnings;

###
### pf::dal::_node_useragent is auto generated any change to this file will be lost
### Instead change in the pf::dal::node_useragent module
###
use base qw(pf::dal);

our @FIELD_NAMES;
our @INSERTABLE_FIELDS;
our @PRIMARY_KEYS;
our %DEFAULTS;
our %FIELDS_META;

BEGIN {
    @FIELD_NAMES = qw(
        mac
        os
        browser
        device
        device_name
        mobile
    );

    %DEFAULTS = (
        mac => '',
        os => undef,
        browser => undef,
        device => 'no',
        device_name => undef,
        mobile => 'no',
    );

    @INSERTABLE_FIELDS = qw(
        mac
        os
        browser
        device
        device_name
        mobile
    );

    %FIELDS_META = (
        mac => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        os => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        browser => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        device => {
            type => 'ENUM',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
            enums_values => {
                'no' => 1,
                'yes' => 1,
            },
        },
        device_name => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        mobile => {
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
        mac
    );
}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of node_useragent

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 field_names

Field names of node_useragent

=cut

sub field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of node_useragent

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "node_useragent" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `node_useragent` WHERE $where;";
};

=head2 _find_one_sql

The precalculated sql to find a single row node_useragent

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for node_useragent

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for node_useragent

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for node_useragent

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
