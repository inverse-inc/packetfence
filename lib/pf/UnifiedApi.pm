package pf::UnifiedApi;

=head1 NAME

pf::UnifiedApi - The base of the mojo app

=cut

=head1 DESCRIPTION

pf::UnifiedApi

=cut

use strict;
use warnings;
use Mojo::Base 'Mojolicious';
use pf::dal;
use pf::file_paths qw($log_conf_dir);
use MojoX::Log::Log4perl;

has commands => sub {
  my $commands = Mojolicious::Commands->new(app => shift);
  Scalar::Util::weaken $commands->{app};
  unshift @{$commands->namespaces}, 'pf::UnifiedApi::Command';
  return $commands;
};

has log => sub {
    return MojoX::Log::Log4perl->new("$log_conf_dir/pfunified_api.conf",5 * 60);
};

=head2 startup

Setting up routes

=cut

our @API_V1_ROUTES = (
    { controller => 'users',     id_key => "user_id",   path => "/users" },
    { controller => 'tenants',   id_key => "tenant_id", path => "/tenants" },
    { controller => 'api_users', id_key => "user_id",   path => "/api_users" },
    { controller => 'locationlog', id_key => "locationlog_id", path => "/locationlog" },
    {
        controller     => 'tenants_onboarding',
        path           => "/tenants_onboarding",
        collection_v2a => { post => 'onboard' },
        resource_v2a   => {}
    },
    {
        controller     => 'users_nodes',
        path           => "/nodes",
        collection_v2a => { get => 'list' },
        resource_v2a   => {},
        parent         => 'Users.resource'
    },
    {
        controller     => 'users_password',
        path           => "/password",
        parent         => 'Users.resource',
        resource_v2a   => {},
        collection_v2a => {
            'get'    => 'get',
            'delete' => 'remove',
            'patch'  => 'update',
            'put'    => 'replace',
            'post'   => 'create'
        },
    },
    {
        controller => 'config-connection_profiles',
        id_key     => 'connection_profile_id',
        path       => '/config/connection_profiles'
    }
);

sub startup {
    my ($self) = @_;
    $self->routes->namespaces(['pf::UnifiedApi::Controller', 'pf::UnifiedApi']);
    $self->hook(before_dispatch => \&set_tenant_id);
    $self->plugin('pf::UnifiedApi::Plugin::RestCrud');
    $self->setup_api_v1_routes();
    $self->custom_startup_hook();
}

sub setup_api_v1_routes {
    my ($self) = @_;
    my $r = $self->routes;
    my $api_v1_route = $r->any("/api/v1")->name("api.v1");
    foreach my $route ($self->api_v1_routes) {
        $api_v1_route->rest_routes($route);
    }

    my $user_route = $api_v1_route->find('api.v1.Users.resource');
    $r->any(sub {
        my ($c) = @_;
        return $c->render(json => { message => "Unknown path", errors => [] }, status => 404);
    });
}

sub api_v1_routes {
    my ($self) = @_;
    return @API_V1_ROUTES, $self->api_v1_custom_routes;
}

sub api_v1_custom_routes {

}

sub custom_startup_hook {

}

sub set_tenant_id {
    my ($c) = @_;
    my $tenant_id = $c->req->headers->header('X-PacketFence-Tenant-Id');
    if (defined $tenant_id) {
        unless (pf::dal->set_tenant($tenant_id)) {
            $c->render(json => { message => "Invalid tenant id provided $tenant_id"}, status => 404);
        }
    } else {
        pf::dal->reset_tenant();
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

