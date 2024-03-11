package pf::UnifiedApi::Controller::CurrentUser;

=head1 NAME

pf::UnifiedApi::Controller::CurrentUser -

=head1 DESCRIPTION

pf::UnifiedApi::Controller::CurrentUser

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::admin_roles qw(admin_allowed_options %ADMIN_ROLES);
use pf::Authentication::constants;
use pf::nodecategory;
use pf::config qw(%Config %ConfigRoles);
use List::Util qw(maxstr);

sub _allowed_options {
    my ($self, $option, $key, $standard_options) = @_;
    my $roles = $self->stash->{admin_roles};
    my @options = admin_allowed_options($roles, $option);
    if (@options == 0) {
        @options = $standard_options->($self, $option);
    }

    return $self->render_items($key, @options);
}

sub _allowed_roles {
    my ($self, $option) = @_;
    my $admin_roles = $self->stash->{admin_roles};
    my @options = admin_allowed_options($admin_roles, $option);
    my @roles;
    if (@options == 0) {
        @roles = nodecategory_view_all();
    } else {
        @roles = nodecategory_view_by_names(@options);
    }

    return $self->render( json => {items => \@roles});
}

sub get_all_roles {
    sort keys %ConfigRoles
}

sub allowed_user_unreg_date {
    my ($self) = @_;
    my $admin_roles = $self->stash->{admin_roles};
    my @options = admin_allowed_options($admin_roles, 'allowed_unreg_date');
    if (@options == 0) {
        return $self->render(json => { items => [] });
    }

    return $self->render(json => { items => [ maxstr @options ] });
}

sub allowed_user_roles {
    my ($self) = @_;
    return $self->_allowed_roles('allowed_roles');
}

sub allowed_user_access_levels {
    my ($self) = @_;
    return $self->_allowed_options('allowed_access_levels', 'access_level', sub { sort keys %ADMIN_ROLES } );
}

sub allowed_user_actions {
    my ($self) = @_;
    return $self->_allowed_options('allowed_actions', 'action', sub { map { @$_ } values %Actions::ACTIONS });
}

sub allowed_user_access_durations {
    my ($self) = @_;
    return $self->_allowed_options('allowed_access_durations', 'access_duration', sub { split(/\s*,\s*/, $Config{'guests_admin_registration'}{'access_duration_choices'}) } );
}

sub allowed_node_roles {
    my ($self) = @_;
    return $self->_allowed_roles('allowed_node_roles');
}

sub render_items {
    my ($self, $key, @items) = @_;
    return $self->render(
        json => {
            items => [ map {  { $key => $_ } } @items]
        }
    );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
