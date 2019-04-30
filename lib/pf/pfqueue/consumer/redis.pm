package pf::pfqueue::consumer::redis;

=head1 NAME

pf::pfqueue::consumer::redis -

=cut

=head1 DESCRIPTION

pf::pfqueue::consumer::redis

=cut

use strict;
use warnings;
use pf::Redis;
use Time::HiRes qw(usleep);
use Sereal::Decoder qw(sereal_decode_with_object);
use pf::dal;
use pf::log;
use pf::Sereal qw($DECODER);
use Moo;
use pf::util::pfqueue qw(task_counter_id);
use pf::constants::pfqueue qw(
    $PFQUEUE_COUNTER 
    $PFQUEUE_EXPIRED_COUNTER
    $STATUS_COMPLETED
    $STATUS_FAILED
    $STATUS_IN_PROGRESS
);
use pf::pfqueue::status_updater::redis;
extends qw(pf::pfqueue::consumer);

has 'redis' => (is => 'rw', lazy => 1, builder => 1);

has 'redis_args' => (is => 'rw', default => sub { {} });

our $STATUS_UPDATER_SINGLETON;

#
# This lua script gets all the job id from a zset with a timestamp less the one passed
# Then push all the job ids the work queue
# It is called like the following
# EVAL LUA_DELAY_JOBS_MOVE 2 DELAY_ZSET JOB_QUEUE TIMESTAMP BATCH
#
our $LUA_DELAY_JOBS_MOVE =<<EOS ;
    local task_ids = redis.call("ZRANGEBYSCORE",KEYS[1],'-inf',ARGV[1],'LIMIT',0,ARGV[2]);
    if table.getn(task_ids) > 0 then
        redis.call("LPUSH",KEYS[2],unpack(task_ids));
        redis.call("ZREM",KEYS[1],unpack(task_ids));
    end
EOS

our $LUA_DELAY_JOBS_MOVE_SHA1;

sub BUILDARGS {
    my ($class, @args) = @_;
    my $args = $class->SUPER::BUILDARGS(@args);
    if (!exists $args->{redis_args}) {
        my %redis_args;
        foreach my $key (grep {/^redis_/} keys %$args) {
            my $new_key = $key;
            $new_key =~ s/^redis_//;
            $redis_args{$new_key} = $args->{$key};
        }
        $args->{redis_args} = \%redis_args;
    }
    return $args;
}

=head2 _empty

_empty

=cut

sub _empty { }

=head2 process_next_job

Process the next job in the queue

=cut

sub process_next_job {
    my ($self, $queues) = @_;
    my $redis = $self->redis;
    if (ref ($queues) ne 'ARRAY') {
        $queues = [$queues];
    }
    my $logger = get_logger();
    my ($queue, $task_id);
    if (@$queues == 1) {
        # Use the faster nonblocking rpop first if there is nothing there use the blocking version
        ($task_id) = $redis->rpop(@$queues);
    }
    unless (defined $task_id) {
        # Block for a second
        ($queue, $task_id) = $redis->brpop(@$queues, 1);
        unless (defined $queue) {
            return;
        }
    }
    my $task_counter_id = _get_task_counter_id_from_task_id($task_id);
    my $data;
    my %task_data;
    $redis->multi(\&_empty);
    $redis->hincrby($PFQUEUE_COUNTER, $task_counter_id, -1, \&_empty);
    $redis->hgetall($task_id, \&_empty);
    $redis->exec(sub {
        my ($replies, $error) = @_;
        return if defined $error;
        # Get the second reply which gets the data from the task hash
        my ($hget_reply, $hget_error) = @{$replies->[1]};
        return if defined $hget_error;
        %task_data = map { $_->[0] } @{$hget_reply};
    });
    $redis->wait_all_responses();
    $data = $task_data{data};
    if ($data) {
        local $@;
        $self->set_tenant_id(\%task_data);
        eval {
            local $@;
            sereal_decode_with_object($DECODER, $data, my $item);
            if (ref($item) ne 'ARRAY') {
                die "Invalid object stored in queue";
            }

            my $type = $item->[0];
            my $args = $item->[1];
            my $task = "pf::task::$type"->new;
            if($task_data{status_update}) {
                $logger->debug("Reporting status for task $task_id");
                $task->set_status_updater($self->get_status_updater($task_id));
            }

            # Now that we're tracking the status of the job, we can delete the key marking it as non-pending
            $redis->del($task_id);
            my $status_updater = $task->status_updater;
            my ($err, $result) = eval {
                $status_updater->start();
                $task->doTask($args)
            };

            if ($@) {
                $err = $@;
            }

            if ($err) {
                unless (ref $err) {
                    $err = {message => $err, status => 500};
                }

                $status_updater->failed($err);
            } else {
                unless (ref $result) {
                    $result = {message => $result, status => 200};
                }

                $status_updater->completed($result);
            }
        };
        if ($@) {
            $logger->error($@);
        }
    } else {
        $redis->hincrby($PFQUEUE_EXPIRED_COUNTER, $task_counter_id, 1);
        $logger->error("Invalid task id $task_id provided");
    }
}

=head2 set_tenant_id

set_tenant_id

=cut

sub set_tenant_id {
    my ($self, $task_data) = @_;
    pf::dal->reset_tenant();
    my $tenant_id = $task_data->{tenant_id};
    if (defined $tenant_id) {
        pf::dal->set_tenant($tenant_id);
    }
}

=head2 _get_task_counter_id_from_task_id

Extract the task counter from the task id

=cut

sub _get_task_counter_id_from_task_id {
    my ($id) = @_;
    $id =~ /^Task:[^:]+:(.*)$/;
    return $1;
}

=head2 _build_redis

Build the redis client

=cut

sub _build_redis {
    my ($self) = @_;
    return pf::Redis->new(%{$self->redis_args}, on_connect => \&on_connect);
}

=head2 get_status_updater

Build the status updater

=cut

sub get_status_updater {
    my ($self, $task_id) = @_;
    unless(defined($STATUS_UPDATER_SINGLETON)) { 
        $STATUS_UPDATER_SINGLETON = pf::pfqueue::status_updater::redis->new(connection => $self->redis, task_id => $task_id);
    }
    else {
        $STATUS_UPDATER_SINGLETON->task_id($task_id);
    }
    return $STATUS_UPDATER_SINGLETON;
}

=head2 process_delayed_jobs

Process delayed jobs

=cut

sub process_delayed_jobs {
    my ($self, $params) = @_;
    my $redis = $self->redis;

    #Getting the current time from the redis service
    my ($seconds, $micro) = $redis->time;
    die "error getting time from the redis service" unless defined $seconds && defined $micro;
    my $time_milli = $seconds * 1000 + int($micro / 1000);
    $redis->evalsha($LUA_DELAY_JOBS_MOVE_SHA1, 2, $params->{delay_queue}, $params->{submit_queue}, $time_milli, $params->{batch});
    # Sleep for 10 milliseconds
    usleep($params->{batch_usleep});
}

=head2 on_connect

What actions to do when connecting to a redis server

=cut

sub on_connect {
    my ($redis) = @_;
    if($LUA_DELAY_JOBS_MOVE_SHA1) {
        my ($loaded) = $redis->script('EXISTS',$LUA_DELAY_JOBS_MOVE_SHA1);
        return if $loaded;
    }
    ($LUA_DELAY_JOBS_MOVE_SHA1) = $redis->script('LOAD',$LUA_DELAY_JOBS_MOVE);
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
