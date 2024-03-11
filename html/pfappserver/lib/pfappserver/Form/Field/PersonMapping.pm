package pfappserver::Form::Field::PersonMapping;

=head1 NAME

pfappserver::Form::Field::PersonMapping -

=cut

=head1 DESCRIPTION

pfappserver::Form::Field::PersonMapping

=cut

use strict;
use warnings;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
use namespace::autoclean;
use pf::log;
use pf::dal::person;
use pf::Authentication::utils;

has '+inflate_default_method'=> ( default => sub { \&inflate } );
has '+deflate_value_method'=> ( default => sub { \&deflate } );
has '+widget_wrapper' => (default => 'Bootstrap');
has '+do_label' => (default => 1 );

has_field person_field => (
    type => 'Select',
    do_label => 0,
    required => 1,
    widget_wrapper => 'None',
    options_method => \&options_person_field,
    element_class => ['input-medium'],
    localize_labels => 1,
);

has_field openid_field => (
    type => 'Text',
    do_label => 0,
    required => 1,
    widget_wrapper => 'None',
    element_class => ['input-xxlarge'],
);

=head2 options_person_field

options_person_field

=cut

sub options_person_field {
    return [
        map { { label => $_, value => $_ } }
          grep { $_ ne 'pid' }
          @{ pf::dal::person->table_field_names }
    ];
}

=head2 inflate

inflate the api method spec string to a hash

=cut

sub inflate {
    my ($self, $value) = @_;
    if (ref $value) {
        return $value;
    }

    return pf::Authentication::utils::inflatePersonMapping($value);
}

=head2 deflate

deflate the api method spec hash to a string

=cut

sub deflate {
    my ($self, $value) = @_;
    return join(":", $value->{person_field}, $value->{openid_field});
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
