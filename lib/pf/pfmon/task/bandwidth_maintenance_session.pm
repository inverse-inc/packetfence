package pf::pfmon::task::bandwidth_maintenance_session;

=head1 NAME

pf::pfmon::task::bandwidth_maintenance_session - class for pfmon task inline accounting maintenance

=cut

=head1 DESCRIPTION

pf::pfmon::task::bandwidth_maintenance_session

=cut

use strict;
use warnings;
use pf::bandwidth_accounting;
use pf::util qw(isenabled);
use Moose;
extends qw(pf::pfmon::task);

has 'batch' => ( is => 'rw');
has 'timeout' => ( is => 'rw', isa => 'PfInterval', coerce => 1);
has 'window' => ( is => 'rw', isa => 'PfInterval', coerce => 1);

=head2 run

run the bandwidth session cleaning tasks

=cut

sub run {
    my ($self) = @_;
    pf::bandwidth_accounting::clean_old_sessions(
        $self->window,
        $self->batch,
        $self->timeout,
    );
}

=head1 AUTHOR


Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
