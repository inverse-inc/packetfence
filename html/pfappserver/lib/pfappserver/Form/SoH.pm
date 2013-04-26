package pfappserver::Form::SoH;

=head1 NAME

pfappserver::Form::SoH - Web form for a SoH filter

=head1 DESCRIPTION

Form definition to create or update a SoH filter.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';

use pf::config;

has '+field_name_space' => ( default => 'pfappserver::Form::Field' );
has '+widget_name_space' => ( default => 'pfappserver::Form::Widget' );
has '+language_handle' => ( builder => 'get_language_handle_from_ctx' );

# Form select options
has 'violations' => ( is => 'ro' );

# Form fields
has_field 'name' =>
  (
   type => 'Text',
   label => 'Name',
   element_class => ['input'],
   required => 1,
  );
has_field 'action' =>
  (
   type => 'Select',
   label => 'Action',
   element_class => ['input-medium'],
   localize_labels => 1,
   required => 1,
  );
has_field 'vid' =>
  (
   type => 'Select',
   widget_wrapper => 'None',
  );
has_field 'rules' =>
  (
   type => 'Repeatable',
   num_extra => 1, # add extra row that serves as a template
  );
has_field 'rules.class' =>
  (
   type => 'Select',
   widget_wrapper => 'None',
   element_class => ['input-medium'],
   localize_labels => 1,
   options_method => \&options_class,
  );
has_field 'rules.op' =>
  (
   type => 'Select',
   widget_wrapper => 'None',
   element_class => ['input-small'],
   localize_labels => 1,
   options_method => \&options_op,
  );
has_field 'rules.status' =>
  (
   type => 'Select',
   widget_wrapper => 'None',
   element_class => ['input-medium'],
   localize_labels => 1,
   options_method => \&options_status,
  );

=head2 options_action

=cut

sub options_action {
    my $self = shift;

    my @actions = map { $_ => $self->_localize($_) } @pf::config::SOH_ACTIONS;

    return @actions;    
}

=head2 options_vid

When the filter action is "violation", populate the associated select menu with all the available violations.

=cut

sub options_vid {
    my $self = shift;

    # $self->violations comes from pfappserver::Model::Config::Violations->readAll
    my @violations = map { $_->{id} => $_->{desc} } @{$self->violations} if ($self->violations);

    return @violations;
}

=head2 options_class

=cut

sub options_class {
    my $self = shift;

    my @classes = map { $_ => $self->_localize($_) } @pf::config::SOH_CLASSES;

    return @classes;
}

=head2 options_op

=cut

sub options_op {
    my $self = shift;

    return
      (
       {
        label => $self->_localize('is'),
        value => 'is',
       },
       {
        label => $self->_localize('isnot'),
        value => 'isnot',
       },
      );
}

=head2 options_status

=cut

sub options_status {
    my $self = shift;

    my @status = map { $_ => $self->_localize($_) } @pf::config::SOH_STATUS;

    return @status;
}

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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
