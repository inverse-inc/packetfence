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

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::UnifiedApi::OpenAPI::Generator::Crud;
use pf::UnifiedApi::Controller::DhcpOption82s;
use pf::UnifiedApi;

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
    is_deeply(
        \%operators,
        {
            'get' => {
                'tags'       => ['DhcpOption82s'],
                'parameters' => [
                    {
                        'in'       => 'path',
                        'name'     => 'dhcp_option82_id',
                        'required' => bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' ),
                        'schema' => {
                            'type' => 'string'
                        },
                        'description' => '`PRIMARY KEY`'
                    }
                ],
                'operationId' => 'api.v1.DhcpOption82s.get',
                'responses'   => {
                    '200' => {
                        'content' => {
                            'application/json' => {
                                'schema' => {
                                    'properties' => {

                                        'item' => {

                                            '$ref' => '#/components/schemas/DhcpOption82'

                                        }

                                    },
                                    'type' => 'object'
                                }
                            }
                        },
                        description => 'Request successful.',

                    },
                    '422' => {
                        '$ref' => '#/components/responses/UnprocessableEntity'
                    },
                    '404' => {
                        '$ref' => '#/components/responses/BadRequest'
                    },
                    '401' => {
                        '$ref' => '#/components/responses/Forbidden'
                    }
                },
                'description' => 'Get an item.'
            }
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
            'delete',
            {
                'parameters' => [
                    {
                        'name'   => 'dhcp_option82_id',
                        'in'     => 'path',
                        'schema' => {
                            'type' => 'string'
                        },
                        'description' => '`PRIMARY KEY`',
                        'required'    =>
                          bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' )
                    }
                ],
                'tags'      => ['DhcpOption82s'],
                'responses' => {
                    '204' => {
                        'description' => 'Item deleted.'
                    }
                },
                'description' => 'Delete an item.',
                'operationId' => 'api.v1.DhcpOption82s.remove'
            }
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
    #    use Data::Dumper;print Dumper(\%operators);
    is_deeply(
        \%operators,
        {
            'patch' => {
                'tags'        => ['DhcpOption82s'],
                'description' => 'Update an item.',
                'requestBody' => {
                    'content' => {
                        'application/json' => {
                            'schema' => {
                                '$ref' => '#/components/schemas/DhcpOption82'
                            }
                        }
                    }
                },
                'parameters' => [
                    {
                        'required' =>
                          bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' ),
                        'schema' => {
                            'type' => 'string'
                        },
                        'name'        => 'dhcp_option82_id',
                        'description' => '`PRIMARY KEY`',
                        'in'          => 'path'
                    }
                ],
                'responses' => {
                    '422' => {
                        '$ref' => '#/components/responses/UnprocessableEntity'
                    },
                    '404' => {
                        '$ref' => '#/components/responses/BadRequest'
                    },
                    '401' => {
                        '$ref' => '#/components/responses/Forbidden'
                    },
                    '200' => {
                        '$ref' => '#/components/responses/Message'
                    }
                },
                'operationId' => 'api.v1.DhcpOption82s.update'
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
            'put' => {
                'operationId' => 'api.v1.DhcpOption82s.replace',
                'responses'   => {
                    '422' => {
                        '$ref' => '#/components/responses/UnprocessableEntity'
                    },
                    '401' => {
                        '$ref' => '#/components/responses/Forbidden'
                    },
                    '200' => {
                        '$ref' => '#/components/responses/Message'
                    },
                    '404' => {
                        '$ref' => '#/components/responses/BadRequest'
                    }
                },
                'parameters' => [
                    {
                        'in'          => 'path',
                        'description' => '`PRIMARY KEY`',
                        'required'    =>
                          bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' ),
                        'schema' => {
                            'type' => 'string'
                        },
                        'name' => 'dhcp_option82_id'
                    }
                ],
                'description' => 'Replace an item.',
                'requestBody' => {
                    'content' => {
                        'application/json' => {
                            'schema' => {
                                '$ref' => '#/components/schemas/DhcpOption82'
                            }
                        }
                    }
                },
                'tags' => ['DhcpOption82s']
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
    #        use Data::Dumper;print Dumper(\%operators);
    is_deeply(
        \%operators,
        {
            'post' => {
                'tags'        => ['DhcpOption82s'],
                'parameters'  => [],
                'operationId' => 'api.v1.DhcpOption82s.search',
                'description' => 'Search all items.',
                'responses'   => {
                    '404' => {
                        '$ref' => '#/components/responses/BadRequest'
                    },
                    '409' => {
                        '$ref' => '#/components/responses/Duplicate'
                    },
                    '401' => {
                        '$ref' => '#/components/responses/Forbidden'
                    },
                    '422' => {
                        '$ref' => '#/components/responses/UnprocessableEntity'
                    },
                    '200' => {
                        'content' => {
                            'application/json' => {
                                'schema' => {
                                    '$ref' =>
                                      '#/components/schemas/DhcpOption82sList'
                                }
                            }
                        },
                        description => 'Request successful.'
                    }
                },
                'requestBody' => {
                    'content' => {
                        'application/json' => {
                            'schema' => {
                                'allOf' => [
                                    {
                                        '$ref' => '#/components/schemas/Search'
                                    },
                                    {
                                        'required'   => ['fields', 'sort'],
                                        'properties' => {
                                            'limit' => {
                                                'type'     => 'integer',
                                                'maximum'  => 1000,
                                                'minimum'  => 1,
                                            },
                                            'sort' => {
                                                'type'  => 'array',
                                                'items' => {
                                                    'enum' => [
                                                        'circuit_id_string ASC',
                                                        'circuit_id_string DESC',
                                                        'created_at ASC',
                                                        'created_at DESC',
                                                        'host ASC',
                                                        'host DESC',
                                                        'mac ASC',
                                                        'mac DESC',
                                                        'module ASC',
                                                        'module DESC',
                                                        'option82_switch ASC',
                                                        'option82_switch DESC',
                                                        'port ASC',
                                                        'port DESC',
                                                        'switch_id ASC',
                                                        'switch_id DESC',
                                                        'vlan ASC',
                                                        'vlan DESC'
                                                    ],
                                                    'type' => 'string'
                                                },
                                            },
                                            'cursor' => {
                                                'type'     => 'string',
                                            },
                                            'fields' => {
                                                'items' => {
                                                    'type' => 'string',
                                                    'enum' => [
                                                        'circuit_id_string',
                                                        'created_at',
                                                        'host',
                                                        'mac',
                                                        'module',
                                                        'option82_switch',
                                                        'port',
                                                        'switch_id',
                                                        'vlan'
                                                    ]
                                                },
                                                'type'     => 'array',
                                            }
                                        }
                                    }
                                ]
                            },
                            'example' => {
                                'fields' => [
                                    'circuit_id_string',
                                    'created_at',
                                    'host',
                                    'mac',
                                    'module',
                                    'option82_switch',
                                    'port',
                                    'switch_id',
                                    'vlan'
                                ],
                                'cursor' => 0,
                                'sort'   => [
                                    'mac ASC'
                                ],
                                'limit' => 25,
                                'query' => {
                                    'op'     => 'and',
                                    'values' => [
                                        {
                                            'values' => [
                                                {
                                                    'value' => 'foo',
                                                    'op'    => 'contains',
                                                    'field' =>
                                                      'circuit_id_string'
                                                },
                                                {
                                                    'value' => 'foo',
                                                    'op'    => 'contains',
                                                    'field' => 'created_at'
                                                },
                                                {
                                                    'op'    => 'contains',
                                                    'field' => 'host',
                                                    'value' => 'foo'
                                                },
                                                {
                                                    'value' => 'foo',
                                                    'field' => 'mac',
                                                    'op'    => 'contains'
                                                },
                                                {
                                                    'op'    => 'contains',
                                                    'field' => 'module',
                                                    'value' => 'foo'
                                                },
                                                {
                                                    'field' =>
                                                      'option82_switch',
                                                    'op'    => 'contains',
                                                    'value' => 'foo'
                                                },
                                                {
                                                    'value' => 'foo',
                                                    'field' => 'port',
                                                    'op'    => 'contains'
                                                },
                                                {
                                                    'value' => 'foo',
                                                    'field' => 'switch_id',
                                                    'op'    => 'contains'
                                                },
                                                {
                                                    'op'    => 'contains',
                                                    'field' => 'vlan',
                                                    'value' => 'foo'
                                                }
                                            ],
                                            'op' => 'or'
                                        }
                                    ]
                                }
                            }
                        }
                    },
                    'required' => bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean'),
                }
            }
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
    #            use Data::Dumper;print STDERR Dumper(\%operators);
    is_deeply(
        \%operators,
        {
            'get' => {
                'parameters' => [
                    {
                        'description' =>
'Comma delimited list of fields to return with each item.',
                        'in'     => 'query',
                        'style'  => 'simple',
                        'schema' => {
                            'items' => {
                                'enum' => [
                                    'circuit_id_string', 'created_at',
                                    'host',              'mac',
                                    'module',            'option82_switch',
                                    'port',              'switch_id',
                                    'vlan'
                                ],
                                'type' => 'string'
                            },
                            'type'    => 'array',
                            'example' => [
                                'circuit_id_string', 'created_at',
                                'host',              'mac',
                                'module',            'option82_switch',
                                'port',              'switch_id',
                                'vlan'
                            ]
                        },
                        'explode' =>
                          bless( do { \( my $o = 0 ) }, 'JSON::PP::Boolean' ),
                        'required' =>
                          bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' ),
                        'name' => 'fields'
                    },
                    {
                        'style'   => 'simple',
                        'explode' =>
                          bless( do { \( my $o = 0 ) }, 'JSON::PP::Boolean' ),
                        'required' =>
                          bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' ),
                        'name'   => 'sort',
                        'schema' => {
                            'example' => ['mac ASC'],
                            'type'    => 'array',
                            'items'   => {
                                'type' => 'string',
                                'enum' => [
                                    'circuit_id_string ASC',
                                    'circuit_id_string DESC',
                                    'created_at ASC',
                                    'created_at DESC',
                                    'host ASC',
                                    'host DESC',
                                    'mac ASC',
                                    'mac DESC',
                                    'module ASC',
                                    'module DESC',
                                    'option82_switch ASC',
                                    'option82_switch DESC',
                                    'port ASC',
                                    'port DESC',
                                    'switch_id ASC',
                                    'switch_id DESC',
                                    'vlan ASC',
                                    'vlan DESC'
                                ]
                            }
                        },
                        'in'          => 'query',
                        'description' =>
'Comma delimited list of fields and respective order to sort items (`default: [ mac ASC ]`).'
                    },
                    {
                        'in'   => 'query',
                        '$ref' => '#/components/parameters/limit'
                    },
                    {
                        '$ref' => '#/components/parameters/cursor',
                        'in'   => 'query'
                    }
                ],
                'tags'        => ['DhcpOption82s'],
                'operationId' => 'api.v1.DhcpOption82s.list',
                'description' => 'List all items.',
                'responses'   => {
                    '422' => {
                        '$ref' => '#/components/responses/UnprocessableEntity'
                    },
                    '409' => {
                        '$ref' => '#/components/responses/Duplicate'
                    },
                    '200' => {
                        'description' => 'Request successful.',
                        'content'     => {
                            'application/json' => {
                                'schema' => {
                                    '$ref' =>
                                      '#/components/schemas/DhcpOption82sList'
                                }
                            }
                        }
                    },
                    '404' => {
                        '$ref' => '#/components/responses/BadRequest'
                    },
                    '401' => {
                        '$ref' => '#/components/responses/Forbidden'
                    }
                }
            },
            'post' => {
                'operationId' => 'api.v1.DhcpOption82s.create',
                'responses'   => {
                    '201' => {
                        '$ref' => '#/components/responses/Created'
                    },
                    '400' => {
                        '$ref' => '#/components/responses/BadRequest'
                    },
                    '422' => {
                        '$ref' => '#/components/responses/UnprocessableEntity'
                    },
                    '409' => {
                        '$ref' => '#/components/responses/Duplicate'
                    }
                },
                'description' => 'Create a new item.',
                'requestBody' => {
                    'content' => {
                        'application/json' => {
                            'schema' => {
                                '$ref' => '#/components/schemas/DhcpOption82'
                            }
                        }
                    }
                },
                'parameters' => [],
                'tags'       => ['DhcpOption82s']
            }
        },
        "Crud collection POST/GET"
    );
}

{
    my $schemas = $generator->generateSchemas(
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
        );
        #    use Data::Dumper;print Dumper($schemas); 
    is_deeply(
        $schemas,
        {
            '/components/schemas/DhcpOption82sList' => {
                'allOf' => [
                    {
                        '$ref' => '#/components/schemas/Iterable'
                    },
                    {
                        'type'       => 'object',
                        'properties' => {
                            'items' => {
                                'type'  => 'array',
                                'items' => {
                                    '$ref' =>
                                      '#/components/schemas/DhcpOption82'
                                },
                                'description' => 'Items.'
                            }
                        }
                    }
                ]
            },
            '/components/schemas/DhcpOption82' => {
                'properties' => {
                    'mac' => {
                        'type'        => 'string',
                        'description' => '`PRIMARY KEY`'
                    },
                    'host' => {
                        'type'     => 'string',
                        'nullable' =>
                          bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' )
                    },
                    'port' => {
                        'type' => 'string'
                    },
                    'vlan' => {
                        'nullable' => bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' ),
                        'type' => 'string',
                    },
                    'module' => {
                        'type'     => 'string',
                        'nullable' => bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' ),
                    },
                    'circuit_id_string' => {
                        'nullable' => bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' ),
                        'type' => 'string'
                    },
                    'created_at' => {
                        'type' => 'string'
                    },
                    'switch_id' => {
                        'nullable' => bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' ),
                        'type' => 'string'
                    },
                    'option82_switch' => {
                        'nullable' => bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' ),
                        'type' => 'string'
                    }
                },
                'type' => 'object'
            }
        },
        "Schemas For DhcpOption82s",
    );
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
