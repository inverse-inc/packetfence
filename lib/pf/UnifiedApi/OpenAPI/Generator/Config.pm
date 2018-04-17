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
            map { $_ => "operationParameters" }
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

sub operationDescriptionsLookup {
    return \%OPERATION_DESCRIPTIONS;
}

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

sub listResponses {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        "200" => {
            content => {
                "application/json" => {
                    schema => {
                        "\$ref" => "#" . $self->schema_list_path($c),
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

sub getResponses {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        "200" => {
            content => {
                "application/json" => {
                    schema => {
                        "\$ref" => "#" . $self->schema_item_path($c),
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

sub generate_schemas {
    my ($self, $controller, $actions) = @_;
    my $list_path = $self->schema_list_path($controller);
    my $item_path = $self->schema_item_path($controller);
    my @forms = buildForms($controller);
    return {
        $list_path => {
            allOf => [
                { '$ref' => "#/components/schemas/Iterable" },
                {
                    "properties" => {
                        "items" => {
                            "items" => {
                                "\$ref" => "#$item_path",
                            },
                            "type" => "array"
                        }
                    },
                    "type" => "object"
                },
            ],
        },
        $item_path => pf::UnifiedApi::GenerateSpec::formsToSchema(\@forms)
    };
}

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

sub removeResponses {
    my ($self, $scope, $c, $m, $a) = @_;
    return {
        '204' => {
            description => 'Deleted a config item'
        }
    };
}

sub buildForms {
    my ($controller, $child) = @_;
    my @form_classes;
    if ( $controller->can("type_lookup") ) {
        @form_classes = values %{ $controller->type_lookup };
    }
    else {
        my $form_class = $controller->form_class;
        return if $form_class eq 'pfappserver::Form::Config::Pf';
        @form_classes = ( $controller->form_class );
    }

    return map { $_->new() } @form_classes;
}

sub operationId {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $a->{operationId};
}

sub createRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->requestBody( $scope, $c, $m, $a );
}

sub replaceRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->requestBody( $scope, $c, $m, $a );
}

sub updateRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->requestBody( $scope, $c, $m, $a );
}

sub requestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        content => {
            "application/json" => {
                schema => {
                    "\$ref" => "#" . $self->schema_item_path($c),
                }
            }
        },
    };
}

=head2 generate_path

generate_path

=cut

sub generate_path {
    my ($self, $controller, $actions) = @_;
    if (@$actions == 1 && $actions->[0]{action} eq 'search') {
        return undef;
    }

    return $self->SUPER::generate_path($controller, $actions);
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
