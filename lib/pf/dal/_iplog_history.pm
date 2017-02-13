package pf::dal::_iplog_history;

=head1 NAME

pf::dal::_iplog_history - pf::dal implementation for the table iplog_history

=cut

=head1 DESCRIPTION

pf::dal::_iplog_history

pf::dal implementation for the table iplog_history

=cut

use strict;
use warnings;

###
### pf::dal::_iplog_history is auto generated any change to this file will be lost
### Instead change in the pf::dal::iplog_history module
###
use base qw(pf::dal);

our @FIELD_NAMES;
our @INSERTABLE_FIELDS;
our @PRIMARY_KEYS;
our %DEFAULTS;
our %FIELDS_META;

BEGIN {
    @FIELD_NAMES = qw(
        ip
        end_time
        id
        mac
        start_time
    );

    %DEFAULTS = (
        ip => '',
        end_time => '',
        mac => '',
        start_time => '',
    );

    @INSERTABLE_FIELDS = qw(
        ip
        end_time
        mac
        start_time
    );

    %FIELDS_META = (
        ip => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        end_time => {
            type => 'DATETIME',
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
        start_time => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
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

The default values of iplog_history

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 field_names

Field names of iplog_history

=cut

sub field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of iplog_history

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "iplog_history" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `iplog_history` WHERE $where;";
};

=head2 _find_one_sql

The precalculated sql to find a single row iplog_history

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for iplog_history

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _inserteable_fields

The inserteable fields for iplog_history

=cut

sub _inserteable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for iplog_history

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
