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

has commands => sub {
  my $commands = Mojolicious::Commands->new(app => shift);
  Scalar::Util::weaken $commands->{app};
  unshift @{$commands->namespaces}, 'pf::UnifiedApi::Command';
  return $commands;
};

=head2 startup

Setting up routes

=cut

our @API_V1_ROUTES = (
    {controller => 'users', id_key => "user_id", path => "/users"},
    {controller => 'tenants', id_key => "tenant_id", path => "/tenants"},
    {controller => 'api_users', id_key => "user_id", path => "/api_users"},
    {controller => 'tenants_onboarding', path => "/tenants_onboarding", collection_v2a => {post => 'onboard'} , resource_v2a => {}},
);

sub startup {
    my ($self) = @_;
    $self->hook(before_dispatch => \&set_tenant_id);
    $self->plugin('pf::UnifiedApi::Plugin::RestCrud');
    $self->setup_api_v1_routes();
}

sub setup_api_v1_routes {
    my ($self) = @_;
    my $r = $self->routes;
    my $api_v1_route = $r->any("/api/v1")->name("api.v1");
    foreach my $route (@API_V1_ROUTES) {
        $api_v1_route->rest_routes($route);
    }
    my $user_route = $api_v1_route->find('api.v1.Users.resource');
    die "Cannot find route api.v1.Users.resource" unless $user_route;
    $user_route->get("/nodes")->to("users_nodes#get")->name("api.v1.Users.resource.Nodes.get");
    $r->any(sub {
        my ($c) = @_;
        return $c->render(json => { message => "Unknown path", errors => [] }, status => 404);
    });
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

