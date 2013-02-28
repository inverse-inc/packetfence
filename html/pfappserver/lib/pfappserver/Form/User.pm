package pfappserver::Form::User;

=head1 NAME

pfappserver::Form::User - Web form for a user

=head1 DESCRIPTION

Form definition to update a user.

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
   type => 'Uneditable',
   label => 'Username',
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
has_field 'sponsor' =>
  (
   type => 'Text',
   label => 'Sponsor',
  );
has_field 'expiration' =>
  (
   type => 'DatePicker',
   label => 'Expiration',
  );
has_field 'valid_from' =>
  (
   type => 'DatePicker',
   label => 'Valid From',
  );
has_field 'access_duration' =>
  (
   type => 'Duration',
   label => 'Access Duration',
  );
has_field 'is_sponsor' =>
  (
   type => 'Toggle',
   label => 'Is a Sponsor',
   checkbox_value => 1,
   uncheckbox_value => 0,
  );
has_field 'category' =>
  (
   type => 'Text',
   label => 'Role'
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
