package pfappserver::Form::Field::EnvVar;

=head1 NAME

pfappserver::Form::Field::EnvVar -

=head1 DESCRIPTION

pfappserver::Form::Field::EnvVar

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
with 'pfappserver::Base::Form::Role::Help';
has '+inflate_default_method'=> ( default => sub { \&inflate } );
has '+deflate_value_method'=> ( default => sub { \&deflate } );

=head2 name

Key

=cut

has_field 'name' => (
    type     => 'Text',
    label    => 'Name',
);

has_field 'value' => (
    type     => 'Text',
    label    => 'Value',
);

=head2 inflate

inflate the api method spec string to a hash

=cut

sub inflate {
    my ($self, $value) = @_;
    if (ref $value) {
        return $value;
    }

    my ($key, $val) = split("=", $value, 2);
    return {name => $key, value => $val}
}

=head2 deflate

deflate the api method spec hash to a string

=cut

sub deflate {
    my ($self, $value) = @_;
    return join("=", $value->{name}, $value->{value});
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

