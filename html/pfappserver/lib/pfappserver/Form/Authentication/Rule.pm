package pfappserver::Form::Authentication::Rule;

=head1 NAME

pfappserver::Form::Authentication::Rule - Rules of a user source

=head1 DESCRIPTION

Form definition to manage the rules (conditions and actions) of an
authentication source.

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';
with 'pfappserver::Form::Widget::Theme::Pf';

use pf::Authentication::Action;

has '+field_name_space' => ( default => 'pfappserver::Form::Field' );
has '+widget_name_space' => ( default => 'pfappserver::Form::Widget' );
has '+language_handle' => ( builder => 'get_language_handle_from_ctx' );

# Form select options
has 'attrs' => ( is => 'ro' );

# Form fields
has_field 'id' =>
  (
   type => 'Text',
   label => 'Name',
   required => 1,
   messages => { required => 'Please specify an identifier for the rule.' },
   apply => [ { check => qr/^\S+$/, message => 'The name must not contain spaces.' } ],
  );
has_field 'description' =>
  (
   type => 'Text',
   label => 'Description',
   required => 0,
  );
has_field 'match' =>
  (
   type => 'Select',
   widget_wrapper => 'None',
   options => 
   [
    { value => 'any', label => 'any' },
    { value => 'all', label => 'all' },
   ],
   element_class => ['input-mini'],
  );
has_field 'conditions' =>
  (
   type => 'Repeatable',
   num_extra => 1, # add extra row that serves as a template
  );
has_field 'conditions.attribute' =>
  (
   type => 'Select',
   options_method => \&options_attributes,
   widget_wrapper => 'None',
   element_class => ['span3'],
  );
has_field 'conditions.operator' =>
  (
   type => 'Select',
   options =>
   [
    { value => 'equals', label => 'equals' },
    { value => 'contains', label => 'contains' },
   ],
   widget_wrapper => 'None',
   element_class => ['span3'],
  );
has_field 'conditions.value' =>
  (
   type => 'Text',
   element_class => ['span5'],
  );
has_field 'actions' =>
  (
   type => 'Repeatable',
   num_extra => 1, # add extra row that serves as a template
  );
has_field 'actions.type' =>
  (
   type => 'Select',
   widget_wrapper => 'None',
   options_method => \&options_actions,
   element_class => ['span3'],
  );
has_field 'actions.value' =>
  (
   type => 'Text',
  );

=head2 options_attributes

Populate the attributes select field with the available attributes of the
authentication source.

=cut

sub options_attributes {
    my $self = shift;
    
    my $form = $self->form;
    my @attributes = map { $_ => $_ } @{$form->attrs} if ($form->attrs);

    return @attributes;
}

=head2 options_actions

Populate the actions select field with the available actions of the
authentication source.

=cut

sub options_actions {
    my $self = shift;

    my $actions_ref = pf::Authentication::Action::availableActions();
    my @actions = map { $_ => $_ } @{$actions_ref};

    return @actions;
}

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

__PACKAGE__->meta->make_immutable;
1;
