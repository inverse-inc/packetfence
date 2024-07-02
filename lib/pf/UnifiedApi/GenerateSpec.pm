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
    Port       => 'integer',
    Integer    => 'integer',
    IntRange   => 'integer',
    PathUpload => 'file',
);
use Lingua::EN::Inflexion qw(noun);

sub formsToSchema {
    my ($item_path, $forms) = @_;
    if (@$forms == 1) {
        return objectSchema(@$forms);
    }

    return subTypesSchema($item_path, @$forms);
}

sub formsToMetaSchemas {
    my ($item_path, $forms) = @_;
    my $meta_path = $item_path . 'Meta';

    if (@$forms == 1) {
        return {
            $meta_path => {
                type => 'object',
                properties => {
                    meta => {
                        type => 'object',
                        properties => formHandlerMetaProperties(@$forms)
                    }
                }
            }
        };
    }

    my %paths;
    my $oneOf = [];
    my %mapping;
    while (my ($k, $form) = each @$forms) {
        my $found = 0;
        for my $field (grep { isSubTypeField($_) } $form->fields) {
            $found = 1;
            my $subTypeMetaPath = subTypePath($meta_path, $field->value);
            $mapping{$field->value} = '#'  . $subTypeMetaPath;
            push @$oneOf, { '$ref' => '#'  . $subTypeMetaPath };
            $paths{$subTypeMetaPath} = {
                type => 'object',
                properties => {
                    meta => {
                        type => 'object',
                        properties => formHandlerMetaProperties($form)
                    }
                },
            };
        }
        if (!$found) {
            $paths{$meta_path} = {
                type => 'object',
                properties => {
                    meta => {
                        type => 'object',
                        properties => formHandlerMetaProperties($form)
                    }
                }
            };
        }
    }
    $paths{$item_path} = {
        discriminator => {
            mapping => \%mapping,
            propertyName => 'type'
        },
        oneOf => [@$oneOf]
    };
    return \%paths;
}

sub formsToSubTypeSchemas {
    my ($item_path, $forms) = @_;
    my $schemas = {};
    if (@$forms > 1) {
        while (my ($k, $form) = each @$forms) {
            for my $field (grep { isSubTypeField($_) } $form->fields) {
                my $subTypePath = subTypePath($item_path, $field->value);
                $schemas->{$subTypePath} = objectSchema($form, 1);
            };
        };
    };
    return $schemas;
}

sub subTypePath {
    my ($item_path, $type) = @_;
    $type = join('', map { ucfirst(lc $_) } split(/[:_]+/, $type));
    return $item_path . 'SubType' . $type;
}

sub objectSchema {
    my ($form, $is_subtype) = @_;
    my $required = formHandlerRequiredProperties($form);
    return {
        type       => 'object',
        properties => formHandlerProperties($form, $is_subtype),
        (
            @$required != 0 ? (required => $required) : ()
        ),
    }
}

sub subTypesSchema {
    my ($item_path, @forms) = @_;
    my %mapping;
    while (my ($k, $form) = each @forms) {
        for my $field (grep { isSubTypeField($_) } $form->fields) {
            my $subTypePath = subTypePath($item_path, $field->value);
            $mapping{$field->value} = '#' . $subTypePath;
        };
    };
    return {
        description => 'Choose one of the request bodies by discriminator (`type`). ',
        oneOf => [
            sort { $a->{'$ref'} cmp $b->{'$ref'} } map { subTypeSchemaRef($item_path, $_, 1) } @forms
        ],
        discriminator => {
            propertyName => 'type',
            mapping => \%mapping
        }
    }
}

sub subTypeSchemaRef {
    my ($item_path, $form) = @_;
    for my $field (grep { isSubTypeField($_) } $form->fields) {
        my $subTypePath = subTypePath($item_path, $field->value);
        return {
            '$ref' => '#' . $subTypePath
        };
    };
    return;
}

sub objectSchemaMapping {
    my (@forms) = @_;
    my %mapping;
    while (my ($k, $form) = each @forms) {
        for my $field (grep { isAllowedField($_) } $form->fields) {
            if ($field->name eq 'type' && $field->value) {
                $mapping{$field->value} = objectSchema($form, 1);
            }
        }
    }
    return \%mapping;
}

sub formHandlerRequiredProperties {
    my ($form) = @_;
    return [map { $_->name } grep { isRequiredField($_) } $form->fields];
}

sub formHandlerProperties {
    my ($form, $is_subtype) = @_;
    my %properties;
    for my $field (grep { isAllowedField($_) } $form->fields) {
        my $name = $field->name;
        $properties{$name} = fieldProperties($field);
        if ($is_subtype && $field->name eq 'type' && $field->value) {
            $properties{$name}->{default} = $field->value;
            $properties{$name}->{description} = 'Discriminator `' . $field->value . '`';
        }
    }
    return \%properties;
}

sub FormFieldsToUuid {
    my ($form) = @_;
    my @fields;
    for my $field (grep { isAllowedField($_) } $form->fields) {
        my $name = $field->name;
        push @fields, $name;
    }
    my @sorted = sort @fields;
    return join(',', @sorted);
}

sub formHandlerMetaProperties {
    my ($form) = @_;
    my %properties;
    for my $field (grep { isAllowedField($_) } $form->fields) {
        my $name = $field->name;
        $properties{$name} = {
            '$ref' => "#/components/schemas/Meta"
        };
    }

    return \%properties;
}

sub fieldProperties {
    my ($field, $not_array) = @_;
    my %props = (
        type => fieldType($field, $not_array),
        description => fieldDescription($field)
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
    if ($field->isa('HTML::FormHandler::Field::Repeatable')) {
        $field->init_state;
        my $element = $field->clone_element(noun($field->name)->singular);
        return fieldProperties($element);
    }

    return fieldProperties($field, 1);
}

sub fieldType {
    my ($field, $not_array) = @_;
    if (isArrayType($field, $not_array)) {
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
    my ($field, $not_array) = @_;
    return $field->isa('HTML::FormHandler::Field::Repeatable') ||
        ($field->isa('HTML::FormHandler::Field::Select') && $field->multiple && !$not_array );
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
    return {
        '$ref'     => '#/components/schemas/Iterable',
        type       => 'object',
        properties => {
            items => {
                type    => 'array',
                items => {
                    '$ref' => "#/components/schemas/$name"
                },
                description => "List",
            }
        },
    };
}

sub isAllowedField {
    my ($field) = @_;
    return $field->is_active && !$field->get_tag('exclude_from_openapi');
}

sub isRequiredField {
    my ($field) = @_;
    return isAllowedField($field) && $field->required;
}

sub isSubTypeField {
    my ($field) = @_;
    return isAllowedField($field) && $field->value && ($field->get_tag('isSubType') || $field->name eq 'type');
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
