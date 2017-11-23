package pf::pfmon::task::queue_stats;

=head1 NAME

pf::pfmon::task::queue_stats - class for pfmon task queue counts

=cut

=head1 DESCRIPTION

pf::pfmon::task::queue_stats

=cut

use strict;
use warnings;
use pf::log;
use pf::StatsD;
use pf::pfqueue::stats;
use Moose;
extends qw(pf::pfmon::task);


=head2 run

Poll the queue counts and record them in statsd

=cut

sub run {
    my ($self) = @_;
    my $logger = get_logger;
    $logger->debug("Polling counters from queues to record them in statsd");
    my $statsd = pf::StatsD->new;

    my $queue_counts = pf::pfqueue::stats->new->queue_counts;
    for my $info (@{$queue_counts}) {
        my $queue_name = $info->{name};
        my $count = $info->{count};
        $logger->debug("Setting queue count of $queue_name to $count in statsd");
        $statsd->gauge("pfqueue.stats.queue_counts.$queue_name", $count, 1);
    }
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
