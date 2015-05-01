package pf::condition::key_couple;

=head1 NAME

pf::condition::key_couple add documentation

=cut

=head1 DESCRIPTION

pf::condition::key_couple

=cut

use strict;
use warnings;

use Moose;
extends 'pf::condition';

=head1 ATTRIBUTES

=head2 key1/key2

The key pairs to use for matching

=cut

has key1 => (is => 'ro', required => 1);

has key2 => (is => 'ro', required => 1);

has value => (
    is       => 'ro',
    required => 1,
    isa      => 'Str',
    trigger => \&_trigger_value,
);

=head2 value1/value2

The values pairs to use for matching

=cut

has [qw(value1 value2)] => (is => 'rw');

=head2 value

add a trigger to the value

=cut

=head1 METHODS

=head2 match

Matches value based off key in provided hash

=cut

sub match {
    my ($self, $data) = @_;
    my $key1 = $self->key1;
    my $key2 = $self->key2;
    return
         exists $data->{$key1}
      && exists $data->{$key2}
      && defined $data->{$key1}
      && defined $data->{$key2}
      && $data->{$key1} eq $self->value1
      && $data->{$key2} eq $self->value2;
}

=head2 _trigger_value

Set value1 and value2 from the value

=cut

sub _trigger_value {
    my ($self) = @_;
    my ($value1, $value2) = split(/-/, $self->value);
    $self->value1($value1);
    $self->value2($value2);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
