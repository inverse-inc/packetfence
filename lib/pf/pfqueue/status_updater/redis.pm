package pf::pfqueue::status_updater::redis;

use strict;
use warnings;

use Moo;
use pf::constants::pfqueue qw(
    $STATUS_SUCCEEDED
    $STATUS_KEY
    $STATUS_MSG_KEY
    $SUB_TASKS_KEY
    $CURRENT_SUB_TASK_KEY
    $PROGRESS_KEY
);

has 'connection' => (is => 'rw', required => 1);

has 'task_id' => (is => 'rw', required => 1);

=head2 status_ttl

How long should the status be available after the job has been initially started
The TTL gets extended everytime something is inserted in the status hash in Redis

=cut

has 'status_ttl' => (is => 'rw', default => sub{60*15});

sub set_status {
    my ($self, $status) = @_;

    if($status eq $STATUS_SUCCEEDED) {
        $self->set_progress(100);
    }
    $self->set_in_status_hash($STATUS_KEY, $status);
}

sub set_status_msg {
    my ($self, $status_msg) = @_;
    $self->set_in_status_hash($STATUS_MSG_KEY, $status_msg);
}

sub set_sub_tasks {
    my ($self, $sub_tasks) = @_;
    $self->set_in_status_hash($SUB_TASKS_KEY, $sub_tasks);
}

sub set_current_sub_task {
    my ($self, $sub_task) = @_;
    $self->set_in_status_hash($CURRENT_SUB_TASK_KEY, $sub_task);
}

sub set_progress {
    my ($self, $progress) = @_;
    $self->set_in_status_hash($PROGRESS_KEY, $progress);
}

sub set_in_status_hash {
    my ($self, $key, $data) = @_;
    # TODO: error validation and logging and exec
    $self->connection->expire($self->status_key, $self->status_ttl);
    return $self->connection->hset($self->status_key, $key, $data);
}

sub status_key {
    my ($self) = @_;
    return $self->task_id."-Status";
}


1;
