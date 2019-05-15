package pfappserver::Form::Config::PortalModule;

=head1 NAME

pfappserver::Form::Config::PortalModule

=head1 DESCRIPTION

Form definition to create or update a portal module.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Identifier',
   required => 1,
   apply => [
       {   check => qr/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/,
           message =>
             'The id is invalid. A portal module id can only contain alphanumeric characters, dashes, and or underscores'
       }
   ],
   tags => {
      option_pattern => \&pfappserver::Base::Form::id_pattern,
   },
   messages => { required => 'Please specify an identifier' },
  );

has_field 'type' =>
  (
   type => 'Hidden',
   messages => { required => 'There was no type specified' },
  );

has_field 'description' =>
  (
   type => 'Text',
   label => 'Description',
   required => 1,
   tags => { after_element => \&help,
             help => 'The description that will be displayed to users' },
  );

has_field 'actions' =>
  (
    'type' => 'DynamicTable',
    'sortable' => 1,
    'do_label' => 0,
     tags => { 
       when_empty => 'If none are specified, the default ones of the module will be used.' 
     },
  );

has_field 'actions.contains' =>
  (
    label => 'Action',
    type => '+PortalModuleAction',
    widget_wrapper => 'DynamicTableRow',
  );


has_block definition =>
  (
   # Generated via the BUILD method
   render_list => [],
  );

sub BUILD {
    my ($self) = @_;
    $self->field('actions.contains')->field('type')->options([$self->options_actions]);
    $self->block('definition')->add_to_render_list(qw(id type description), $self->child_definition());
    $self->setup();
}

# To override in the child modules
sub child_definition {
    return ();
}

# Meant for overriding or to place hooks around
# as problems were hit when placings hooks around BUILD
# which anyway is not recommended
sub setup {
    return;
}

=head2 remove_field

Remove a field from the definition of the form

=cut

sub remove_field {
    my ($self, $name) = @_;
    my @fields = $self->all_fields;
    $self->clear_fields();
    foreach my $field (@fields) {
        unless($field->name eq $name) {
            $self->add_field($field);
        }
    }
}

=head2 options_actions

Options available for the actions

=cut

sub options_actions {
    my ($self) = @_;
    return map { 
        {
            value => $_,
            label => $self->_localize($_),
        }
    } ("Select an option", @{$self->for_module->available_actions});
}

=head2 dynamic_tables

Get all the DynamicTable fields of this form

=cut

sub dynamic_tables {
    my ($self) = @_;
    return map { $_->name } grep { $_->type eq "DynamicTable" && $_->is_active } $self->all_fields;
}

=over

=back

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
