package pf::dal::_class;

=head1 NAME

pf::dal::_class -

=cut

=head1 DESCRIPTION

pf::dal::_class -

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
        priority
        vid
        window
        grace_period
        max_enables
        enabled
        vclose
        max_enable_url
        template
        auto_enable
        delay_by
        description
        vlan
        external_command
        redirect_url
        button_text
        target_category
    );

    %DEFAULTS = (
        priority => '',
        vid => '',
        window => '0',
        grace_period => '',
        max_enables => '0',
        enabled => 'N',
        vclose => undef,
        max_enable_url => undef,
        template => undef,
        auto_enable => 'Y',
        delay_by => '0',
        description => 'none',
        vlan => undef,
        external_command => undef,
        redirect_url => undef,
        button_text => undef,
        target_category => undef,
    );

    %FIELDS_META = (
        priority => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        vid => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        window => {
            type => 'VARCHAR',
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
        max_enables => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        enabled => {
            type => 'CHAR',
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
        max_enable_url => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        template => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        auto_enable => {
            type => 'CHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        delay_by => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        description => {
            type => 'VARCHAR',
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
        external_command => {
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
        target_category => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
    );

    @PRIMARY_KEYS = qw(
        vid
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

sub table { "class" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM class WHERE $where;";
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
