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

=head2 set_status

Set the status of the job

=cut

sub set_status {}

=head2 set_status_msg

Set the status message for the job

=cut

sub set_status_msg {}

=head2 set_sub_tasks

Set the list of sub tasks

=cut

sub set_sub_tasks {}

=head2 set_current_sub_task

Set the current sub task

=cut

sub set_current_task {}

=head2 set_progress

Set the progress of the job (on 100)

=cut

sub set_progress {}

=head2 set_result

Set the result of the job

=cut

sub set_result {}

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

