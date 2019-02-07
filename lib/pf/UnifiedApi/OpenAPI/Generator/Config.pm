package pf::UnifiedApi::OpenAPI::Generator::Config;

=head1 NAME

pf::UnifiedApi::OpenAPI::Generator::Config -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::OpenAPI::Generator::Config

=cut

use strict;
use warnings;
use Module::Load;
use Moo;
use pf::UnifiedApi::GenerateSpec;
use pf::constants::pfconf;

extends qw(pf::UnifiedApi::OpenAPI::Generator);

our %METHODS_WITH_ID = (
    get  => 1,
    post => 1,
);

our %OPERATION_GENERATORS = (
    requestBody => {
        create  => "createRequestBody",
        search  => sub { undef },
        replace => "replaceRequestBody",
        update  => "updateRequestBody",
    },
    responses => {
        search  => sub { undef },
        list    => "listResponses",
        get     => "getResponses",
        replace => "replaceResponses",
        update  => "updateResponses",
        remove  => "removeResponses",
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
    push @$parameters, $self->path_parameter($c->primary_key);
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

=head2 createResponses

The OpenAPI Operation Repsonses for the create action

=cut

sub createResponses {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        "400" => {
            "\$ref" => "#/components/responses/BadRequest"
        },
        "422" => {
            "\$ref" => "#/components/responses/UnprocessableEntity"
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

=head2 getresponses

the openapi operation repsonses for the get action

=cut

sub getResponses {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        "200" => {
            description => "Item",
            content => {
                "application/json" => {
                    schema => {
                        "\$ref" => "#" . $self->schemaItemPath($c),
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

=head2 generateSchemas

generate schemas for controller

=cut

sub generateSchemas {
    my ($self, $controller, $actions) = @_;
    my $list_path = $self->schemaListPath($controller);
    my $item_path = $self->schemaItemPath($controller);
    my @forms = buildForms($controller);
    return {
        $list_path => {
            description => "List",
            allOf => [
                { '$ref' => "#/components/schemas/Iterable" },
                {
                    "properties" => {
                        "items" => {
                            "items" => {
                                "\$ref" => "#$item_path",
                            },
                            "type" => "array",
                            "description" => "List",
                        },
                    },
                    "type" => "object"
                },
            ],
        },
        $item_path => pf::UnifiedApi::GenerateSpec::formsToSchema(\@forms)
    };
}

=head2 replaceResponses

The OpenAPI Operation Repsonses for the replace action

=cut

sub replaceResponses {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        "201" => {
            "\$ref" => "#/components/responses/Created"
        },
        "400" => {
            "\$ref" => "#/components/responses/BadRequest"
        },
        "422" => {
            "\$ref" => "#/components/responses/UnprocessableEntity"
        }
    };
}

=head2 updateResponses

The OpenAPI Operation Repsonses for the update action

=cut

sub updateResponses {
    my ($self, $scope, $c, $m, $a) = @_;
    return {
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
    my ($self, $scope, $c, $m, $a) = @_;
    return {
        '204' => {
            description => 'Deleted a config item'
        }
    };
}

=head2 buildForms

Build the forms for the forms

=cut

sub buildForms {
    my ($controller, $child) = @_;
    my @form_classes;
    if ( $controller->can("type_lookup") ) {
        @form_classes = values %{ $controller->type_lookup };
    } else {
        my $form_class = $controller->form_class;
        if ($form_class eq 'pfappserver::Form::Config::Pf') {
            return map { $form_class->new( section => $_ ) } keys %pf::constants::pfconf::ALLOWED_SECTIONS;
        }
        @form_classes = ( $controller->form_class );
    }

    return map { $_->new() } @form_classes;
}

=head2 createRequestBody

The OpenAPI Operation RequestBody for the create action

=cut

sub createRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->requestBody( $scope, $c, $m, $a );
}

=head2 replaceRequestBody

The OpenAPI Operation RequestBody for the replace action

=cut

sub replaceRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->requestBody( $scope, $c, $m, $a );
}

=head2 updateRequestBody

The OpenAPI Operation RequestBody for the update action

=cut

sub updateRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->requestBody( $scope, $c, $m, $a );
}

=head2 RequestBody

The generic OpenAPI Operation RequestBody for a config controller

=cut

sub requestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        content => {
            "application/json" => {
                schema => {
                    "\$ref" => "#" . $self->schemaItemPath($c),
                }
            }
        },
    };
}

=head2 generatePath

generate Path excluding search

=cut

sub generatePath {
    my ($self, $controller, $actions) = @_;
    if (@$actions == 1 && $actions->[0]{action} eq 'search') {
        return undef;
    }

    return $self->SUPER::generatePath($controller, $actions);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
