package pf::UnifiedApi::Controller::Users::Nodes;

=head1 NAME

pf::UnifiedApi::Controller::Users::Nodes -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Users::Nodes

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::person;
use pf::node;
use pf::enforcement;
use pf::admin_roles;
use pf::UnifiedApi::Controller::Nodes ();

has 'dal' => 'pf::dal::node';
has 'url_param_name' => 'node_id';
has 'primary_key' => 'mac';
has 'parent_primary_key_map' => sub { {user_id => 'pid'} };
has 'url_parent_ids' =>  sub { [qw(user_id)] };

=head2 validate

The nodes of a user are validated like the nodes (roles, bypass role, bypass
VLAN and ACLs, MAC address)

=cut

sub validate {
    my ($self, $json) = @_;
    return pf::UnifiedApi::Controller::Nodes::validate($self, $json);
}

=head2 validate_bypass_acls

validate_bypass_acls

=cut

sub validate_bypass_acls {
    my ($self, @args) = @_;
    return pf::UnifiedApi::Controller::Nodes::validate_bypass_acls($self, @args);
}

=head2 can_create

Creating a node of a user requires NODES_CREATE

=cut

sub can_create {
    my ($self) = @_;
    return $self->_can_manage_nodes('NODES_CREATE');
}

=head2 can_update

Updating a node of a user requires NODES_UPDATE

=cut

sub can_update {
    my ($self) = @_;
    return $self->_can_manage_nodes('NODES_UPDATE');
}

=head2 can_remove

Removing a node of a user requires NODES_DELETE, and the node must be
removable like with the nodes API

=cut

sub can_remove {
    my ($self) = @_;
    my ($status, $msg) = $self->_can_manage_nodes('NODES_DELETE');
    return ($status, $msg) if $status != 200;
    my ($result, $error) = pf::node::_can_delete($self->id);
    return $result ? (200, '') : (422, $error);
}

sub _can_manage_nodes {
    my ($self, $action) = @_;
    my $roles = $self->stash->{admin_roles} // [];
    # Without admin roles, the request doesn't come from the admin API frontend
    if (@$roles && !admin_can($roles, $action)) {
        return (403, "$action is required");
    }

    return (200, '');
}

=head2 post_update

Reevaluate the access of the node when its role or status changes

=cut

sub post_update {
    my ($self, $updated_data) = @_;
    if (exists $updated_data->{category_id} || exists $updated_data->{status}) {
        pf::enforcement::reevaluate_access($self->id, "admin_modify");
    }

    return;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
