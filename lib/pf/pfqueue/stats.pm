package pf::pfqueue::stats;

=head1 NAME

pf::pfqueue::stats

=head1 DESCRIPTION

Object for collecting pfqueue stats

=cut

use Moo;
use namespace::autoclean;
use pf::config::pfqueue;
use pf::log;
use pf::util::pfqueue qw(consumer_redis_client);
use pf::constants::pfqueue qw($PFQUEUE_COUNTER $PFQUEUE_QUEUE_PREFIX $PFQUEUE_EXPIRED_COUNTER);

has redis => (is => 'ro', builder => 1, lazy => 1);

has stats_data => (is => 'rw', builder => 1, lazy => 1);

=head1 METHODS

=head2 my $counters = $self->counters()

Get all the task counters

=cut

sub counters {
    my ($self) = @_;
    return $self->stats_data->{counters};
}

=head2 my $miss_counters = $self->miss_counters()

Get all the miss counters

=cut

sub miss_counters {
    my ($self) = @_;
    return $self->stats_data->{miss_counters};
}

=head2 $counters = $self->_get_counters_for($counter_name)

Get all the counters for a namespace

=cut

sub _get_counters_for {
    my ($self, $counter_name) = @_;
    my $redis = $self->redis;
    my %counters = $redis->hgetall($counter_name);
    my @counters = map { _counter_map(\%counters, $_) } sort keys %counters;
    return \@counters;
}

=head2 my $counter = _counter_map($counters, $key)

Utility function for normalizing the counter data

=cut

sub _counter_map {
    my ($counters, $key) = @_;
    return unless $key =~ /^\Q$PFQUEUE_QUEUE_PREFIX\E([^:]+):(.*)$/;
    my $queue = $1;
    my $name = $2;
    my %counter = (
        name => $name,
        queue => $queue,
        count => $counters->{$key},
    );
    return \%counter;
}

=head2 _build_stats_data

_build_stats_data

=cut

sub _build_stats_data {
    my ($self) = @_;
    my @queues = @{$ConfigPfqueue{queues}};
    my @queue_counts = map {{name => $_->{name}, count => -1}} @queues;
    my %stats = (
        queue_counts => \@queue_counts,
        miss_counters => [],
        counters => [],
    );
    my $redis = $self->redis;
    if (!defined $redis) {
        return \%stats;
    }

    $redis->multi(sub {});
    foreach my $queue (@queues) {
        my $name = $queue->{name};
        my $qname = "${PFQUEUE_QUEUE_PREFIX}${name}";
        $redis->llen($qname, sub { });
    }
    $redis->hgetall($PFQUEUE_COUNTER ,sub {});
    $redis->hgetall($PFQUEUE_EXPIRED_COUNTER ,sub {});
    $redis->exec(sub {
        my ($replies, $error) = @_;
        return if defined $error;
        my $i = 0;
        for (; $i < @queues;$i++) {
            my ($reply, $error) = @{$replies->[$i]};
            next if defined $error;
            $queue_counts[$i]{count} = $reply;
        }
        for my $counter (qw(counters miss_counters))  {
            my ($reply, $error) = @{$replies->[$i]};
            next if defined $error;
            my %c = map { $_->[0] } @$reply;
            @{$stats{$counter}} = map { _counter_map(\%c, $_) } sort keys %c;
        } continue {
            $i++;
        }
    });
    $redis->wait_all_responses;
    return \%stats;
}

=head2 _build_redis

=cut

sub _build_redis {
    my ($self) = @_;
    my $redis = eval {
        consumer_redis_client();
    };
    if ($@) {
        get_logger->error($@);
        return undef;
    }

    return $redis;
}

=head2 $queue_counts = $self->queue_counts();

=cut

sub queue_counts {
    my ($self) = @_;
    return $self->stats_data->{queue_counts};
}

=head2 queue_count

=cut

sub queue_count {
    my ($self, $queue) = @_;
    return $self->redis->llen("${PFQUEUE_QUEUE_PREFIX}${queue}");
}

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
