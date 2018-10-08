#!/usr/bin/perl

=head1 NAME

PathGenerator

=cut

=head1 DESCRIPTION

unit test for PathGenerator

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';
use pf::UnifiedApi::OpenAPI::Generator::Crud;
use pf::UnifiedApi::Controller::DhcpOption82s;
use pf::UnifiedApi;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 8;
#This test will running last
use Test::NoWarnings;


my $app = pf::UnifiedApi->new;

my $generator = pf::UnifiedApi::OpenAPI::Generator::Crud->new;
my $controller = pf::UnifiedApi::Controller::DhcpOption82s->new;

my @actions = (
            {
                'operationId' => 'api.v1.DhcpOption82s.create',
                'name'        => 'api.v1.DhcpOption82s.create',
                'path'        => '/dhcp_option82s',
                'children'    => [],
                'depth'       => 2,
                'paths'       => [ '/dhcp_option82s' ],
                'controller'  => 'DhcpOption82s',
                'path_type'   => 'collection',
                'action'      => 'create',
                'path_part'   => '',
                'methods'     => [ 'POST' ],
                'full_path'   => '/api/v1/dhcp_option82s'
            },
            {
                'operationId' => 'api.v1.DhcpOption82s.list',
                'name'        => 'api.v1.DhcpOption82s.list',
                'path'        => '/dhcp_option82s',
                'children'    => [],
                'depth'       => 2,
                'paths'       => [ '/dhcp_option82s' ],
                'controller'  => 'DhcpOption82s',
                'path_type'   => 'collection',
                'action'      => 'list',
                'path_part'   => '',
                'methods'     => [ 'GET' ],
                'full_path'   => '/api/v1/dhcp_option82s'
            },
            {
                'operationId' => 'api.v1.DhcpOption82s.update',
                'name'        => 'api.v1.DhcpOption82s.update',
                'path'        => '/dhcp_option82/{dhcp_option82_id}',
                'children'    => [],
                'depth'       => 2,
                'paths'       => [ '/dhcp_option82/{dhcp_option82_id}' ],
                'controller'  => 'DhcpOption82s',
                'path_type'   => 'resource',
                'action'      => 'update',
                'path_part'   => '',
                'methods'     => [ 'PATCH' ],
                'full_path'   => '/api/v1/dhcp_option82/{dhcp_option82_id}'
            },
            {
                'operationId' => 'api.v1.DhcpOption82s.replace',
                'name'        => 'api.v1.DhcpOption82s.replace',
                'path'        => '/dhcp_option82/{dhcp_option82_id}',
                'children'    => [],
                'depth'       => 2,
                'paths'       => [ '/dhcp_option82/{dhcp_option82_id}' ],
                'controller'  => 'DhcpOption82s',
                'path_type'   => 'resource',
                'action'      => 'replace',
                'path_part'   => '',
                'methods'     => [ 'PUT' ],
                'full_path'   => '/api/v1/dhcp_option82/{dhcp_option82_id}'
            },
);

{

    my $controller = pf::UnifiedApi::Controller::DhcpOption82s->new(app => $app);
    my $generator = pf::UnifiedApi::OpenAPI::Generator::Crud->new;
    my %operators = $generator->operations($controller,
        [
            {
                'operationId' => 'api.v1.DhcpOption82s.get',
                'name'        => 'api.v1.DhcpOption82s.get',
                'path'        => '/dhcp_option82/{dhcp_option82_id}',
                'children'    => [],
                'depth'       => 2,
                'paths'       => [ '/dhcp_option82/{dhcp_option82_id}' ],
                'controller'  => 'DhcpOption82s',
                'path_type'   => 'resource',
                'action'      => 'get',
                'path_part'   => '',
                'methods'     => [ 'GET' ],
                'full_path'   => '/api/v1/dhcp_option82/{dhcp_option82_id}'
            }
        ]
    );
#    use Data::Dumper;print Dumper(\@operators);
    is_deeply(
        \%operators,
        {
            get => {
                'parameters' => [
                    {
                        in     => 'path',
                        name   => 'dhcp_option82_id',
                        schema => {
                            type => 'string'
                        }
                    }
                ],
                'operationId' => 'api.v1.DhcpOption82s.get',
                'responses'   => {
                    "200" => {
                        description => 'Get item',
                        content => {
                            "application/json" => {
                                schema => {
                                    'description' => 'Item',
                                    "properties" => {
                                        "item" => {
                                            "\$ref" => "#/components/schemas/DhcpOption82",
                                        }
                                    },
                                    "type" => "object"
                                }
                            }
                        },
                    },
                    "400" => {
                        "\$ref" => "#/components/responses/BadRequest",
                    },
                    "422" => {
                        "\$ref" => "#/components/responses/UnprocessableEntity"
                    }
                },
                'description' => 'Get an item'
            },
        },
        "Crud resource GET"
    );
}

{

    my $controller = pf::UnifiedApi::Controller::DhcpOption82s->new(app => $app);
    my $generator = pf::UnifiedApi::OpenAPI::Generator::Crud->new;
    my @operators = $generator->operations(
        $controller,
        [
            {
                'operationId' => 'api.v1.DhcpOption82s.remove',
                'name'        => 'api.v1.DhcpOption82s.remove',
                'path'        => '/dhcp_option82/{dhcp_option82_id}',
                'children'    => [],
                'depth'       => 2,
                'paths'       => [ '/dhcp_option82/{dhcp_option82_id}' ],
                'controller'  => 'DhcpOption82s',
                'path_type'   => 'resource',
                'action'      => 'remove',
                'path_part'   => '',
                'methods'     => [ 'DELETE' ],
                'full_path'   => '/api/v1/dhcp_option82/{dhcp_option82_id}'
            },
        ]
    );
#    use Data::Dumper;print Dumper(\@operators);
    is_deeply(
        \@operators,
        [
            delete => {
                'parameters' => [
                    {
                        in     => 'path',
                        name   => 'dhcp_option82_id',
                        schema => {
                            type => 'string'
                        }
                    }
                ],
                'operationId' => 'api.v1.DhcpOption82s.remove',
                'description' => 'Remove an item',
                responses => {
                    '204' => {
                        description => 'Item deleted'
                    }
                }
              },
        ],
        "Crud resource DELETE"
    );
}

{

    my $controller = pf::UnifiedApi::Controller::DhcpOption82s->new(app => $app);
    my $generator = pf::UnifiedApi::OpenAPI::Generator::Crud->new;
    my %operators = $generator->operations(
        $controller,
        [
            {
                'operationId' => 'api.v1.DhcpOption82s.update',
                'name'        => 'api.v1.DhcpOption82s.update',
                'path'        => '/dhcp_option82/{dhcp_option82_id}',
                'children'    => [],
                'depth'       => 2,
                'paths'       => [ '/dhcp_option82/{dhcp_option82_id}' ],
                'controller'  => 'DhcpOption82s',
                'path_type'   => 'resource',
                'action'      => 'update',
                'path_part'   => '',
                'methods'     => [ 'PATCH' ],
                'full_path'   => '/api/v1/dhcp_option82/{dhcp_option82_id}'
            },
        ]
    );
    is_deeply(
        \%operators,
        {
            patch => {
                'parameters' => [
                    {
                        in     => 'path',
                        name   => 'dhcp_option82_id',
                        schema => {
                            type => 'string'
                        }
                    }
                ],
                'operationId' => 'api.v1.DhcpOption82s.update',
                'description' => 'Update an item',
                "requestBody" => {
                   "content" => {
                      "application/json" => {
                         "schema" => {
                            "\$ref" => "#/components/schemas/DhcpOption82"
                         }
                      }
                   },
                },
                "responses" => {
                   "200" => {
                      "\$ref" => "#/components/responses/Message"
                   },
                   "400" => {
                      "\$ref" => "#/components/responses/BadRequest"
                   },
                   "422" => {
                      "\$ref" => "#/components/responses/UnprocessableEntity"
                   }
                },
            }
        },
        "Crud resource PATCH"
    );
}

{

    my $controller = pf::UnifiedApi::Controller::DhcpOption82s->new(app => $app);
    my $generator = pf::UnifiedApi::OpenAPI::Generator::Crud->new;
    my %operators = $generator->operations(
        $controller,
        [
            {
                'operationId' => 'api.v1.DhcpOption82s.replace',
                'name'        => 'api.v1.DhcpOption82s.replace',
                'path'        => '/dhcp_option82/{dhcp_option82_id}',
                'children'    => [],
                'depth'       => 2,
                'paths'       => [ '/dhcp_option82/{dhcp_option82_id}' ],
                'controller'  => 'DhcpOption82s',
                'path_type'   => 'resource',
                'action'      => 'replace',
                'path_part'   => '',
                'methods'     => [ 'PUT' ],
                'full_path'   => '/api/v1/dhcp_option82/{dhcp_option82_id}'
            },
        ]
    );
    is_deeply(
        \%operators,
        {
            put => {
                'parameters' => [
                    {
                        in     => 'path',
                        name   => 'dhcp_option82_id',
                        schema => {
                            type => 'string'
                        }
                    }
                ],
                'operationId' => 'api.v1.DhcpOption82s.replace',
                'description' => 'Replace an item',
                "requestBody" => {
                   "content" => {
                      "application/json" => {
                         "schema" => {
                            "\$ref" => "#/components/schemas/DhcpOption82"
                         }
                      }
                   },
                },
                "responses" => {
                   "200" => {
                      "\$ref" => "#/components/responses/Message"
                   },
                   "400" => {
                      "\$ref" => "#/components/responses/BadRequest"
                   },
                   "422" => {
                      "\$ref" => "#/components/responses/UnprocessableEntity"
                   }
                },
            }
        },
        "Crud resource PUT"
    );
}

{

    my $controller = pf::UnifiedApi::Controller::DhcpOption82s->new(app => $app);
    my $generator = pf::UnifiedApi::OpenAPI::Generator::Crud->new;
    my %operators = $generator->operations(
        $controller,
        [
           {
                'operationId' => 'api.v1.DhcpOption82s.search',
                'name'        => 'api.v1.DhcpOption82s.search',
                'path'        => '/dhcp_option82s/search',
                'children'    => [],
                'depth'       => 3,
                'paths'       => [ '/dhcp_option82s', '/search' ],
                'controller'  => 'DhcpOption82s',
                'path_type'   => 'collection',
                'action'      => 'search',
                'path_part'   => '',
                'methods'     => [ 'POST' ],
                'full_path'   => '/api/v1/dhcp_option82s/search'
            },
        ]
    );
#    use Data::Dumper;print Dumper(\@operators);
    is_deeply(
        \%operators,
        {
            post => {
                'parameters'  => [ ],
                'operationId' => 'api.v1.DhcpOption82s.search',
                'requestBody' => {
                    description => 'Search for items',
                    content => {
                        "application/json" => {
                            schema => {
                                "\$ref" => "#/components/schemas/Search",
                            }
                        }
                    }
                },
                'responses'  => {
                    "200" => {
                        description => 'List',
                        content => {
                            "application/json" => {
                                schema => {
                                    "\$ref" => "#/components/schemas/DhcpOption82sList"
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
                }
            },
        },
        "Crud collection SEARCH"
    );
}

{

    my $controller = pf::UnifiedApi::Controller::DhcpOption82s->new(app => $app);
    my $generator = pf::UnifiedApi::OpenAPI::Generator::Crud->new;
    my %operators = $generator->operations(
        $controller,
        [
            {
                'operationId' => 'api.v1.DhcpOption82s.create',
                'name'        => 'api.v1.DhcpOption82s.create',
                'path'        => '/dhcp_option82s',
                'children'    => [],
                'depth'       => 2,
                'paths'       => [ '/dhcp_option82s' ],
                'controller'  => 'DhcpOption82s',
                'path_type'   => 'collection',
                'action'      => 'create',
                'path_part'   => '',
                'methods'     => [ 'POST' ],
                'full_path'   => '/api/v1/dhcp_option82s'
            },
            {
                'operationId' => 'api.v1.DhcpOption82s.list',
                'name'        => 'api.v1.DhcpOption82s.list',
                'path'        => '/dhcp_option82s',
                'children'    => [],
                'depth'       => 2,
                'paths'       => [ '/dhcp_option82s' ],
                'controller'  => 'DhcpOption82s',
                'path_type'   => 'collection',
                'action'      => 'list',
                'path_part'   => '',
                'methods'     => [ 'GET' ],
                'full_path'   => '/api/v1/dhcp_option82s'
            },
        ]
    );
#    use Data::Dumper;print Dumper(\@operators);
    is_deeply(
        \%operators,
        {
            post => {
                'parameters'  => [],
                'operationId' => 'api.v1.DhcpOption82s.create',
                'description' => 'Create an item',
                requestBody => {
                    description => 'Create item',
                    content => {
                        "application/json" => {
                            schema => {
                                "\$ref" => "#/components/schemas/DhcpOption82"
                            }
                        }
                    }
                },
                responses => {
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
                  },
            },
            get => {
                'parameters'  => [
                    { "\$ref" => '#/components/parameters/cursor' },
                    { "\$ref" => '#/components/parameters/limit' },
                    { "\$ref" => '#/components/parameters/fields' },
                    { "\$ref" => '#/components/parameters/sort' },
                ],
                'operationId' => 'api.v1.DhcpOption82s.list',
                'description' => 'List items',
                'responses'  => {
                    "200" => {
                        description => 'List',
                        content => {
                            "application/json" => {
                                schema => {
                                    "\$ref" => "#/components/schemas/DhcpOption82sList"
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
                },
            },
        },
        "Crud collection POST/GET"
    );
}

{
    is_deeply(
        $generator->generateSchemas(
            $controller,
            [
                {
                    'operationId' => 'api.v1.DhcpOption82s.create',
                    'name'        => 'api.v1.DhcpOption82s.create',
                    'path'        => '/dhcp_option82s',
                    'children'    => [],
                    'depth'       => 2,
                    'paths'       => [ '/dhcp_option82s' ],
                    'controller'  => 'DhcpOption82s',
                    'path_type'   => 'collection',
                    'action'      => 'create',
                    'path_part'   => '',
                    'methods'     => [ 'POST' ],
                    'full_path'   => '/api/v1/dhcp_option82s'
                },
                {
                    'operationId' => 'api.v1.DhcpOption82s.list',
                    'name'        => 'api.v1.DhcpOption82s.list',
                    'path'        => '/dhcp_option82s',
                    'children'    => [],
                    'depth'       => 2,
                    'paths'       => [ '/dhcp_option82s' ],
                    'controller'  => 'DhcpOption82s',
                    'path_type'   => 'collection',
                    'action'      => 'list',
                    'path_part'   => '',
                    'methods'     => [ 'GET' ],
                    'full_path'   => '/api/v1/dhcp_option82s'
                },
                {
                    'operationId' => 'api.v1.DhcpOption82s.search',
                    'name'        => 'api.v1.DhcpOption82s.search',
                    'path'        => '/dhcp_option82s/search',
                    'children'    => [],
                    'depth'       => 3,
                    'paths'       => [ '/dhcp_option82s', '/search' ],
                    'controller'  => 'DhcpOption82s',
                    'path_type'   => 'collection',
                    'action'      => 'search',
                    'path_part'   => '',
                    'methods'     => [ 'POST' ],
                    'full_path'   => '/api/v1/dhcp_option82s/search'
                },
                {
                    'operationId' => 'api.v1.DhcpOption82s.update',
                    'name'        => 'api.v1.DhcpOption82s.update',
                    'path'        => '/dhcp_option82/{dhcp_option82_id}',
                    'children'    => [],
                    'depth'       => 2,
                    'paths'       => [ '/dhcp_option82/{dhcp_option82_id}' ],
                    'controller'  => 'DhcpOption82s',
                    'path_type'   => 'resource',
                    'action'      => 'update',
                    'path_part'   => '',
                    'methods'     => [ 'PATCH' ],
                    'full_path'   => '/api/v1/dhcp_option82/{dhcp_option82_id}'
                },
                {
                    'operationId' => 'api.v1.DhcpOption82s.remove',
                    'name'        => 'api.v1.DhcpOption82s.remove',
                    'path'        => '/dhcp_option82/{dhcp_option82_id}',
                    'children'    => [],
                    'depth'       => 2,
                    'paths'       => [ '/dhcp_option82/{dhcp_option82_id}' ],
                    'controller'  => 'DhcpOption82s',
                    'path_type'   => 'resource',
                    'action'      => 'remove',
                    'path_part'   => '',
                    'methods'     => [ 'DELETE' ],
                    'full_path'   => '/api/v1/dhcp_option82/{dhcp_option82_id}'
                },
                {
                    'operationId' => 'api.v1.DhcpOption82s.replace',
                    'name'        => 'api.v1.DhcpOption82s.replace',
                    'path'        => '/dhcp_option82/{dhcp_option82_id}',
                    'children'    => [],
                    'depth'       => 2,
                    'paths'       => [ '/dhcp_option82/{dhcp_option82_id}' ],
                    'controller'  => 'DhcpOption82s',
                    'path_type'   => 'resource',
                    'action'      => 'replace',
                    'path_part'   => '',
                    'methods'     => [ 'PUT' ],
                    'full_path'   => '/api/v1/dhcp_option82/{dhcp_option82_id}'
                },
                {
                    'operationId' => 'api.v1.DhcpOption82s.get',
                    'name'        => 'api.v1.DhcpOption82s.get',
                    'path'        => '/dhcp_option82/{dhcp_option82_id}',
                    'children'    => [],
                    'depth'       => 2,
                    'paths'       => [ '/dhcp_option82/{dhcp_option82_id}' ],
                    'controller'  => 'DhcpOption82s',
                    'path_type'   => 'resource',
                    'action'      => 'get',
                    'path_part'   => '',
                    'methods'     => [ 'GET' ],
                    'full_path'   => '/api/v1/dhcp_option82/{dhcp_option82_id}'
                }
            ],
        ),
        {
            '/components/schemas/DhcpOption82sList' => {
                allOf => [
                    { '$ref' => "#/components/schemas/Iterable" },
                    {
                        "properties" => {
                            "items" => {
                                description => 'Items',
                                "items" => {
                                    "\$ref" =>
                                      "#/components/schemas/DhcpOption82"
                                },
                                "type" => "array"
                            }
                        },
                        "type" => "object"
                    }
                ]
            },
            '/components/schemas/DhcpOption82' => {
                properties => {
                    mac               => { type => 'string' },
                    created_at        => { type => 'string' },
                    option82_switch   => { type => 'string' },
                    switch_id         => { type => 'string' },
                    port              => { type => 'string' },
                    vlan              => { type => 'string' },
                    circuit_id_string => { type => 'string' },
                    module            => { type => 'string' },
                    host              => { type => 'string' },
                },
                type     => 'object',
            },
        },
        "Schemas For DhcpOption82s",
    );
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
