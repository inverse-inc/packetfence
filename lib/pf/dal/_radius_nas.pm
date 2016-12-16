package pf::dal::_radius_nas;

=head1 NAME

pf::dal::_radius_nas -

=cut

=head1 DESCRIPTION

pf::dal::_radius_nas -

=cut

use strict;
use warnings;

use base qw(pf::dal);

our @FIELD_NAMES;
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

sub _defaults {
    return {%DEFAULTS};
}

sub field_names {
    return [@FIELD_NAMES];
}

sub primary_keys {
    return [@PRIMARY_KEYS];
}

sub table { "radius_nas" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM radius_nas WHERE $where;";
};

sub _find_one_sql {
    return $FIND_SQL;
}

sub _updateable_fields {
    return [@FIELD_NAMES];
}

sub get_meta {
    return \%FIELDS_META;
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
