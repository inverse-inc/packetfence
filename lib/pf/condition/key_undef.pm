package pf::condition::key_undef;

=head1 NAME

pf::condition::key_undef

=cut

=head1 DESCRIPTION

pf::condition::key_undef

=cut

use strict;
use warnings;
use Moose;
extends qw(pf::condition);
use pf::constants;
use Scalar::Util qw(reftype);

=head2 key

The key to match in the hash

=cut

has key => (
    is => 'ro',
    required => 1,
    isa  => 'Str',
);

=head2 condition

The sub condition to match

=cut

has condition => (
    is => 'ro',
    required => 1,
    isa => 'pf::condition',
);

=head2 match

Match a sub condition using the value in a hash

=cut

sub match {
    my ($self,$arg,$args) = @_;
    if (!(defined($args))) {
        $args = $arg
    }

    return $FALSE unless defined $arg && reftype ($arg) eq 'HASH';
    my $key = $self->key;
    my $value = exists $arg->{$key} ? $arg->{$key} : undef;
    return $self->condition->match($value,$args);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

