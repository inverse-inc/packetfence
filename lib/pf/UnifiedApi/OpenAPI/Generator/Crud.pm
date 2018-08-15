package pf::UnifiedApi::OpenAPI::Generator::Crud;

=head1 NAME

pf::UnifiedApi::OpenAPI::Generator::Crud -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::OpenAPI::Generator::Crud

=cut

use strict;
use warnings;
use Moo;
extends qw(pf::UnifiedApi::OpenAPI::Generator);

our %OPERATION_GENERATORS = (
    requestBody => {
        (
            map { $_ => "${_}RequestBody" }
            qw(create search replace update)
        )
    },
    responses => {
        (
            map { $_ => "${_}Responses" }
              qw(create list get search replace update remove)
        )
    },
    parameters => {
        (
            map { $_ => "${_}OperationParameters" }
              qw(create search list get replace update remove)
        )
    },
    description => {
        (
            map { $_ => "operationDescription" }
              qw(create search list get replace update remove)
        )
    },
    operationId => {
        (
            map { $_ => "operationId" }
              qw(create search list get replace update remove)
        )
    }
);

sub operation_generators {
    \%OPERATION_GENERATORS;
}

my %OPERATION_DESCRIPTIONS = (
    remove  => 'Delete an item',
    create  => 'Create an item',
    list    => 'List items',
    get     => 'Get an item',
    replace => 'Replace an item',
    update  => 'Update an item',
    remove  => 'Remove an item',
);

sub resoureParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    my $parameters = $self->operationParameters( $scope, $c, $m, $a );
    push @$parameters, $self->path_parameter($c->url_param_name), (map { $self->path_parameter($_) } sort keys %{$c->parent_primary_key_map});
    return $parameters;
}

sub createOperationParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->operationParameters( $scope, $c, $m, $a );
}

sub searchOperationParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->operationParameters( $scope, $c, $m, $a );
}

sub listOperationParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->operationParameters( $scope, $c, $m, $a );
}

sub getOperationParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->resoureParameters( $scope, $c, $m, $a );
}

sub replaceOperationParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->resoureParameters( $scope, $c, $m, $a );
}

sub updateOperationParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->resoureParameters( $scope, $c, $m, $a );
}

sub removeOperationParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->resoureParameters( $scope, $c, $m, $a );
}

sub operationDescriptionsLookup {
    return \%OPERATION_DESCRIPTIONS;
}

my %SQLTYPES_TO_OPENAPI = (
    BIGINT    => 'integer',
    INT       => 'integer',
    TINYINT   => 'integer',
    DOUBLE    => 'number',
    LONGBLOB  => 'string',
    TEXT      => 'string',
    VARCHAR   => 'string',
    DATETIME  => 'string',
    TIMESTAMP => 'string',
    CHAR      => 'string',
    ENUM      => 'string',
);

sub sqlTypeToOpenAPIType {
    my ($type) = @_;
    if (exists $SQLTYPES_TO_OPENAPI{$type}) {
        return $SQLTYPES_TO_OPENAPI{$type};
    }

    return "string";
}

=head2 dalToOpenAPISchemaProperties

Creatte OpenAPI Schema Properties from the dal object

=cut

sub dalToOpenAPISchemaProperties {
    my ($self, $dal) = @_;
    my $meta = $dal->get_meta;
    my %properties;
    while (my ($k, $v) = each %$meta) {
        $properties{$k} = {
            type => sqlTypeToOpenAPIType($v->{type}),
        };
    }
    return \%properties;
}

our %OPERATION_PARAMETERS_LOOKUP = (
    list => [
        { "\$ref" => '#/components/parameters/cursor' },
        { "\$ref" => '#/components/parameters/limit' },
        { "\$ref" => '#/components/parameters/fields' },
        { "\$ref" => '#/components/parameters/sort' },
    ],
);

sub operationParametersLookup {
    \%OPERATION_PARAMETERS_LOOKUP
}

=head2 getResponses

The OpenAPI Operation Repsonses for the get action

=cut

sub getResponses {
    my ($self, $scope, $c, $m, $a) = @_;
    return {
        "200" => {
            description => "Get item",
            content => {
                "application/json" => {
                    schema => {
                        description => "Item",
                        properties => {
                            item => {
                                "\$ref" => "#" . $self->schemaItemPath($c),
                            }
                        },
                        type => 'object',
                    }
                }
            },
        },
        "400" => {
            "\$ref" => "#/components/responses/BadRequest"
        },
        "422" => {
            "\$ref" => "#/components/responses/UnprocessableEntity"
        }
    };
}

=head2 removeResponses

The OpenAPI Operation Repsonses for the remove action

=cut

sub removeResponses {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        '204' => {
            description => 'Item deleted',
        }
    };
}

=head2 createRequestBody

The OpenAPI Operation RequestBody for the create action

=cut

sub createRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        description => "Create item",
        "content" => {
            "application/json" => {
                "schema" => {
                    "\$ref" => "#" . $self->schemaItemPath($c)
                }
            }
        }
    };
}

=head2 createResponses

The OpenAPI Operation Repsonses for the create action

=cut

sub createResponses {
    my ($self, $scope, $c, $m, $a) = @_;
    return {
        '201' => {
            "\$ref" => '#/components/responses/Created'
        },
        '400' => {
            "\$ref" => '#/components/responses/BadRequest'
        },
        '409' => {
            "\$ref" => '#/components/responses/Duplicate'
        },
        '422' => {
            "\$ref" => '#/components/responses/UnprocessableEntity'
        },
    };
}

=head2 listRequestBody

The OpenAPI Operation RequestBody for the list action

=cut

sub listRequestBody {
    my ($self, $scope, $c, $m, $a) = @_;
    return undef;
}

=head2 searchRequestBody

The OpenAPI Operation RequestBody for the search action

=cut

sub searchRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        description => "Search for items",
        content => {
            "application/json" => {
                schema => {
                    "\$ref" => "#/components/schemas/Search",
                }
            }
        }
    };
}

=head2 listResponses

The OpenAPI Operation Repsonses for the list action

=cut

sub listResponses {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        "200" => {
            description => "List",
            content => {
                "application/json" => {
                    schema => {
                        "\$ref" => "#" . $self->schemaListPath($c),
                    }
                }
            },
        },
        "400" => {
            "\$ref" => "#/components/responses/BadRequest"
        },
        "422" => {
            "\$ref" => "#/components/responses/UnprocessableEntity"
        }
    };
}

=head2 searchResponses

The OpenAPI Operation Repsonses for the search action

=cut

sub searchResponses {
    my ($self, $scope, $c, $m, $a) = @_;
    return $self->listResponses($scope, $c, $m, $a);
}

=head2 replaceRequestBody

The OpenAPI Operation RequestBody for the replace action

=cut

sub replaceRequestBody {
    my ($self, $scope, $c, $m, $a) = @_;
    return $self->updateRequestBody($scope, $c, $m, $a);;
}

=head2 replaceResponses

The OpenAPI Operation Repsonses for the replace action

=cut

sub replaceResponses {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->updateResponses($scope, $c, $m, $a);;
}

=head2 updateRequestBody

The OpenAPI Operation RequestBody for the update action

=cut

sub updateRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        "content" => {
            "application/json" => {
                "schema" => {
                    "\$ref" => "#" . $self->schemaItemPath($c),
                }
            }
        },
    };
}

=head2 updateResponses

The OpenAPI Operation Repsonses for the update action

=cut

sub updateResponses {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        "200" => {
            "\$ref" => "#/components/responses/Message"
        },
        "400" => {
            "\$ref" => "#/components/responses/BadRequest"
        },
        "422" => {
            "\$ref" => "#/components/responses/UnprocessableEntity"
        }
    };
}

=head2 generateSchemas

generate schemas for controller

=cut

sub generateSchemas {
    my ($self, $controller, $actions) = @_;
    my (%schemas, $schema);
    if (defined ($schema = $self->generateListSchema($controller, $actions))) {
        $schemas{$self->schemaListPath($controller)} = $schema;
    }

    if (defined ($schema = $self->generateItemSchema($controller, $actions))) {
        $schemas{$self->schemaItemPath($controller)} = $schema;
    }

    return \%schemas;
}

=head2 generateItemSchema

generate Item Schema

=cut

sub generateItemSchema {
    my ($self, $controller, $actions) = @_;
    my $required = $self->itemRequired($controller, $actions);
    return {
        properties => $self->itemProperies($controller, $actions),
        (
            @$required != 0 ? ( required => $required) : (),
        ),
        type => 'object'
    };
}

=head2 itemProperies

item Properies

=cut

sub itemProperies {
    my ($self, $controller, $actions) = @_;
    return  $self->dalToOpenAPISchemaProperties($controller->dal);
}

=head2 itemRequired

item Required

=cut

sub itemRequired {
    my ($self, $controller, $actions) = @_;
    my $meta = $controller->dal->get_meta;
    my @required;
    while (my ($k, $v) = each %$meta) {
        if ($self->isFieldRequired($k, $v)) {
            push @required, $k;
        }
    }
    return \@required;
}

=head2 isFieldRequired

is field required

=cut

sub isFieldRequired {
    my ($self, $field, $meta) = @_;
    return 0;
}

=head2 generateListSchema

generate list schema

=cut

sub generateListSchema {
    my ($self, $controller, $actions) = @_;
    return {
        allOf => [
            { '$ref' => "#/components/schemas/Iterable" },
            {
                "properties" => {
                    "items" => {
                        "items" => {
                            "\$ref" => "#" . $self->schemaItemPath($controller),
                        },
                        "type" => "array",
                        "description" => "Items",
                    }
                },
                "type" => "object"
            },
        ],
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
