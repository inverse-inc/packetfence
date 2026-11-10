package pf::condition::date_before;

=head1 NAME

pf::condition::date_before

=cut

=head1 DESCRIPTION

Check if a given date is before actual (or supplied) date

See pf::condition::date_compare for the supported formats

=cut

use strict;
use warnings;

use Moose;

extends 'pf::condition::date_compare';

=head2 compare_dates

Whether the given date is before the control date

=cut

sub compare_dates {
    my ($self, $date_to_compare, $date_control) = @_;
    return $date_to_compare < $date_control;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

