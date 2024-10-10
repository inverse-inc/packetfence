package pfappserver::Form::Field::FilterCondition;

=head1 NAME

pfappserver::Form::Field::FilterCondition -

=head1 DESCRIPTION

pfappserver::Form::Field::FilterCondition

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
with 'pfappserver::Base::Form::Role::Help';


=head2 name

Name

=cut

has_field 'field' => (
    type     => 'SelectSuggested',
    label    => 'Field',
    options_method => \&options_field,
);

has_field 'value' => (
    type     => 'Text',
    label    => 'Value',
);

sub options_field {
    my ($field) = @_;
    my $form = $field->form;
    return $form->options_field;
}

sub make_options {
    my ($requires, @ops) = @_;
    return map {
        { label => $_, value => $_, requires => $requires },
    } @ops;
}

sub make_options_with_not {
    my ($requires, @ops) = @_;
    return map {
        (
            { label => $_, value => $_, requires => $requires },
            { label => "not_$_", value => "not_$_", requires => $requires },
        )
    } @ops;
}

has_field 'op' => (
    type     => 'Select',
    label    => 'Value',
    required => 1,
    default  => 'and',
    options => [
        make_options( ['values'], qw(and or not_and not_or) ),
        make_options_with_not(
            [qw(value field)], qw(
              contains
              equals
              starts_with
              ends_with
              regex
              includes
              fingerbank_device_is_a
              date_is_before
              date_is_after)
        ),
        make_options_with_not( [qw(field)], qw(defined) ),
        make_options( [qw(value)], qw(time_period not_time_period) ),
        make_options( [], 'true'),
      ],
);

has_field values => (
    type => 'Repeatable',
    num_when_empty => 0,
);

has_field 'values.contains' => (
    type => 'Nested',
);

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
