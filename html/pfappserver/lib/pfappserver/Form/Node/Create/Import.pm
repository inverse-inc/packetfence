package pfappserver::Form::Node::Create::Import;

=head1 NAME

pfappserver::Form::Node::Create::Import - CSV file import

=head1 DESCRIPTION

Form to import multiple nodes from a CSV file.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw(pfappserver::Role::Form::RolesAttribute);

use pf::config qw(%Config);

has '+enctype' => ( default => 'multipart/form-data');

=head2 FIELDS

=cut

has_field 'nodes_file' =>
  (
   type => 'Upload',
   label => 'CSV File',
   required => 1,
  );
has_field 'delimiter' =>
  (
   type => 'Select',
   label => 'Column Delimiter',
   required => 1,
   options =>
   [
    { value => 'comma', label => 'Comma' },
    { value => 'semicolon', label => 'Semicolon' },
    { value => 'tab', label => 'Tab' },
   ],
  );

has_field 'default_pid' =>
  (
   type => 'Text',
   label => 'Default Owner',
   element_attr => {'data-provide' => 'typeahead',
                    'placeholder' => $Config{node_import}{pid}},
  );
has_field 'default_category_id' =>
  (
   type => 'Select',
   label => 'Default Role',
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'No role'},
  );
has_field 'default_voip' =>
  (
   type => 'Checkbox',
   label => 'Default Voice Over IP',
   checkbox_value => 'yes',
   default => $Config{node_import}{voip},
  );

has_field 'columns' =>
  (
   type => 'Repeatable',
  );
has_field 'columns.enabled' =>
  (
   type => 'Checkbox',
  );
has_field 'columns.name' =>
  (
   type => 'Hidden',
  );
has_field 'columns.label' =>
  (
   type => 'Uneditable',
  );

sub init_object {
    my $self = shift;

    my $object =
      {
       'columns' =>
       [
        { 'enabled' => 1, name => 'mac', label => $self->_localize('MAC Address') },
        { 'enabled' => 0, name => 'pid', label => $self->_localize('Owner') },
        { 'enabled' => 0, name => 'category', label => $self->_localize('Role') },
        { 'enabled' => 0, name => 'unregdate', label => $self->_localize('Unregistration Date') },
        { 'enabled' => 0, name => 'voip', label => $self->_localize('Voice Over IP (yes/no)') },
        { 'enabled' => 0, name => 'notes', label => $self->_localize('Notes') },
        { 'enabled' => 0, name => 'bypass_role', label => $self->_localize('Bypass Role') },
        { 'enabled' => 0, name => 'bypass_vlan', label => $self->_localize('Bypass VLAN') },
       ]
      };

    return $object;
}

=head2 options_default_category_id

=cut

sub options_default_category_id {
    my $self = shift;

    # $self->roles comes from pfappserver::Model::Roles
    my @roles = map { $_->{category_id} => $_->{name} } @{$self->roles} if ($self->roles);

    return ('' => '', @roles);
}

=head2 default_default_category_id

=cut

sub default_default_category_id {
    my $self = shift;

    foreach my $role (@{$self->roles}) {
        return $role->{category_id} if ($role->{name} eq $Config{node_import}{category});
    }
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
