package pf::dal::_activation;

=head1 NAME

pf::dal::_activation - pf::dal implementation for the table activation

=cut

=head1 DESCRIPTION

pf::dal::_activation

pf::dal implementation for the table activation

=cut

use strict;
use warnings;

###
### pf::dal::_activation is auto generated any change to this file will be lost
### Instead change in the pf::dal::activation module
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
        code_id
        tenant_id
        pid
        mac
        contact_info
        carrier_id
        activation_code
        expiration
        unregdate
        status
        type
        portal
        source_id
    );

    %DEFAULTS = (
        tenant_id => '1',
        pid => undef,
        mac => undef,
        contact_info => '',
        carrier_id => undef,
        activation_code => '',
        expiration => '',
        unregdate => undef,
        status => undef,
        type => '',
        portal => undef,
        source_id => undef,
    );

    @INSERTABLE_FIELDS = qw(
        tenant_id
        pid
        mac
        contact_info
        carrier_id
        activation_code
        expiration
        unregdate
        status
        type
        portal
        source_id
    );

    %FIELDS_META = (
        code_id => {
            type => 'INT',
            is_auto_increment => 1,
            is_primary_key => 1,
            is_nullable => 0,
        },
        tenant_id => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        pid => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        mac => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        contact_info => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        carrier_id => {
            type => 'INT',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        activation_code => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        expiration => {
            type => 'DATETIME',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        unregdate => {
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
        type => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 0,
        },
        portal => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
        source_id => {
            type => 'VARCHAR',
            is_auto_increment => 0,
            is_primary_key => 0,
            is_nullable => 1,
        },
    );

    @PRIMARY_KEYS = qw(
        code_id
    );

    @COLUMN_NAMES = qw(
        activation.code_id
        activation.tenant_id
        activation.pid
        activation.mac
        activation.contact_info
        activation.carrier_id
        activation.activation_code
        activation.expiration
        activation.unregdate
        activation.status
        activation.type
        activation.portal
        activation.source_id
    );

}

use Class::XSAccessor {
    accessors => \@FIELD_NAMES,
};

=head2 _defaults

The default values of activation

=cut

sub _defaults {
    return {%DEFAULTS};
}

=head2 field_names

Field names of activation

=cut

sub field_names {
    return [@FIELD_NAMES];
}

=head2 primary_keys

The primary keys of activation

=cut

sub primary_keys {
    return [@PRIMARY_KEYS];
}

=head2

The table name

=cut

sub table { "activation" }

our $FIND_SQL = do {
    my $where = join(", ", map { "$_ = ?" } @PRIMARY_KEYS);
    "SELECT * FROM `activation` WHERE $where;";
};

=head2 find_columns

find_columns

=cut

sub find_columns {
    return [@COLUMN_NAMES];
}

=head2 _find_one_sql

The precalculated sql to find a single row activation

=cut

sub _find_one_sql {
    return $FIND_SQL;
}

=head2 _updateable_fields

The updateable fields for activation

=cut

sub _updateable_fields {
    return [@FIELD_NAMES];
}

=head2 _insertable_fields

The insertable fields for activation

=cut

sub _insertable_fields {
    return [@INSERTABLE_FIELDS];
}

=head2 get_meta

Get the meta data for activation

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
