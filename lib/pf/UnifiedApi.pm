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
    {
        controller => 'Users',
        resource   => {
            children => [
                {
                    controller => 'Users::Nodes',
                    resource => {
                        children => [ 'Users::Nodes::Locationlogs' ],
                    }
                },
                {
                    controller => 'Users::Password',
                    collection => undef,
                    allow_singular => 1,
                    resource => {
                        http_methods => {
                            'get'    => 'get',
                            'delete' => 'remove',
                            'patch'  => 'update',
                            'put'    => 'replace',
                            'post'   => 'create'
                        }
                    },
                }
            ]
        },
    },
    { controller => 'Nodes' },
    { controller => 'Tenants' },
    { controller => 'ApiUsers' },
    { controller => 'Locationlogs' },
    { 
        controller => 'Violations',
        collection => {
            subroutes    => {
                'by_mac/:search' => { get => 'by_mac' },                
            },
        },      
    },
    {
        controller  => 'Reports',
        resource    => undef,
        collection => {
            http_methods => undef,
            subroutes => {
                map { $_ => { get => $_ } }
                  qw (
                  os
                  os_active
                  os_all
                  osclass_all
                  osclass_active
                  inactive_all
                  active_all
                  unregistered_all
                  unregistered_active
                  registered_all
                  registered_active
                  unknownprints_all
                  unknownprints_active
                  statics_all
                  statics_active
                  openviolations_all
                  openviolations_active
                  connectiontype
                  connectiontype_all
                  connectiontype_active
                  connectiontypereg_all
                  connectiontypereg_active
                  ssid
                  ssid_all
                  ssid_active
                  osclassbandwidth
                  osclassbandwidth_all
                  nodebandwidth
                  nodebandwidth_all
                  topsponsor_all
                  )
            },
        },
    },
    { controller => 'DhcpOption82s' },
    {
        controller  => 'Ip4logs',
        collection => {
            subroutes    => {
                'history/:search' => { get => 'history' },
                'archive/:search' => { get => 'archive' },
                'open/:search' => { get => 'open' }, 
            },
        },
    },    
    { 
        controller => 'Services',
        resource   => {
            subroutes => {
                'status'  => { get => 'status' },
                'start'   => { post => 'start' },
                'stop'    => { post => 'stop' },
                'restart' => { post => 'restart' },
                'enable'  => { post => 'enable' },
                'disable' => { post => 'disable' },
            },
        },
        collection => {
            http_methods => {
                get => 'list',
            }
        },
    },
    { controller => 'RadiusAuditLogs' },
    { 
        controller => 'Authentication',
        allow_singular => 1,
        collection => {
            subroutes    => {
                'admin_authentication' => { post => 'adminAuthentication' },
            },
        },      
    },
    qw(
        Config::AdminRoles
        Config::Bases
        Config::BillingTiers
        Config::ConnectionProfiles
        Config::DeviceRegistrations
        Config::Domains
        Config::Firewalls
        Config::FloatingDevices
        Config::MaintenanceTasks
        Config::PkiProviders
        Config::PortalModules
        Config::Realms
        Config::Roles
        Config::Scans
        Config::Sources
        Config::Switches
        Config::SwitchGroups
        Config::SyslogParsers
        Config::TrafficShapingPolicies
        Config::Violations
    ),
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

    $r->any(sub {
        my ($c) = @_;
        return $c->render(json => { message => "Unknown path", errors => [] }, status => 404);
    });
}

sub api_v1_routes {
    my ($self) = @_;
    return $self->api_v1_default_routes, $self->api_v1_custom_routes;
}

sub api_v1_default_routes {
    @API_V1_ROUTES
}

sub api_v1_custom_routes {

}

sub custom_startup_hook {

}

=head2 set_tenant_id

Set the tenant ID to the one specified in the header, or reset it to the default one if there is none

=cut

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

