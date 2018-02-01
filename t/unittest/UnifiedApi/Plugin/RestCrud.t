#!/usr/bin/perl

=head1 NAME

RestCrud.t

=cut

=head1 DESCRIPTION

unit test for RestCrud

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}
use pf::UnifiedApi::Plugin::RestCrud;
use Mojolicious;
use Lingua::EN::Inflexion qw(noun);

use Test::More tests => 71;

#This test will running last
use Test::NoWarnings;

my $crud = pf::UnifiedApi::Plugin::RestCrud->new;

my $app = Mojolicious->new;

$app->plugin('pf::UnifiedApi::Plugin::RestCrud');#, {controller => "users", id_key => 'user_id'});

my $routes = $app->routes;

$routes->rest_routes({controller => 'Users'});

ok($routes->find("Users"), "The top level Route Users created");

routes_created($routes, "Users.", qw(list create get remove update replace resource));

{
    my $r = $routes->any("/api")->name("api");

    $r->rest_routes({controller => 'Users'});
    routes_created($r, "api.Users.", qw(list create get remove update replace resource));
}

{
    my $r = $routes->any("/hello")->name("hello");
    $r->rest_routes({
        controller => 'Worlds',
        collection => {
            http_methods => {
                post => 'search',
                put => 'add',
            }
        },
        resource => undef,
    });
    routes_created($r, "hello.Worlds.", qw(add search));
    routes_not_created($r, "hello.Worlds.", qw(list create get remove update replace resource));

    $r->rest_routes({
        controller => 'Universes',
        collection => undef,
        resource => {
            http_methods => {
                get => 'find',
                put => 'change',
                patch => 'modify',
                delete => 'annihilate',
            },
            subroutes => {
                take_me_to_your_leader => {
                    get => 'find_leader',
                },
            },
        },
    });
    routes_created($r, 'hello.Universes.', qw(find change modify annihilate find_leader));
    routes_not_created($r, "hello.Universes.", qw(list create get remove update replace ));
}


{
    $routes->rest_routes(
        {
            controller => 'Quackers',
            resource => undef,
            collection => {
                subroutes => {
                    tail_spin => {
                        get => 'scrooge_mcduck',
                    },
                },
            },
        }
    );
    routes_created($routes, "Quackers.", qw(list create scrooge_mcduck));
    routes_not_created($routes, "Quackers.", qw( get remove update replace resource));
}

{
    my $r = $routes->any("/api_child_test")->name("ApiChildTest");
    $r->rest_routes(
        {
            controller => 'Users',
            resource => {
                children => [
                    {
                        controller => 'Nodes'
                    },
                ],
            },
        }
    );
    routes_created($routes, "ApiChildTest.Users.", qw(list create get remove update replace resource));
    routes_created($routes, "ApiChildTest.Users.Nodes.", qw(list create get remove update replace resource));
}

is (
    pf::UnifiedApi::Plugin::RestCrud::munge_name_prefix_option($routes, {controller => 'Users'}),
    "Users",
    "The name prefix",
);

{
    my $r = $routes->any("/api/v2")->name("Api.v2");

    is (
        pf::UnifiedApi::Plugin::RestCrud::munge_name_prefix_option($r, {controller => 'Users'}),
        "Api.v2.Users",
        "The name prefix with a parent",
    );
}

eval {
    pf::UnifiedApi::Plugin::RestCrud::munge_options($routes, {controller => 'User'});
};

ok ($@ && $@ =~ 'cannot be singular noun', "Enforce no singular noun for controllers");

eval {
    pf::UnifiedApi::Plugin::RestCrud::munge_options($routes, {});
};

ok ($@ , "Should die if an invalid config is given");

is_deeply(
    pf::UnifiedApi::Plugin::RestCrud::munge_resource_options(
        $routes,
        {
            controller => 'Users',
            short_name => 'users',
            noun       => noun('users'),
            base_url   => '',
            resource   => {
                http_methods => {
                    get => 'bob',
                },
                subroutes => {
                    close_nodes => {
                        post => 'close_nodes_',
                    },
                },
            }
        }
    ),
    {
        url_param_key => 'user_id',
        subroutes     => {
            close_nodes => {
                POST => 'close_nodes_',
            }
        },
        http_methods  => {
            GET    => 'bob',
        },
        'path' => '/user/:user_id',
        children => [],
    },
    "Munging resource options"
);

is_deeply (
   pf::UnifiedApi::Plugin::RestCrud::munge_resource_options($routes, { controller => 'Users', short_name => 'users', noun => noun('users'), base_url => '' }),
    {
        url_param_key => 'user_id',
        subroutes     => {},
        http_methods       => {
            GET    => 'get',
            PATCH  => 'update',
            PUT    => 'replace',
            DELETE => 'remove',
        },
        'path' => '/user/:user_id',
        children => [],
    },
    "Munging resource options"
);

is_deeply (
    pf::UnifiedApi::Plugin::RestCrud::munge_resource_options($routes, { controller => 'Config::ConnectionProfiles', short_name => 'connection_profiles', noun => noun('connection_profiles'), base_url => '/config' }),
    {
        url_param_key => 'connection_profile_id',
        subroutes     => {},
        http_methods       => {
            GET    => 'get',
            PATCH  => 'update',
            PUT    => 'replace',
            DELETE => 'remove',
        },
        'path' => '/config/connection_profile/:connection_profile_id',
        children => [],
    },
    "Munging resource options with a sub path"
);

is_deeply (
    pf::UnifiedApi::Plugin::RestCrud::munge_options(
        $routes,
        {
            controller => 'Users',
        }
    ),
    {
        controller => 'Users',
        name_prefix => 'Users',
        resource => {
            url_param_key => 'user_id',
            subroutes => { },
            http_methods => {
                GET  => 'get',
                PATCH => 'update',
                PUT => 'replace',
                DELETE => 'remove',
            },
            'path' => '/user/:user_id',
            children => []
        },
        collection => {
            subroutes => {},
            http_methods => {
                GET => 'list',
                POST => 'create',
            },
            path => '/users',
        },
    },
    "Expanded config"
);

is_deeply (
    pf::UnifiedApi::Plugin::RestCrud::munge_options(
        $routes,
        {
            controller => 'Config::ConnectionProfiles',
        }
    ),
    {
        controller => 'Config::ConnectionProfiles',
        name_prefix => 'Config::ConnectionProfiles',
        resource => {
            url_param_key => 'connection_profile_id',
            subroutes => { },
            http_methods => {
                GET  => 'get',
                PATCH => 'update',
                PUT => 'replace',
                DELETE => 'remove',
            },
            path => '/config/connection_profile/:connection_profile_id',
            children => [],
        },
        collection => {
            subroutes => {},
            http_methods => {
                GET => 'list',
                POST => 'create',
            },
            path => '/config/connection_profiles',
        },
    },
    "Expanded config"
);

is_deeply (
    pf::UnifiedApi::Plugin::RestCrud::munge_options(
        $routes,
        {
            controller => 'NoResources',
            resource => undef,
        }
    ),
    {
        controller => 'NoResources',
        name_prefix => 'NoResources',
        resource => undef,
        collection => {
            subroutes => {},
            http_methods => {
                GET => 'list',
                POST => 'create',
            },
            path => '/no_resources',
        },
    },
    "Do not expand resource if it is undef",
);

is_deeply (
    pf::UnifiedApi::Plugin::RestCrud::munge_options(
        $routes,
        {
            controller => 'Collections',
            resource => undef,
            collection => {
                http_methods => undef,
                subroutes => {
                    r1 => {
                        get => 'm1'
                    },
                },
            },
        }
    ),
    {
        controller => 'Collections',
        name_prefix => 'Collections',
        resource => undef,
        collection => {
            subroutes => {
                r1 => {
                    GET => 'm1'
                }
            },
            http_methods => undef,
            path => '/collections',
        },
    },
    "Do not expand collections httpd_methods if it is undef",
);

eval {
    pf::UnifiedApi::Plugin::RestCrud::munge_options(
        $routes,
        {
            controller => 'EnforceHttpMethods',
            collection => undef,
            resource => {
                http_methods => undef,
            }
        }
    );
};

ok($@, "http methods enforced for resources");

is_deeply(
    pf::UnifiedApi::Plugin::RestCrud::munge_options(
        $routes,
        {
            controller => 'Users',
            resource   => {
                children => [
                    {
                        controller => 'Nodes',
                    },
                ],
            },
        }
    ),
    {
        controller  => 'Users',
        name_prefix => 'Users',
        resource    => {
            url_param_key => 'user_id',
            subroutes     => {},
            http_methods  => {
                GET    => 'get',
                PATCH  => 'update',
                PUT    => 'replace',
                DELETE => 'remove',
            },
            'path'   => '/user/:user_id',
            children => [
                {
                    controller  => 'Nodes',
                    name_prefix => 'Users.Nodes',
                    resource    => {
                        url_param_key => 'node_id',
                        subroutes     => {},
                        http_methods  => {
                            GET    => 'get',
                            PATCH  => 'update',
                            PUT    => 'replace',
                            DELETE => 'remove',
                        },
                        'path'   => '/node/:node_id',
                        children => []
                    },
                    collection => {
                        subroutes    => {},
                        http_methods => {
                            GET  => 'list',
                            POST => 'create',
                        },
                        path => '/nodes',
                    },
                },
            ]
        },
        collection => {
            subroutes    => {},
            http_methods => {
                GET  => 'list',
                POST => 'create',
            },
            path => '/users',
        },
    },
    "Expanding child options"
);

sub routes_created {
    my ($r, $prefix, @routes) = @_;
    foreach my $name (@routes) {
        my $route_name = $prefix . $name;
        ok($r->find($route_name), "Route $route_name was created");
    }
}

sub routes_not_created {
    my ($r, $prefix, @routes) = @_;
    foreach my $name (@routes) {
        my $route_name = $prefix . $name;
        ok(!$r->find($route_name), "Route $route_name was not created");
    }
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
