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
$YAML::XS::Boolean = "JSON::PP";
use JSON::MaybeXS ();
use Clone qw(clone);

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
              qw(create list get search replace update remove)
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
    },
    tags => {
        (
            map { $_ => "operationTags" }
              qw(create search list get replace update remove)
        )
    },

);

sub operation_generators {
    \%OPERATION_GENERATORS;
}

sub paramUnique {
    my ($p) = @_;
    return $p->{name} if exists $p->{name};
    return "$p";
}

=head2 operationParameters

operationParameters

=cut

sub operationParameters {
    my ($self, $scope, $c, $m, $a) = @_;
    my @parameters = @{$self->SUPER::operationParameters($scope, $c, $m, $a)};
    push @parameters, $self->parent_path_parameters($scope, $c, $m, $a);
    my %seen;
    use Data::Dumper;
    return [ grep { my $u = paramUnique($_); my $e = exists $seen{$u}; $seen{$u} = 1 ;!$e} @parameters ];
}

sub resoureParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    my $parameters = $self->operationParameters( $scope, $c, $m, $a );
    push @$parameters, $self->path_parameter($c->url_param_name);
    my %seen;
    return [ grep { my $u = paramUnique($_); my $e = exists $seen{$u}; $seen{$u} = 1 ;!$e} @$parameters ];
}

sub parent_path_parameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return (map { $self->path_parameter($_) } @{$c->url_parent_ids});
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

my %SQLTYPES_TO_OPENAPI = (
    BIGINT    => { type => 'integer' },
    INT       => { type => 'integer' },
    TINYINT   => { type => 'integer' },
    DOUBLE    => { type => 'number' },
    LONGBLOB  => { type => 'string' },
    TEXT      => { type => 'string' },
    VARCHAR   => { type => 'string' },
    DATETIME  => { type => 'string', format => 'date-time', example => '1970-01-01 00:00:00' },
    TIMESTAMP => { type => 'string' },
    CHAR      => { type => 'string' },
    ENUM      => { type => 'string' },
);

sub sqlTypeToOpenAPI {
    my ($type) = @_;
    if (exists $SQLTYPES_TO_OPENAPI{$type}) {
        return clone($SQLTYPES_TO_OPENAPI{$type});
    }
    return { type => 'string' };
}

=head2 dalToOpenAPISchemaProperties

Creatte OpenAPI Schema Properties from the dal object

=cut

sub dalToOpenAPISchemaProperties {
    my ($self, $dal) = @_;
    my $meta = $dal->get_meta;
    my %properties;
    while (my ($k, $v) = each %$meta) {
        $properties{$k} = sqlTypeToOpenAPI($v->{type});
        if ($v->{is_primary_key}) {
            $properties{$k}->{description} = '`PRIMARY KEY`';
        };
        if ($v->{is_nullable}) {
            $properties{$k}->{nullable} = JSON::MaybeXS::true;
        };
        if ($v->{enums_values}) {
            $properties{$k}->{enum} = [ sort { $a cmp $b } keys %{$v->{enums_values}} ];
        };
    }
    return \%properties;
}

sub dalToFields {
    my ( $self, $dal ) = @_;
    my $meta = $dal->get_meta();
    return [sort keys %$meta];
}

sub dalToSorts {
    my ( $self, $dal ) = @_;
    my $meta = $dal->get_meta();
    my $sorts = [];
    while (my ($key, $value) = each %$meta) {
        push @$sorts, $key.' ASC';
        push @$sorts, $key.' DESC';
    };
    return [sort @$sorts];
}

sub dalToPK {
    my ( $self, $dal ) = @_;
    my $meta = $dal->get_meta();
    my $pk = undef;
    while (my ($key, $value) = each %$meta) {
        if ($value->{is_primary_key}) {
            $pk = $key;
        }
    }
    return $pk;
}

sub dalToOpFields {
    my ($self, $dal) = @_;
    my $fields = $self->dalToFields($dal);
    return {
        name => 'fields',
        required => JSON::MaybeXS::true,
        in => 'path',
        required => JSON::MaybeXS::true,
        schema => {
            type => 'array',
            items => {
                type => 'string',
                enum => [@$fields],
            },
            example => [@$fields],
        },
        style => 'simple',
        explode => JSON::MaybeXS::false,
        description => 'Comma delimited list of fields to return with each item.'
    };
}

sub dalToOpSort {
    my ($self, $dal) = @_;
    my $sorts = $self->dalToSorts($dal);
    my $pk = $self->dalToPK($dal);
    return {
        name => 'sort',
        in => 'path',
        required => JSON::MaybeXS::true,
        schema => {
            type => 'array',
            items => {
                type => 'string',
                enum => [sort @$sorts],
            },
            example => [ $pk.' ASC' ],
        },
        style => 'simple',
        explode => JSON::MaybeXS::false,
        description => 'Comma delimited list of fields and respective order to sort items (`default: [ '.$pk.' ASC ]`).',
    };
}

sub dalToExampleQuery {
    my ($self, $dal) = @_;
    my $meta = $dal->get_meta();
    my @values = map { { field => $_, op => 'contains', value => 'foo' } } sort keys %$meta;
    return { op => 'and', values => [ { op => 'or', values => \@values } ] };
}

sub operationParametersLookup {
    my ($self, $scope, $c, $m, $a) = @_;

    my $opFields = $self->dalToOpFields($c->dal);
    $opFields->{in} = 'query';

    my $opSort = $self->dalToOpSort($c->dal);
    $opSort->{in} = 'query';

    return {
        list => [
            $opFields,
            $opSort,
            { "\$ref" => "#/components/parameters/limit", in => 'query' },
            { "\$ref" => "#/components/parameters/cursor", in => 'query' },
        ]
    }
}


=head2 getResponses

The OpenAPI Operation Repsonses for the get action

=cut

sub getResponses {
    my ($self, $scope, $c, $m, $a) = @_;
    return {
        '200' => {
            description => 'Request successful.',
            content => {
                "application/json" => {
                    schema => {
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
        '401' => {
            "\$ref" => "#/components/responses/Forbidden"
        },
        '404' => {
            "\$ref" => "#/components/responses/BadRequest"
        },
        '422' => {
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
            description => 'Item deleted.',
        }
    };
}

=head2 createRequestBody

The OpenAPI Operation RequestBody for the create action

=cut

sub createRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
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
    my $pk = $self->dalToPK($c->dal);
    my $fields = $self->dalToFields($c->dal);
    my $sorts = $self->dalToSorts($c->dal);
    my $query = $self->dalToExampleQuery($c->dal);
    return {
        required => JSON::MaybeXS::true,
        content => {
            "application/json" => {
                schema => {
                    allOf => [
                        {
                            "\$ref" => "#/components/schemas/Search"
                        },
                        {
                            required => [ 'fields', 'sort' ],
                            properties => {
                                cursor => {
                                    type => 'string',
                                },
                                fields => {
                                    type => 'array',
                                    items => {
                                        type => 'string',
                                        enum => [sort @$fields],
                                    },
                                },
                                limit => {
                                    type => 'integer',
                                    minimum => 1,
                                    maximum => 1000,
                                },
                                sort => {
                                    type => 'array',
                                    items => {
                                        type => 'string',
                                        enum => [sort @$sorts],
                                    },
                                }
                            }
                        },

                    ],
                },
                example => {
                    cursor => 0,
                    fields => \@$fields,
                    limit => 25,
                    sort => [ $pk.' ASC' ],
                    query => $query,
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
        '200' => {
            description => 'Request successful.',
            content => {
                "application/json" => {
                    schema => {
                        "\$ref" => "#" . $self->schemaListPath($c),
                    }
                }
            },
        },
        '401' => {
            "\$ref" => "#/components/responses/Forbidden"
        },
        '404' => {
            "\$ref" => "#/components/responses/BadRequest"
        },
        '409' => {
            "\$ref" => '#/components/responses/Duplicate'
        },
        '422' => {
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
                    "\$ref" => "#" . $self->schemaItemPath($c)
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
        '200' => {
            "\$ref" => "#/components/responses/Message"
        },
        '401' => {
            "\$ref" => "#/components/responses/Forbidden"
        },
        '404' => {
            "\$ref" => "#/components/responses/BadRequest"
        },
        '422' => {
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
                        "description" => "Items.",
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
