package pf::dal::_savedsearch;

=head1 NAME

pf::dal::_savedsearch -

=cut

=head1 DESCRIPTION

pf::dal::_savedsearch -

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
        pid
        id
        name
        in_dashboard
        namespace
        query
    );

    %DEFAULTS = (
        pid => '',
        name => '',
        in_dashboard => undef,
        namespace => '',
        query => undef,
    );

    %FIELDS_META = (
        pid => {
            type => 'VARCHAR',
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
        name => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        in_dashboard => {
            type => 'TINYINT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        namespace => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        query => {
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

    true => [qw(has_primary_key)],

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

sub table { "savedsearch" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM savedsearch WHERE $where;";
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
