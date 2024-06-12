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

use pf::UnifiedApi::OpenAPI::Generator;
use pf::UnifiedApi::OpenAPI::Generator::Config;
use pf::UnifiedApi::Controller::Config::FloatingDevices;
use pf::UnifiedApi;

use Test::More tests => 5;
#This test will running last
use Test::NoWarnings;


my $app = pf::UnifiedApi->new;

my $controller = pf::UnifiedApi::Controller::Config::FloatingDevices->new(app => $app);

my $generator = pf::UnifiedApi::OpenAPI::Generator->new;

sub standardGetContent {
    return (
        "content" => {
            "application/json" => {
                schema => standardSchema(),
            }
        },
    );
}

sub standardSchema {
    return {
        properties => {
            id => {
                description => 'MAC Address',
                type        => 'string'
            },
            ip => {
                description => 'IP Address',
                type        => 'string'
            },
            pvid => {
                description => 'VLAN in which PacketFence should put the port',
                type        => 'integer'
            },
            taggedVlan => {
                description =>
'Comma separated list of VLANs. If the port is a multi-vlan, these are the VLANs that have to be tagged on the port.',
                type => 'string'
            },
            trunkPort => {
                description =>
                  'The port must be configured as a muti-vlan port',
                type => 'string'
            },
        },
        required => [qw(id pvid)],
        type     => 'object',
    };
}


{

    my $generator = pf::UnifiedApi::OpenAPI::Generator::Config->new;
    my %schemas = $generator->operations(
        $controller,
        [
            {
                'operationId' => 'api.v1.Config::FloatingDevices.get',
                'name'        => 'api.v1.Config::FloatingDevices.get',
                'children'    => [],
                'path'        => '/config/floating_device/{floating_device_id}',
                'depth'       => 2,
                'paths' => ['/config/floating_device/{floating_device_id}'],
                'controller' => 'Config::FloatingDevices',
                'path_type'  => 'resource',
                'methods'    => ['GET'],
                'path_part'  => '',
                'action'     => 'get',
                'full_path'  =>
                  '/api/v1/config/floating_device/{floating_device_id}'
            }
        ]
    );

    is_deeply(
        \%schemas,
        {
            'get' => {
                'description' => 'Get an item.',
                'parameters'  => [
                    {
                        'schema' => {
                            'type' => 'string'
                        },
                        'name'     => 'floating_device_id',
                        'required' =>
                          bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' ),
                        'in'          => 'path',
                        'description' => '`PRIMARY KEY`'
                    }
                ],
                'responses' => {
                    '401' => {
                        '$ref' => '#/components/responses/Forbidden'
                    },
                    '200' => {
                        'description' =>
'Request successful. Response contains a specific resource.',
                        'content' => {
                            'application/json' => {
                                'schema' => {
                                    '$ref' =>
'#/components/schemas/ConfigFloatingDeviceWrapped'
                                }
                            }
                        }
                    },
                    '404' => {
                        '$ref' => '#/components/responses/NotFound'
                    }
                },
                'operationId' => 'api.v1.Config::FloatingDevices.get',
                'tags'        => ['Config/FloatingDevices']
            }
        },
        "Config Get"
    );
}

{
    my $generator = pf::UnifiedApi::OpenAPI::Generator::Config->new;
    my $schemas   = $generator->generateSchemas(
        $controller,
        [
            {
                'operationId' => 'api.v1.Config::FloatingDevices.create',
                'name'        => 'api.v1.Config::FloatingDevices.create',
                'children'    => [],
                'path'        => '/config/floating_devices',
                'depth'       => 2,
                'paths'       => ['/config/floating_devices'],
                'controller'  => 'Config::FloatingDevices',
                'path_type'   => 'collection',
                'methods'     => ['POST'],
                'path_part'   => '',
                'action'      => 'create',
                'full_path'   => '/api/v1/config/floating_devices'
            },
            {
                'operationId' => 'api.v1.Config::FloatingDevices.list',
                'name'        => 'api.v1.Config::FloatingDevices.list',
                'children'    => [],
                'path'        => '/config/floating_devices',
                'depth'       => 2,
                'paths'       => ['/config/floating_devices'],
                'controller'  => 'Config::FloatingDevices',
                'path_type'   => 'collection',
                'methods'     => ['GET'],
                'path_part'   => '',
                'action'      => 'list',
                'full_path'   => '/api/v1/config/floating_devices'
            },
            {
                'operationId' => 'api.v1.Config::FloatingDevices.search',
                'name'        => 'api.v1.Config::FloatingDevices.search',
                'children'    => [],
                'path'        => '/config/floating_devices/search',
                'depth'       => 3,
                'paths'       => [ '/config/floating_devices', '/search' ],
                'controller'  => 'Config::FloatingDevices',
                'path_type'   => 'collection',
                'methods'     => ['POST'],
                'path_part'   => '',
                'action'      => 'search',
                'full_path'   => '/api/v1/config/floating_devices/search'
            },
            {
                'operationId' => 'api.v1.Config::FloatingDevices.update',
                'name'        => 'api.v1.Config::FloatingDevices.update',
                'children'    => [],
                'path'        => '/config/floating_device/{floating_device_id}',
                'depth'       => 2,
                'paths' => ['/config/floating_device/{floating_device_id}'],
                'controller' => 'Config::FloatingDevices',
                'path_type'  => 'resource',
                'methods'    => ['PATCH'],
                'path_part'  => '',
                'action'     => 'update',
                'full_path'  =>
                  '/api/v1/config/floating_device/{floating_device_id}'
            },
            {
                'operationId' => 'api.v1.Config::FloatingDevices.remove',
                'name'        => 'api.v1.Config::FloatingDevices.remove',
                'children'    => [],
                'path'        => '/config/floating_device/{floating_device_id}',
                'depth'       => 2,
                'paths' => ['/config/floating_device/{floating_device_id}'],
                'controller' => 'Config::FloatingDevices',
                'path_type'  => 'resource',
                'methods'    => ['DELETE'],
                'path_part'  => '',
                'action'     => 'remove',
                'full_path'  =>
                  '/api/v1/config/floating_device/{floating_device_id}'
            },
            {
                'operationId' => 'api.v1.Config::FloatingDevices.replace',
                'name'        => 'api.v1.Config::FloatingDevices.replace',
                'children'    => [],
                'path'        => '/config/floating_device/{floating_device_id}',
                'depth'       => 2,
                'paths' => ['/config/floating_device/{floating_device_id}'],
                'controller' => 'Config::FloatingDevices',
                'path_type'  => 'resource',
                'methods'    => ['PUT'],
                'path_part'  => '',
                'action'     => 'replace',
                'full_path'  =>
                  '/api/v1/config/floating_device/{floating_device_id}'
            },
            {
                'operationId' => 'api.v1.Config::FloatingDevices.get',
                'name'        => 'api.v1.Config::FloatingDevices.get',
                'children'    => [],
                'path'        => '/config/floating_device/{floating_device_id}',
                'depth'       => 2,
                'paths' => ['/config/floating_device/{floating_device_id}'],
                'controller' => 'Config::FloatingDevices',
                'path_type'  => 'resource',
                'methods'    => ['GET'],
                'path_part'  => '',
                'action'     => 'get',
                'full_path'  =>
                  '/api/v1/config/floating_device/{floating_device_id}'
            }
        ],
    );
    is_deeply(
        $schemas,
        {
            '/components/schemas/ConfigFloatingDeviceWrapped' => {
                'properties' => {
                    'status' => {
                        'type' => 'integer'
                    },
                    'item' => {
                        '$ref' => '#/components/schemas/ConfigFloatingDevice'
                    }
                },
                'type' => 'object'
            },
            '/components/schemas/ConfigFloatingDevicesList' => {
                'allOf' => [
                    {
                        '$ref' => '#/components/schemas/Iterable'
                    },
                    {
                        'type'       => 'object',
                        'properties' => {
                            'items' => {
                                'items' => {
                                    '$ref' =>
'#/components/schemas/ConfigFloatingDevice'
                                },
                                'type' => 'array'
                            }
                        }
                    }
                ]
            },
            '/components/schemas/ConfigFloatingDeviceMeta' => {
                'properties' => {
                    'meta' => {
                        'type'       => 'object',
                        'properties' => {
                            'ip' => {
                                '$ref' => '#/components/schemas/Meta'
                            },
                            'pvid' => {
                                '$ref' => '#/components/schemas/Meta'
                            },
                            'id' => {
                                '$ref' => '#/components/schemas/Meta'
                            },
                            'trunkPort' => {
                                '$ref' => '#/components/schemas/Meta'
                            },
                            'taggedVlan' => {
                                '$ref' => '#/components/schemas/Meta'
                            }
                        }
                    }
                },
                'type' => 'object'
            },
            '/components/schemas/ConfigFloatingDevice' => {
                'type'       => 'object',
                'properties' => {
                    'pvid' => {
                        'type'        => 'integer',
                        'description' =>
                          'VLAN in which PacketFence should put the port'
                    },
                    'id' => {
                        'description' => 'MAC Address',
                        'type'        => 'string'
                    },
                    'trunkPort' => {
                        'type'        => 'string',
                        'description' =>
                          'The port must be configured as a muti-vlan port'
                    },
                    'ip' => {
                        'type'        => 'string',
                        'description' => 'IP Address'
                    },
                    'taggedVlan' => {
                        'description' =>
'Comma separated list of VLANs. If the port is a multi-vlan, these are the VLANs that have to be tagged on the port.',
                        'type' => 'string'
                    }
                },
                'required' => [ 'id', 'pvid' ]
            }
        },
        "Schemas For Config::FloatingDevices"
    );
}

{

    my $generator = pf::UnifiedApi::OpenAPI::Generator::Config->new;
    my %schemas   = $generator->operations(
        $controller,
        [
            {
                'name'        => 'api.v1.Config::FloatingDevices.replace',
                'operationId' => 'api.v1.Config::FloatingDevices.replace',
                'children'    => [],
                'path'        => '/config/floating_device/{floating_device_id}',
                'depth'       => 2,
                'paths' => ['/config/floating_device/{floating_device_id}'],
                'controller' => 'Config::FloatingDevices',
                'path_type'  => 'resource',
                'methods'    => ['PUT'],
                'path_part'  => '',
                'action'     => 'replace',
                'full_path'  =>
                  '/api/v1/config/floating_device/{floating_device_id}'
            }
        ]
    );
    is_deeply(
        \%schemas,
        {
            'put' => {
                'tags'        => ['Config/FloatingDevices'],
                'operationId' => 'api.v1.Config::FloatingDevices.replace',
                'responses'   => {
                    '404' => {
                        '$ref' => '#/components/responses/NotFound'
                    },
                    '400' => {
                        '$ref' => '#/components/responses/BadRequest'
                    },
                    '401' => {
                        '$ref' => '#/components/responses/Forbidden'
                    },
                    '201' => {
                        '$ref' => '#/components/responses/Created'
                    },
                    '422' => {
                        '$ref' => '#/components/responses/UnprocessableEntity'
                    }
                },
                'requestBody' => {
                    'content' => {
                        'application/json' => {
                            'schema' => {
                                '$ref' =>
                                  '#/components/schemas/ConfigFloatingDevice'
                            }
                        }
                    }
                },
                'description' => 'Replace an item.',
                'parameters'  => [
                    {
                        'description' => '`PRIMARY KEY`',
                        'in'          => 'path',
                        'name'        => 'floating_device_id',
                        'schema'      => {
                            'type' => 'string'
                        },
                        'required' =>
                          bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' )
                    }
                ]
            }
        },
        "Config PUT"
    );
}

{

    my $generator = pf::UnifiedApi::OpenAPI::Generator::Config->new;
    my %schemas = $generator->operations(
        $controller,
        [
            {
                'operationId' => 'api.v1.Config::FloatingDevices.remove',
                'name'        => 'api.v1.Config::FloatingDevices.get',
                'children'    => [],
                'path'        => '/config/floating_device/{floating_device_id}',
                'depth'       => 2,
                'paths' => ['/config/floating_device/{floating_device_id}'],
                'controller' => 'Config::FloatingDevices',
                'path_type'  => 'resource',
                'methods'    => ['DELETE'],
                'path_part'  => '',
                'action'     => 'remove',
                'full_path'  =>
                  '/api/v1/config/floating_device/{floating_device_id}'
            }
        ]
    );
    is_deeply(
        \%schemas,
        {
            'delete' => {
                'responses' => {
                    '200' => {
                        '$ref' => '#/components/responses/Deleted'
                    },
                    '404' => {
                        '$ref' => '#/components/responses/NotFound'
                    },
                    '401' => {
                        '$ref' => '#/components/responses/Forbidden'
                    }
                },
                'tags'        => ['Config/FloatingDevices'],
                'description' => 'Delete an item.',
                'parameters'  => [
                    {
                        'description' => '`PRIMARY KEY`',
                        'name'        => 'floating_device_id',
                        'required'    =>
                          bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' ),
                        'schema' => {
                            'type' => 'string'
                        },
                        'in' => 'path'
                    }
                ],
                'operationId' => 'api.v1.Config::FloatingDevices.remove'
            }
        },
        "Config DELETE"
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
