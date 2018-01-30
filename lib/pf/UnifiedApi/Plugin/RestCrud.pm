package pf::UnifiedApi::Plugin::RestCrud;

=head1 NAME

pf::UnifiedApi::Plugin::RestCrud -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Plugins::RestCrud

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Lingua::EN::Inflexion qw(noun);
use Mojo::Util qw(decamelize camelize);
use Clone qw(clone);

sub register {
    my ($self, $app, $config) = @_;
    my $routes = $app->routes;
    $routes->add_shortcut( rest_routes => \&register_rest_routes);
}

sub register_rest_routes {
    my ($routes, $config) = @_;
    my $options = munge_options($routes, $config);
    unless (defined $options) {
        return;
    }

    if ($options->{parent}) {
        return register_child_routes($routes, $options);
    }

    my $name_prefix = $options->{name_prefix};
    my $r = $routes->any($options->{path})->name($name_prefix);
    register_collection_routes($r, $options);
    if (keys %{$options->{resource_v2a}}) {
        my $id_key = $options->{id_key};
        my $item_path = "/:$id_key";
        register_resource_routes($r->under($item_path => [ $id_key => qr/[^\/]+/])->to("$options->{controller}#resource")->name("$name_prefix.resource"), $options);
    }
}

sub register_child_routes {
    my ($route, $options) = @_;
    my $name_prefix = delete $options->{parent};
    my $parent_name = $route->name;
    if ($parent_name) {
        $name_prefix = "$parent_name.$name_prefix";
    }
    my $r = $route->find($name_prefix);
    return $r->rest_routes( $options);
}

our %ALLOWED_VERBS = (
    GET => 1,
    POST => 1,
    DELETE => 1,
    PUT => 1,
    PATCH => 1,
    OPTIONS => 1,
);

our %DEFAULT_RESOURCE_OPTIONS = (
    subroutes     => {},
    http_methods => {
        GET    => 'get',
        PATCH  => 'update',
        PUT    => 'replace',
        DELETE => 'remove',
    },
);

our %DEFAULT_COLLECTION_OPTIONS = (
    subroutes     => {},
    http_methods => {
        GET    => 'list',
        POST   => 'create',
    },
);


our %ALLOWED_METHODS = (
    POST   => 1,
    GET    => 1,
    PATCH  => 1,
    PUT    => 1,
    DELETE => 1,
);


our %DEFAULT_COLLECTION_VERBS_TO_ACTIONS = (
    GET => 'list',
    POST => 'create',
);

our %DEFAULT_RESOURCE_VERBS_TO_ACTIONS = (
    GET    => 'get',
    DELETE => 'remove',
    PATCH  => 'update',
    PUT    => 'replace'
);

sub get_collection_verb_to_actions {
    my ($config) = @_;
    return verb_to_actions(
        $config->{collection_v2a} // {%DEFAULT_COLLECTION_VERBS_TO_ACTIONS}
    );
}

sub verb_to_actions {
    my ($temp) = @_;
    my %filtered;
    my %v2a;
    while (my ($v, $a) = each %$temp) {
        $v = uc($v);
        next unless exists $ALLOWED_VERBS{$v};
        $v2a{$v} = $a;
    }
    return \%v2a;
}

sub get_resource_verb_to_actions {
    my ($config) = @_;
    return verb_to_actions(
        $config->{resource_v2a} // {%DEFAULT_RESOURCE_VERBS_TO_ACTIONS}
    );
}

sub register_collection_routes {
    my ($r, $options) = @_;
    my ($controller, $name_prefix) = @{$options}{qw(controller name_prefix)};
    register_verb_and_actions($r, $controller, $name_prefix, $options->{collection_v2a});
    for my $route (@{$options->{collection_additional_routes} }) {
        $r->post("/$route")->to("$controller#$route")->name("$name_prefix.$route");
    }
}

sub register_verb_and_actions {
    my ($r, $controller, $name_prefix, $verbs_to_action) = @_;
    while (my ($v,$a) = each %$verbs_to_action) {
        $r->any([$v])->to("$controller#$a")->name("$name_prefix.$a");
    }
}

sub register_resource_routes {
    my ($r, $options) = @_;
    my ($controller, $name_prefix) = @{$options}{qw(controller name_prefix)};
    register_verb_and_actions($r, $controller, $name_prefix, $options->{resource_v2a});
    for my $verb (@{$options->{resource_verbs} }) {
        $r->post("/$verb")->to("$controller#$verb")->name("$name_prefix.$verb");
    }
}

sub munge_options {
    my ($route, $options) = @_;
    my $controller = $options->{controller};
    if (!defined $controller || $controller eq '' ) {
        die "Controller not given";
    }
    my $decamelized = decamelize($controller);
    my @paths = split(/-/,$decamelized);
    my $short_name = pop @paths;
    if (@paths) {
        unshift @paths, '';
    }
    my $base_url = join ('/', @paths);
    my $noun = noun($short_name);
    if ($noun->is_singular) {
        die "$controller cannot be singular noun";
    }
    %$options = (%$options, short_name => $short_name, noun => $noun, decamelized => $decamelized, base_url => $base_url);
    return {
        controller  => $controller,
        name_prefix => munge_name_prefix_option( $route, $options ),
        resource    => munge_resource_options( $route, $options ),
        collection  => munge_collection_options( $route, $options ),
    };
}

sub munge_name_prefix_option {
    my ($route, $options) = @_;
    my $name_prefix = $options->{controller};
    my $parent_name = $route->name;
    if ($parent_name) {
        $name_prefix = "$parent_name.$name_prefix";
    }
    return $name_prefix;
}

sub munge_resource_options {
    my ($route, $options) = @_;
    my $resource = exists $options->{resource} ? $options->{resource} : \%DEFAULT_RESOURCE_OPTIONS;
    if (!defined $resource) {
        return undef;
    }
    $resource  = clone($resource);
    add_defaults($resource, \%DEFAULT_RESOURCE_OPTIONS);
    my $http_methods = $resource->{http_methods};
    if (!defined $http_methods || keys %$http_methods == 0 ) {
        die "http_methods is empty for $options->{controller}";
    }
    my $singular = $options->{noun}->singular();
    my $url_param_key = "${singular}_id";
    $resource->{url_param_key} //= $url_param_key;
    $resource->{path} //= "$options->{base_url}/$singular/:$url_param_key";
    $resource->{subroutes} = clean_subroutes($resource->{subroutes});
    $resource->{http_methods} = cleanup_http_methods($resource->{http_methods});
    $resource->{children} = munge_children_options( $route, $options );
    return $resource;
}

sub clean_subroutes {
    my ($subroutes) = @_;
    my %hash;
    while (my ($k, $v) = each %{$subroutes // {}}) {
        $hash{$k} = cleanup_http_methods($v);
    }
    return \%hash;
}

sub cleanup_http_methods {
    my ($methods) = @_;
    my %temp;
    while (my ($k, $v) = each %$methods) {
        $k = uc($k);
        if (exists $ALLOWED_METHODS{$k}) {
            $temp{$k} = $v;
        }
    }
    return \%temp;
}

sub add_defaults {
    my ($hash, $defaults) = @_;
    while (my ($k, $v) = each %$defaults) {
        if (!exists $hash->{$k}) {
            $hash->{$k} = clone($v);
        }
    }
}

sub munge_collection_options {
    my ($route, $options) = @_;
    my $collection = exists $options->{collection} ? 
        $options->{collection} : 
        \%DEFAULT_COLLECTION_OPTIONS;
    if (!defined $collection) {
        return undef;
    }
    $collection  = clone($collection);
    $collection->{path} //= "$options->{base_url}/$options->{short_name}";
    $collection->{subroutes} = clean_subroutes($collection->{subroutes}); 
    return $collection;
}

sub munge_children_options {
    my ($route, $options) = @_;
    return [
        map { local $_ = $_; my $o = $_; munge_options($route, clone($o))} @{$options->{children} // []}
    ];
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

