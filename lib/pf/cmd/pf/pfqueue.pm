package pf::cmd::pf::pfqueue;

=head1 NAME

pf::cmd::pf::pfqueue

=head1 SYNOPSIS

 pfcmd pfqueue <command> [options]

  Commands:

   clear <queue>          | clear a queue
   clear_expired_counters | clear expired tasks counters
   count <queue>          | show the queue count
   list                   | list all queues
   stats                  | show stats of pfqueue

=head1 DESCRIPTION

Sub-commands to interact with pfqueue via pfcmd.

=cut

use strict;
use warnings;
use pf::constants;
use pf::constants::exit_code qw($EXIT_SUCCESS);
use pf::constants::pfqueue qw($PFQUEUE_COUNTER $PFQUEUE_EXPIRED_COUNTER);
use pf::config::pfqueue;
use pf::util::pfqueue qw(consumer_redis_client);
use pf::pfqueue::stats;
use base qw(pf::base::cmd::action_cmd);

our @STATS_FIELDS = qw(queue name count);
our @COUNT_FIELDS = qw(name count);
our $STATS_HEADING_FORMAT = "| %-30s | %-30s | %-10s |\n";
our $STATS_FORMAT = "| %-30s | %-30s | % 10d |\n";
our $COUNT_HEADING_FORMAT = "| %-30s | %-10s |\n";
our $COUNT_FORMAT = "| %-30s | % 10d |\n";

sub stats {
    return pf::pfqueue::stats->new;
}

=head2 action_clear

Clear a queue

=cut

sub action_clear {
    my ($self) = @_;
    my ($queue) = $self->action_args;
    my $redis = consumer_redis_client();
    $redis->del("Queue:$queue");
    return $EXIT_SUCCESS;
}

=head2 action_list

List all the queue

=cut

sub action_list {
    my ($self) = @_;
    foreach my $queue (@{$ConfigPfqueue{queues}}) {
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
    $self->_print_counters("Queue Counts\n", $COUNT_HEADING_FORMAT, $COUNT_FORMAT, \@COUNT_FIELDS, $stats->queue_counts);
    $self->_print_counters("Outstanding Task Counters\n", $STATS_HEADING_FORMAT, $STATS_FORMAT, \@STATS_FIELDS, $stats->counters);
    $self->_print_counters("Expired Task Counters\n", $STATS_HEADING_FORMAT, $STATS_FORMAT, \@STATS_FIELDS, $stats->miss_counters);
    print "\n";
    return $EXIT_SUCCESS;
}

sub _print_counters {
    my ($self, $title, $heading_format, $format, $fields, $counters) = @_;
    return if @$counters == 0;
    print "\n$title\n";
    my $heading = sprintf($heading_format, @$fields);
    my $delimter = $heading;
    $delimter =~ s/./-/g;
    print $delimter;
    print $heading;
    print $delimter;
    foreach my $counter (@$counters) {
        print sprintf($format, @{$counter}{@$fields});
    }
    print $delimter;
}

=head2 action_count

=cut

sub action_count {
    my ($self) = @_;
    my ($queue) = $self->action_args;
    print $self->stats->queue_count($queue),"\n";
    return $EXIT_SUCCESS;
}

=head2 action_clear_expired_counters

clear expired counters

=cut

sub action_clear_expired_counters {
    my ($self) = @_;
    my $redis = consumer_redis_client();
    $redis->del($PFQUEUE_EXPIRED_COUNTER);
    return $EXIT_SUCCESS;
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
