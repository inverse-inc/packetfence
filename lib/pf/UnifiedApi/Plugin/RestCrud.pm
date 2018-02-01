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

our %DEFAULT_RESOURCE_OPTIONS = (
    subroutes    => {},
    http_methods => {
        GET => {
            action => 'get',
        },
        PATCH => {
            action => 'update',
        },
        PUT => {
            action => 'replace',
        },
        DELETE => {
            action => 'remove',
        }
    },
);

our %DEFAULT_COLLECTION_OPTIONS = (
    subroutes    => {},
    http_methods => {
        GET => {
            action => 'list',
        },
        POST => {
            action => 'create',
        }
    },
);

our %ALLOWED_METHODS = (
    POST   => 1,
    GET    => 1,
    PATCH  => 1,
    PUT    => 1,
    DELETE => 1,
);

sub register {
    my ($self, $app, $config) = @_;
    my $routes = $app->routes;
    $routes->add_shortcut( rest_routes => \&register_rest_routes);
}

sub register_rest_routes {
    my ($routes, $config) = @_;
    my $options = munge_options($routes, $config);
    if (!defined $options) {
        return die "Route options is invalid";
    }

    my $name_prefix = $options->{name_prefix};
    my $collection_options = $options->{collection};
    if (defined $collection_options) {
        my $r = $routes->any($collection_options->{path})->name($name_prefix);
        register_collection_routes($r, $options, $collection_options);
    }
    my $resource_options = $options->{resource};
    if (defined $resource_options) {
        my $r = $routes->under($resource_options->{path} => [ $resource_options->{url_param_key} => qr/[^\/]+/])->to("$options->{controller}#resource")->name("$name_prefix.resource");
        register_resource_routes($r, $options, $resource_options);
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

sub register_collection_routes {
    my ($r, $options, $collection_options) = @_;
    my ($controller, $name_prefix) = @{$options}{qw(controller name_prefix)};
    register_http_methods($r, $controller, $name_prefix, $collection_options->{http_methods});
    register_subroutes($r, $controller, $name_prefix, $collection_options->{subroutes});
}

sub register_http_methods {
    my ($r, $controller, $name_prefix, $http_methods) = @_;
    while (my ($v, $d) = each %{$http_methods // {} }) {
        my $a = delete $d->{action};
        $r->any([$v])->to("$controller#$a" => $d)->name("$name_prefix.$a");
    }
}

sub register_resource_routes {
    my ($r, $options, $resource_options) = @_;
    my ($controller, $name_prefix) = @{$options}{qw(controller name_prefix)};
    register_http_methods($r, $controller, $name_prefix, $resource_options->{http_methods});
    register_subroutes($r, $controller, $name_prefix, $resource_options->{subroutes});
    register_children($r, $options, $resource_options);
}

sub register_children {
    my ($r, $options, $resource_options) = @_;
    for my $child (@{$resource_options->{children} // []}) {
        $r->rest_routes($child);
    }
}

sub register_subroutes {
    my ($r, $controller, $name_prefix, $subroutes) = @_;
    while (my ($subroute_name, $http_methods) = each %{$subroutes}) {
        if (!defined $http_methods || keys %{$http_methods} == 0 ) {
            die "Cannot register sub route ${name_prefix}.$subroute_name invalid http methods defined";
        }
        my $subroute = $r->any("/$subroute_name");
        register_http_methods($subroute, $controller, $name_prefix, $http_methods);
    }
}

sub munge_options {
    my ($route, $options) = @_;
    my $controller = $options->{controller};
    if (!defined $controller || $controller eq '' ) {
        die "Controller not given";
    }
    my $path_part = $route->pattern->unparsed || '';
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
    my $name_prefix = $options->{name_prefix} // munge_name_prefix_option( $route, $options );
    %$options = (
        %$options,
        short_name  => $short_name,
        noun        => $noun,
        decamelized => $decamelized,
        base_url    => $base_url,
        name_prefix => $name_prefix
    );
    my $resource = munge_resource_options( $route, $options );
    $options->{resource} = $resource;

    return {
        controller  => $controller,
        name_prefix => $name_prefix,
        parent_path => munge_parent_path( $route, $options),
        resource    => $resource,
        collection  => munge_collection_options( $route, $options ),
    };
}

sub munge_parent_path {
    my ($route, $options) = @_;
    my $path_part = $route->pattern->unparsed || '';
    my $parent_path = $options->{parent_path} // '';
    return "${parent_path}${path_part}";
}

sub munge_name_prefix_option {
    my ($route, $options) = @_;
    my $name_prefix = $options->{controller};
    my $parent_name = $options->{parent_name} // $route->name;
    if ($parent_name) {
        $name_prefix = "$parent_name.$name_prefix";
    }
    return $name_prefix;
}

sub munge_resource_options {
    my ($route, $options) = @_;
    my $resource = munge_standard_options($options, 'resource', \%DEFAULT_RESOURCE_OPTIONS);
    if (!defined $resource) {
        return undef;
    }
    if (!defined $resource->{http_methods}) {
        die "$options->{controller}.resources.http_methods is undefined";
    }
    my $singular = $options->{noun}->singular();
    my $url_param_key = "${singular}_id";
    $resource->{url_param_key} //= $url_param_key;
    my $base_path = "$options->{base_url}/$singular";
    $resource->{base_path} = $base_path;
    $resource->{path} //= "$base_path/:$url_param_key";
    $resource->{children} = munge_children_options( $route, $options, $resource );
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
    if (!defined $methods) {
        return undef;
    }
    my %temp;
    while (my ($k, $v) = each %$methods) {
        $k = uc($k);
        if (exists $ALLOWED_METHODS{$k}) {
            $temp{$k} = ref($v) ? clone ($v) : {action => $v};
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

sub munge_standard_options {
    my ($options, $name, $defaults) = @_;
    my $suboptions = exists $options->{$name} ?
        $options->{$name} :
        $defaults;
    if (!defined $suboptions) {
        return undef;
    }
    $suboptions = clone($suboptions);
    add_defaults($suboptions, $defaults);
    my $http_methods = $suboptions->{http_methods};
    if (defined $http_methods && keys %$http_methods == 0 ) {
        die "$name.http_methods is empty for $options->{controller}";
    }
    $suboptions->{subroutes} = clean_subroutes($suboptions->{subroutes});
    $suboptions->{http_methods} = cleanup_http_methods($suboptions->{http_methods});
    return $suboptions;
}

sub munge_collection_options {
    my ($route, $options) = @_;
    my $collection = munge_standard_options($options, 'collection', \%DEFAULT_COLLECTION_OPTIONS);
    if (!defined $collection) {
        return undef;
    }
    $collection->{path} //= "$options->{base_url}/$options->{short_name}";
    return $collection;
}

sub munge_child_options {
    my ($route, $parent_options, $child_options, $resource) = @_;
    my $parent_name = $parent_options->{name_prefix};
    $child_options->{parent_name} = $parent_name;
    $child_options->{parent_path} = $resource->{path};
    return munge_options($route, $child_options);
}

sub munge_children_options {
    my ($route, $options, $resource) = @_;
    return [
        map {
            local $_ = $_;
            my $o = $_;
            $o = clone($o);
            munge_child_options($route, $options, $o, $resource)
        } @{$resource->{children} // []}
    ];
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

