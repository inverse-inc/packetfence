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
use pf::SwitchFactory;
pf::SwitchFactory->preloadAllModules();
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
                        reevaluate_access apply_security_event
                        close_security_event fingerbank_refresh
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
                    search bulk_register bulk_deregister bulk_close_security_events
                    bulk_reevaluate_access bulk_restart_switchport bulk_apply_security_event
                    bulk_apply_role bulk_apply_bypass_role bulk_fingerbank_refresh
                  )
            }
        }
    },
    ReadonlyEndpoint('NodeCategories'),
    ReadonlyEndpoint('Classes'),
    { 
        controller => 'SecurityEvents',
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
                'opensecurity_events'                                 => { get => 'opensecurity_events_all' },
                'opensecurity_events/active'                          => { get => 'opensecurity_events_active' },
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
        controller => 'Cluster',
        allow_singular => 1,
        collection => {
            subroutes => {
                'servers' => {get => "servers"},
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
    { 
        controller => 'Authentication',
        allow_singular => 1,
        collection => {
            subroutes    => {
                'admin_authentication' => { post => 'adminAuthentication' },
            },
        },      
    },
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
    foreach my $route ($self->api_v1_routes) {
        $api_v1_route->rest_routes($route);
    }

    $self->setup_api_v1_crud_routes($api_v1_route);
    $self->setup_api_v1_config_routes($api_v1_route->any("/config")->name("api.v1.Config"));
    $self->setup_api_v1_translations_routes($api_v1_route);
}

sub api_v1_routes {
    my ($self) = @_;
    return $self->api_v1_default_routes;
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

=head2 setup_api_v1_crud_routes

setup_api_v1_crud_routes

=cut

sub setup_api_v1_crud_routes {
    my ($self, $root) = @_;
    $self->setup_api_v1_tenants_routes($root);
    $self->setup_api_v1_locationlogs_routes($root);
    $self->setup_api_v1_dhcp_option82s_routes($root);
    $self->setup_api_v1_auth_logs_routes($root);
    $self->setup_api_v1_radius_audit_logs_routes($root);
    $self->setup_api_v1_wrix_locations_routes($root);
    return;
}

=head2 setup_api_v1_config_routes

setup api v1 config routes

=cut

sub setup_api_v1_config_routes {
    my ($self, $root) = @_;
    $self->setup_api_v1_config_admin_roles_routes($root);
    $self->setup_api_v1_config_bases_routes($root);
    $self->setup_api_v1_config_billing_tiers_routes($root);
    $self->setup_api_v1_config_certificates_routes($root);
    $self->setup_api_v1_config_connection_profiles_routes($root);
    $self->setup_api_v1_config_device_registrations_routes($root);
    $self->setup_api_v1_config_domains_routes($root);
    $self->setup_api_v1_config_filters_routes($root);
    $self->setup_api_v1_config_firewalls_routes($root);
    $self->setup_api_v1_config_floating_devices_routes($root);
    $self->setup_api_v1_config_maintenance_tasks_routes($root);
    $self->setup_api_v1_config_pki_providers_routes($root);
    $self->setup_api_v1_config_portal_modules_routes($root);
    $self->setup_api_v1_config_provisionings_routes($root);
    $self->setup_api_v1_config_realms_routes($root);
    $self->setup_api_v1_config_roles_routes($root);
    $self->setup_api_v1_config_scans_routes($root);
    $self->setup_api_v1_config_security_events_routes($root);
    $self->setup_api_v1_config_sources_routes($root);
    $self->setup_api_v1_config_switches_routes($root);
    $self->setup_api_v1_config_switch_groups_routes($root);
    $self->setup_api_v1_config_syslog_forwarders_routes($root);
    $self->setup_api_v1_config_syslog_parsers_routes($root);
    $self->setup_api_v1_config_traffic_shaping_policies_routes($root);
    return;
}

=head2 setup_api_v1_tenants_routes

setup_api_v1_tenants_routes

=cut

sub setup_api_v1_tenants_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "Tenants",
        "/tenants",
        "/tenant/#tenant_id",
        "api.v1.Tenant",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_locationlogs_routes

setup_api_v1_locationlogs_routes

=cut

sub setup_api_v1_locationlogs_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "Locationlogs",
        "/locationlogs",
        "/locationlog/#locationlog_id",
        "api.v1.Locationlogs",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_dhcp_option82s_routes

setup_api_v1_dhcp_option82s_routes

=cut

sub setup_api_v1_dhcp_option82s_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "DhcpOption82s",
        "/dhcp_option82s",
        "/dhcp_option82/#dhcp_option82_id",
        "api.v1.DhcpOption82s",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_auth_logs_routes

setup_api_v1_auth_logs_routes

=cut

sub setup_api_v1_auth_logs_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "AuthLogs",
        "/auth_logs",
        "/auth_log/#auth_log_id",
        "api.v1.AuthLogs",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_radius_audit_logs_routes

setup_api_v1_radius_audit_logs_routes

=cut

sub setup_api_v1_radius_audit_logs_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "RadiusAuditLogs",
        "/radius_audit_logs",
        "/radius_audit_log/#radius_audit_log_id",
        "api.v1.RadiusAuditLogs",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_wrix_locations_routes

setup_api_v1_wrix_locations_routes

=cut

sub setup_api_v1_wrix_locations_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "WrixLocations",
        "/wrix_Locations",
        "/wrix_location/#wrix_location_id",
        "api.v1.WrixLocations",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_std_crud_routes

setup_api_v1_std_crud_routes

=cut

sub setup_api_v1_std_crud_routes {
    my ($self, $root, $controller, $collection_path, $resource_path, $name) = @_;
    my $collection_route = $root->any($collection_path)->name($name);
    $self->setup_api_v1_std_crud_collection_routes($collection_route, $name, $controller);
    my $resource_route = $root->under($resource_path)->to("${controller}#resource")->name("${name}.resource");
    $self->setup_api_v1_std_crud_resource_routes($resource_route, "${name}.resource", $controller);
    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_std_crud_collection_routes

setup_api_v1_std_crud_collection_routes

=cut

sub setup_api_v1_std_crud_collection_routes {
    my ($self, $root, $name, $controller) = @_;
    $root->any(['GET'])->to("$controller#list" => {})->name("${name}.list");
    $root->any(['POST'])->to("$controller#create" => {})->name("${name}.create");
#    $root->any(['OPTIONS'])->to("$controller#options" => {})->name("${name}.options");
    $root->any(['POST'] => "/search")->to("$controller#search" => {})->name("${name}.search");
    return ;
}

=head2 setup_api_v1_std_crud_resource_routes

setup_api_v1_std_crud_resource_routes

=cut

sub setup_api_v1_std_crud_resource_routes {
    my ($self, $root, $name, $controller) = @_;
    $root->any(['GET'])->to("$controller#get" => {})->name("${name}.get");
    $root->any(['PATCH'])->to("$controller#update" => {})->name("${name}.update");
    $root->any(['PUT'])->to("$controller#replace" => {})->name("${name}.replace");
    $root->any(['DELETE'])->to("$controller#remove" => {})->name("${name}.remove");
#    $root->any(['OPTIONS'])->to("$controller#resource_options" => {})->name("${name}.resource_options");
    return ;
}

=head2 setup_api_v1_std_config_routes

setup_api_v1_std_config_routes

=cut

sub setup_api_v1_std_config_routes {
    my ($self, $root, $controller, $collection_path, $resource_path, $name) = @_;
    my $collection_route = $root->any($collection_path)->name($name);
    $self->setup_api_v1_std_config_collection_routes($collection_route, $name, $controller);
    my $resource_route = $root->under($resource_path)->to("${controller}#resource")->name("${name}.resource");
    $self->setup_api_v1_std_config_resource_routes($resource_route, "${name}.resource", $controller);
    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_std_config_collection_routes

setup_api_v1_standard_config_collection_routes

=cut

sub setup_api_v1_std_config_collection_routes {
    my ($self, $root, $name, $controller) = @_;
    $root->any(['GET'])->to("$controller#list" => {})->name("${name}.list");
    $root->any(['POST'])->to("$controller#create" => {})->name("${name}.create");
    $root->any(['OPTIONS'])->to("$controller#options" => {})->name("${name}.options");
    $root->any(['POST'] => "/search")->to("$controller#search" => {})->name("${name}.search");
    return ;
}

=head2 setup_api_v1_std_config_resource_routes

setup_api_v1_std_config_resource_routes

=cut

sub setup_api_v1_std_config_resource_routes {
    my ($self, $root, $name, $controller) = @_;
    $root->any(['GET'])->to("$controller#get" => {})->name("${name}.get");
    $root->any(['PATCH'])->to("$controller#update" => {})->name("${name}.update");
    $root->any(['PUT'])->to("$controller#replace" => {})->name("${name}.replace");
    $root->any(['DELETE'])->to("$controller#remove" => {})->name("${name}.remove");
    $root->any(['OPTIONS'])->to("$controller#resource_options" => {})->name("${name}.resource_options");
    return ;
}

=head2 setup_api_v1_config_admin_roles_routes

 setup_api_v1_config_admin_roles_routes

=cut

sub setup_api_v1_config_admin_roles_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::AdminRoles",
        "/admin_roles",
        "/admin_role/#admin_role_id",
        "api.v1.Config.AdminRoles"
    );

    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_bases_routes

 setup_api_v1_config_bases_routes

=cut

sub setup_api_v1_config_bases_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Bases",
        "/bases",
        "/base/#base_id",
        "api.v1.Config.Bases"
    );

    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_billing_tiers_routes

 setup_api_v1_config_billing_tiers_routes

=cut

sub setup_api_v1_config_billing_tiers_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::BillingTiers",
        "/billing_tiers",
        "/billing_tiers/#billing_tier_id",
        "api.v1.Config.BillingTiers"
    );

    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_device_registrations_routes

 setup_api_v1_config_device_registrations_routes

=cut

sub setup_api_v1_config_device_registrations_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::DeviceRegistrations",
        "/device_registrations",
        "/device_registration/#device_registration_id",
        "api.v1.Config.DeviceRegistrations"
    );

    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_domains_routes

 setup_api_v1_config_domains_routes

=cut

sub setup_api_v1_config_domains_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Domains",
        "/domains",
        "/domain/#domain_id",
        "api.v1.Config.Domains"
    );

    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_floating_devices_routes

 setup_api_v1_config_floating_devices_routes

=cut

sub setup_api_v1_config_floating_devices_routes {
    my ( $self, $root ) = @_;
    my ( $collection_route, $resource_route ) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::FloatingDevices",
        "/floating_devices",
        "/floating_device/#floating_device_id",
        "api.v1.Config.FloatingDevices"
      );

    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_maintenance_tasks_routes

 setup_api_v1_config_maintenance_tasks_routes

=cut

sub setup_api_v1_config_maintenance_tasks_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::MaintenanceTasks",
        "/maintenance_tasks",
        "/maintenance_task/#maintenance_task_id",
        "api.v1.Config.MaintenanceTasks"
      );

    return ($collection_route, $resource_route);
}


=head2 setup_api_v1_config_pki_providers_routes

 setup_api_v1_config_pki_providers_routes

=cut

sub setup_api_v1_config_pki_providers_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::PkiProviders",
        "/pki_providers",
        "/pki_provider/#pki_provider_id",
        "api.v1.Config.PkiProviders"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_portal_modules_routes

 setup_api_v1_config_portal_modules_routes

=cut

sub setup_api_v1_config_portal_modules_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::PortalModules",
        "/portal_modules",
        "/portal_module/#portal_module_id",
        "api.v1.Config.PortalModules"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_provisionings_routes

 setup_api_v1_config_provisionings_routes

=cut

sub setup_api_v1_config_provisionings_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Provisionings",
        "/provisionings",
        "/provisioning/#provisioning_id",
        "api.v1.Config.Provisionings"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_realms_routes

 setup_api_v1_config_realms_routes

=cut

sub setup_api_v1_config_realms_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Realms",
        "/realms",
        "/realm/#realm_id",
        "api.v1.Config.Realms"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_roles_routes

 setup_api_v1_config_roles_routes

=cut

sub setup_api_v1_config_roles_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Roles",
        "/roles",
        "/role/#role_id",
        "api.v1.Config.Roles"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_scans_routes

 setup_api_v1_config_scans_routes

=cut

sub setup_api_v1_config_scans_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Scans",
        "/scans",
        "/scan/#scan_id",
        "api.v1.Config.Scans"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_switch_groups_routes

 setup_api_v1_config_switch_groups_routes

=cut

sub setup_api_v1_config_switch_groups_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::SwitchGroups",
        "/switch_groups",
        "/switch_group/#switch_group_id",
        "api.v1.Config.SwitchGroups"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_syslog_forwarders_routes

 setup_api_v1_config_syslog_forwarders_routes

=cut

sub setup_api_v1_config_syslog_forwarders_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::SyslogForwarders",
        "/syslog_forwarders",
        "/syslog_forwarder/#syslog_forwarder_id",
        "api.v1.Config.SyslogForwarders"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_traffic_shaping_policies_routes

 setup_api_v1_config_traffic_shaping_policies_routes

=cut

sub setup_api_v1_config_traffic_shaping_policies_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::TrafficShapingPolicies",
        "/traffic_shaping_policies",
        "/traffic_shaping_policy/#traffic_shaping_policy_id",
        "api.v1.Config.TrafficShapingPolicies"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_security_events_routes

 setup_api_v1_config_security_events_routes

=cut

sub setup_api_v1_config_security_events_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::SecurityEvents",
        "/security_events",
        "/security_event/#security_event_id",
        "api.v1.Config.SecurityEvents"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_firewalls_routes

setup_api_v1_config_firewalls_routes

=cut

sub setup_api_v1_config_firewalls_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Firewalls",
        "/firewalls",
        "/firewall/#firewall_id",
        "api.v1.Config.Firewalls"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_connection_profiles_routes

setup_api_v1_config_connection_profiles_routes

=cut

sub setup_api_v1_config_connection_profiles_routes {
    my ($self, $root) = @_;
    my $controller = "Config::ConnectionProfiles";
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        $controller,
        "/connection_profiles",
        "/connection_profile/#connection_profile_id",
        "api.v1.Config.ConnectionProfiles"
    );

    my $name = "api.v1.Config.ConnectionProfiles.resource.files";
    my $files_route = $resource_route->any("/files")->name($name);
    $files_route->any(['GET'])->to("$controller#files" => {})->name("${name}.dir");
    my $file_route = $files_route->any("/*file_name")->name("${name}.file");
    $files_route->any(['GET'])->to("$controller#get_file" => {})->name("${name}.file.get");
    $files_route->any(['PATCH'])->to("$controller#replace_file" => {})->name("${name}.file.replace");
    $files_route->any(['PUT'])->to("$controller#new_file" => {})->name("${name}.file.new");
    $files_route->any(['DELETE'])->to("$controller#delete_file" => {})->name("${name}.file.delete");

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_switches_routes

setup_api_v1_config_switches_routes

=cut

sub setup_api_v1_config_switches_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Switches",
        "/switches",
        "/switch/#switch_id",
        "api.v1.Config.Switches"
    );

    $resource_route->any(['POST'] => "/invalidate_cache")->to("Config::Switches#invalidate_cache")->name("api.v1.Config.Switches.invalidate_cache");

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_sources_routes

setup_api_v1_config_sources_routes

=cut

sub setup_api_v1_config_sources_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::Sources",
        "/sources",
        "/source/#source_id",
        "api.v1.Config.Source"
    );

    $collection_route->any(['POST'] => "/test")->to("Config::Sources#test")->name("api.v1.Config.Sources.test");

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_syslog_parsers_routes

setup_api_v1_config_syslog_parsers_routes

=cut

sub setup_api_v1_config_syslog_parsers_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::SyslogParsers",
        "/syslog_parsers",
        "/syslog_parser/#syslog_parser_id",
        "api.v1.Config.SyslogParsers"
    );

    $collection_route->any(['POST'] => "/dry_run")->to("Config::SyslogParsers#dry_run")->name("api.v1.Config.SyslogParsers.dry_run");

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_filters_routes

setup_api_v1_config_filters_routes

=cut

sub setup_api_v1_config_filters_routes {
    my ($self, $root) = @_;
    my $resource_route = $root->any("/filter/#filter_id")->name("api.v1.Config.Filters.resource");
    $resource_route->any(['GET'])->to("Config::Filters#get")->name("api.v1.Config.Filters.resource.get");
    $resource_route->any(['PUT'])->to("Config::Filters#replace")->name("api.v1.Config.Filters.resource.replace");

    return (undef, $resource_route);
}

=head2 setup_api_v1_config_certificates_routes

setup_api_v1_config_certificates_routes

=cut

sub setup_api_v1_config_certificates_routes {
    my ($self, $root) = @_;
    my $resource_route = $root->any("/certificate/#certificate_id")->name("api.v1.Config.Certificates.resource");
    $resource_route->any(['GET'])->to("Config::Certificates#get")->name("api.v1.Config.Certificates.resource.get");
    $resource_route->any(['PUT'])->to("Config::Certificates#replace")->name("api.v1.Config.Certificates.resource.replace");
    $resource_route->any(['GET'] => "/info")->to("Config::Certificates#info")->name("api.v1.Config.Certificates.resource.info");
    $resource_route->any(['POST'] => "/generate_csr")->to("Config::Certificates#generate_csr")->name("api.v1.Config.Certificates.resource.generate_csr");

    return (undef, $resource_route);
}

=head2 setup_api_v1_translations_routes

setup_api_v1_translations_routes

=cut

sub setup_api_v1_translations_routes {
    my ($self, $root) = @_;
    my $collection_route = $root->any(['GET'] => "/translations")->to("Translations#list")->name("api.v1.Config.Translations.list");
    my $resource_route = $root->under("/translation/#translation_id")->to("Translations#resource")->name("api.v1.Config.Translations.resource");
    $resource_route->any(['GET'])->to("Translations#get")->name("api.v1.Config.Translations.resource.get");
    return ($collection_route, $resource_route);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
