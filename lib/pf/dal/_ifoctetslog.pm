package pf::dal::_ifoctetslog;

=head1 NAME

pf::dal::_ifoctetslog - pf::dal implementation for the table ifoctetslog

=cut

=head1 DESCRIPTION

pf::dal::_ifoctetslog

pf::dal implementation for the table ifoctetslog

=cut

use strict;
use warnings;

###
### pf::dal::_ifoctetslog is auto generated any change to this file will be lost
### Instead change in the pf::dal::ifoctetslog module
###
use base qw(pf::dal);

our @FIELD_NAMES;
our @INSERTABLE_FIELDS;
our @PRIMARY_KEYS;
our %DEFAULTS;
our %FIELDS_META;

BEGIN {
    @FIELD_NAMES = qw(
        switch
        port
        read_time
        mac
        ifInOctets
        ifOutOctets
    );

    %DEFAULTS = (
        switch => '',
        port => '',
        read_time => '0000-00-00 00:00:00',
        mac => undef,
        ifInOctets => '0',
        ifOutOctets => '0',
    );

    @INSERTABLE_FIELDS = qw(
        switch
        port
        read_time
        mac
        ifInOctets
        ifOutOctets
    );

    %FIELDS_META = (
        switch => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        port => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        read_time => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        mac => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        ifInOctets => {
            type => 'BIGINT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        ifOutOctets => {
            type => 'BIGINT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
    );

    @PRIMARY_KEYS = qw(
        switch
        port
        read_time
    );
}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of ifoctetslog

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 field_names

Field names of ifoctetslog

=cut

sub field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of ifoctetslog

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "ifoctetslog" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `ifoctetslog` WHERE $where;";
};

=head2 _find_one_sql

The precalculated sql to find a single row ifoctetslog

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for ifoctetslog

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for ifoctetslog

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for ifoctetslog

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
