package pf::dal::_violation;

=head1 NAME

pf::dal::_violation - pf::dal implementation for the table violation

=cut

=head1 DESCRIPTION

pf::dal::_violation

pf::dal implementation for the table violation

=cut

use strict;
use warnings;

###
### pf::dal::_violation is auto generated any change to this file will be lost
### Instead change in the pf::dal::violation module
###
use base qw(pf::dal);

our @FIELD_NAMES;
our @INSERTABLE_FIELDS;
our @PRIMARY_KEYS;
our %DEFAULTS;
our %FIELDS_META;

BEGIN {
    @FIELD_NAMES = qw(
        vid
        id
        mac
        release_date
        status
        ticket_ref
        start_date
        notes
    );

    %DEFAULTS = (
        vid => '',
        mac => '',
        release_date => '0000-00-00 00:00:00',
        status => 'open',
        ticket_ref => undef,
        start_date => '',
        notes => undef,
    );

    @INSERTABLE_FIELDS = qw(
        vid
        mac
        release_date
        status
        ticket_ref
        start_date
        notes
    );

    %FIELDS_META = (
        vid => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        id => {
            type => 'INT',
            is_auto_increment => 1,
            is_primary_key => 1,
            is_nullable => 0,
        },
        mac => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        release_date => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        status => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        ticket_ref => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        start_date => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        notes => {
            type => 'TEXT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
    );

    @PRIMARY_KEYS = qw(
        id
    );
}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of violation

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 field_names

Field names of violation

=cut

sub field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of violation

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "violation" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `violation` WHERE $where;";
};

=head2 _find_one_sql

The precalculated sql to find a single row violation

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for violation

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _inserteable_fields

The inserteable fields for violation

=cut

sub _inserteable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for violation

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
