package pf::condition::date_after;

=head1 NAME

pf::condition::date_after

=cut

=head1 DESCRIPTION

Check if a given date is after actual (or supplied) date

Date format is YYYY-MM-DD HH:MM:SS

=cut

use strict;
use warnings;

use Moose;
use POSIX qw(strftime);
use Time::Piece;

extends 'pf::condition';

has value => (
    is => 'rw',
    isa => 'Maybe[Str]',
    required => 0,
);

sub match {
    my ($self, $arg) = @_;

    my $date_format = "%Y-%m-%d %H:%M:%S";

    my $date_to_compare = $arg;
    my $date_control = $self->value // strftime $date_format, localtime;

    $date_to_compare = Time::Piece->strptime($date_to_compare, $date_format);
    $date_control = Time::Piece->strptime($date_control, $date_format);

    return $date_to_compare > $date_control;
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

