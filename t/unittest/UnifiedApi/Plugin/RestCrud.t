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

use Test::More tests => 42;

#This test will running last
use Test::NoWarnings;

my $crud = pf::UnifiedApi::Plugin::RestCrud->new;

my $app = Mojolicious->new;

$app->plugin('pf::UnifiedApi::Plugin::RestCrud');#, {controller => "users", id_key => 'user_id'});

my $routes = $app->routes;

$routes->rest_routes({controller => 'Users'});

ok($routes->find("Users"), "The top level Route Users created");
foreach my $name (qw(list create get remove update replace)) {
    ok($routes->find("Users.$name"), "Route Users.$name created");
}

exit 0;

{
    my $r = $routes->any("/api")->name("api");

    $r->rest_routes({controller => 'users', id_key => "user_id" , resource_verbs => [qw(run walk)]});
    foreach my $name (qw(list create get remove update replace run walk resource)) {
        ok($r->find("api.Users.$name"), "Route api.Users.$name created");
    }
}

{
    my $r = $routes->any("/hello")->name("hello");
    $r->rest_routes({controller => 'bobbies', id_key => "user_id", collection_v2a => { post => 'search', put => 'add' } });
    foreach my $name (qw(add search get remove update replace )) {
        ok($r->find("hello.Bob.$name"), "Route hello.Bob.$name created");
    }

    $r->rest_routes({controller => 'jones', id_key => "user_id", resource_v2a => {} });
    foreach my $name (qw( get remove update replace )) {
        ok(!$r->find("hello.Jones.$name"), "Route hello.Jones.$name not created");
    }
}

{
    my @additional_routes = qw(howard the duck);
    $routes->rest_routes({controller => 'collection_verbs', collection_v2a => {}, collection_additional_routes => \@additional_routes, resource_v2a => {} });
    foreach my $name (@additional_routes) {
        ok($routes->find("CollectionVerbs.$name"), "Route CollectionVerbs.$name was created");
    }
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

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
