package pf::pfmon::task::bandwidth_maintenance;

=head1 NAME

pf::pfmon::task::bandwidth_maintenance - class for pfmon task inline accounting maintenance

=cut

=head1 DESCRIPTION

pf::pfmon::task::bandwidth_maintenance

=cut

use strict;
use warnings;
use pf::bandwidth_accounting qw(bandwidth_maintenance);
use pf::config qw(%Config);
use pf::util qw(isenabled);
use Moose;
extends qw(pf::pfmon::task);

has 'batch' => ( is => 'rw');
has 'timeout' => ( is => 'rw', isa => 'PfInterval', coerce => 1 );
has 'history_batch' => ( is => 'rw', default => "100" );
has 'history_timeout' => ( is => 'rw', isa => 'PfInterval', default => "10s" );
has 'history_window' => ( is => 'rw', isa => 'PfInterval', default => "2D" );

=head2 run

run the inline accounting maintenance task

=cut

sub run {
    my ($self) = @_;
    bandwidth_maintenance($self->batch, $self->timeout);
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
