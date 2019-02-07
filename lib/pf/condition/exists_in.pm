package pf::condition::exists_in;

=head1 NAME

pf::condition::exists_in - checks if a value exists in a hash

=cut

=head1 DESCRIPTION

pf::condition::exists_in

=cut

use strict;
use warnings;
use Moose;
use MooseX::Types::Moose qw(HashRef);
extends qw(pf::condition);
use pf::constants;

=head2 lookup

The hash to lookup the values

=cut

has lookup => (
    is => 'ro',
    isa => HashRef,
    required => 1,
);

=head2 match

Matches if the argument exists in the hash

=cut

sub match {
    my ($self,$arg) = @_;
    return $FALSE if(!defined($arg));
    return exists ${$self->lookup}{$arg} ? $TRUE : $FALSE;
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
