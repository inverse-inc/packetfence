package pfappserver::Form::User::Create::Single;

=head1 NAME

pfappserver::Form::User::Create::Single - Single user account creation

=head1 DESCRIPTION

Form to create a single user account.

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';
with 'pfappserver::Form::Widget::Theme::Pf';

has '+field_name_space' => ( default => 'pfappserver::Form::Field' );
has '+widget_name_space' => ( default => 'pfappserver::Form::Widget' );
has '+language_handle' => ( builder => 'get_language_handle_from_ctx' );

# Form fields
has_field 'pid' =>
  (
   type => 'Text',
   label => 'Username',
   required => 1,
   tags => { after_element => \&help,
             help => 'The username to use for login to the captive portal.' },
  );
has_field 'password' =>
  (
   type => 'Password',
   label => 'Password',
   tags => { after_element => \&help,
             help => 'Leave it empty if you want to generate a random password.' },
  );
has_field 'firstname' =>
  (
   type => 'Text',
   label => 'Firstname',
  );
has_field 'lastname' =>
  (
   type => 'Text',
   label => 'Lastname',
  );
has_field 'company' =>
  (
   type => 'Text',
   label => 'Company',
  );
has_field 'email' =>
  (
   type => 'Email',
   label => 'Email',
   required => 1,
  );
has_field 'address' =>
  (
   type => 'TextArea',
   label => 'Address',
  );
has_field 'notes' =>
  (
   type => 'TextArea',
   label => 'Notes',
  );

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
