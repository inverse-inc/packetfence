package pf::UnifiedApi::Plugin::RestCrud;

=head1 NAME

pf::UnifiedApi::Plugin::RestCrud -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Plugins::RestCrud

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Util qw(camelize);

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

sub munge_options {
    my ($route, $config) = @_;
    my $controller = $config->{controller};
    return undef unless defined $controller;
    my $name_prefix = $config->{name} // camelize($controller);
    my $parent_name = $route->name;
    if ($parent_name) {
        $name_prefix = "$parent_name.$name_prefix";
    }
    return {
        controller => $controller,
        name_prefix => $name_prefix,
        path => $config->{path} // "/$controller",
        id_key => $config->{id_key} // 'id',
        collection_v2a => get_collection_verb_to_actions($config),
        resource_v2a => get_resource_verb_to_actions($config),
        resource_verbs => $config->{resource_verbs} // [],
        parent => $config->{parent},
    };
}

our %ALLOWED_VERBS = (
    GET => 1,
    POST => 1,
    DELETE => 1,
    PUT => 1,
    PATCH => 1,
    OPTIONS => 1,
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
    register_verb_and_actions($r, $options->{controller}, $options->{name_prefix}, $options->{collection_v2a});
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

