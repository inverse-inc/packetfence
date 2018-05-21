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
use pf::error qw(is_error);
use pf::locationlog qw(locationlog_history_mac locationlog_view_open_mac);
use pf::UnifiedApi::SearchBuilder::Nodes;

has 'search_builder_class' => 'pf::UnifiedApi::SearchBuilder::Nodes';

has dal => 'pf::dal::node';
has url_param_name => 'node_id';
has primary_key => 'mac';

sub latest_locationlog_by_mac {
    my ($self) = @_;
    my $mac = $self->param('mac');
    $self->render(json => locationlog_view_open_mac($mac));
}

sub locationlog_by_mac {
    my ($self) = @_;
    my $mac = $self->param('mac');
    $self->render(json => { items => [locationlog_history_mac($mac)]});
}

sub register {
    my ($self) = @_;
    my $mac = $self->stash->{node_id};
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $pid = delete $data->{pid};
    if (!defined $pid || length($pid) == 0) {
        return $self->render_error(422, "pid field is required");
    }

    my ($success, $msg) = node_register($mac, $pid, %$data);
    if (!$success) {
        return $self->render_error(status => 422, "Cannot register $mac" . ($msg ? " $msg" : ""));
    }

    return $self->render_empty;
}

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

    my $nodes = $iter->all;
    my $count = 0;
    for my $node (@$nodes) {
        node_register($node->{mac}, $node->{pid});
    }

    return $self->render(status => 200, json => { count => $count });
}

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

    my $nodes = $iter->all;
    my $count = 0;
    for my $node (@$nodes) {
        node_deregister($node->{mac});
    }

    return $self->render(status => 200, json => { count => $count });
}

=head2 fingerbank_info

fingerbank_info

=cut

sub fingerbank_info {
    my ($self) = @_;
    my $mac = $self->stash->{node_id};
    return $self->render(status => 200, json => { item => pf::node::fingerbank_info($mac) });
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

