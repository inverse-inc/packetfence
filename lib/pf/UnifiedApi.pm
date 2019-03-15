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
    $self->setup_api_v1_crud_routes($api_v1_route);
    $self->setup_api_v1_config_routes($api_v1_route->any("/config")->name("api.v1.Config"));
    $self->setup_api_v1_reports_routes($api_v1_route);
    $self->setup_api_v1_services_routes($api_v1_route);
    $self->setup_api_v1_cluster_routes($api_v1_route);
    $self->setup_api_v1_authentication_routes($api_v1_route);
    $self->setup_api_v1_queues_routes($api_v1_route);
    $self->setup_api_v1_translations_routes($api_v1_route);
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
    $self->setup_api_v1_users_routes($root);
    $self->setup_api_v1_nodes_routes($root);
    $self->setup_api_v1_tenants_routes($root);
    $self->setup_api_v1_locationlogs_routes($root);
    $self->setup_api_v1_dhcp_option82s_routes($root);
    $self->setup_api_v1_auth_logs_routes($root);
    $self->setup_api_v1_radius_audit_logs_routes($root);
    $self->setup_api_v1_wrix_locations_routes($root);
    $self->setup_api_v1_security_events_routes($root);
    $self->setup_api_v1_node_categories_routes($root);
    $self->setup_api_v1_classes_routes($root);
    $self->setup_api_v1_ip4logs_routes($root);
    $self->setup_api_v1_ip6logs_routes($root);
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
    $self->setup_api_v1_config_fingerbank_settings_routes($root);
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

=head2 setup_api_v1_ip4logs_routes

setup_api_v1_ip4logs_routes

=cut

sub setup_api_v1_ip4logs_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "Ip4logs",
        "/ip4logs",
        "/ip4log/#ip4log_id",
        "api.v1.Ip4logs",
    );

    $collection_route->any(['GET'] => "/history/#search")->to("Ip4logs#history")->name("api.v1.Ip4logs.history");
    $collection_route->any(['GET'] => "/archive/#search")->to("Ip4logs#archive")->name("api.v1.Ip4logs.archive");
    $collection_route->any(['GET'] => "/open/#search")->to("Ip4logs#open")->name("api.v1.Ip4logs.open");
    $collection_route->any(['GET'] => "/mac2ip/#mac")->to("Ip4logs#mac2ip")->name("api.v1.Ip4logs.mac2ip");
    $collection_route->any(['GET'] => "/ip2mac/#ip")->to("Ip4logs#ip2mac")->name("api.v1.Ip4logs.ip2mac");

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_ip6logs_routes

setup_api_v1_ip6logs_routes

=cut

sub setup_api_v1_ip6logs_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "Ip6logs",
        "/ip6logs",
        "/ip6log/#ip6log_id",
        "api.v1.Ip6logs",
    );

    $collection_route->any(['GET'] => "/history/#search")->to("Ip6logs#history")->name("api.v1.Ip6logs.history");
    $collection_route->any(['GET'] => "/archive/#search")->to("Ip6logs#archive")->name("api.v1.Ip6logs.archive");
    $collection_route->any(['GET'] => "/open/#search")->to("Ip6logs#open")->name("api.v1.Ip6logs.open");
    $collection_route->any(['GET'] => "/mac2ip/#mac")->to("Ip6logs#mac2ip")->name("api.v1.Ip6logs.mac2ip");
    $collection_route->any(['GET'] => "/ip2mac/#ip")->to("Ip6logs#ip2mac")->name("api.v1.Ip6logs.ip2mac");

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_users_routes

setup_api_v1_users_routes

=cut

sub setup_api_v1_users_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "Users",
        "/users",
        "/user/#user_id",
        "api.v1.Users"
    );

    $self->add_subroutes($collection_route, "Users", "POST", qw(unassign_nodes));
    my ($sub_collection_route, $sub_resource_route) = 
      $self->setup_api_v1_std_crud_routes(
        $resource_route,
        "Users::Nodes",
        "/nodes",
        "/node/#node_id",
        "api.v1.Users.resource.Nodes"
    );

    $self->setup_api_v1_std_crud_routes(
        $sub_resource_route,
        "Users::Nodes::Locationlogs",
        "/locationlogs",
        "/locationlog/#locationlog_id",
        "api.v1.Users.resource.Nodes.Locationlogs"
    );

    my $password_route = $resource_route->any("/password");
    $password_route->any(['GET'])->to("Users::Password#get")->name("api.v1.Users.resource.Password.get");
    $password_route->any(['DELETE'])->to("Users::Password#remove")->name("api.v1.Users.resource.Password.remove");
    $password_route->any(['PATCH'])->to("Users::Password#update")->name("api.v1.Users.resource.Password.update");
    $password_route->any(['PUT'])->to("Users::Password#replace")->name("api.v1.Users.resource.Password.replace");
    $password_route->any(['POST'])->to("Users::Password#create")->name("api.v1.Users.resource.Password.create");

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_nodes_routes

setup_api_v1_nodes_routes

=cut

sub setup_api_v1_nodes_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "Nodes",
        "/nodes",
        "/node/#node_id",
        "api.v1.Nodes"
    );

    $self->add_subroutes(
        $resource_route, "Nodes", 'POST',
        qw( register deregister restart_switchport reevaluate_access apply_security_event close_security_event fingerbank_refresh)
    );
    $self->add_subroutes(
        $resource_route, "Nodes", 'GET',
        qw(fingerbank_info)
    );
    $self->add_subroutes(
        $collection_route, "Nodes", 'POST',
        qw(
          bulk_register bulk_deregister bulk_close_security_events
          bulk_reevaluate_access bulk_restart_switchport bulk_apply_security_event
          bulk_apply_role bulk_apply_bypass_role bulk_fingerbank_refresh
          )
    );

    return ( $collection_route, $resource_route );
}


=head2 add_subroutes

add_subroutes

=cut

sub add_subroutes {
    my ($self, $root, $controller, $method, @subroutes) = @_;
    my $name = $root->name;
    for my $subroute (@subroutes) {
        $root
          ->any([$method] => "/$subroute")
          ->to("$controller#$subroute")
          ->name("${name}.$subroute");
    }
    return ;
}

=head2 setup_api_v1_security_events_routes

setup_api_v1_security_events_routes

=cut

sub setup_api_v1_security_events_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_routes(
        $root,
        "SecurityEvents",
        "/security_events",
        "/security_event/#security_event_id",
        "api.v1.SecurityEvents",
    );

    $collection_route->any(['GET'] => '/by_mac/#search')->to("SecurityEvents#by_mac")->name("api.v1.SecurityEvents.by_mac");
    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_node_categories_routes

setup_api_v1_node_categories_routes

=cut

sub setup_api_v1_node_categories_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_readonly_routes(
        $root,
        "NodeCategories",
        "/node_categories",
        "/node_category/#node_category_id",
        "api.v1.NodeCategories",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_classes_routes

setup_api_v1_classes_routes

=cut

sub setup_api_v1_classes_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_crud_readonly_routes(
        $root,
        "Classes",
        "/classes",
        "/class/#class_id",
        "api.v1.Classes",
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
        "/wrix_locations",
        "/wrix_location/#wrix_location_id",
        "api.v1.WrixLocations",
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_std_crud_readonly_routes

setup_api_v1_std_crud_readonly_routes

=cut

sub setup_api_v1_std_crud_readonly_routes {
    my ($self, $root, $controller, $collection_path, $resource_path, $name) = @_;
    my $collection_route = $root->any($collection_path)->name($name);
    $collection_route->any(['GET'])->to("$controller#list")->name("${name}.list");
    $collection_route->any(['POST'] => "/search")->to("$controller#search")->name("${name}.search");
    my $resource_route = $root->under($resource_path)->to("${controller}#resource")->name("${name}.resource");
    $resource_route->any(['GET'])->to("$controller#get")->name("${name}.resource.get");
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
    $root->any(['GET'])->to("$controller#list")->name("${name}.list");
    $root->any(['POST'])->to("$controller#create")->name("${name}.create");
#    $root->any(['OPTIONS'])->to("$controller#options" => {})->name("${name}.options");
    $root->any(['POST'] => "/search")->to("$controller#search")->name("${name}.search");
    return ;
}

=head2 setup_api_v1_std_crud_resource_routes

setup_api_v1_std_crud_resource_routes

=cut

sub setup_api_v1_std_crud_resource_routes {
    my ($self, $root, $name, $controller) = @_;
    $root->any(['GET'])->to("$controller#get")->name("${name}.get");
    $root->any(['PATCH'])->to("$controller#update")->name("${name}.update");
    $root->any(['PUT'])->to("$controller#replace")->name("${name}.replace");
    $root->any(['DELETE'])->to("$controller#remove")->name("${name}.remove");
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
    $root->any(['PATCH'] => "/sort_items")->to("$controller#sort_items" => {})->name("${name}.sort_items");
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
        "/billing_tier/#billing_tier_id",
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

    $self->setup_api_v1_config_connection_profiles_files_routes($controller, $resource_route);
    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_connection_profiles_files_routes

setup_api_v1_config_connection_profiles_files_routes

=cut

sub setup_api_v1_config_connection_profiles_files_routes {
    my ($self, $controller, $root) = @_;
    my $name = "api.v1.Config.ConnectionProfiles.resource.files";
    my $files_route = $root->any("/files")->name($name);
    $files_route->any(['GET'])->to("$controller#files" => {})->name("${name}.dir");
    my $file_route = $files_route->any("/*file_name")->name("${name}.file");
    $file_route->any(['GET'])->to("$controller#get_file" => {})->name("${name}.file.get");
    $file_route->any(['PATCH'])->to("$controller#replace_file" => {})->name("${name}.file.replace");
    $file_route->any(['PUT'])->to("$controller#new_file" => {})->name("${name}.file.new");
    $file_route->any(['DELETE'])->to("$controller#delete_file" => {})->name("${name}.file.delete");

    return ;
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
    my $collection_route = $root->any(['GET'] => '/filters')->to(controller => "Config::Filters", action => 'list')->name("api.v1.Config.Filters.list");
    my $resource_route = $root->under("/filter/#filter_id")->to(controller => "Config::Filters", action => "resource")->name("api.v1.Config.Filters.resource");
    $resource_route->any(['GET'])->to(action => "get")->name("api.v1.Config.Filters.resource.get");
    $resource_route->any(['PUT'])->to(action=> "replace")->name("api.v1.Config.Filters.resource.replace");

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_fingerbank_settings_routes

setup_api_v1_config_fingerbank_settings_routes

=cut

sub setup_api_v1_config_fingerbank_settings_routes {
    my ($self, $root) = @_;
    my ($collection_route, $resource_route) =
      $self->setup_api_v1_std_config_routes(
        $root,
        "Config::FingerbankSettings",
        "/fingerbank_settings",
        "/fingerbank_setting/#fingerbank_setting_id",
        "api.v1.Config.FingerbankSettings"
    );

    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_config_certificates_routes

setup_api_v1_config_certificates_routes

=cut

sub setup_api_v1_config_certificates_routes {
    my ($self, $root) = @_;
    
    $root->any("/certificates/lets_encrypt/test")->any(['GET'])->to("Config::Certificates#lets_encrypt_test")->name("api.v1.Config.Certificates.list.lets_encrypt_test");

    my $resource_route = $root->any("/certificate/#certificate_id")->name("api.v1.Config.Certificates.resource");
    $resource_route->any(['GET'])->to("Config::Certificates#get")->name("api.v1.Config.Certificates.resource.get");
    $resource_route->any(['PUT'])->to("Config::Certificates#replace")->name("api.v1.Config.Certificates.resource.replace");
    $resource_route->any(['GET'] => "/info")->to("Config::Certificates#info")->name("api.v1.Config.Certificates.resource.info");
    $resource_route->any(['POST'] => "/generate_csr")->to("Config::Certificates#generate_csr")->name("api.v1.Config.Certificates.resource.generate_csr");
    $resource_route->any(['PUT'] => "/lets_encrypt")->to("Config::Certificates#lets_encrypt_replace")->name("api.v1.Config.Certificates.resource.lets_encrypt_replace");

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

=head2 setup_api_v1_reports_routes

setup_api_v1_reports_routes

=cut

sub setup_api_v1_reports_routes {
    my ( $self, $root ) = @_;
    my $collection_route = $root->any("/reports");
    $collection_route
      ->any(['GET'] => "/os")
      ->to("Reports#os_all")
      ->name("api.v1.Reports.os_all");
    $collection_route
      ->any(['GET'] => "/os/#start/#end")
      ->to("Reports#os_range")
      ->name("api.v1.Reports.os_range");
    $collection_route
      ->any(['GET'] => "/os/active")
      ->to("Reports#os_active")
      ->name("api.v1.Reports.os_active");
    $collection_route
      ->any(['GET'] => "/osclass")
      ->to("Reports#osclass_all")
      ->name("api.v1.Reports.osclass_all");
    $collection_route
      ->any(['GET'] => "/osclass/active")
      ->to("Reports#osclass_active")
      ->name("api.v1.Reports.osclass_active");
    $collection_route
      ->any(['GET'] => "/inactive")
      ->to("Reports#inactive_all")
      ->name("api.v1.Reports.inactive_all");
    $collection_route
      ->any(['GET'] => "/active")
      ->to("Reports#active_all")
      ->name("api.v1.Reports.active_all");
    $collection_route
      ->any(['GET'] => "/unregistered")
      ->to("Reports#unregistered_all")
      ->name("api.v1.Reports.unregistered_all");
    $collection_route
      ->any(['GET'] => "/unregistered/active")
      ->to("Reports#unregistered_active")
      ->name("api.v1.Reports.unregistered_active");
    $collection_route
      ->any(['GET'] => "/registered")
      ->to("Reports#registered_all")
      ->name("api.v1.Reports.registered_all");
    $collection_route
      ->any(['GET'] => "/registered/active")
      ->to("Reports#registered_active")
      ->name("api.v1.Reports.registered_active");
    $collection_route
      ->any(['GET'] => "/unknownprints")
      ->to("Reports#unknownprints_all")
      ->name("api.v1.Reports.unknownprints_all");
    $collection_route
      ->any(['GET'] => "/unknownprints/active")
      ->to("Reports#unknownprints_active")
      ->name("api.v1.Reports.unknownprints_active");
    $collection_route
      ->any(['GET'] => "/statics")
      ->to("Reports#statics_all")
      ->name("api.v1.Reports.statics_all");
    $collection_route
      ->any(['GET'] => "/statics/active")
      ->to("Reports#statics_active")
      ->name("api.v1.Reports.statics_active");
    $collection_route
      ->any(['GET'] => "/opensecurity_events")
      ->to("Reports#opensecurity_events_all")
      ->name("api.v1.Reports.opensecurity_events_all");
    $collection_route
      ->any(['GET'] => "/opensecurity_events/active")
      ->to("Reports#opensecurity_events_active")
      ->name("api.v1.Reports.opensecurity_events_active");
    $collection_route
      ->any(['GET'] => "/connectiontype")
      ->to("Reports#connectiontype_all")
      ->name("api.v1.Reports.connectiontype_all");
    $collection_route
      ->any(['GET'] => "/connectiontype/#start/#end")
      ->to("Reports#connectiontype_range")
      ->name("api.v1.Reports.connectiontype_range");
    $collection_route
      ->any(['GET'] => "/connectiontype/active")
      ->to("Reports#connectiontype_active")
      ->name("api.v1.Reports.connectiontype_active");
    $collection_route
      ->any(['GET'] => "/connectiontypereg")
      ->to("Reports#connectiontypereg_all")
      ->name("api.v1.Reports.connectiontypereg_all");
    $collection_route
      ->any(['GET'] => "/connectiontypereg/active")
      ->to("Reports#connectiontypereg_active")
      ->name("api.v1.Reports.connectiontypereg_active");
    $collection_route
      ->any(['GET'] => "/ssid")
      ->to("Reports#ssid_all")
      ->name("api.v1.Reports.ssid_all");
    $collection_route
      ->any(['GET'] => "/ssid/#start/#end")
      ->to("Reports#ssid_range")
      ->name("api.v1.Reports.ssid_range");
    $collection_route
      ->any(['GET'] => "/ssid/active")
      ->to("Reports#ssid_active")
      ->name("api.v1.Reports.ssid_active");
    $collection_route
      ->any(['GET'] => "/osclassbandwidth")
      ->to("Reports#osclassbandwidth_all")
      ->name("api.v1.Reports.osclassbandwidth_all");
    $collection_route
      ->any(['GET'] => "/osclassbandwidth/#start/#end")
      ->to("Reports#osclassbandwidth_range")
      ->name("api.v1.Reports.osclassbandwidth_range");
    $collection_route
      ->any(['GET'] => "/osclassbandwidth/day")
      ->to("Reports#osclassbandwidth_day")
      ->name("api.v1.Reports.osclassbandwidth_day");
    $collection_route
      ->any(['GET'] => "/osclassbandwidth/week")
      ->to("Reports#osclassbandwidth_week")
      ->name("api.v1.Reports.osclassbandwidth_week");
    $collection_route
      ->any(['GET'] => "/osclassbandwidth/month")
      ->to("Reports#osclassbandwidth_month")
      ->name("api.v1.Reports.osclassbandwidth_month");
    $collection_route
      ->any(['GET'] => "/osclassbandwidth/year")
      ->to("Reports#osclassbandwidth_year")
      ->name("api.v1.Reports.osclassbandwidth_year");
    $collection_route
      ->any(['GET'] => "/nodebandwidth")
      ->to("Reports#nodebandwidth_all")
      ->name("api.v1.Reports.nodebandwidth_all");
    $collection_route
      ->any(['GET'] => "/nodebandwidth/#start/#end")
      ->to("Reports#nodebandwidth_range")
      ->name("api.v1.Reports.nodebandwidth_range");
    $collection_route
      ->any(['GET'] => "/topauthenticationfailures/mac/#start/#end")
      ->to("Reports#topauthenticationfailures_by_mac")
      ->name("api.v1.Reports.topauthenticationfailures_by_mac");
    $collection_route
      ->any(['GET'] => "/topauthenticationfailures/ssid/#start/#end")
      ->to("Reports#topauthenticationfailures_by_ssid")
      ->name("api.v1.Reports.topauthenticationfailures_by_ssid");
    $collection_route
      ->any(['GET'] => "/topauthenticationfailures/username/#start/#end")
      ->to("Reports#topauthenticationfailures_by_username")
      ->name("api.v1.Reports.topauthenticationfailures_by_username");
    $collection_route
      ->any(['GET'] => "/topauthenticationsuccesses/mac/#start/#end")
      ->to("Reports#topauthenticationsuccesses_by_mac")
      ->name("api.v1.Reports.topauthenticationsuccesses_by_mac");
    $collection_route
      ->any(['GET'] => "/topauthenticationsuccesses/ssid/#start/#end")
      ->to("Reports#topauthenticationsuccesses_by_ssid")
      ->name("api.v1.Reports.topauthenticationsuccesses_by_ssid");
    $collection_route
      ->any(['GET'] => "/topauthenticationsuccesses/username/#start/#end")
      ->to("Reports#topauthenticationsuccesses_by_username")
      ->name("api.v1.Reports.topauthenticationsuccesses_by_username");
    $collection_route
      ->any(['GET'] => "/topauthenticationsuccesses/computername/#start/#end")
      ->to("Reports#topauthenticationsuccesses_by_computername")
      ->name("api.v1.Reports.topauthenticationsuccesses_by_computername");
    return ( $collection_route, undef );
}

=head2 setup_api_v1_cluster_routes

setup_api_v1_cluster_routes

=cut

sub setup_api_v1_cluster_routes {
    my ($self, $root) = @_;
    my $resource_route = $root->any("/cluster");
    $resource_route->any(['GET'] => "/servers")->to("Cluster#servers")->name("api.v1.Cluster.servers");
    return (undef, $resource_route);
}

=head2 setup_api_v1_services_routes

setup_api_v1_services_routes

=cut

sub setup_api_v1_services_routes {
    my ($self, $root) = @_;
    my $collection_route = $root->any("/services")->name("api.v1.Config.Services");
    $collection_route->any(['GET'])->to("Services#list")->name("api.v1.Config.Services.list");
    $self->add_subroutes($collection_route, "Services", "GET", qw(cluster_status));
    my $resource_route = $root->under("/service/#service_id")->to("Services#resource")->name("api.v1.Config.Services.resource");
    $self->add_subroutes($resource_route, "Services", "GET", qw(status));
    $self->add_subroutes($resource_route, "Services", "POST", qw(start stop restart enable disable));
    return ($collection_route, $resource_route);
}

=head2 setup_api_v1_authentication_routes

setup_api_v1_authentication_routes

=cut

sub setup_api_v1_authentication_routes {
    my ($self, $root) = @_;
    my $route = $root->any("/authentication");
    $route->any(['POST'] => "/admin_authentication")->to("Authentication#adminAuthentication")->name("api.v1.Authentication.admin_authentication");
    return ;
}

=head2 setup_api_v1_queues_routes

setup_api_v1_queues_routes

=cut

sub setup_api_v1_queues_routes {
    my ($self, $root) = @_;
    my $route = $root->any("/queues");
    $route->any(['GET'] => "/stats")->to("Queues#stats")->name("api.v1.Queues.stats");
    return ;
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
