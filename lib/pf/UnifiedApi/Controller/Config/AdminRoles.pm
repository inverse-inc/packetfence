package pf::UnifiedApi::Controller::Config::AdminRoles;

=head1 NAME

pf::UnifiedApi::Controller::Config::AdminRoles -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::AdminRoles

=cut

use strict;
use warnings;
use Mojo::Base qw(pf::UnifiedApi::Controller::Config);
use pf::ConfigStore::AdminRoles;
use pfappserver::Form::Config::AdminRoles;
use pf::config qw(%ConfigAdminRoles %Config);
use List::MoreUtils qw(uniq);
use pf::admin_roles;
use pf::dal::node_category;
use pf::nodecategory;

has 'config_store_class' => 'pf::ConfigStore::AdminRoles';
has 'form_class' => 'pfappserver::Form::Config::AdminRoles';
has 'primary_key' => 'admin_role_id';

sub cleanup_items {
    my ($self, $items) = @_;
    $items = $self->SUPER::cleanup_items($items);
    unshift @$items, $self->extra_items;
    return $items;
}

sub extra_items {
    my ($self) = @_;
    map {
        {
            id            => $_,
            actions       => [ keys %{ $ConfigAdminRoles{$_}{ACTIONS} } ],
            not_updatable => $self->json_false(),
        }
    } qw(NONE ALL ALL_PF_ONLY);
}

sub allowed_roles {
    my ($self) = @_;
    return $self->_allowed_roles("allowed_roles");
}

=head2 default_roles

default_roles

=cut

sub default_roles {
    my ($self) = @_;
    return map { {value => $_->{category_id}, text => $_->{name} } } nodecategory_view_all();
}

=head2 _allowed_roles

_allowed_roles

=cut

sub _allowed_roles {
    my ($self, $option) = @_;
    my @roles = admin_allowed_options( $self->stash->{admin_roles}, $option);
    my @items;
    if (@roles == 0) {
        @items = $self->default_roles();
    } else {
        my ($status, $iter) = pf::dal::node_category->search(
            -columns => [qw(category_id|value name|text)],
            -where => {
                name => \@roles,
            },
            -with_class => undef,
        );
        @items = $iter->all();
    }

    return $self->render( json => { items => \@items } );
}

sub allowed_node_roles {
    my ($self) = @_;
    return $self->_allowed_roles("allowed_node_roles");
}

sub allowed_access_levels {
    my ($self) = @_;
    my @options = admin_allowed_options( $self->stash->{admin_roles}, "allowed_access_levels" );
    if (@options == 0) {
        @options = $self->default_allowed_access_levels();
    }

    return $self->render(
        json => { items => [ map { { value => $_, text => $_ } } @options ] }
    );
}

=head2 default_allowed_access_levels

default_allowed_access_levels

=cut

sub default_allowed_access_levels {
    my ($self) = @_;
    return uniq qw(NONE ALL ALL_PF_ONLY), sort keys %ADMIN_ROLES;
}

sub allowed_actions {
    my ($self) = @_;
    my @options = admin_allowed_options( $self->stash->{admin_roles}, "allowed_actions" );
    if (@options == 0) {
        @options = $self->default_allowed_actions();
    }

    return $self->render(
        json => { items => [ map { { value => $_, text => $_ } } @options ] }
    );
}

=head2 default_allowed_actions

default_allowed_actions

=cut

sub default_allowed_actions {
    my ($self) = @_;
    return;
}

sub allowed_unreg_date {
    my ($self) = @_;
    my @options = admin_allowed_options( $self->stash->{admin_roles}, "allowed_unreg_date" );
    if (@options == 0) {
        @options = $self->default_allowed_unreg_date();
    }

    return $self->render(
        json => { items => [ map { { value => $_, text => $_ } } @options ] }
    );
}

=head2 default_allowed_unreg_date

default_allowed_unreg_date

=cut

sub default_allowed_unreg_date {
    my ($self) = @_;
    return;
}

sub allowed_access_durations {
    my ($self) = @_;
    my @options = admin_allowed_options( $self->stash->{admin_roles}, "allowed_access_durations" );
    if (@options == 0) {
        @options = $self->default_allowed_access_durations();
    }

    return $self->render(
        json => { items => [ map { { value => $_, text => $_ } } @options ] }
    );
}

=head2 default_allowed_access_durations

default_allowed_access_durations

=cut

sub default_allowed_access_durations {
    my ($self) = @_;
    return split (/\s*,\s*/, $Config{guests_admin_registration}{access_duration_choices});
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
