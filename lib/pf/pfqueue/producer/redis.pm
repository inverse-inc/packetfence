package pf::pfqueue::producer::redis;

=head1 NAME

pf::pfqueue::producer::redis - The client for adding messages to pfqueue via redis

=cut

=head1 DESCRIPTION

pf::pfqueue::producer::redis

=cut

use strict;
use warnings;
use Moo;
extends qw(pf::pfqueue::producer);
use pf::Redis;
use pf::dal;
use List::MoreUtils qw(all);
use Sereal::Encoder qw(sereal_encode_with_object);
use pf::Sereal qw($ENCODER);
use pf::task;
use pf::util::pfqueue qw(task_counter_id);
use pf::constants::pfqueue qw($PFQUEUE_COUNTER $PFQUEUE_QUEUE_PREFIX);

our $DEFAULT_EXPIRATION = 300;

=head2 redis

The redis client to use

=cut

has redis => (
    is      => 'rw',
    builder => 1,
    lazy    => 1,
);

=head2 server

The server of the redis client

=cut

has server => (
    is       => 'rw',
    required => 1,
    default  => sub { "127.0.0.1:6380" },
);

=head2 _build_redis

Build the redis client

=cut

sub _build_redis {
    my ($self) = @_;
    my %args;
    my $server = $self->server;

    #If there is a / then consider it unix socket
    if ($server =~ m#/#) {
        $args{sock} = $server;
    }
    else {
        $args{server} = $server;
    }
    return pf::Redis->new(%args);
}

=head2 submit

Submit a task to the queue

=cut

sub submit {
    my ($self, $queue, $task_type, $task_data, $expire_in, %opts) = @_;
    $expire_in //= $DEFAULT_EXPIRATION;
    my $queue_name = $PFQUEUE_QUEUE_PREFIX . $queue;
    my $task_counter_id = task_counter_id($queue_name, $task_type, $task_data);
    my $id    = pf::task->generateId($task_counter_id);
    my $redis = $self->redis;
    # Batch the creation of the task and it's ttl and placing it on the queue to improve performance
    $redis->multi(sub {});
    $redis->hmset($id, data => sereal_encode_with_object($ENCODER, [$task_type, $task_data]), expire => $expire_in, tenant_id => pf::dal->get_tenant(), , %opts, sub {});
    $redis->expire($id, $expire_in, sub {});
    $redis->hincrby($PFQUEUE_COUNTER, $task_counter_id, 1, sub {});
    $redis->lpush($queue_name, $id, sub {});
    $redis->exec(sub {});
    $redis->wait_all_responses();
    return $id;
}

sub submit_delayed {
    my ($self, $queue, $task_type, $delay, $task_data, $expire_in, %opts) = @_;
    $expire_in //= $DEFAULT_EXPIRATION;
    my $queue_name = $PFQUEUE_QUEUE_PREFIX . $queue;
    my $task_counter_id = task_counter_id($queue_name, $task_type, $task_data);
    my $id    = pf::task->generateId($task_counter_id);
    my $redis = $self->redis;
    #Getting the current time from the redis service
    my ($seconds, $micro) = $redis->time;
    my $time_milli = $seconds * 1000 + int($micro / 1000);
    $time_milli += $delay;
    # Batch the creation of the task and it's ttl and placing it on the queue to improve performance
    $redis->multi(sub {});
    $redis->hmset($id, data => sereal_encode_with_object($ENCODER, [$task_type, $task_data]), expire => $expire_in, tenant_id => pf::dal->get_tenant(), %opts, sub {});
    $redis->expire($id, $expire_in + int($delay / 1000), sub {});
    $redis->hincrby($PFQUEUE_COUNTER, $task_counter_id, 1, sub {});
    $redis->zadd("Delayed:$queue", $time_milli, $id, sub {});
    $redis->exec(sub {});
    $redis->wait_all_responses();
    return $id;
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
