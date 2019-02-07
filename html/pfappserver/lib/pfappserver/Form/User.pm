package pfappserver::Form::User;

=head1 NAME

pfappserver::Form::User - Web form for a user

=head1 DESCRIPTION

Form definition to update a user.

=cut

use pf::config;
use HTTP::Status qw(:constants is_success);
use HTML::FormHandler::Moose;

extends 'pfappserver::Base::Form::Authentication::Action';
with 'pfappserver::Base::Form::Role::Help';

has '+source_type' => ( default => 'SQL' );

=head1 FIELDS

=head2 pid

=cut

has_field 'pid' =>
  (
   type => 'Uneditable',
   label => 'Username',
  );

=head2 firstname

=cut

has_field 'firstname' =>
  (
   type => 'Text',
   label => 'Firstname',
  );

=head2 lastname

=cut

has_field 'lastname' =>
  (
   type => 'Text',
   label => 'Lastname',
  );

=head2 company

=cut

has_field 'company' =>
  (
   type => 'Text',
   label => 'Company',
  );

=head2 email

=cut

has_field 'email' =>
  (
   type => 'Email',
   label => 'Email',
   required => 1,
  );

=head2 telephone

=cut

has_field 'telephone' =>
  (
   type => 'Text',
   label => 'Telephone',
  );

=head2 sponsor

=cut

has_field 'sponsor' =>
  (
   type => 'Text',
   label => 'Sponsor',
  );

=head2 address

=cut

has_field 'address' =>
  (
   type => 'TextArea',
   label => 'Address',
  );

=head2 notes

=cut

has_field 'notes' =>
  (
   type => 'TextArea',
   label => 'Notes',
  );

=head2 login_remaining

=cut

has_field 'login_remaining' =>
  (
   type => 'PosInteger',
   label => 'Login remaining',
   default => undef,
   disabled => 1,
   tags => { after_element => \&help,
             help => 'Unlimited logins when empty.' },
  );

=head2 valid_from

=cut

has_field 'valid_from' =>
  (
   type => 'DatePicker',
   messages => { required => 'Please specify the start date of the registration window.' },
  );

=head2 expiration

=cut

has_field 'expiration' =>
  (
   type => 'DatePicker',
   messages => { required => 'Please specify the end date of the registration window.' },
  );

has_field 'anniversary' =>
  (
   type => 'Text',
   label => 'anniversary',
  );

has_field 'birthday' =>
  (
   type => 'Text',
   label => 'birthday',
  );

has_field 'gender' =>
  (
   type => 'Text',
   label => 'gender',
  );

has_field 'lang' =>
  (
   type => 'Text',
   label => 'lang',
  );

has_field 'nickname' =>
  (
   type => 'Text',
   label => 'nickname',
  );

has_field 'cell_phone' =>
  (
   type => 'Text',
   label => 'cell_phone',
  );

has_field 'work_phone' =>
  (
   type => 'Text',
   label => 'work_phone',
  );

has_field 'title' =>
  (
   type => 'Text',
   label => 'title',
  );

has_field 'building_number' =>
  (
   type => 'Text',
   label => 'building_number',
  );

has_field 'apartment_number' =>
  (
   type => 'Text',
   label => 'apartment_number',
  );

has_field 'room_number' =>
  (
   type => 'Text',
   label => 'room_number',
  );

has_field 'custom_field_1' =>
  (
   type => 'Text',
   label => 'custom_field_1',
  );

has_field 'custom_field_2' =>
  (
   type => 'Text',
   label => 'custom_field_2',
  );

has_field 'custom_field_3' =>
  (
   type => 'Text',
   label => 'custom_field_3',
  );

has_field 'custom_field_4' =>
  (
   type => 'Text',
   label => 'custom_field_4',
  );

has_field 'custom_field_5' =>
  (
   type => 'Text',
   label => 'custom_field_5',
  );

has_field 'custom_field_6' =>
  (
   type => 'Text',
   label => 'custom_field_6',
  );

has_field 'custom_field_7' =>
  (
   type => 'Text',
   label => 'custom_field_7',
  );

has_field 'custom_field_8' =>
  (
   type => 'Text',
   label => 'custom_field_8',
  );

has_field 'custom_field_9' =>
  (
   type => 'Text',
   label => 'custom_field_9',
  );

has_field 'psk' =>
  (
   type => 'Text',
   Label => 'PSK key',
   minlength => 8,
   tags => { after_element => \&help,
         help => 'Minimum of 8 characters.' },
  );

=head2 Blocks

=over

=item user block

  The user block contains the static fields of user

=cut

has_block 'user' =>
  (
   render_list => [qw(pid firstname lastname company telephone email sponsor address notes)],
  );

has_block 'miscellaneous' =>
  (
   render_list => [qw(anniversary birthday gender lang nickname cell_phone work_phone title building_number apartment_number room_number psk)]
  );

has_block 'custom_fields' =>
  (
   render_list => [qw(custom_field_1 custom_field_2 custom_field_3 custom_field_4 custom_field_5 custom_field_6 custom_field_7 custom_field_8 custom_field_9)]
  );

=item templates block

 The templates block contains the dynamic fields of the rule definition.

 The following fields depend on the selected condition attribute :
  - the condition operators select fields
  - the condition value fields
 The following fields depend on the selected action type :
  - the action value fields

=cut

has_block 'templates' =>
  (
   tag => 'div',
   render_list => [
                   map( { "${_}_action" } map( { @$_ } values %Actions::ACTIONS)), # the field are defined in the super class
                  ],
   attr => { id => 'templates' },
   class => [ 'hidden' ],
  );

=back

=head1 METHODS

=head2 update_fields

When editing a local/SQL user, set as required the arrival date.

=cut

sub update_fields {
    my $self = shift;

    if ($self->{init_object} && $self->{init_object}->{password}) {
        $self->field('valid_from')->required(1);
        $self->field('expiration')->required(1);
    }

    # Call the theme implementation of the method
    $self->SUPER::update_fields();
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
