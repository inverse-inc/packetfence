package pf::UnifiedApi::Controller::Config::Roles;

=head1 NAME

pf::UnifiedApi::Controller::Config::Roles - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Roles

=cut

use strict;
use warnings;
use pf::dal::node_category;
use pf::error qw(is_error);

use Mojo::Base qw(pf::UnifiedApi::Controller::Config);

has 'config_store_class' => 'pf::ConfigStore::Roles';
has 'form_class' => 'pfappserver::Form::Config::Roles';
has 'primary_key' => 'role_id';

use pf::ConfigStore::Roles;
use pfappserver::Form::Config::Roles;
use pfconfig::cached_hash;

tie our %RolesReverseLookup, 'pfconfig::cached_hash', 'resource::RolesReverseLookup';

sub can_delete {
    my ($self) = @_;
    my ($status, $msg) = $self->can_delete_from_db();
    if (is_error($status)) {
        return ($status, $msg);
    }

    ($status, $msg) = $self->can_delete_from_config();
    if (is_error($status)) {
        return ($status, $msg);
    }

    return (200, '');
}

sub can_delete_from_config {
    my ($self) = @_;
    if (exists $RolesReverseLookup{$self->id}) {
        return (422, 'Role still in use');
    }

    return (200, '');
}

my $CAN_DELETE_FROM_DB_SQL = <<SQL;
SELECT
    x.node_category_id && x.node_bypass_role_id && x.class_target_category && x.password_category AS `still_in_use`,
    x.*
    FROM (
    SELECT
        EXISTS (SELECT 1 FROM node, node_category WHERE (node.category_id = node_category.category_id ) AND node_category.name = ? LIMIT 1) as node_category_id,
        EXISTS (SELECT 1 FROM node, node_category WHERE (node.bypass_role_id = node_category.category_id ) AND node_category.name = ? LIMIT 1) as node_bypass_role_id,
        EXISTS (SELECT 1 FROM `class`, node_category WHERE `class`.target_category = ? LIMIT 1 ) as class_target_category,
        EXISTS (SELECT 1 FROM password, node_category WHERE password.category = node_category.category_id AND node_category.name = ? LIMIT 1) as password_category
) AS x;
SQL

sub can_delete_from_db {
    my ($self) = @_;
    my $id = $self->id;
    my ($status, $sth) = pf::dal::node_category->db_execute($CAN_DELETE_FROM_DB_SQL, $id, $id, $id, $id);
    if (is_error($status)) {
        return ($status, "Unable to check role in the database");
    }

    my $role_data = $sth->fetchrow_hashref;
    $sth->finish;
    if ($role_data->{still_in_use}) {
        return (422, 'Role still in use');
    }

    return (200, '');
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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

