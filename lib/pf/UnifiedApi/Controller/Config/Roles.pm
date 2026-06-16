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
use pf::error qw(is_error is_success);

use Mojo::Base qw(pf::UnifiedApi::Controller::Config);

has 'config_store_class' => 'pf::ConfigStore::Roles';
has 'form_class' => 'pfappserver::Form::Config::Roles';
has 'primary_key' => 'role_id';

use pf::ConfigStore::Roles;
use pfappserver::Form::Config::Roles;
use pf::config qw(%ConfigRoles %Config);
use pfconfig::cached_hash;
use pf::config::cluster;
use pf::dal::node;
use pf::dal::person;
use pf::enforcement;
use pf::ConfigStore::AdminRoles;
use pf::ConfigStore::Scan;
use pf::ConfigStore::Provisioning;
use pf::ConfigStore::SelfService;
use pf::ConfigStore::BillingTiers;
use pf::ConfigStore::Firewall_SSO;
use pf::ConfigStore::Switch;
use pf::ConfigStore::Source;
use pf::ConfigStore::PortalModule;
use pf::api::queue;

tie our %RolesReverseLookup, 'pfconfig::cached_hash', 'resource::RolesReverseLookup';

sub post_update {
    my ($self, $id) = @_;
    # Submit to background queue - API returns immediately
    my $client = pf::api::queue->new(queue => 'general');
    $client->notify('generate_ansible_configuration_all_switches');
}


sub can_delete {
    my ($self) = @_;
    my ($db_status, $db_msg, $db_errors) = $self->can_delete_from_db();
    if (is_error($db_status) && !defined $db_errors) {
        return ($db_status, $db_msg);
    }

    my ($config_status, $config_msg, $config_errors) = $self->can_delete_from_config();
    if (is_error($config_status) || is_error($db_status)) {
        return (422, 'Role still in use', [ @{$db_errors // []}, @{$config_errors // []} ]  );
    }

    return (200, '');
}

sub cleanup_item {
    my ($self, $item, $form) = @_;
    $item = $self->SUPER::cleanup_item($item, $form);
    my $id = $item->{id};
    if (defined $id && exists $ConfigRoles{$id}) {
        $item->{children} = $ConfigRoles{$id}{children};
    }

    return $item;
}

sub standardPlaceholder {
    my ($self) = @_;
    my $placeholder = $self->SUPER::standardPlaceholder;
    if (ref $placeholder eq 'HASH') {
        # The default_role_parent_id role's own parent_id leaks into the
        # parent_id field placeholder via the form's default_method (fired
        # by cleanup_item's `init_object + posted=0` processing). Suppress
        # it — the form's `default` already pre-selects the default parent
        # for new roles, and clearing the dropdown should show nothing.
        delete $placeholder->{parent_id};
    }
    return $placeholder;
}

sub cleanupItemForCreate {
    my ($self, $item) = @_;
    if (!exists $item->{parent_id}) {
        my $default_parent = $Config{advanced}{default_role_parent_id};
        if (defined $default_parent && length $default_parent
            && $default_parent ne ($item->{id} // '')
            && $self->config_store->hasId($default_parent)) {
            $item->{parent_id} = $default_parent;
        } else {
            $item->{parent_id} = '';
        }
    } elsif (!defined $item->{parent_id}) {
        $item->{parent_id} = '';
    }
    return $item;
}

sub cleanupItemForUpdate {
    my ($self, $old_item, $new_data, $data) = @_;
    # null and "" both mean "user explicitly cleared parent_id" — lock
    # as empty. Missing key is handled by mergeUpdate (preserves old).
    if (exists $data->{parent_id}
        && (!defined $data->{parent_id} || $data->{parent_id} eq '')) {
        $new_data->{parent_id} = '';
    }
    return;
}

sub cleanupItemForReplace {
    my ($self, $item) = @_;
    # PUT replaces the role with exactly this payload. Apply the same
    # parent_id normalization as create so PUT and POST agree on the
    # missing/null/value matrix — without this, `{"parent_id": null}`
    # over PUT would land in storage as undef (param removed) instead
    # of the explicit empty lock that PATCH produces.
    return $self->cleanupItemForCreate($item);
}

sub can_delete_from_config {
    my ($self) = @_;
    my $id = $self->id;
    my @errors;
    if (exists $RolesReverseLookup{$id}) {
         @errors = map { config_delete_error($id, $_, $RolesReverseLookup{$id}{$_}) } sort keys %{$RolesReverseLookup{$id}};
    }

    if (@errors) {
        return (422, 'Role still in use', \@errors);
    }

    return (200, '');
}

sub config_delete_error {
    my ($name, $namespace, $ids) = @_;
    my $reason = uc($namespace) . "_IN_USE";
    my %seen;
    my @ids = sort grep { !$seen{$_}++ } @{ $ids // [] };
    my $message = "Role still in use for $namespace";
    $message .= ": " . join(", ", @ids) if @ids;
    return { name => $name, message => $message, reason => $reason, status => 422, ids => \@ids };
}

my $CAN_DELETE_FROM_DB_SQL = <<SQL;
SELECT
    x.node_category_id || x.node_bypass_role_id || x.password_category AS `still_in_use`,
    x.*
    FROM (
    SELECT
        EXISTS (SELECT 1 FROM node, node_category WHERE (node.category_id = node_category.category_id ) AND node_category.name = ? LIMIT 1) as node_category_id,
        EXISTS (SELECT 1 FROM node, node_category WHERE (node.bypass_role_id = node_category.category_id ) AND node_category.name = ? LIMIT 1) as node_bypass_role_id,
        EXISTS (SELECT 1 FROM password, node_category WHERE password.category = node_category.category_id AND node_category.name = ? LIMIT 1) as password_category
) AS x;
SQL

my $NODES_IN_CATGEORY = <<SQL;
SELECT mac FROM node WHERE category_id IS NOT NULL && category_id IN (SELECT node_category.category_id FROM node_category WHERE name = ? );
SQL

my %IN_USE_MESSAGE = (
    node_category_id => 'Role is still used by node(s) as a role',
    node_bypass_role_id => 'Role is still used by node(s) as a bypass role',
    password_category => 'Role is still used by user(s)',
);

sub db_delete_error {
    my ($name, $namespace) = @_;
    my $reason = uc($namespace) . "_IN_USE";
    return { message => $IN_USE_MESSAGE{$namespace} // "Role still in use", name => $name, reason => $reason, status => 422 };
}

sub can_delete_from_db {
    my ($self) = @_;
    my $id = $self->id;
    my ($status, $sth) = pf::dal::node_category->db_execute($CAN_DELETE_FROM_DB_SQL, $id, $id, $id);
    if (is_error($status)) {
        return ($status, "Unable to check role in the database");
    }

    my $role_data = $sth->fetchrow_hashref;
    $sth->finish;
    my @errors;
    if ($role_data->{still_in_use}) {
        delete $role_data->{still_in_use};
        for my $key (sort keys %$role_data) {
            if ($role_data->{$key}) {
                push @errors, db_delete_error($id, $key);
            }
        }

        return (422, "Role still in use", \@errors);
    }

    return (200, '');
}

my $REASSIGN_NODE_CATEGORY_ID = <<SQL;
UPDATE
    node,
    (SELECT category_id from node_category WHERE name = ?) as old_nc,
    (SELECT category_id from node_category WHERE name = ?) as new_nc
SET node.category_id = new_nc.category_id
WHERE
    old_nc.category_id IS NOT NULL AND
    new_nc.category_id IS NOT NULL AND
    node.category_id = old_nc.category_id;
SQL

my $REASSIGN_NODE_BYPASS_ROLE_ID = <<SQL;
UPDATE
    node,
    (SELECT category_id from node_category WHERE name = ?) as old_nc,
    (SELECT category_id from node_category WHERE name = ?) as new_nc
SET node.bypass_role_id = new_nc.category_id
WHERE
    old_nc.category_id IS NOT NULL AND
    new_nc.category_id IS NOT NULL AND
    node.bypass_role_id = old_nc.category_id;
SQL

my $REASSIGN_PASSWORD_CATEGORY = <<SQL;
UPDATE
    password,
    (SELECT category_id from node_category WHERE name = ?) as old_nc,
    (SELECT category_id from node_category WHERE name = ?) as new_nc
SET password.category = new_nc.category_id
WHERE
    old_nc.category_id IS NOT NULL AND
    new_nc.category_id IS NOT NULL AND
    password.category = old_nc.category_id;
SQL

sub reassign {
    my ($self) = @_;
    my ($error, $data) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }

    my @errors;
    my $old = $self->id;
    my $new = $data->{id};
    $self->check_reassign_args($old, $new, \@errors);
    if (@errors) {
        return $self->render_error(422, "Unable to reassign role", \@errors);
    }

    $self->reassign_role_with_sql(\@errors, "pf::dal::node", $REASSIGN_NODE_CATEGORY_ID, $old, $new, "node category");
    $self->reassign_role_with_sql(\@errors, "pf::dal::node", $REASSIGN_NODE_BYPASS_ROLE_ID, $old, $new, "node bypass role");
    $self->reassign_role_with_sql(\@errors, "pf::dal::person", $REASSIGN_PASSWORD_CATEGORY, $old, $new, "password category");
    $self->reassign_role_config_store(\@errors, "pf::ConfigStore::Roles", $old, $new, qw(parent_id));
    $self->reassign_role_config_store(\@errors, "pf::ConfigStore::AdminRoles", $old, $new, qw(allowed_roles allowed_node_roles));
    $self->reassign_role_config_store(\@errors, "pf::ConfigStore::Scan", $old, $new, qw(categories));
    $self->reassign_role_config_store(\@errors, "pf::ConfigStore::Provisioning", $old, $new, qw(category role_to_apply));
    $self->reassign_role_config_store(\@errors, "pf::ConfigStore::SelfService", $old, $new, qw(roles_allowed_to_unregister device_registration_roles));
    $self->reassign_role_config_store(\@errors, "pf::ConfigStore::BillingTiers", $old, $new, qw(roles_allowed_to_unregister device_registration_roles));
    $self->reassign_role_config_store(\@errors, "pf::ConfigStore::Firewall_SSO", $old, $new, qw(categories));
    $self->reassign_role_config_store_switch(\@errors, $old, $new);
    $self->reassign_role_config_store_source(\@errors, $old, $new);
    $self->reassign_role_config_store_portal_module(\@errors, $old, $new);
    if (@errors) {
        return $self->render_error(422, "Unable to reassign role", \@errors);
    }

    return $self->render(200, json => {});
}

sub reassign_role_config_store {
    my ($self, $errors, $class, $old, $new, @fields) = @_;
    my $cs = $class->new;
    my $i = 0;
    my $cachedConfig = $cs->cachedConfig;
    for my $sect ($cs->_Sections()) {
        for my $f (@fields) {
            next if !$cachedConfig->exists($sect, $f);
            my $values = $cachedConfig->val($sect, $f);
            my @roles = split(/\s*,\s*/, $values);
            my @new_roles = map { $_ eq $old ? $new : $_ } @roles;
            if (@new_roles) {
                $cachedConfig->setval($sect, $f, join(",", @new_roles));
                $i |= 1;
            }
        }
    }

    if ($i) {
        $cs->commit();
    }
}

sub reassign_role_config_store_switch {
    my ($self, $errors, $old, $new) = @_;
    $self->migrate_role_in_switches($old, $new);
}

=head2 migrate_role_in_switches

Rename every per-role mapping key (${old}Role, ${old}Vlan, ...) to use the new
role name (${new}Role, ${new}Vlan, ...) for the given role across all switches.
Used when a role is reassigned/renamed so that switch-specific Role/Vlan/Url/...
mappings follow the role instead of being lost. An existing mapping already set
under the new role is preserved (the old value is dropped) so we don't clobber
config the new role already had.

=cut

sub migrate_role_in_switches {
    my ($self, $old, $new) = @_;
    return unless defined $old && length $old;
    return unless defined $new && length $new;
    return if $old eq $new;
    my $cs = pf::ConfigStore::Switch->new;
    my $i = 0;
    my $cachedConfig = $cs->cachedConfig;
    for my $sect ($cachedConfig->Sections()) {
        for my $suffix (qw(Role Url Vlan AccessList Vpn Interface Network NetworkFrom)) {
            my $old_key = "${old}${suffix}";
            next if !$cachedConfig->exists($sect, $old_key);
            my $value = $cachedConfig->val($sect, $old_key);
            my $new_key = "${new}${suffix}";
            if (!$cachedConfig->exists($sect, $new_key)) {
                $cachedConfig->setval($sect, $new_key, $value);
            }
            $cachedConfig->delval($sect, $old_key);
            $i |= 1;
        }
    }

    if ($i) {
        $cs->commit();
    }
}

=head2 prune_role_from_switches

Delete every per-role mapping key (${role}Role, ${role}Vlan, ...) for the given
role from all switches. Used both when a role is reassigned/renamed and when it
is deleted, so stale per-role keys never accumulate in switches.conf.

=cut

sub prune_role_from_switches {
    my ($self, $role) = @_;
    return unless defined $role && length $role;
    my $cs = pf::ConfigStore::Switch->new;
    my $i = 0;
    my $cachedConfig = $cs->cachedConfig;
    for my $sect ($cachedConfig->Sections()) {
        for my $f (map { "${role}${_}" } qw(Role Url Vlan AccessList Vpn Interface Network NetworkFrom) ) {
            next if !$cachedConfig->exists($sect, $f);
            $cachedConfig->delval($sect, $f);
            $i |= 1;
        }
    }

    if ($i) {
        $cs->commit();
    }
}

=head2 post_remove

After a role is deleted, prune its per-role mapping keys from all switches so
that orphaned mappings can't accumulate (which otherwise bloats switches.conf
and makes the switch config API very slow).

=cut

sub post_remove {
    my ($self, $id, $old_item) = @_;
    $self->prune_role_from_switches($id);
    return;
}

sub reassign_role_config_store_source {
    my ($self, $errors, $old, $new) = @_;
    my $cs = pf::ConfigStore::Source->new;
    my $i = 0;
    my $cachedConfig = $cs->cachedConfig;
    for my $sect ( grep { / rule / } $cachedConfig->Sections()) {
        for my $p ( grep { /^action\d+/ } $cachedConfig->Parameters($sect) ) {
            my $val = $cachedConfig->val($sect, $p);
            if ($val =~ s/^set_role=\Q$old\E/set_role=$new/) {
                $cachedConfig->setval($sect, $p, $val);
                $i |= 1;
            }
        }
    }

    if ($i) {
        $cs->commit();
    }
}

sub reassign_role_config_store_portal_module {
    my ($self, $errors, $old, $new) = @_;
    my $cs = pf::ConfigStore::PortalModule->new;
    my $i = 0;
    my $cachedConfig = $cs->cachedConfig;
    for my $sect ( $cachedConfig->Sections()) {
        my $val = $cachedConfig->val($sect, 'actions');
        next if !defined $val;
        if ($val =~ s/set_role\(\Q$old\E\)/set_role($new)/) {
            $cachedConfig->setval($sect, 'actions', $val);
            $i |= 1;
        }
    }

    if ($i) {
        $cs->commit();
    }
}

sub reassign_role_with_sql {
    my ($self, $errors, $dal, $sql, $old, $new, $scope) = @_;
    my ($status, $sth) = $dal->db_execute($sql, $old, $new);
    if (is_error($status)) {
        push @$errors, { message => "Unable to reassign roles for $scope", status => $status};
    } else {
        $sth->finish;
    }
}

sub check_reassign_args {
    my ($self, $old, $new, $errors) = @_;
    if (!defined $old) {
        push @$errors, { field => "old", message => "'old' field is missing", status => 422};
    }

    if (!defined $new) {
        push @$errors, { field => "new", message => "'new' field is missing", status => 422};
    }

    my $cs = $self->config_store;
    if (defined $old && !$cs->hasId($old)) {
        push @$errors, { field => "old", message => "'$old' field is invalid", status => 422};
    }

    if (defined $new && !$cs->hasId($new)) {
        push @$errors, { field => "new", message => "'$new' field is invalid", status => 422};
    }

}

sub bulk_reevaluate_access {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    if ($data->{async}) {
        my $task_id = $self->task_id;
        my $subprocess = Mojo::IOLoop->subprocess;
        $subprocess->run(
            sub {
                my ($subprocess) = @_;
                my $updater = pf::pfqueue::status_updater::redis->new( connection => consumer_redis_client(), task_id => $task_id );
                $updater->start;
                my ($status, $results) = $self->do_bulk_reevaluate_access($data, $updater);
                if (is_error($status)) {
                    $updater->failed({ message => $results });
                    return;
                }

                $updater->completed($results);
                return;
            },
            sub { } # Do nothing
        );

        return $self->render( json => {status => 202, task_id => $task_id }, status => 202);
    }

    ($status, my $results) = $self->do_bulk_reevaluate_access($data);
    if (is_error($status)) {
        return $self->render_error(
            $status,
            $results,
        );
    }

    return $self->render(json => $results);
}

sub do_bulk_reevaluate_access {
    my ($self, $data, $updater) = @_;
    my @items;
    my $id = $self->id;
    my ($status, $nodes) = get_nodes_for_role($id);
    if (is_error($status)) {
        return ($status, "Unable to get nodes");
    }

    for my $mac (@{$nodes}) {
        my %item = (mac => $mac);
        my $result = pf::enforcement::reevaluate_access($mac, "admin_modify");
        $item{status} = $result ? "success" : "failed";
        push @items, \%item;
    }

    return ($status, {items => \@items });
}

sub get_nodes_for_role {
    my ($name) = @_;
    my ($status, $sth) = pf::dal::node->db_execute($NODES_IN_CATGEORY, $name);
    if (is_error($status)) {
        get_logger()->error("Unable to get nodes in the database");
        return ($status, []);
    }

    my $nodes = $sth->fetchall_arrayref([0]);
    $sth->finish;
    my $n = [map {$_->[0]} @{$nodes}];
    return ($status, $n);
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
