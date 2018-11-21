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
use pf::util qw(add_jitter);
use pf::file_paths qw($log_conf_dir);
use MojoX::Log::Log4perl;
use pf::UnifiedApi::Controller;
our $MAX_REQUEST_HANDLED = 2000;
our $REQUEST_HANDLED_JITTER = 500;

has commands => sub {
  my $commands = Mojolicious::Commands->new(app => shift);
  Scalar::Util::weaken $commands->{app};
  unshift @{$commands->namespaces}, 'pf::UnifiedApi::Command';
  return $commands;
};

has log => sub {
    return MojoX::Log::Log4perl->new("$log_conf_dir/pfperl-api.conf",5 * 60);
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
                    resource => undef,
                    allow_singular => 1,
                    collection => {
                        http_methods => {
                            'get'    => 'get',
                            'delete' => 'remove',
                            'patch'  => 'update',
                            'put'    => 'replace',
                            'post'   => 'create'
                        }
                    },
                }
            ],
          subroutes => {
            unassign_nodes => {
                post => 'unassign_nodes',
            },
          },
        },
    },
    {
        controller => 'Nodes',
        resource   => {
            subroutes => {
                (
                map { $_ => { post => $_ } }
                    qw(
                        register deregister restart_switchport
                        reevaluate_access apply_violation
                        close_violation fingerbank_refresh
                    )
                ),
                fingerbank_info => {
                    get => 'fingerbank_info',
                }
            }
        },
        collection => {
            subroutes => {
                map { $_ => { post => $_ } }
                  qw(
                    search bulk_register bulk_deregister bulk_close_violations
                    bulk_reevaluate_access bulk_restart_switchport bulk_apply_violation
                    bulk_apply_role bulk_apply_bypass_role bulk_fingerbank_refresh
                  )
            }
        }
    },
    { controller => 'Tenants' },
    { controller => 'Locationlogs' },
    ReadonlyEndpoint('NodeCategories'),
    ReadonlyEndpoint('Classes'),
    { 
        controller => 'Violations',
        collection => {
            subroutes    => {
                'by_mac/#search' => { get => 'by_mac' },
                'search' => {
                    'post' => 'search'
                },
            },
        },      
    },
    {
        controller  => 'Reports',
        resource    => undef,
        collection => {
            http_methods => undef,
            subroutes => {
                'os'                                                  => { get => 'os_all' },
                'os/#start/#end'                                      => { get => 'os_range' },
                'os/active'                                           => { get => 'os_active' },
                'osclass'                                             => { get => 'osclass_all' },
                'osclass/active'                                      => { get => 'osclass_active' },
                'inactive'                                            => { get => 'inactive_all' },
                'active'                                              => { get => 'active_all' },
                'unregistered'                                        => { get => 'unregistered_all' },
                'unregistered/active'                                 => { get => 'unregistered_active' },
                'registered'                                          => { get => 'registered_all' },
                'registered/active'                                   => { get => 'registered_active' },
                'unknownprints'                                       => { get => 'unknownprints_all' },
                'unknownprints/active'                                => { get => 'unknownprints_active' },
                'statics'                                             => { get => 'statics_all' },
                'statics/active'                                      => { get => 'statics_active' },
                'openviolations'                                      => { get => 'openviolations_all' },
                'openviolations/active'                               => { get => 'openviolations_active' },
                'connectiontype'                                      => { get => 'connectiontype_all' },
                'connectiontype/#start/#end'                          => { get => 'connectiontype_range' },
                'connectiontype/active'                               => { get => 'connectiontype_active' },
                'connectiontypereg'                                   => { get => 'connectiontypereg_all' },
                'connectiontypereg/active'                            => { get => 'connectiontypereg_active' },
                'ssid'                                                => { get => 'ssid_all' },
                'ssid/#start/#end'                                    => { get => 'ssid_range' },
                'ssid/active'                                         => { get => 'ssid_active' },
                'osclassbandwidth'                                    => { get => 'osclassbandwidth_all' },
                'osclassbandwidth/#start/#end'                        => { get => 'osclassbandwidth_range' },
                'osclassbandwidth/day'                                => { get => 'osclassbandwidth_day' },
                'osclassbandwidth/week'                               => { get => 'osclassbandwidth_week' },
                'osclassbandwidth/month'                              => { get => 'osclassbandwidth_month' },
                'osclassbandwidth/year'                               => { get => 'osclassbandwidth_year' },
                'nodebandwidth'                                       => { get => 'nodebandwidth_all' },
                'nodebandwidth/#start/#end'                           => { get => 'nodebandwidth_range' },
                'topauthenticationfailures/mac/#start/#end'           => { get => 'topauthenticationfailures_by_mac' },
                'topauthenticationfailures/ssid/#start/#end'          => { get => 'topauthenticationfailures_by_ssid' },
                'topauthenticationfailures/username/#start/#end'      => { get => 'topauthenticationfailures_by_username' },
                'topauthenticationsuccesses/mac/#start/#end'          => { get => 'topauthenticationsuccesses_by_mac' },
                'topauthenticationsuccesses/ssid/#start/#end'         => { get => 'topauthenticationsuccesses_by_ssid' },
                'topauthenticationsuccesses/username/#start/#end'     => { get => 'topauthenticationsuccesses_by_username' },
                'topauthenticationsuccesses/computername/#start/#end' => { get => 'topauthenticationsuccesses_by_computername' },
            },
        },
    },
    { controller => 'DhcpOption82s' },
    { controller => 'AuthLogs' },
    {
        controller  => 'Ip4logs',
        collection => {
            subroutes => {
                'history/#search' => { get => 'history' },
                'archive/#search' => { get => 'archive' },
                'open/#search' => { get => 'open' },
                'mac2ip/#mac' => { get => 'mac2ip' },
                'ip2mac/#ip'  => { get => 'ip2mac' },
                'search' => {
                    'post' => 'search'
                },
            },
        },
    },
    {
        controller  => 'Ip6logs',
        collection => {
            subroutes => {
                'history/#search' => { get => 'history' },
                'archive/#search' => { get => 'archive' },
                'open/#search' => { get => 'open' }, 
                'mac2ip/#mac' => { get => 'mac2ip' },
                'ip2mac/#ip'  => { get => 'ip2mac' },
                'search' => {
                    'post' => 'search'
                },
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
            },
            subroutes => {
                'cluster_status' => { get => 'cluster_status' },
            },
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
        Config::Provisionings
        Config::Realms
        Config::Roles
        Config::Scans
        Config::SwitchGroups
        Config::SyslogForwarders
        Config::TrafficShapingPolicies
        Config::Violations
    ),
    {
        controller => 'Config::Switches',
        resource   => {
            subroutes => {
                invalidate_cache => {
                    post => 'invalidate_cache',
                }
            }
        }
    },
    {
        controller => 'Config::Filters',
        collection => undef,
        resource => {
            http_methods => {
                get => 'get',
                put => 'replace',
            },
            subroutes => undef,
        },
    },
    {
        controller => 'Config::SyslogParsers',
        collection => {
            subroutes => {
                map { $_ => { post => $_ } } qw(search dry_run)
            }
        }
    },
    {
        controller => 'Config::Sources',
        collection   => {
            subroutes => {
                test => {
                    post => 'test',
                }
            }
        },
    },
    {
        controller => 'Translations',
        collection => {
            http_methods => {
                get => "list",
            },
            subroutes => undef,
        },
        resource => {
            http_methods => {
                get => "get",
            },
            subroutes => undef,
        },
    },
    'WrixLocations',
    {
        controller => 'Queues',
        collection => {
            subroutes    => {
                'stats' => {
                    get => 'stats'
                },
            },
        },
        resource => undef,
    },
);

sub startup {
    my ($self) = @_;
    $self->controller_class('pf::UnifiedApi::Controller');
    $self->routes->namespaces(['pf::UnifiedApi::Controller', 'pf::UnifiedApi']);
    $self->hook(before_dispatch => \&before_dispatch_cb);
    $self->hook(after_dispatch => \&after_dispatch_cb);
    $self->hook(before_render => \&before_render_cb);
    $self->plugin('pf::UnifiedApi::Plugin::RestCrud');
    $self->setup_api_v1_routes();
    $self->custom_startup_hook();
    $self->routes->any( '/*', sub {
        my ($c) = @_;
        return $c->unknown_action;
    });

    return;
}

=head2 before_render_cb

before_render_cb

=cut

sub before_render_cb {
    my ($self, $args) = @_;
    my $json = $args->{json};
    return unless $json;
    $json->{status} //= ($args->{status} // 200);
}

=head2 after_dispatch_cb

after_dispatch_cb

=cut

sub after_dispatch_cb {
    my ($c) = @_;
    my $app = $c->app;
    my $max = $app->{max_requests_handled} //= add_jitter( $MAX_REQUEST_HANDLED, $REQUEST_HANDLED_JITTER );
    if (++$app->{requests_handled} >= $max) {
        kill 'QUIT', $$;
    }
    return;
}

=head2 before_dispatch_cb

before_dispatch_cb

=cut

sub before_dispatch_cb {
    my ($c) = @_;
    # To allow dispatching with encoded slashes
    $c->stash->{path} = $c->req->url->path;
    set_tenant_id($c)
}

sub setup_api_v1_routes {
    my ($self) = @_;
    my $r = $self->routes;
    my $api_v1_route = $r->any("/api/v1")->name("api.v1");
    $api_v1_route->options('/*', sub {
        my ($c) = @_;
        $c->res->headers->header('Access-Control-Allow-Methods' => 'GET, OPTIONS, POST, DELETE, PUT, PATCH');
        $c->respond_to(any => { data => '', status => 200 });
    });
    foreach my $route ($self->api_v1_routes) {
        $api_v1_route->rest_routes($route);
    }
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

=head2 ReadonlyEndpoint

ReadonlyEndpoint

=cut

sub ReadonlyEndpoint {
    my ($model) = @_;
    return {
        controller => $model,
        collection => {
            http_methods => {
                'get'    => 'list',
            },
            subroutes => {
                map { $_ => { post => $_ } } qw(search)
            }
        },
        resource => {
            http_methods => {
                'get'    => 'get',
            },
        },
    },
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

