package pf::pfmon::task::iplog_cleanup;

=head1 NAME

pf::pfmon::task::iplog_cleanup - class for pfmon task iplog cleanup

=cut

=head1 DESCRIPTION

pf::pfmon::task::iplog_cleanup

=cut

use strict;
use warnings;
use Moose;
use pf::iplog;
extends qw(pf::pfmon::task);

has 'batch' => ( is => 'rw', default => 100 );
has 'window' => ( is => 'rw', default => 2592000 );
has 'timeout' => ( is => 'rw', default => 10 );
has 'table' => ( is => 'rw' );

=head2 run

run the iplog cleanup task

=cut

sub run {
    my ($self) = @_;
    my $window = $self->window;
    pf::iplog::cleanup($window, $self->batch, $self->timeout, $self->table) if $self->window;
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
