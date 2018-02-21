package pf::UnifiedApi::GenerateSpec;

=head1 NAME

pf::UnifiedApi::GenerateSpec - Auto generate the spec

=cut

=head1 DESCRIPTION

pf::UnifiedApi::GenerateSpec

=cut

use strict;
use warnings;
our %FIELDS_TYPES_TO_SCHEMA_TYPES = (
    PosInteger => 'integer',
);
use Lingua::EN::Inflexion qw(noun);

sub formHandlerToSchema {
    my ($form) = @_;
    my $name = ref $form;
    $name =~ s/^.*:://;
    return {
        $name => {
            type       => 'object',
            properties => formHandlerProperties($form),
            required   => formHandlerRequiredProperties($form),
        },
        listSchema($name)
    };
}

sub formHandlerRequiredProperties {
    my ($form) = @_;
    return [map { $_->name } grep { $_->required } $form->fields];
}

sub formHandlerProperties {
    my ($form) = @_;
    my %properties;
    for my $field ($form->fields) {
        my $name = $field->name;
        $properties{$name} = fieldProperties($field);
    }
    return \%properties;
}

sub fieldProperties {
    my ($field) = @_;
    my %props = (
        type => fieldType($field),
        description => fieldDescription($field),
    );
    if ($props{type} eq 'array') {
        $props{items} = fieldArrayItems($field);
    } elsif ($props{type} eq 'object') {
        $props{properties} = formHandlerProperties($field);
    }

    return \%props;
}

sub fieldArrayItems {
    my ($field) = @_;
    my $element = $field->clone_element(noun($field->name)->singular);
    return fieldProperties($element);
}

sub fieldType {
    my ($field) = @_;
    if (isArrayType($field)) {
        return 'array';
    }

    if (isObjectType($field)) {
        return 'object';
    }

    my $type = $field->type;
    if (exists $FIELDS_TYPES_TO_SCHEMA_TYPES{$type}) {
        return $FIELDS_TYPES_TO_SCHEMA_TYPES{$type};
    }
    return "string";
}

sub isArrayType {
    my ($field) = @_;
    return $field->isa('HTML::FormHandler::Field::Repeatable') || 
        ($field->isa('HTML::FormHandler::Field::Select') && $field->multiple );
}

sub isObjectType {
    my ($field) = @_;
    return $field->isa('HTML::FormHandler::Field::Compound');
}

sub fieldDescription {
    my ($field) = @_;
    my $description = $field->get_tag('help') || $field->label;
    return $description;
}

sub listSchema {
    my ($name) = @_;
    return "${name}List" => {
        '$ref'     => '#/components/schemas/Iterable',
        type       => 'object',
        properties => {
            items => {
                type    => 'array',
                'items' => {
                    '$ref' => "#/components/schemas/$name"
                }
            }
        },
    };
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

