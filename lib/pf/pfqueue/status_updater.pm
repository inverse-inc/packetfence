package pf::pfqueue::status_updater;


=head1 NAME

pf::pfqueue::status_updater

=cut

=head1 DESCRIPTION

Base class for updating the status of a job
All subs are no-op so this could be used directly

=cut

use strict;
use warnings;

use Moo;

=head2 start

start tracking the status/process of a job

=cut

sub start { }

=head2 failed

mark a job as failed

=cut

sub failed { }

=head2 completed

mark a job as completed

=cut

sub completed { }

=head2 update_progress

Update progress and optionally the message of the task status
The progress will normalized to be between 0 and 99
The progress can only be set to 100 by $su->completed($results) or $su->failed($err)

=cut

sub update_progress { }

=head2 update_message

update message of task

=cut

sub update_message { }

=head2 finalize

Finalize a job which stops all status updates

=cut

sub finalize {}

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
