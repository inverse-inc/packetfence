package pfappserver::Form::Field::SourceRuleCondition;

=head1 NAME

pfappserver::Form::Field::SourceRuleCondition - Rules of a user source

=head1 DESCRIPTION

Form definition to manage the rules (conditions and actions) of an
authentication source.

=cut

use pfappserver::Form::Field::DynamicList;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
use pf::Authentication::constants;
has '+widget_wrapper' => (default => 'Bootstrap');
has '+inflate_default_method'=> ( default => sub { \&inflate } );
has '+deflate_value_method'=> ( default => sub { \&deflate } );


# Form fields

has_field 'attribute' => (
    type            => 'Select',
    localize_labels => 1,
    required        => 1,
    element_attr   => {
        'data-required' => 'required',
    },
    widget_wrapper  => 'None',
    options_method  => \&options_attributes,
    element_class   => ['span5'],
    do_label        => 0,
);

has_field 'operator' => (
    type           => 'Select',
    required        => 1,
    element_attr   => {
        'data-required' => 'required',
    },
    widget_wrapper => 'None',
    options_method => \&options_operators,
    element_class  => ['span3'],
    do_label       => 0,
);

has_field 'value' => (
    type           => 'Text',
    required       => 1,
    element_attr   => {
        'data-required' => 'required',
    },
    do_label       => 0,
    widget_wrapper => 'None',
);

=head2 options_attributes

Populate the condition attributes select field with the available attributes of
the authentication source.

=cut

sub options_attributes {
    my $self = shift;

    my $form = $self->form;
    my @attributes = map {{label => $_->{value}, value => $_->{value}, attributes => {'data-type' => $_->{type}}}}
      @{$form->get_source->available_attributes // []};

    return @attributes;
}


=head2 options_operators

Populate the operators select field with all possible options.
The options will be later limited using JavaScript when displaying the rule.

=cut

sub options_operators {
    my $self = shift;

    my %all_operators = map {
        map {$_ => 1} @{$_}
    } values %Conditions::OPERATORS;
    my @options = map {$_ => $_} keys %all_operators;

    return @options;
}

=head2 inflate

inflate the value from the config store

=cut

sub inflate {
    my ($self, $value) = @_;
    my %condition;
    @condition{qw(attribute operator value)} = split /\s*,\s*/, $value, 3;
    return \%condition;
}

=head2 deflate

deflate to be saved into the config store

=cut

sub deflate {
    my ($self, $value) = @_;
    return join(",", @{$value}{qw(attribute operator value)});
}

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
