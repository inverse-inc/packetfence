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

use pf::config;
use pf::Authentication::constants;
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
   options_method => \&options_operators,
   widget_wrapper => 'None',
   element_class => ['span3'],
  );
has_field 'conditions.value' =>
  (
   type => 'Hidden',
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
   type => 'Hidden',
  );

# The templates block contains the dynamic fields of the rule definition.
#
# The following fields depend on the selected condition attribute :
#  - the condition operators select fields
#  - the condition value fields
# The following fields depend on the selected action type :
#  - the action value fields
#
# The field substitution is made through JavaScript.

has_block 'templates' =>
  (
   tag => 'div',
   render_list => [
                   map( { ("${_}_operator", "${_}_value") } keys %Conditions::OPERATORS),
                   map( { "${_}_action" } @Actions::ACTIONS),
                  ],
   attr => { id => 'templates' },
   class => [ 'hidden' ],
  );
has_field "${Conditions::STRING}_operator" =>
  (
   type => 'Select',
   do_label => 0,
   wrapper => 0,
   options_method => \&operators,
   element_class => ['span3'],
  );
has_field "${Conditions::STRING}_value" =>
  (
   type => 'Text',
   do_label => 0,
   wrapper => 0,
   element_class => ['span5'],
  );
has_field "${Conditions::NUMBER}_operator" =>
  (
   type => 'Select',
   do_label => 0,
   wrapper => 0,
   options_method => \&operators,
   element_class => ['span3'],
 );
has_field "${Conditions::NUMBER}_value" =>
  (
   type => 'PosInteger',
   do_label => 0,
   wrapper => 0,
   element_class => ['span5'],
  );
has_field "${Conditions::DATE}_operator" =>
  (
   type => 'Select',
   do_label => 0,
   wrapper => 0,
   options_method => \&operators,
   element_class => ['span3'],
  );
has_field "${Conditions::DATE}_value" =>
  (
   type => 'DatePicker',
   do_label => 0,
   wrapper => 0,
  );
has_field "${Conditions::TIME}_operator" =>
  (
   type => 'Select',
   do_label => 0,
   wrapper => 0,
   options_method => \&operators,
   element_class => ['span3'],
  );
has_field "${Conditions::TIME}_value" =>
  (
   type => 'TimePicker',
   do_label => 0,
   wrapper => 0,
   element_class => ['span5'],
  );
has_field "${Actions::MARK_AS_SPONSOR}_action" =>
  (
   type => 'Hidden',
  );
has_field "${Actions::SET_ACCESS_LEVEL}_action" =>
  (
   type => 'Select',
   do_label => 0,
   wrapper => 0,
   options_method => \&options_access_level,
  );
has_field "${Actions::SET_ROLE}_action" =>
  (
   type => 'Select',
   do_label => 0,
   wrapper => 0,
#   options_method => \&options_roles,
  );
has_field "${Actions::SET_UNREG_DATE}_action" =>
  (
   type => 'DatePicker',
   do_label => 0,
   wrapper => 0,
  );

=head2 options_attributes

Populate the attributes select field with the available attributes of the
authentication source.

=cut

sub options_attributes {
    my $self = shift;
    
    my $form = $self->form;
    my @attributes = map {{
        label => $_->{value},
        value => $_->{value},
        attributes => { 'data-type' => $_->{type} }
    }} @{$form->attrs} if ($form->attrs);

    return @attributes;
}

=head2 options_operators

Populate the operators select field with all possible options.
The options will be later limited using JavaScript when displaying the rule.

=cut

sub options_operators {
    my $self = shift;

    my %all_operators = map { map { $_ => 1 } @{$_} } values %Conditions::OPERATORS;
    my @options = map { $_ => $self->_localize($_) } keys %all_operators;

    return @options;
}

=head2 options_actions

Populate the actions select field with the available actions of the
authentication source.

=cut

sub options_actions {
    my $self = shift;

    my $actions_ref = pf::Authentication::Action::availableActions();
    my @actions = map { $_ => $self->_localize($_) } @{$actions_ref};

    return @actions;
}

=head2 operators

Return the appropriate operators for the condition type select field.

=cut

sub operators {
    my $self = shift;

    my ($type) = $self->name =~ m/^([^_]+)_operator$/;
    my @operators = map { $_ => $self->_localize($_) } @{$Conditions::OPERATORS{$type}};

    return @operators;
}

=head2 options_access_level

Populate the select field for the 'access level' template action.

=cut

sub options_access_level {
    my $self = shift;

    return ({
             label => $self->_localize('None'),
             value => $WEB_ADMIN_NONE,
            },
            {
             label => $self->_localize('All'),
             value => $WEB_ADMIN_ALL,
            },
           );
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
