package pf::constants::pfqueue;

=head1 NAME

pf::constants::pfqueue - constants for pfqueue service

=cut

=head1 DESCRIPTION

pf::constants::pfqueue

=cut

use strict;
use warnings;
use base qw(Exporter);

our @EXPORT_OK = qw(
    $PFQUEUE_COUNTER
    $PFQUEUE_QUEUE_PREFIX
    $PFQUEUE_EXPIRED_COUNTER
    $PFQUEUE_WORKERS_DEFAULT
    $PFQUEUE_MAX_TASKS_DEFAULT
    $PFQUEUE_TASK_JITTER_DEFAULT
    $PFQUEUE_WEIGHT_DEFAULT
    $PFQUEUE_DELAYED_QUEUE_BATCH_DEFAULT
    $PFQUEUE_DELAYED_QUEUE_WORKERS_DEFAULT
    $PFQUEUE_DELAYED_QUEUE_SLEEP_DEFAULT
    $PFQUEUE_WEIGHTS

    $STATUS_KEY
    $STATUS_MSG_KEY
    $SUB_TASKS_KEY
    $CURRENT_SUB_TASK_KEY
    $PROGRESS_KEY
    $RESULT_KEY
    
    $STATUS_COMPLETED
    $STATUS_FAILED
    $STATUS_IN_PROGRESS
);

our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
);

our $PFQUEUE_COUNTER = "TaskCounters";

our $PFQUEUE_EXPIRED_COUNTER = "ExpiredCounters";

our $PFQUEUE_QUEUE_PREFIX = "Queue:";

our $PFQUEUE_WORKERS_DEFAULT = 0;

our $PFQUEUE_WEIGHT_DEFAULT = 1;

our $PFQUEUE_DELAYED_QUEUE_BATCH_DEFAULT = 100;

our $PFQUEUE_DELAYED_QUEUE_WORKERS_DEFAULT = 1;

our $PFQUEUE_DELAYED_QUEUE_SLEEP_DEFAULT = 100;

our $PFQUEUE_MAX_TASKS_DEFAULT = 2000;

our $PFQUEUE_TASK_JITTER_DEFAULT = 100;

our $PFQUEUE_WEIGHTS = 'QueueWeights';

=head2 Job status related constants

=cut

our $STATUS_KEY = "status";
our $STATUS_MSG_KEY = "status_msg";
our $SUB_TASKS_KEY = "sub_tasks";
our $CURRENT_SUB_TASK_KEY = "sub_task";
our $PROGRESS_KEY = "progress";
our $RESULT_KEY = "result";

our $STATUS_COMPLETED = "Completed";
our $STATUS_FAILED = "Failed";
our $STATUS_IN_PROGRESS = "In progress";

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
