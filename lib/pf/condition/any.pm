package pf::condition::any;
=head1 NAME

pf::condition::any

=cut

=head1 DESCRIPTION

pf::condition::any

=cut

use strict;
use warnings;
use Moose;
extends qw(pf::condition);
use List::MoreUtils qw(any);

=head2 conditions

The sub conditions to match

=cut

has conditions => (
    traits  => ['Array'],
    isa     => 'ArrayRef[pf::condition]',
    default => sub {[]},
    handles => {
        all_conditions        => 'elements',
        add_condition         => 'push',
        count_conditions      => 'count',
        has_conditions        => 'count',
        no_conditions         => 'is_empty',
    },
);

=head2 match

Matches any the sub conditions

=cut

sub match {
    my ($self, $arg) = @_;
    return any { $_->match($arg) } $self->all_conditions;
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

