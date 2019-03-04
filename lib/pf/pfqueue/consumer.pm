package pf::pfqueue::consumer;

=head1 NAME

pf::pfqueue::consumer -

=cut

=head1 DESCRIPTION

pf::pfqueue::consumer

=cut

use strict;
use warnings;
use Moo;

=head2 process_next_job

Process the next job in the queue

=cut

sub process_next_job {
    die "process_next_job not implemented";
}

=head2 process_delayed_jobs

Process delayed jobs

=cut

sub process_delayed_jobs {
    die "process_delayed_jobs not implemented";
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
