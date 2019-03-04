package pfappserver::Form::User::Create::Import;

=head1 NAME

pfappserver::Form::User::Create::Import - CSV file import

=head1 DESCRIPTION

Form to import multiple user accounts from a CSV file.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';

has '+enctype' => ( default => 'multipart/form-data');

# Form fields
has_field 'users_file' =>
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

has_field 'pid_overwrite' => (
    type    => 'Checkbox',
    label   => 'Username (PID) overwrite',
    tags    => {
        after_element   => \&help,
        help            => 'Overwrite the username (PID) if it already exists',
    },
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
        { 'enabled' => 1, name => 'c_username', label => $self->_localize('Username') },
        { 'enabled' => 1, name => 'c_password', label => $self->_localize('Password') },
        { 'enabled' => 0, name => 'c_firstname', label => $self->_localize('Firstname') },
        { 'enabled' => 0, name => 'c_lastname', label => $self->_localize('Lastname') },
        { 'enabled' => 0, name => 'c_email', label => $self->_localize('Email') },
        { 'enabled' => 0, name => 'c_phone', label => $self->_localize('Phone') },
        { 'enabled' => 0, name => 'c_company', label => $self->_localize('Company') },
        { 'enabled' => 0, name => 'c_address', label => $self->_localize('Address') },
        { 'enabled' => 0, name => 'c_note', label => $self->_localize('Note') },
       ]
      };

    return $object;
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
