package pf::dal::_radacct_log;

=head1 NAME

pf::dal::_radacct_log -

=cut

=head1 DESCRIPTION

pf::dal::_radacct_log -

=cut

use strict;
use warnings;

###
### pf::dal::_radacct_log is auto generated any change to this file will be lost
### Make and changes to this file in pf::dal::radacct_log
###
use base qw(pf::dal);

our @FIELD_NAMES;
our @INSERTABLE_FIELDS;
our @PRIMARY_KEYS;
our %DEFAULTS;
our %FIELDS_META;

BEGIN {
    @FIELD_NAMES = qw(
        acctoutputoctets
        acctsessiontime
        acctinputoctets
        nasipaddress
        acctsessionid
        acctstatustype
        timestamp
        acctuniqueid
        username
        radacct_log_id
    );

    %DEFAULTS = (
        acctoutputoctets => undef,
        acctsessiontime => undef,
        acctinputoctets => undef,
        nasipaddress => '',
        acctsessionid => '',
        acctstatustype => '',
        timestamp => undef,
        acctuniqueid => '',
        username => '',
    );

    @INSERTABLE_FIELDS = qw(
        acctoutputoctets
        acctsessiontime
        acctinputoctets
        nasipaddress
        acctsessionid
        acctstatustype
        timestamp
        acctuniqueid
        username
    );

    %FIELDS_META = (
        acctoutputoctets => {
            type => 'BIGINT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        acctsessiontime => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        acctinputoctets => {
            type => 'BIGINT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        nasipaddress => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        acctsessionid => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        acctstatustype => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        timestamp => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        acctuniqueid => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        username => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        radacct_log_id => {
            type => 'INT',
            is_auto_increment => 1,
            is_primary_key => 1,
            is_nullable => 0,
        },
    );

    @PRIMARY_KEYS = qw(
        radacct_log_id
    );
}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of radacct_log

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 field_names

Field names of radacct_log

=cut

sub field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of radacct_log

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "radacct_log" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `radacct_log` WHERE $where;";
};

=head2 _find_one_sql

The precalculated sql to find a single row radacct_log

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for radacct_log

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _inserteable_fields

The inserteable fields for radacct_log

=cut

sub _inserteable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for radacct_log

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
