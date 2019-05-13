package pf::UnifiedApi::Controller::Users;

=head1 NAME

pf::UnifiedApi::Controller::User -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::User

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::dal::person;
use pf::dal::node;
use pf::dal::security_event;
use pf::security_event;
use pf::constants;
use pf::person qw(person_security_events person_unassign_nodes person_delete);
use pf::node;
use pf::constants qw($default_pid);
use pf::error qw(is_error);

has dal => 'pf::dal::person';
has url_param_name => 'user_id';
has primary_key => 'pid';

=head2 create_data_update

create_data_update

=cut

sub create_data_update {
    my ($self, $data) = @_;
    if (exists $data->{sponsor} && length($data->{sponsor})) {
        return;
    }

    $data->{sponsor} = $self->stash->{current_user};
    return ;
}

=head2 cleanup_item

Remove the password field from the item

=cut

sub cleanup_item {
    my ($self, $item) = @_;
    delete $item->{password};
    $item = $self->SUPER::cleanup_item($item);
    if (exists $item->{category}) {
        $item->{category_name} = delete $item->{category};
    }

    if (exists $item->{category_id}) {
        $item->{category} = delete $item->{category_id};
    }
    return $item;
}

=head2 unassign_nodes

unassign user nodes

=cut

sub unassign_nodes {
    my ($self) = @_;
    my $pid = $self->id;
    my $count = person_unassign_nodes($pid);
    if (!defined $count) {
        return $self->render_error(500, "Unable the unassign nodes for $pid");
    }

    return $self->render(json => {count => $count});
}

=head2 security_events

security_events

=cut

sub security_events {
    my ($self) = @_;
    my $pid = $self->id;
    my @security_events = eval {
        map { $_->{release_date} = '' if ($_->{release_date} eq '0000-00-00 00:00:00'); $_ } person_security_events($pid)
    };
    if ($@) {
        return $self->render_error(500, "Can't fetch security events from database.");
    }

    return $self->render(json => { items => \@security_events });
}

=head2 bulk_register

bulk_register

=cut

sub bulk_register {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    ($status, my $iter) = pf::dal::node->search(
        -columns => [qw(mac pid node.category_id)],
        -where => {
            pid => { -in => $items},
            status => { "!=" => $pf::node::STATUS_REGISTERED }
        },
        -with_class => undef,
    );

    my ($indexes, $results) = bulk_init_results($items, 'nodes');
    my $nodes = $iter->all;
    for my $node (@$nodes) {
        my $pid = delete $node->{pid};
        my $mac = $node->{mac};
        my ($result, $msg) = node_register($mac, $pid, category_id => delete $node->{category_id});
        my %status = ( mac => $mac );
        if ($result) {
            $node->{status} = 200;
            pf::enforcement::reevaluate_access($mac, "admin_modify");
        } else {
            $node->{status} = 422;
            $node->{message} = $msg // '';
        }

        push @{$results->[$indexes->{$pid}]{nodes}}, $node;
    }

    return $self->render(json => { items => $results });
}

=head2 bulk_deregister

bulk_deregister

=cut

sub bulk_deregister {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    ($status, my $iter) = pf::dal::node->search(
        -columns => [qw(mac pid)],
        -where => {
            pid => { -in => $items},
            status => { "!=" => $pf::node::STATUS_UNREGISTERED }
        },
        -with_class => undef,
    );

    if (is_error($status)) {
        return $self->render_error($status, "Error finding nodes");
    }

    my ($indexes, $results) = bulk_init_results($items, 'nodes');
    my $nodes = $iter->all;
    for my $node (@$nodes) {
        my $pid = delete $node->{pid};
        my $mac = $node->{mac};
        my $result = node_deregister($mac);
        if ($result) {
            $node->{status} = 200;
            pf::enforcement::reevaluate_access($mac, "admin_modify");
        } else {
            $node->{status} = 422;
        }

        push @{$results->[$indexes->{$pid}]{nodes}}, $node;
    }

    return $self->render(json => { items => $results });
}

=head2 bulk_close_security_events

bulk_close_security_events

=cut

sub bulk_close_security_events {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    ($status, my $iter) = pf::dal::security_event->search(
        -where => {
            'node.pid' => { -in => $items},
            'security_event.status' => "open",
        },
        -columns => [qw(security_event.security_event_id security_event.mac node.pid)],
        -from => [-join => qw(security_event <=>{security_event.security_event_id=class.security_event_id} class), '=>{security_event.tenant_id=node.tenant_id,security_event.mac=node.mac}', 'node'],
        -with_class => undef,
    );

    if (is_error($status)) {
        return $self->render_error($status, "Error finding security_events");
    }

    my ($indexes, $results) = bulk_init_results($items, 'security_events');
    my $security_events = $iter->all;
    for my $security_event (@$security_events) {
        my $pid = delete $security_event->{pid};
        my $mac = $security_event->{mac};
        my $index = $indexes->{$pid};
        if (security_event_force_close($mac, $security_event->{security_event_id})) {
            pf::enforcement::reevaluate_access($mac, "admin_modify");
            $security_event->{status} = 200;
        } else {
            $security_event->{status} = 422;
        }

        push @{$results->[$indexes->{$pid}]{security_events}}, $security_event;
    }

    return $self->render(json => { items => $results });
}

=head2 close_security_events

close_security_events

=cut

sub close_security_events {
    my ($self) = @_;

    my ($status, $iter) = pf::dal::security_event->search(
        -where => {
            'node.pid' => $self->id,
            'security_event.status' => "open",
        },
        -columns => [qw(security_event.security_event_id security_event.mac)],
        -from => [-join => qw(security_event <=>{security_event.security_event_id=class.security_event_id} class), '=>{security_event.tenant_id=node.tenant_id,security_event.mac=node.mac}', 'node'],
        -with_class => undef,
    );

    if (is_error($status)) {
        return $self->render_error($status, "Error finding security_events");
    }
    my $results = [];
    my $security_events = $iter->all;
    for my $security_event (@$security_events) {
        my $mac = $security_event->{mac};
        if (security_event_force_close($mac, $security_event->{security_event_id})) {
            pf::enforcement::reevaluate_access($mac, "admin_modify");
            $security_event->{status} = 200;
        } else {
            $security_event->{status} = 422;
        }

        push @$results, $security_event;
    }

    return $self->render(json => { items => $results });
}

=head2 bulk_apply_security_event

bulk_apply_security_event

=cut

sub bulk_apply_security_event {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    my $security_event_id = $data->{security_event_id};
    ($status, my $iter) = pf::dal::node->search(
        -columns => [qw(mac pid)],
        -where => {
            pid => { -in => $items},
        },
        -with_class => undef,
    );

    if (is_error($status)) {
        return $self->render_error($status, "Error finding nodes");
    }

    my ($indexes, $results) = bulk_init_results($items, 'security_events');
    my $nodes = $iter->all;
    for my $node (@$nodes) {
        my $pid = delete $node->{pid};
        my $mac = $node->{mac};
        $node->{'security_event_id'} = $security_event_id;
        my ($last_id) = security_event_add($mac, $security_event_id, ( 'force' => $TRUE ));
        if ($last_id > 0) {
            $node->{status} = 200;
            $node->{security_event_id} = $last_id;
        } else {
            $node->{status} = 422;
        }
        push @{$results->[$indexes->{$pid}]{security_events}}, $node;
    }

    return $self->render(json => { items => $results });
}

=head2 bulk_reevaluate_access

bulk_reevaluate_access

=cut

sub bulk_reevaluate_access {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    ($status, my $iter) = pf::dal::node->search(
        -columns => [qw(mac pid)],
        -where => {
            pid => { -in => $items},
        },
        -with_class => undef,
    );
    if (is_error($status)) {
        return $self->render_error($status, "Error finding nodes");
    }

    my ($indexes, $results) = bulk_init_results($items, 'nodes');
    my $nodes = $iter->all;
    for my $node (@$nodes) {
        my $pid = delete $node->{pid};
        my $result = pf::enforcement::reevaluate_access($node->{mac}, "admin_modify");
        $node->{status} = $result ? 200 : 422;
        push @{$results->[$indexes->{$pid}]{nodes}}, $node;
    }

    return $self->render(json => { items => $results });
}

=head2 bulk_init_results

bulk_init_results

=cut

sub bulk_init_results {
    my ($items, $key) = @_;
    my $i = 0;
    my %index = map { $_ => $i++ } @$items;
    my @results = map { { pid => $_, (defined $key ? ($key => [] ) : ()) } } @$items;
    return (\%index, \@results);
}

=head2 bulk_fingerbank_refresh

bulk_fingerbank_refresh

=cut

sub bulk_fingerbank_refresh {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    ($status, my $iter) = pf::dal::node->search(
        -columns => [qw(mac pid)],
        -where => {
            pid => { -in => $items},
        },
        -with_class => undef,
    );
    if (is_error($status)) {
        return $self->render_error($status, "Error finding nodes");
    }

    my ($indexes, $results) = bulk_init_results($items, 'nodes');
    my $nodes = $iter->all;
    for my $node (@$nodes) {
        my $mac = $node->{mac};
        my $pid = delete $node->{pid};
        my $result = pf::fingerbank::process($mac, $TRUE);
        $node->{status} = $result ? 200 : 422;
        push @{$results->[$indexes->{$pid}]{nodes}}, $node;
    }

    return $self->render(json => { items => $results });
}


=head2 do_bulk_update_field

do_bulk_update_field

=cut

sub do_bulk_update_field {
    my ($self, $field) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    my $value = $data->{$field};
    ($status, my $iter) = pf::dal::node->search(
        -columns => [qw(mac pid)],
        -where => {
            pid => { -in => $items },
            "node.${field}" => [ {"!=" => $value}, defined $value ? ({"=" => undef} ) : () ],
        },
        -with_class => undef,
    );

    if (is_error($status)) {
        return $self->render_error($status, "Error finding nodes");
    }

    my ($indexes, $results) = bulk_init_results($items, 'nodes');
    my $nodes = $iter->all;
    for my $node (@$nodes) {
        my $mac = $node->{mac};
        my $pid = delete $node->{pid};
        my $result = node_modify($mac, $field => $value);
        if ($result) {
            $node->{status} = 200;
            pf::enforcement::reevaluate_access($mac, "admin_modify");
        } else {
            $node->{status} = 422;
        }

        push @{$results->[$indexes->{$pid}]{nodes}}, $node;
    }

    return $self->render( status => 200, json => { items => $results } );
}

=head2 bulk_apply_role

bulk_apply_role

=cut

sub bulk_apply_role {
    my ($self) = @_;
    return $self->do_bulk_update_field('category_id');
}

=head2 bulk_apply_bypass_role

bulk_apply_bypass_role

=cut

sub bulk_apply_bypass_role {
    my ($self) = @_;
    return $self->do_bulk_update_field('bypass_role_id');
}

=head2 bulk_delete

bulk_delete

=cut

sub bulk_delete {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    my ($indexes, $results) = bulk_init_results($items);
    for my $pid ( @$items ) {
         person_unassign_nodes($pid);
         person_delete($pid);
         $results->[$indexes->{$pid}]->{status} = 200;
    }

    return $self->render(json => { items => $results });
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
