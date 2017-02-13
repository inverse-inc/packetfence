package pf::dal::_radius_nas;

=head1 NAME

pf::dal::_radius_nas - pf::dal implementation for the table radius_nas

=cut

=head1 DESCRIPTION

pf::dal::_radius_nas

pf::dal implementation for the table radius_nas

=cut

use strict;
use warnings;

###
### pf::dal::_radius_nas is auto generated any change to this file will be lost
### Instead change in the pf::dal::radius_nas module
###
use base qw(pf::dal);

our @FIELD_NAMES;
our @INSERTABLE_FIELDS;
our @PRIMARY_KEYS;
our %DEFAULTS;
our %FIELDS_META;

BEGIN {
    @FIELD_NAMES = qw(
        end_ip
        community
        server
        id
        description
        ports
        type
        range_length
        shortname
        config_timestamp
        nasname
        secret
        start_ip
    );

    %DEFAULTS = (
        end_ip => '0',
        community => undef,
        server => undef,
        description => 'RADIUS Client',
        ports => undef,
        type => 'other',
        range_length => '0',
        shortname => undef,
        config_timestamp => undef,
        nasname => '',
        secret => 'secret',
        start_ip => '0',
    );

    @INSERTABLE_FIELDS = qw(
        end_ip
        community
        server
        description
        ports
        type
        range_length
        shortname
        config_timestamp
        nasname
        secret
        start_ip
    );

    %FIELDS_META = (
        end_ip => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        community => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        server => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        id => {
            type => 'INT',
            is_auto_increment => 1,
            is_primary_key => 0,
            is_nullable => 0,
        },
        description => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        ports => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        type => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        range_length => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        shortname => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        config_timestamp => {
            type => 'BIGINT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        nasname => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        secret => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        start_ip => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
    );

    @PRIMARY_KEYS = qw(
        nasname
    );
}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of radius_nas

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 field_names

Field names of radius_nas

=cut

sub field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of radius_nas

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "radius_nas" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `radius_nas` WHERE $where;";
};

=head2 _find_one_sql

The precalculated sql to find a single row radius_nas

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for radius_nas

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _inserteable_fields

The inserteable fields for radius_nas

=cut

sub _inserteable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for radius_nas

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
