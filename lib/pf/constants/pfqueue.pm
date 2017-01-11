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
    $PFQUEUE_DELAYED_QUEUE_BATCH_DEFAULT
    $PFQUEUE_DELAYED_QUEUE_WORKERS_DEFAULT
    $PFQUEUE_DELAYED_QUEUE_SLEEP_DEFAULT
);

our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
);

our $PFQUEUE_COUNTER = "TaskCounters";

our $PFQUEUE_EXPIRED_COUNTER = "ExpiredCounters";

our $PFQUEUE_QUEUE_PREFIX = "Queue:";

our $PFQUEUE_WORKERS_DEFAULT = 10;

our $PFQUEUE_DELAYED_QUEUE_BATCH_DEFAULT = 100;

our $PFQUEUE_DELAYED_QUEUE_WORKERS_DEFAULT = 1;

our $PFQUEUE_DELAYED_QUEUE_SLEEP_DEFAULT = 100;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
