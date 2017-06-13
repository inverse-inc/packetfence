package pfappserver::PacketFence::Controller::RemoteDeployment;

=head1 NAME

pfappserver::PacketFence::Controller::RemoteDeployment - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use pf::constants qw($TRUE $FALSE);
use pf::admin_roles;
use pf::multi_cluster::flansible;
use namespace::autoclean;

BEGIN { extends 'pfappserver::Base::Controller'; }

=head2 index

=cut

sub index :Path :Args(0) :AdminRole('REMOTE_DEPLOYMENT_READ') {
    my ( $self, $c ) = @_;
    $c->stash->{rootRegion} = pf::multi_cluster::rootRegion();
}

sub allDeploymentsStatus :Local :Args(0) :AdminRole('REMOTE_DEPLOYMENT_READ') {
    my ($self, $c) = @_;

    my $multi_cluster_status = $c->stash->{multi_cluster_status} = {};

    my $childs = pf::multi_cluster::allChilds(pf::multi_cluster::rootRegion);

    for my $child (@$childs) {
        $multi_cluster_status->{$child->name} = int(!$child->hasUnpushedChanges());
    }
    
    $c->stash(current_view => 'JSON');
}

sub deploy :Local :Args(1) :AdminRole('REMOTE_DEPLOYMENT_CREATE') {
    my ($self, $c, $id) = @_;
    $c->stash->{remote_deployment_scope} = $id;

    $c->log->info("Deploying ", $c->stash->{remote_deployment_scope});
    my $task_id = pf::multi_cluster::flansible::play("push-configuration", $c->stash->{remote_deployment_scope});

    $c->stash(current_view => 'JSON');
    $c->stash->{status_msg} = "Successfully dispatched job with task ID $task_id";
}

sub jobStatus :Local :Args(1) :AdminRole('REMOTE_DEPLOYMENT_READ') {
    my ($self, $c, $task_id) = @_;

    my $item = $c->stash->{items} = {};
    $item->{jobStatus} = pf::multi_cluster::flansible::playStatus($task_id);
    $item->{jobOutput} = pf::multi_cluster::flansible::playOutput($task_id);

    $c->stash(current_view => 'JSON');
}

sub jobList :Local :AdminRole('REMOTE_DEPLOYMENT_READ') {
    my ($self, $c) = @_;

    $c->stash->{items} = pf::multi_cluster::flansible::listTasks();
    $c->stash(current_view => 'JSON');
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
