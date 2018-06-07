package pf::UnifiedApi::Controller::Nodes;

=head1 NAME

pf::UnifiedApi::Controller::Nodes -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Nodes

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::dal::node;
use pf::node;
use pf::constants qw($TRUE);
use pf::dal::violation;
use pf::error qw(is_error);
use pf::locationlog qw(locationlog_history_mac locationlog_view_open_mac);
use pf::UnifiedApi::SearchBuilder::Nodes;
use pf::violation;
use pf::Connection;
use pf::SwitchFactory;

has 'search_builder_class' => 'pf::UnifiedApi::SearchBuilder::Nodes';

has dal => 'pf::dal::node';
has url_param_name => 'node_id';
has primary_key => 'mac';

=head2 register

register

=cut

sub register {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }
    my $node = $self->item;
    my $mac = $node->{mac};

    my $pid = delete $data->{pid};
    if (!defined $pid || length($pid) == 0) {
        $pid = $node->{pid}
    }

    my ($success, $msg) = node_register($mac, $pid, %$data);
    if (!$success) {
        return $self->render_error(status => 422, "Cannot register $mac" . ($msg ? " $msg" : ""));
    }

    return $self->render_empty;
}

=head2 deregister

deregister

=cut

sub deregister {
    my ($self) = @_;
    my $mac = $self->stash->{node_id};
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my ($success) = node_deregister($mac, %$data);
    if (!$success) {
        return $self->render_error(status => 422, "Cannot deregister $mac");
    }

    return $self->render_empty;
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
    ($status, my $iter) = $self->dal->search(
        -columns => [qw(mac pid)],
        -where => {
            mac => { -in => $items},
            status => { "!=" => $pf::node::STATUS_REGISTERED }
        },
        -with_class => undef,
    );
    if (is_error($status)) {
        return $self->render_error(status => $status, "Error finding nodes");
    }

    my ($indexes, $results) = bulk_init_results($items);
    my $nodes = $iter->all;
    for my $node (@$nodes) {
        my $mac = $node->{mac};
        my ($result, $msg) = node_register($mac, $node->{pid});
        my $index = $indexes->{$mac};
        if ($result) {
            $results->[$index]{status} = "success";
            pf::enforcement::reevaluate_access($mac, "admin_modify");
        } else {
            $results->[$index]{status} = "failed";
            $results->[$index]{message} = $msg // '';
        }
    }

    return $self->render(status => 200, json => { items => $results });
}

=head2 bulk_init_results

bulk_init_results

=cut

sub bulk_init_results {
    my ($items) = @_;
    my $i = 0;
    my %index = map { $_ => $i++ } @$items;
    my @results = map { { mac => $_, status => 'skipped'} } @$items;
    return (\%index, \@results);
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
    ($status, my $iter) = $self->dal->search(
        -columns => [qw(mac pid)],
        -where => {
            mac => { -in => $items},
            status => { "!=" => $pf::node::STATUS_UNREGISTERED }
        },
        -with_class => undef,
    );
    if (is_error($status)) {
        return $self->render_error(status => $status, "Error finding nodes");
    }

    my ($index, $results) = bulk_init_results($items);
    my $nodes = $iter->all;
    for my $node (@$nodes) {
        my $mac = $node->{mac};
        my $result = node_deregister($mac);
        if ($result) {
            pf::enforcement::reevaluate_access($mac, "admin_modify");
        }
        $results->[$index->{$mac}]{status} = $result ? "success" : "failed";
    }

    return $self->render(status => 200, json => { items => $results });
}

=head2 fingerbank_info

fingerbank_info

=cut

sub fingerbank_info {
    my ($self) = @_;
    my $mac = $self->stash->{node_id};
    return $self->render(status => 200, json => { item => pf::node::fingerbank_info($mac) });
}

=head2 bulk_close_violations

bulk_close_violations

=cut

sub bulk_close_violations {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    ($status, my $iter) = pf::dal::violation->search(
        -where => {
            mac => { -in => $items},
            status => "open",
        },
        -columns => [qw(violation.vid mac)],
        -from => [-join => qw(violation <=>{violation.vid=class.vid} class)],
        -order_by => { -desc => 'start_date' },
        -with_class => undef,
    );

    if (is_error($status)) {
        return $self->render_error(status => $status, "Error finding nodes");
    }

    my ($indexes, $results) = bulk_init_results($items);
    my $violations = $iter->all;
    for my $violation (@$violations) {
        my $mac = $violation->{mac};
        my $index = $indexes->{$mac};
        if (violation_force_close($mac, $violation->{vid})) {
            pf::enforcement::reevaluate_access($mac, "admin_modify");
            $results->[$index]{status} = "success";
        } else {
            $results->[$index]{status} = "failed";
        }
    }

    return $self->render(status => 200, json => { items => $results });
}

=head2 close_violation

close_violation

=cut

sub close_violation {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }
    my $mac = $self->param('node_id');
    my $violation_id = $data->{violation_id};
    my $violation = violation_exist_id($violation_id);
    if (!$violation || $violation->{mac} ne $mac ) {
        return $self->render_error(status => 404, "Error finding violation");
    }

    my $result = 0;
    if (violation_force_close($mac, $violation->{vid})) {
        pf::enforcement::reevaluate_access($mac, "admin_modify");
        $result = 1;
    }

    unless ($result) {
        return $self->render_error(500, "Unable to close violation");
    }

    return $self->render_empty();
}

=head2 create_error_msg

create_error_msg

=cut

sub create_error_msg {
    my ($self, $obj) = @_;
    return "There's already a node with this MAC address"
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
    my ($indexes, $results) = bulk_init_results($items);
    for my $mac (@$items) {
        my $result = pf::enforcement::reevaluate_access($mac, "admin_modify");
        $results->[$indexes->{$mac}]{status} = $result ? "success" : "failed";
    }

    return $self->render(status => 200, json => { items => $results });
}

=head2 bulk_restart_switchport

bulk_restart_switchport

=cut

sub bulk_restart_switchport {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    my ($indexes, $results) = bulk_init_results($items);
    for my $mac (@$items) {
        my ($status, $msg) = $self->do_restart_switchport($mac);
        if (is_error($status)) {
            if ($STATUS::INTERNAL_SERVER_ERROR == $status) {
                $results->[$indexes->{$mac}]{status} = "failed";
            }

            $results->[$indexes->{$mac}]{message} = $msg;
        } else {
            $results->[$indexes->{$mac}]{status} = "success";
        }
    }

    return $self->render(status => 200, json => { items => $results });
}

=head2 bulk_apply_violation

bulk_apply_violation

=cut

sub bulk_apply_violation {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    my $vid = $data->{vid};
    my ($indexes, $results) = bulk_init_results($items);
    for my $mac (@$items) {
        my ($last_id) = violation_add($mac, $vid, ( 'force' => $TRUE ));
        $results->[$indexes->{$mac}]{status} = $last_id > 0 ? "success" : "failed";
    }

    return $self->render( status => 200, json => { items => $results } );
}

=head2 apply_violation

apply_violation

=cut

sub apply_violation {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }
    my $mac = $self->param('node_id');
    my $vid = $data->{vid};
    my ($last_id) = violation_add($mac, $vid, ( 'force' => $TRUE ));

    return $self->render(status => 200, json => { violation_id => $last_id });
}

=head2 bulk_apply_role

bulk_apply_role

=cut

sub bulk_apply_role {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    my $role_id = $data->{role_id};
    return $self->do_bulk_update_field($items, 'category_id', $role_id);
}

=head2 bulk_apply_bypass_role

bulk_apply_bypass_role

=cut

sub bulk_apply_bypass_role {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    my $role_id = $data->{role_id};
    return $self->do_bulk_update_field($items, 'bypass_role_id', $role_id);
}

=head2 do_bulk_update_field

do_bulk_update_field

=cut

sub do_bulk_update_field {
    my ($self, $items, $field, $value) = @_;
    my ($status, $iter) = $self->dal->search(
        -columns => [qw(mac)],
        -where => {
            mac => { -in => $items },
            $field => [ {"!=" => $value}, defined $value ? ({"=" => undef} ) : () ],
        },
        -from => $self->dal->table,
        -with_class => undef,
    );
    if (is_error($status)) {
        return $self->render_error(status => $status, "Error finding nodes");
    }

    my ($indexes, $results) = bulk_init_results($items);
    my $nodes = $iter->all;
    for my $node (@$nodes) {
        my $mac = $node->{mac};
        my $result = node_modify($mac, $field => $value);
        if ($result) {
            $results->[$indexes->{$mac}]{status} = "success";
            pf::enforcement::reevaluate_access($mac, "admin_modify");
        } else {
            $results->[$indexes->{$mac}]{status} = "failed";
        }
    }

    return $self->render( status => 200, json => { items => $results } );
}

=head2 restart_switchport

restart_switchport

=cut

sub restart_switchport {
    my ($self) = @_;
    my $mac = $self->param('node_id');
    my ($status, $msg) = $self->do_restart_switchport($mac);
    if (is_error($status)) {
        return $self->render_error($status, $msg);
    }

    return $self->render_empty();
}

=head2 do_restart_switchport

do_restart_switchport

=cut

sub do_restart_switchport {
    my ($self, $mac) = @_;
    my $ll = locationlog_view_open_mac($mac);
    unless (my $ll) {
        return ($STATUS::NOT_FOUND, "Unable to find node location.");
    }

    my $connection = pf::Connection->new;
    $connection->backwardCompatibleToAttributes($ll->{connection_type});
    unless ($connection->transport eq "Wired") {
        return ($STATUS::UNPROCESSABLE_ENTITY, "Trying to restart the port of a non-wired connection");
    }

    my $switch = pf::SwitchFactory->instantiate($ll->{switch});
    unless ($switch) {
        return ($STATUS::NOT_FOUND, "Unable to instantiate switch $ll->{switch}");
    }

    unless ($switch->bouncePort($ll->{port})) {
        return ($STATUS::INTERNAL_SERVER_ERROR, "Couldn't restart port.");
    }

    return ($STATUS::OK, "");
}

=head2 reevaluate_access

reevaluate_access

=cut

sub reevaluate_access {
    my ($self) = @_;
    my $mac = $self->param('node_id');
    my $result = pf::enforcement::reevaluate_access($mac, "admin_modify");
    unless ($result) {
        return $self->render_error($STATUS::UNPROCESSABLE_ENTITY, "unable reevaluate access for $mac");
    }

    return $self->render_empty();
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
