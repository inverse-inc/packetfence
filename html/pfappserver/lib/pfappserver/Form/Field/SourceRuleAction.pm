package pfappserver::Form::Field::SourceRuleAction;

=head1 NAME

pfappserver::Form::Field::SourceRuleAction - action of a user source rule

=head1 DESCRIPTION

Manages the action of  user source rule

=cut

use pfappserver::Form::Field::DynamicList;
use pf::Authentication::Action;
use HTML::FormHandler::Moose;
use pf::Authentication::constants;

extends 'HTML::FormHandler::Field::Compound';
has '+widget_wrapper' => (default => 'Bootstrap');
has '+inflate_default_method'=> ( default => sub { \&inflate } );
has '+deflate_value_method'=> ( default => sub { \&deflate } );

# Form fields

has_field 'type' => (
    type           => 'Select',
    widget_wrapper => 'None',
    options_method => \&options_type,
    do_label       => 0,
);

has_field 'value' => (
    type           => 'Text',
    do_label       => 0,
    required       => 1,
    widget_wrapper => 'None',
);

=head2 options_type

Populate the action type select field with the available actions of the
authentication source.

=cut

sub options_type {
    my ($self) = @_;
    my $form = $self->form;
    my $rule_class = $self->parent->parent->parent->rule_class;

    my @allowed_actions = $form->_get_allowed_options('allowed_actions');
    unless (@allowed_actions) {
        my $source = $form->get_source;
        @allowed_actions = @{$source->available_actions()};
    }
    my @actions = map {
      {
        value => $_,
        label => $self->_localize($_),
      }
    } grep { pf::Authentication::Action->getRuleClassForAction($_) eq $rule_class } @allowed_actions;

    return @actions;
}

=head2 inflate

inflate the value from the config store

=cut

sub inflate {
    my ($self, $value) = @_;
    my %condition;
    @condition{qw(type value)} = split /\s*=\s*/, $value;
    return \%condition;
}

=head2 deflate

deflate to be saved into the config store

=cut

sub deflate {
    my ($self, $value) = @_;
    if(ref(@{$value}{value}) eq 'ARRAY' ) {
        my $list = join(',', @{@{$value}{value}});
        return @{$value}{type}."=".$list;
    }
    return join("=", @{$value}{qw(type value)});
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
