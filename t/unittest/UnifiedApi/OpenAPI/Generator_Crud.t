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

use Test::More tests => 2;
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
);

{

    my $controller = pf::UnifiedApi::Controller::DhcpOption82s->new(app => $app);
    my $generator = pf::UnifiedApi::OpenAPI::Generator::Crud->new;
    my @operators = $generator->operations($controller, \@actions);
#    use Data::Dumper;print Dumper(\@operators);
    is_deeply(
        \@operators,
        [
            delete => {
                'parameters'  => [],
                'operationId' => 'api.v1.DhcpOption82s.remove',
                'description' => 'Remove an item',
                responses => {
                    '204' => {
                        description => 'Item deleted'
                    }
                }
              },
            get => {
                'parameters'  => [],
                'operationId' => 'api.v1.DhcpOption82s.get',
                'responses'   => {
                    'content' => {
                        'application/json' => {
                            'schema' => {
                                'type'       => 'object',
                                'properties' => {
                                    'item' => {}
                                }
                            }
                        }
                    },
                    'description' => 'Get an item'
                },
                'description' => 'Get an item'
            },
            post => {
                'parameters'  => [],
                'operationId' => 'api.v1.DhcpOption82s.search'
            },
            put => {
                'parameters'  => [],
                'operationId' => 'api.v1.DhcpOption82s.replace',
                'description' => 'Replace an item'
            },
            patch => {
                'parameters'  => [],
                'operationId' => 'api.v1.DhcpOption82s.update',
                'description' => 'Update an item'
            }
        ],
        "Crud DELETE"
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
