package pf::cmd::pf::pfqueue;

=head1 NAME

pf::cmd::pf::pfqueue

=head1 SYNOPSIS

 pfcmd pfqueue <command> [options]

  Commands:

   clear <queue>    | clear the queue
   list             | list all the current queues
   stats            | show the stats
   count <queue>    | show the count of the a queue

=head1 DESCRIPTION

Sub-commands to interact with pfqueue via pfcmd.

=cut

use strict;
use warnings;
use pf::constants;
use pf::constants::exit_code qw($EXIT_SUCCESS);
use pf::constants::pfqueue qw($PFQUEUE_COUNTER);
use Redis::Fast;
use pf::config::pfqueue;
use pf::pfqueue::stats;
use base qw(pf::base::cmd::action_cmd);
our @STATS_FIELDS = qw(name queue count);
our @COUNT_FIELDS = qw(name count);
our $STATS_FORMAT = "  %-20s %-10s %-20s\n";
our $COUNT_FORMAT = "  %-20s %-10s\n";

sub stats {
    return pf::pfqueue::stats->new;
}

=head2 action_clear

Clear a queue

=cut

sub action_clear {
    my ($self) = @_;
    my ($queue) = $self->action_args;
    my $redis = $self->redis;
    $redis->del("Queue:$queue");
    return $EXIT_SUCCESS;
}

=head2 action_list

List all the queue

=cut

sub action_list {
    my ($self) = @_;
    foreach my $queue (@{$ConfigPfQueue{queues}}) {
        print "$queue->{name}\n";
    }
    return $EXIT_SUCCESS;
}

=head2 action_stats

Stats all the queue

=cut

sub action_stats {
    my ($self) = @_;
    my $stats = $self->stats;
    $self->_print_counters("Queue Counts\n", $COUNT_FORMAT, \@COUNT_FIELDS, $stats->queue_counts);
    $self->_print_counters("Outstanding Task Counters\n", $STATS_FORMAT, \@STATS_FIELDS, $stats->counters);
    $self->_print_counters("Expired Task Counters\n", $STATS_FORMAT, \@STATS_FIELDS, $stats->miss_counters);
    print "\n";
    return $EXIT_SUCCESS;
}

sub _print_counters {
    my ($self, $title, $format, $fields, $counters) = @_;
    print "\n$title\n";
    print sprintf($format, @$fields);
    foreach my $counter (@$counters) {
        print sprintf($format, @{$counter}{@$fields});
    }
}

=head2 action_count

=cut

sub action_count {
    my ($self) = @_;
    my ($queue) = $self->action_args;
    my $redis = $self->redis;
    my $real_queue = "Queue:$queue";
    print $redis->llen($real_queue),"\n";
    return $EXIT_SUCCESS;
}

sub redis {
    my ($self) = @_;
    return Redis::Fast->new( %{$ConfigPfQueue{consumer}{redis_args}});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
