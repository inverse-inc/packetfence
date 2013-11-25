package captive::portal::Base::Controller;

=head1 NAME

captive::portal::Base::Controller add documentation

=cut

=head1 DESCRIPTION

captive::portal::Base::Controller

=cut

use Moose;
use Moose::Util qw(apply_all_roles);
use namespace::autoclean;
use pf::authentication;
use pf::config;
use pf::enforcement qw(reevaluate_access);
use pf::iplog qw(ip2mac);
use pf::node
  qw(node_attributes node_modify node_register node_view is_max_reg_nodes_reached);
use pf::os qw(dhcp_fingerprint_view);
use pf::useragent;
use pf::util;
use pf::violation qw(violation_count);
use pf::web::constants;
use pf::web;
BEGIN { extends 'Catalyst::Controller'; }

sub showError {
    my ( $self, $c, $error ) = @_;
    my $text_message;
    if ( ref($error) ) {
        $text_message = i18n_format(@$error);
    } else {
        $text_message = i18n($error);
    }
    $c->stash(
        template    => 'error.html',
        txt_message => $text_message,
    );
    $c->detach;
}

sub _parse_Hookable_attr {
    my ( $self, $c, $name, $value ) = @_;
    return Hookable => $value;
}

=head2 around create_action

Construction of a new Catalyst::Action.

See https://metacpan.org/module/Catalyst::Controller#self-create_action-args

=cut

around create_action => sub {
    my ( $orig, $self, %args ) = @_;
    my $action = $self->$orig(%args);
    return $action
      if ( $args{name} =~ /^_(DISPATCH|BEGIN|AUTO|ACTION|END)$/ );

    my $attributes = $args{attributes};
    return $action
      unless ( exists $attributes->{Hookable} );

    my $type = $attributes->{Hookable}->[0] || '';
    delete $attributes->{Hookable};
    if ( $type eq 'Private' ) {
        $attributes->{Private} = [];
    }
    my @roles;
    my $config = $self->_findActionHooksConfig( $args{name} );
    if ($config) {
        if ( $config->{override} ) {
            push @roles,
              $self->_addHookable( 'Override', $config->{override}, $action );
        } else {
            if ( $config->{after} ) {
                push @roles,
                  $self->_addHookable( 'After', $config->{after}, $action);
            }
            if ( $config->{before} ) {
                push @roles,
                  $self->_addHookable( 'Before', $config->{before}, $action );
            }
        }
    }
    apply_all_roles( $action, @roles ) if @roles;
    return $action;
};

sub _addHookable {
    my ( $self, $type, $args, $argsref ) = @_;
    $argsref->{"Hookable${type}Args"} =
      [ $self->_toArgs($args) ];
    return "captive::portal::Role::Action::Hookable::$type";

}

sub _findActionHooksConfig {
    my ( $self, $actionName ) = @_;
    my $config;
    my $hooksConfig = $self->_application->config->{Hooks};
    if ($hooksConfig) {
        my $controllerName = ref($self) || $self;
        $controllerName =~ s/^captive::portal::Controller:://;
        my $controllerHooksConfig = $hooksConfig->{$controllerName};
        if ($controllerHooksConfig) {
            $config = $controllerHooksConfig->{$actionName};
        }
    }
    return $config;
}

sub _toArgs {
    my ( $self, $args ) = @_;
    my ( $controller, $action ) = split / +/, $args;
    $action = 'index' unless $action;
    return ( $controller, $action );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
