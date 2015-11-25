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
use pf::util::pfqueue;
use base qw(pf::base::cmd::action_cmd);
our @STATS_FIELDS = qw(name queue count);

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
    my $config = pf::util::pfqueue::load_config_hash;
    my $inifile = tied(%$config);
    foreach my $queue ( map { s/^queue //;$_} $inifile->GroupMembers("queue")) {
        print "$queue\n";
    }
    return $EXIT_SUCCESS;
}

=head2 action_stats

Stats all the queue

=cut

sub action_stats {
    my ($self) = @_;
    my $counters = $self->counters;
    my $format = "%-20s %-10s %-20s\n";
    print sprintf($format, @STATS_FIELDS);
    foreach my $counter (@$counters) {
        print sprintf($format, @{$counter}{@STATS_FIELDS});
    }
    return $EXIT_SUCCESS;
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

sub counters {
    my ($self) = @_;
    my $redis = $self->redis;
    my %counters = $redis->hgetall($PFQUEUE_COUNTER);
    my @counters = map { &_counter_map(\%counters, $_) } sort keys %counters;
    return \@counters;
}

sub _counter_map {
    my ($counters, $key) = @_;
    $key =~ /Queue:([^:]+):(.*)$/;
    my $queue = $1;
    my $name = $2;
    my %counter = (
        name => $name,
        queue => $queue,
        count => $counters->{$key},
    );
    return \%counter;
}

sub redis {
    my ($self) = @_;
    return Redis::Fast->new( %{$self->redis_options});
}

sub redis_options {
    my ($self) = @_;
    my $config = pf::util::pfqueue::load_config_hash;
    my $consumer_options = $config->{consumer};
    my %options;
    foreach my $key ( map {s/^redis_(.*)$//;$1} keys %$consumer_options ) {
        $options{$key} = $consumer_options->{"redis_$key"};
    }
    return \%options;
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
