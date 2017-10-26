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
our @COLUMN_NAMES;

BEGIN {
    @FIELD_NAMES = qw(
        id
        tenant_id
        nasname
        shortname
        type
        ports
        secret
        server
        community
        description
        config_timestamp
        start_ip
        end_ip
        range_length
    );

    %DEFAULTS = (
        tenant_id => '1',
        nasname => '',
        shortname => undef,
        type => 'other',
        ports => undef,
        secret => 'secret',
        server => undef,
        community => undef,
        description => 'RADIUS Client',
        config_timestamp => undef,
        start_ip => '0',
        end_ip => '0',
        range_length => '0',
    );

    @INSERTABLE_FIELDS = qw(
        tenant_id
        nasname
        shortname
        type
        ports
        secret
        server
        community
        description
        config_timestamp
        start_ip
        end_ip
        range_length
    );

    %FIELDS_META = (
        id => {
            type => 'INT',
            is_auto_increment => 1,
            is_primary_key => 0,
            is_nullable => 0,
        },
        tenant_id => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        nasname => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 1,
            is_nullable => 0,
        },
        shortname => {
            type => 'VARCHAR',
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
        ports => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        secret => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        server => {
            type => 'VARCHAR',
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
        description => {
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
        start_ip => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        end_ip => {
            type => 'INT',
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
    );

    @PRIMARY_KEYS = qw(
        nasname
    );

    @COLUMN_NAMES = qw(
        radius_nas.id
        radius_nas.tenant_id
        radius_nas.nasname
        radius_nas.shortname
        radius_nas.type
        radius_nas.ports
        radius_nas.secret
        radius_nas.server
        radius_nas.community
        radius_nas.description
        radius_nas.config_timestamp
        radius_nas.start_ip
        radius_nas.end_ip
        radius_nas.range_length
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

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

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

=head2 _insertable_fields

The insertable fields for radius_nas

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for radius_nas

=cut

sub get_meta {
    return \%FIELDS_META;
}

=head2 update_params_for_select

Automatically add the current tenant_id to the where clause of the select statement

=cut

sub update_params_for_select {
    my ($self, %args) = @_;
    unless ($args{'-no_auto_tenant_id'}) {
        my $where = {
            tenant_id => $self->get_tenant,
        };
        my $old_where = delete $args{-where};
        if (defined $old_where) {
            $where->{-and} = $old_where;
        }
        $args{-where} = $old_where;
    }
    return $self->SUPER::update_params_for_select(%args);
}

=head2 update_params_for_update

Automatically add the current tenant_id to the where clause of the update statement

=cut

sub update_params_for_update {
    my ($self, %args) = @_;
    unless ($args{'-no_auto_tenant_id'}) {
        my $where = {
            tenant_id => $self->get_tenant,
        };
        my $old_where = delete $args{-where};
        if (defined $old_where) {
            $where->{-and} = $old_where;
        }
        $args{-where} = $old_where;
    }
    return $self->SUPER::update_params_for_select(%args);
}

=head2 update_params_for_delete

Automatically add the current tenant_id to the where clause of the delete statement

=cut

sub update_params_for_delete {
    my ($self, %args) = @_;
    unless ($args{'-no_auto_tenant_id'}) {
        my $where = {
            tenant_id => $self->get_tenant,
        };
        my $old_where = delete $args{-where};
        if (defined $old_where) {
            $where->{-and} = $old_where;
        }
        $args{-where} = $old_where;
    }
    return $self->SUPER::update_params_for_select(%args);
}

=head2 update_params_for_insert

Automatically add the current tenant_id to the set clause of the insert statement

=cut

sub update_params_for_insert {
    my ($self, %args) = @_;
    unless ($args{'-no_auto_tenant_id'}) {
        my $old_set = delete $args{-set} // {};
        $old_set->{tenant_id} = $self->get_tenant;
        $args{-set} = $old_set;
    }
    return $self->SUPER::update_params_for_insert(%args);
}

=head2 defaults

=cut

sub defaults {
    my ($self) = @_;
    return {%{$self->SUPER::defaults}, tenant_id => $self->get_tenant};
}

 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
