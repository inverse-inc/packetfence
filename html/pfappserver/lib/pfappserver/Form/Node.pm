package pfappserver::Form::Node;

=head1 NAME

pfappserver::Form::Node - Web form for a node

=head1 DESCRIPTION

Form definition to create or update a node.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';

# Form select options
has 'roles' => ( is => 'ro' );
has 'status' => ( is => 'ro' );

# Form fields
has_field 'pid' =>
  (
   type => 'Uneditable',
   label => 'Identifier',
  );
has_field 'status' =>
  (
   type => 'Select',
   label => 'Status',
   element_class => ['chzn-select'],
  );
has_field 'category_id' =>
  (
   type => 'Select',
   label => 'Role',
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'No role'},
  );
has_field 'regdate' =>
  (
   type => 'Uneditable',
   label => 'Registration',
  );
has_field 'unregdate' =>
  (
   type => '+DateTimePicker',
   label => 'Unregistration',
  );
has_field 'vendor' =>
  (
   type => 'Uneditable',
   label => 'MAC Vendor',
  );
has_field 'computername' =>
  (
   type => 'Uneditable',
   label => 'Name',
  );
has_field 'voip' =>
  (
   type => 'Checkbox',
   label => 'Is Voice Over IP',
   checkbox_value => 'yes',
  );
has_field 'last_dot1x_username' =>
  (
   type => 'Uneditable',
   label => '802.1X Username',
  );
has_field 'user_agent' =>
  (
   type => 'Uneditable',
   label => 'User Agent',
  );
has_field 'useragent' =>
  (
   type => 'Compound', # virtual field to access the 'useragent' hash
  );
has_field 'useragent.mobile' =>
  (
   type => 'Toggle',
   label => 'Is a mobile',
   element_attr => {disabled => 1},
  );
has_field 'useragent.device' =>
  (
   type => 'Toggle',
   label => 'Is a device',
   element_attr => {disabled => 1},
  );

=head2 options_status

=cut

sub options_status {
    my $self = shift;

    # $self->status comes from pfappserver::Model::Node->availableStatus
    my @status = map { $_ => $_ } @{$self->status} if ($self->status);

    return @status;
}

=head2 options_category_id

=cut

sub options_category_id {
    my $self = shift;

    # $self->roles comes from pfappserver::Model::Roles
    my @roles = map { $_->{category_id} => $_->{name} } @{$self->roles} if ($self->roles);

    return ('' => '', @roles);
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
