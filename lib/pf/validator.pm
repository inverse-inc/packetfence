package pf::validator;

=head1 NAME

pf::validator -

=head1 DESCRIPTION

pf::validator

=cut

use strict;
use warnings;
use Class::Load qw(load_optional_class);
use Moose;
use pf::validator::Ctx;

has fields => (
    traits    => ['Array'],
    is        => 'rw',
    isa       => 'ArrayRef',
    handles   => {
        add_to_field_list => 'push',
        has_field_list => 'count',
    },

    builder => '_build_fields',
);

has is_nullable => (
    is  => 'ro',
    isa => 'Bool',
    default => 0,
);

sub validate {
    my ($self, $ctx, $value) = @_;

    if (!defined $value) {
        if (!$self->is_nullable) {
            $ctx->add_error({ message => 'Cannot be Null' });
        }

        return;
    }

    for my $field (@{$self->fields}) {
        my $name = $field->name;
        my $field_val;
        if (exists $value->{$name}) {
            $field_val = $value->{$name};
        }

        $field->validate($ctx, $field_val);
    }

    return;
}

sub _build_fields {
    my ($self) = @_;
    my @fields;
    my $fields_data = $self->_build_meta_field_list;
    for my $d (@$fields_data) {
        push @fields, $self->_build_field($d);
    }

    return \@fields;
}

sub _build_field {
    my ($self, $attr) = @_;
    my $type = $attr->{type} ||= 'String';
    my $name = $attr->{name};
    my $class = $self->_field_class($type, $name);
    return $self->_create_field($class, $attr);
}

sub _create_field {
    my ($self, $class, $attr) = @_;
    return $class->new(%$attr);
}

sub _field_class {
    my ($self, $type, $name) = @_;
    my $class = "pf::validator::Field::$type";
    unless (load_optional_class($class)) {
        die "Could not load field class '$type' for field '$name'";
    }

    return $class;
}

sub _build_meta_field_list {
    my $self = shift;
    my $field_list = [];

    foreach my $sc ( reverse $self->meta->linearized_isa ) {
        my $meta = $sc->meta;
        if ( $meta->can('calculate_all_roles') ) {
            foreach my $role ( reverse $meta->calculate_all_roles ) {
                if ( $role->can('field_list') && $role->has_field_list ) {
                    foreach my $fld_def ( @{ $role->field_list } ) {
                        push @$field_list, $fld_def;
                    }
                }
            }
        }

        if ( $meta->can('field_list') && $meta->has_field_list ) {
            foreach my $fld_def ( @{ $meta->field_list } ) {
                push @$field_list, $fld_def;
            }
        }
    }

    return $field_list if scalar @$field_list;
}

sub optionsMeta {
    my ($self) = @_;
    my %meta;
    for my $field (@{$self->fields}) {
        my $name = $field->name;
        $meta{$name} = $field->optionsMeta;
    }

    return \%meta;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

