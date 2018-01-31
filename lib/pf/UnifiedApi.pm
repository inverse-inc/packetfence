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
    },
    { controller => 'violations', resource_v2a => {}, collection_v2a => { get => 'list' }, path => '/violations' },
    { controller => 'violations', resource_v2a => {}, collection_v2a => { get => 'list_by_search' }, path => '/violations/:search' },
    { controller => 'reports', collection_v2a => { get => 'os' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/os' },
    { controller => 'reports', collection_v2a => { get => 'os_active' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/os_active' },
    { controller => 'reports', collection_v2a => { get => 'os_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/os_all' },
    { controller => 'reports', collection_v2a => { get => 'osclass_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/osclass_all' },
    { controller => 'reports', collection_v2a => { get => 'osclass_active' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/osclass_active' },
    { controller => 'reports', collection_v2a => { get => 'inactive_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/inactive_all' },
    { controller => 'reports', collection_v2a => { get => 'active_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/active_all' },
    { controller => 'reports', collection_v2a => { get => 'unregistered_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/unregistered_all' },
    { controller => 'reports', collection_v2a => { get => 'unregistered_active' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/unregistered_active' },
    { controller => 'reports', collection_v2a => { get => 'registered_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/registered_all' },
    { controller => 'reports', collection_v2a => { get => 'registered_active' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/registered_active' },
    { controller => 'reports', collection_v2a => { get => 'unknownprints_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/unknownprints_all' },
    { controller => 'reports', collection_v2a => { get => 'unknownprints_active' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/unknownprints_active' },
    { controller => 'reports', collection_v2a => { get => 'statics_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/statics_all' },
    { controller => 'reports', collection_v2a => { get => 'statics_active' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/statics_active' },
    { controller => 'reports', collection_v2a => { get => 'openviolations_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/openviolations_all' },
    { controller => 'reports', collection_v2a => { get => 'openviolations_active' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/openviolations_active' },
    { controller => 'reports', collection_v2a => { get => 'connectiontype' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/connectiontype' },
    { controller => 'reports', collection_v2a => { get => 'connectiontype_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/connectiontype_all' },
    { controller => 'reports', collection_v2a => { get => 'connectiontype_active' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/connectiontype_active' },
    { controller => 'reports', collection_v2a => { get => 'connectiontypereg_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/connectiontypereg_all' },
    { controller => 'reports', collection_v2a => { get => 'connectiontypereg_active' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/connectiontypereg_active' },
    { controller => 'reports', collection_v2a => { get => 'ssid' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/ssid' },
    { controller => 'reports', collection_v2a => { get => 'ssid_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/ssid_all' },
    { controller => 'reports', collection_v2a => { get => 'ssid_active' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/ssid_active' },
    { controller => 'reports', collection_v2a => { get => 'osclassbandwidth' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/osclassbandwidth' },
    { controller => 'reports', collection_v2a => { get => 'osclassbandwidth_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/osclassbandwidth_all' },
    { controller => 'reports', collection_v2a => { get => 'nodebandwidth' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/nodebandwidth' },
    { controller => 'reports', collection_v2a => { get => 'nodebandwidth_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/nodebandwidth_all' },
    { controller => 'reports', collection_v2a => { get => 'topsponsor_all' }, resource_v2a => {},  id_key => 'report_id', path => '/reports/topsponsor_all' },

    { controller => 'nodes', collection_v2a => { get => 'latest_locationlog_by_mac' }, resource_v2a => {}, path => '/nodes/:mac/latest_locationlog' },
    { controller => 'nodes', collection_v2a => { get => 'locationlog_by_mac' }, resource_v2a => {}, path => '/nodes/:mac/locationlog' },
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

