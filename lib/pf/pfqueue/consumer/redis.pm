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
use pf::log;
use pf::Sereal qw($DECODER);
use Moo;
use pf::util::pfqueue qw(task_counter_id);
use pf::constants::pfqueue qw($PFQUEUE_COUNTER $PFQUEUE_EXPIRED_COUNTER);
extends qw(pf::pfqueue::consumer);

has 'redis' => (is => 'rw', lazy => 1, builder => 1);

has 'redis_args' => (is => 'rw', default => sub { {} });

has 'queue_name' => (is => 'rw');

has 'delay_queue' => (is => 'rw');

has 'submit_queue' => (is => 'rw');

has 'batch' => (is => 'rw');

has 'batch_sleep' => (is => 'rw');

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

=head2 process_next_job

Process the next job in the queue

=cut

sub process_next_job {
    my ($self) = @_;
    my $redis = $self->redis;
    my $queue_name = $self->queue_name;
    my $logger = get_logger();
    my ($queue, $task_id) = $redis->brpop($queue_name, 1);
    if ($queue) {
        my $data = $redis->hget($task_id, 'data');
        my $task_counter_id = _get_task_counter_id_from_task_id($task_id);
        if($data) {
            local $@;
            eval {
                sereal_decode_with_object($DECODER, $data, my $item);
                if (ref ($item) eq 'ARRAY' ) {
                    my $type = $item->[0];
                    my $args = $item->[1];
                    eval {
                        "pf::task::$type"->doTask($args);
                    };
                    die $@ if $@;
                } else {
                    $logger->error("Invalid object stored in queue");
                }
            };
            if ($@) {
                $logger->error($@);
            }
        } else {
            $redis->hincrby($PFQUEUE_EXPIRED_COUNTER, $task_counter_id, 1, sub { });
            $logger->error("Invalid task id $task_id provided");
        }
        $redis->hincrby($PFQUEUE_COUNTER, $task_counter_id, -1, sub { });
        $redis->del($task_id, sub {});
        $redis->wait_all_responses();
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

=head2 process_delayed_jobs

Process delayed jobs

=cut

sub process_delayed_jobs {
    my ($self) = @_;
    my $redis = $self->redis;

    #Getting the current time from the redis service
    my ($seconds, $micro) = $redis->time;
    die "error getting time from the redis service" unless defined $seconds && defined $micro;
    my $time_milli = $seconds * 1000 + int($micro / 1000);
    $redis->evalsha($LUA_DELAY_JOBS_MOVE_SHA1, 2, $self->delay_queue, $self->submit_queue, $time_milli, $self->batch);
    # Sleep for 10 milliseconds
    usleep($self->batch_sleep);
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

1;
