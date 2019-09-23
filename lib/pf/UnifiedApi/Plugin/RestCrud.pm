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

our %ALLOWED_METHODS = (
    POST    => 1,
    GET     => 1,
    PATCH   => 1,
    PUT     => 1,
    DELETE  => 1,
    OPTIONS => 1,
);

sub register {
    my ($self, $app, $config) = @_;
    my $routes = $app->routes;
    $routes->add_shortcut( register_sub_actions => \&register_actions);
    $routes->add_shortcut( register_sub_action => \&register_action);
}

=head2 register_actions

$route->register_actions({
    method => 'GET',
    actions => ['action1', ...],
})

=cut

sub register_actions {
    my ($route, $args) = @_;
    my $method = $args->{method};
    if (!defined $method || !exists $ALLOWED_METHODS{$method}) {
        die "invalid method given ". ($method // "undef" );
    }
    my %subroutes;
    for my $action (@{$args->{actions}}) {
        $subroutes{$action} = $route->register_sub_action({method => $method, action => $action});
    }
    return \%subroutes;
}

=head2 register_action

my $new_route = $route->register_action({
    method => 'GET',
    action => 'action',
    controller => 'Controller',
    path   => '/action_path',
    name   => 'name',
});

The minimum needed

my $new_route = $route->register_action({
    method => 'GET',
    action => 'action',
});

Is the same as

my $new_route = $route->register_action({
    method => 'GET',
    action => 'action',
    path   => '/action',
    name   => 'action',
});

If no controller is defined then will use the parent route controller

=cut

sub register_action {
    my ($route, $args) = @_;
    my $method = delete $args->{method};
    if (!defined $method || !exists $ALLOWED_METHODS{$method}) {
        die "invalid method given ". ($method // "undef" );
    }

    my $action = $args->{action};
    if (!defined $action) {
        die "no action is defined"
    }

    my $path = delete $args->{path} // "/$action";
    my $name = delete $args->{name} // $action;
    return
      $route->any([$method] => $path)
            ->to(%$args)
            ->name( $route->name . ".$name" );
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

