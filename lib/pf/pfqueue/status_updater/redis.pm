package pf::pfqueue::status_updater::redis;

use strict;
use warnings;

use Moo;
use pf::constants::pfqueue qw(
    $STATUS_COMPLETED
    $STATUS_KEY
    $STATUS_MSG_KEY
    $SUB_TASKS_KEY
    $CURRENT_SUB_TASK_KEY
    $PROGRESS_KEY
    $RESULT_KEY
);
use JSON::MaybeXS;
use pf::constants;
use pf::log;

has 'connection' => (is => 'rw', required => 1);

has 'task_id' => (is => 'rw', required => 1, trigger => \&reset_state);

=head2 status_ttl

How long should the status be available after the job has been initially started
The TTL gets extended everytime something is inserted in the status hash in Redis

=cut

has 'status_ttl' => (is => 'rw', default => sub{60*15});

has 'finalized' => (is => 'rw', default => sub{$FALSE});

sub reset_state {
    my ($self) = @_;
    get_logger->trace("Setting new task ID, resetting state");
    $self->finalized($FALSE);
}

sub set_status {
    my ($self, $status) = @_;

    if($status eq $STATUS_COMPLETED) {
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

sub set_result {
    my ($self, $result) = @_;
    $result = encode_json({result => $result});
    $self->set_in_status_hash($RESULT_KEY, $result);
}

sub finalize {
    my ($self) = @_;
    $self->finalized($TRUE);
}

sub set_in_status_hash {
    my ($self, $key, $data) = @_;
    if($self->finalized) {
        get_logger->trace("Not reporting data for $key since status has been finalized");
        return;
    }
    
    # TODO: error validation and logging and exec
    $self->connection->expire($self->status_key, $self->status_ttl);
    $self->connection->hset($self->status_key, $key, $data);
    $self->connection->publish($self->status_publish_key, 1)
}

sub status_key {
    my ($self) = @_;
    return $self->task_id."-Status";
}

sub status_publish_key {
    my ($self) = @_;
    return $self->status_key . "-Updates";
}

1;
