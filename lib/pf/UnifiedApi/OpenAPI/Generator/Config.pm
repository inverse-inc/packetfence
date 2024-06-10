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
use JSON::MaybeXS;

extends qw(pf::UnifiedApi::OpenAPI::Generator);

our %METHODS_WITH_ID = (
    get  => 1,
    post => 1,
);

our %OPERATION_GENERATORS = (
    requestBody => {
        create  => "createRequestBody",
        search  => "searchRequestBody",
        replace => "replaceRequestBody",
        update  => "updateRequestBody",
        bulk_update => "bulkUpdateRequestBody",
        bulk_delete => "bulkDeleteRequestBody",
        bulk_import => "bulkImportRequestBody",
    },
    responses => {
        create  => "createResponses",
        search  => "searchResponses",
        list    => "listResponses",
        options => "metaResponses",
        bulk_update => "getResponses",
        bulk_delete => "getResponses",
        bulk_import => "getResponses",
        sort_items => "getResponses",
        get     => "getResponses",
        replace => "replaceResponses",
        update  => "updateResponses",
        remove  => "removeResponses",
        resource_options => "metaResponses",
    },
    parameters => {
        create  => "operationParameters",
        search  => "operationParameters",
        list    => "operationParameters",
        options => "operationParameters",
        bulk_update => "operationParameters",
        bulk_delete => "operationParameters",
        bulk_import => "operationParameters",
        sort_items => "operationParameters",
        get     => "resourceParameters",
        replace => "resourceParameters",
        update  => "resourceParameters",
        remove  => "resourceParameters",
        resource_options => "resourceParameters",
    },
    description => {
        (
            map { $_ => "operationDescription" }
              qw(create search list bulk_update bulk_delete bulk_import sort_items options get replace update remove resource_options)
        )
    },
    operationId => {
        (
            map { $_ => "operationId" }
              qw(create search list bulk_update bulk_delete bulk_import sort_items options get replace update remove resource_options)
        )
    },
    tags => {
        (
            map { $_ => "operationTags" }
              qw(create search list bulk_update bulk_delete bulk_import sort_items options get replace update remove resource_options)
        )
    }
);

sub operation_generators {
    \%OPERATION_GENERATORS;
}

sub resourceParameters {
    my ( $self, $scope, $c, $m, $a ) = @_;
    my $parameters = $self->operationParameters( $scope, $c, $m, $a );
    my $parameter = $self->path_parameter($c->primary_key);
    $parameter->{required} = JSON::MaybeXS::true;
    $parameter->{description} = '`PRIMARY KEY`';
    if (ref($c) =~ /Config::.*(?<!Subtype)$/ && $c->config_store->importConfigFile) {
        my $ini = Config::IniFiles->new(
            -file => $c->config_store->importConfigFile,
            -allowempty => 1,
        );
        my $enum = [];
        for my $section ($ini->Sections) {
            push @$enum, $section;
        };
        if (@$enum) {
            $parameter->{schema}->{enum} = [sort @$enum];
        }
    }
    push @$parameters, $parameter;
    return $parameters;
}

=head2 createResponses

The OpenAPI Operation Responses for the create action

=cut

sub createResponses {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        "201" => {
            "\$ref" => "#/components/responses/Created"
        },
        "400" => {
            "\$ref" => "#/components/responses/BadRequest"
        },
        "401" => {
            "\$ref" => "#/components/responses/Forbidden"
        },
        "409" => {
            "\$ref" => "#/components/responses/Duplicate"
        },
        "422" => {
            "\$ref" => "#/components/responses/UnprocessableEntity"
        }
    };
}

=head2 listResponses

The OpenAPI Operation Responses for the list action

=cut

sub listResponses {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        "200" => {
            description => 'Request successful. Response contains a list of resources.',
            content => {
                "application/json" => {
                    schema => {
                        "\$ref" => "#" . $self->schemaListPath($c),
                    }
                }
            },
        },
        "401" => {
            "\$ref" => "#/components/responses/Forbidden"
        },
    };
}

=head2 searchResponses

The OpenAPI Operation Responses for the search action

=cut

sub searchResponses {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->listResponses($scope, $c, $m, $a);
}

=head2 metaResponses

The OpenAPI Operation Responses for the meta action

=cut

sub metaResponses {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        "200" => {
            description => 'Request successful. Response contains meta for a resource.',
            content => {
                "application/json" => {
                    schema => {
                        "\$ref" => "#" . $self->schemaMetaPath($c),
                    }
                }
            },
        },
        "401" => {
            "\$ref" => "#/components/responses/Forbidden"
        },
        "404" => {
            "\$ref" => "#/components/responses/NotFound"
        },
    };
}

=head2 getresponses

the openapi operation repsonses for the get action

=cut

sub getResponses {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        "200" => {
            description => 'Request successful. Response contains a specific resource.',
            content => {
                "application/json" => {
                    schema => {
                        "\$ref" => "#" . $self->schemaItemWrappedPath($c),
                    }
                }
            },
        },
        "401" => {
            "\$ref" => "#/components/responses/Forbidden"
        },
        "404" => {
            "\$ref" => "#/components/responses/NotFound"
        },
    };
}

=head2 replaceResponses

The OpenAPI Operation Responses for the replace action

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
        "401" => {
            "\$ref" => "#/components/responses/Forbidden"
        },
        "404" => {
            "\$ref" => "#/components/responses/NotFound"
        },
        "422" => {
            "\$ref" => "#/components/responses/UnprocessableEntity"
        }
    };
}

=head2 updateResponses

The OpenAPI Operation Responses for the update action

=cut

sub updateResponses {
    my ($self, $scope, $c, $m, $a) = @_;
    return {
        "201" => {
            "\$ref" => "#/components/responses/Updated"
        },
        "400" => {
            "\$ref" => "#/components/responses/BadRequest"
        },
        "401" => {
            "\$ref" => "#/components/responses/Forbidden"
        },
        "404" => {
            "\$ref" => "#/components/responses/NotFound"
        },
        "422" => {
            "\$ref" => "#/components/responses/UnprocessableEntity"
        }
    };
}

=head2 removeResponses

The OpenAPI Operation Responses for the remove action

=cut

sub removeResponses {
    my ($self, $scope, $c, $m, $a) = @_;
    return {
        "200" => {
            "\$ref" => "#/components/responses/Deleted"
        },
        "401" => {
            "\$ref" => "#/components/responses/Forbidden"
        },
        "404" => {
            "\$ref" => "#/components/responses/NotFound"
        },
    };
}

=head2 generateSchemas

generate schemas for controller

=cut

sub generateSchemas {
    my ($self, $controller, $actions) = @_;
    my $list_path = $self->schemaListPath($controller);
    my $item_path = $self->schemaItemPath($controller);
    my $item_wrapped_path = $self->schemaItemWrappedPath($controller);
    my @forms = buildForms($controller);
    return {
        $list_path => {
            allOf => [
                { '$ref' => "#/components/schemas/Iterable" },
                {
                    properties => {
                        items => {
                            items => {
                                "\$ref" => "#$item_path",
                            },
                            type => "array",
                        },
                    },
                    type => "object"
                },
            ],
        },
        $item_path => pf::UnifiedApi::GenerateSpec::formsToSchema($item_path, \@forms),
        $item_wrapped_path => {
            type => "object",
            properties => {
                item => {
                    "\$ref" => "#$item_path"
                },
                status => {
                    type => "integer"
                }
            }
        },
        %{pf::UnifiedApi::GenerateSpec::formsToMetaSchemas($item_path, \@forms)},
        %{pf::UnifiedApi::GenerateSpec::formsToSubTypeSchemas($item_path, \@forms)}
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
        if (!defined $form_class) {
            return;
        }

        if ($form_class eq 'pfappserver::Form::Config::Pf') {
            return map { $form_class->new( section => $_ ) } keys %pf::constants::pfconf::ALLOWED_SECTIONS;
        }

        @form_classes = ( $form_class );
    }

    return map { $_->new() } @form_classes;
}

=head2 searchRequestBody

The OpenAPI Operation RequestBody for the search action

=cut

sub searchRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        description => "Search for items.",
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
                                    },
                                }
                            }
                        },

                    ],
                },
                example => {
                    cursor => 0,
                    limit => 25,
                }
            }
        }
    };
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

=head2 requestBody

The generic OpenAPI Operation requestBody for a config controller

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


=head2 bulkDeleteRequestBody

The OpenAPI Operation RequestBody for the bulk_delete action

=cut

sub bulkDeleteRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        content => {
            "application/json" => {
                schema => {
                    type => 'object',
                    properties => {
                        items => {
                            type => 'array',
                            items => {
                                type => 'string',
                                description => '`PRIMARY KEY`'
                            }
                        }
                    }
                }
            }
        },
    };
}

=head2 bulkUpdateRequestBody

The OpenAPI Operation RequestBody for the bulk_update action

=cut

sub bulkUpdateRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->bulkRequestBody( $scope, $c, $m, $a );
}

=head2 bulkImportRequestBody

The OpenAPI Operation RequestBody for the bulk_import action

=cut

sub bulkImportRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return $self->bulkRequestBody( $scope, $c, $m, $a );
}

=head2 bulkRequestBody

The generic OpenAPI Operation bulk requestBody for a config controller

=cut

sub bulkRequestBody {
    my ( $self, $scope, $c, $m, $a ) = @_;
    return {
        content => {
            "application/json" => {
                schema => {
                    type => 'object',
                    properties => {
                        items => {
                            type => 'array',
                            items => {
                                "\$ref" => "#" . $self->schemaItemPath($c),
                            }
                        }
                    }
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
    # if (@$actions == 1 && $actions->[0]{action} eq 'search') {
    #     return undef;
    # }

    return $self->SUPER::generatePath($controller, $actions);
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
