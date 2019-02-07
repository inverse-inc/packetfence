package pf::filter;

=head1 NAME

pf::filter

=cut

=head1 DESCRIPTION

pf::filter

=cut

use strict;
use warnings;
use Moose;

=head1 ATTRIBUTES

=head2 conditions

The conditions of the filter

=cut

has condition => (
    is => 'ro',
    isa => 'pf::condition',
);

=head2 answer

The answer of the filter

=cut

has answer => (
   is => 'ro',
   required => 1,
);

=head1 METHODS

=head2 match

Test to see if the condition of the filter matches

=cut

sub match {
    my ($self,$arg) = @_;
    return $self->condition->match($arg);
}

=head2 get_answer

Returns the answer

=cut

sub get_answer {
    my ($self) = @_;
    return $self->answer;
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

