package pfappserver::Form::Config::Source::Potd;

=head1 NAME

pfappserver::Form::Config::Source::Potd - Web form for a potd user source

=head1 DESCRIPTION

Form definition to create or update a potd user source.

=cut

use pf::person;
use HTML::FormHandler::Moose;
use pf::Authentication::Source::PotdSource;
extends 'pfappserver::Form::Config::Source';
with 'pfappserver::Base::Form::Role::Help', 'pfappserver::Base::Form::Role::InternalSource';

# Form fields
has_field 'id' =>
  (
   type => 'Text',
   label => 'Name',
   required => 1,
   messages => { required => 'Please specify the name of the source entry' },
   apply => [ pfappserver::Base::Form::id_validator('source name') ],
   validate_method => sub {
       my ($field) = @_;
       my $name = $field->value;
       if ( !pf::person::person_exist($name) ) {
           return;
       } else {
           my $person = pf::person::person_view($name);
           if ($person->{potd} eq 'no') {
               $field->add_error("User is not allowed to be use for Password Of the Day");
           }
       }
   },
  );

has_field 'password_rotation' =>
  (
   type => 'Duration',
   label => 'Password Rotation Period',
   required => 1,
   default => pfappserver::Form::Field::Duration->duration_inflate(pf::Authentication::Source::PotdSource->meta->get_attribute('password_rotation')->default),
   tags => { after_element => \&help,
             help => 'Period of time after the password must be rotated.' },
  );

has_field 'password_length' =>
  (
   type => 'PosInteger',
   label => 'Password length',
   required => 1,
   default => 8,
   tags => { after_element => \&help,
             help => 'The length of the password to generate.' },
  );

has_field 'password_email_update' => (
    type        => 'Text',
    label       => 'Email',
    required    => 1,
    tags        => {
        after_element   => \&help,
        help            => "Email addresses to send the new generated password.",
    },
);

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
