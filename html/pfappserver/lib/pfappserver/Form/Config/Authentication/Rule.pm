package pfappserver::Form::Config::Authentication::Rule;

=head1 NAME

pfappserver::Form::Config::Authentication::Rule - Rules of a user source

=head1 DESCRIPTION

Form definition to manage the rules (conditions and actions) of an
authentication source.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form::Authentication::Action';

use pf::config;
use pf::Authentication::constants;

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
   localize_labels => 1,
   options => 
   [
    { value => $Rules::ANY, label => 'any' },
    { value => $Rules::ALL, label => 'all' },
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
   localize_labels => 1,
   options_method => \&options_attributes,
   widget_wrapper => 'None',
   element_class => ['span3'],
  );
has_field 'conditions.operator' =>
  (
   type => 'Select',
   localize_labels => 1,
   options_method => \&options_operators,
   widget_wrapper => 'None',
   element_class => ['span3'],
  );
has_field 'conditions.value' =>
  (
   type => 'Hidden',
  );

has_field "${Conditions::SUBSTRING}_operator" =>
  (
   type => 'Select',
   do_label => 0,
   wrapper => 0,
   localize_labels => 1,
   options_method => \&operators,
   element_class => ['span3'],
  );
has_field "${Conditions::SUBSTRING}_value" =>
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
   localize_labels => 1,
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
   localize_labels => 1,
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
   localize_labels => 1,
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
has_field "${Conditions::CONNECTION}_operator" =>
  (
   type => 'Select',
   do_label => 0,
   wrapper => 0,
   localize_labels => 1,
   options_method => \&operators,
   element_class => ['span3'],
  );
has_field "${Conditions::CONNECTION}_value" =>
  (
   type => 'Select',
   do_label => 0,
   wrapper => 0,
   localize_labels => 1,
   options_method => \&options_connection,
   element_class => ['span5'],
  );
has_field "${Conditions::LDAP_ATTRIBUTE}_operator" =>
  (
   type => 'Select',
   do_label => 0,
   wrapper => 0,
   localize_labels => 1,
   options_method => \&operators,
   element_class => ['span3'],
  );
has_field "${Conditions::LDAP_ATTRIBUTE}_value" =>
  (
   type => 'Text',
   do_label => 0,
   wrapper => 0,
   element_class => ['span5'],
  );

=head2 build_block_list

Dynamically construct the 'templates' block of actions corresponding to the
authentication source type.

The templates block contains the dynamic fields of the rule definition.

The following fields depend on the selected condition attribute :
 - the condition operators select fields
 - the condition value fields
The following fields depend on the selected action type :
 - the action value fields

The field substitution is made through JavaScript.

=cut

sub build_block_list {
    my $self = shift;

    # Action fields are dynamically defined in the super class
    my @actions = map { $_->name =~ /_action$/ ? $_->name : () } $self->fields;
    return
      [
       {
        name => 'templates',
        tag => 'div',
        render_list => [
                        map( { ("${_}_operator", "${_}_value") } keys %Conditions::OPERATORS),
                        @actions,
                       ],
        attr => { id => 'templates' },
        class => [ 'hidden' ],
       },
      ];
}

=head2 options_attributes

Populate the condition attributes select field with the available attributes of
the authentication source.

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
    my @options = map { $_ => $_ } keys %all_operators;

    return @options;
}

=head2 options_connection

Populate the connection types and connection groups field for the
'connection type' condition.

=cut

sub options_connection {
    my $self = shift;

    my @types = map { { value => $_, label => $_ } } sort keys %connection_type;
    my @groups = map { { value => $_, label => $_ } } sort keys %connection_group;

    return
      [
       {
        group => 'Types',
        options => \@types,
       },
       {
        group => 'Groups',
        options => \@groups,
       },
      ];
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

=head2 validate

Validate the following constraints :

 - an access duration and an unregistration date cannot be both defined
 - an access duration or an unregistration date must be defined when setting a role
 - one of these actions must be defined: set role, mark as sponsor, set access level
 - oauth2 sources must have a set role action

=cut

sub validate {
    my $self = shift;

    $self->SUPER::validate();

    my @actions;

    @actions = grep { $_->{type} eq $Actions::SET_ACCESS_DURATION } @{$self->value->{actions}};
    if (scalar @actions > 0) {
        @actions = grep { $_->{type} eq $Actions::SET_UNREG_DATE } @{$self->value->{actions}};
        if (scalar @actions > 0) {
            $self->field('actions')->add_error("You can't define an access duration and an unregistration date at the same time.");
        }
    }

    @actions = grep { $_->{type} eq $Actions::SET_ROLE } @{$self->value->{actions}};
    if (scalar @actions > 0) {
        @actions = grep { $_->{type} eq $Actions::SET_ACCESS_DURATION || $_->{type} eq $Actions::SET_UNREG_DATE }
          @{$self->value->{actions}};
        if (scalar @actions == 0) {
            $self->field('actions')->add_error("You must set an access duration or an unregistration date when setting a role.");
        }
    }

    @actions = grep {
        $_->{type} eq $Actions::SET_ROLE || $_->{type} eq $Actions::MARK_AS_SPONSOR || $_->{type} eq $Actions::SET_ACCESS_LEVEL
    } @{$self->value->{actions}};
    if (scalar @actions == 0) {
        $self->field('actions')->add_error("You must at least set a role, mark the user as a sponsor, or set an access level.");
    }

    if ($self->source_type eq 'Facebook' || $self->source_type eq 'Google' || $self->source_type eq 'Github') {
        @actions = grep { $_->{type} eq $Actions::SET_ROLE } @{$self->value->{actions}};
        unless (scalar @actions > 0) {
            $self->field('actions')->add_error("For this authentication source type, the rule must set a role as one of its actions.");
        }
    }

    if (scalar @{$self->value->{conditions}} == 0) {
        # This rule has no condition (catchall); force the match to 'all'
        # See pf::Authentication::Source->match
        $self->field('match')->value($Rules::ALL);
    }
}

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

__PACKAGE__->meta->make_immutable;
1;
