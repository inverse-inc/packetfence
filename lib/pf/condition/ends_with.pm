package pf::condition::ends_with;

=head1 NAME

pf::condition::ends_with

=cut

=head1 DESCRIPTION

pf::condition::ends_with

Check if the value defined in the condition ends with a value

=cut

use strict;
use warnings;
use Moose;
extends qw(pf::condition);

=head2 value

The value to match against

=cut

has value => (
    is => 'ro',
    required => 1,
    isa  => 'Str',
);

=head2 match

Check if the value ends with the string passed as an argument

=cut

sub match {
    my ($self,$arg) = @_;
    my $value = quotemeta $self->value;
    return 0 if(!defined($arg));
    return $arg =~ /$value\z/;
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
