package pfappserver::Form::User::Create::Multiple;

=head1 NAME

pfappserver::Form::User::Create::Multiple - Multiple accounts creation

=head1 DESCRIPTION

Form to create multiple user accounts using an incremental username pattern.

Ex: guest[1-10]

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

# Form fields
has_field 'prefix' =>
  (
   type => 'Text',
   label => 'Username Prefix',
   required => 1,
  );
has_field 'quantity' =>
  (
   type => 'PosInteger',
   label => 'Quantity',
   required => 1,
  );
has_field 'pid_overwrite' => (
    type    => 'Checkbox',
    label   => 'Username (PID) overwrite',
    tags    => {
        after_element   => \&help,
        help            => 'Overwrite the username (PID) if it already exists',
    },
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
has_field 'notes' =>
  (
   type => 'TextArea',
   label => 'Notes',
  );
has_field 'login_remaining' =>
  (
   type => 'PosInteger',
   label => 'Login remaining',
   default => undef,
   tags => { after_element => \&help,
             help => 'Leave it empty to allow unlimited logins.' },
  );


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
