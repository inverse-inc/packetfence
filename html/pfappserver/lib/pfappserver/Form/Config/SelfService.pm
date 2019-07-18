package pfappserver::Form::Config::SelfService;

=head1 NAME

pfappserver::Form::Config::SelfService - Web form for the self service portal 

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw (
    pfappserver::Base::Form::Role::Help
    pfappserver::Role::Form::RolesAttribute
);

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Profile Name',
   required => 1,
   messages => { required => 'Please specify a name of the Self Service Portal entry.' },
   apply => [ pfappserver::Base::Form::id_validator('self service ID') ],
   tags => {
      option_pattern => \&pfappserver::Base::Form::id_pattern,
   }
  );

has_field 'description' =>
  (
   type => 'Text',
   messages => { required => 'Please specify the description of the Self Service Portal entry.' },
  );

has_field 'roles_allowed_to_unregister' =>
  (
   type => 'Select',
   label => 'Allowed roles',
   multiple => 1,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a role'},
   options_method => \&options_roles,
   tags => { after_element => \&help,
             help => 'The list of roles that are allowed to unregister devices using the self-service portal. Leaving this empty will allow all users to unregister their devices.' },
  );

has_field 'device_registration_role' =>
  (
   type => 'Select',
   label => 'Role to assign',
   options_method => \&options_roles,
   tags => { after_element => \&help,
             help => 'The role to assign to devices registered from the self-service portal. If none is specified, the role of the registrant is used.' },
  );

has_field 'device_registration_allowed_devices' =>
  (
   type => 'FingerbankSelect',
   multiple => 1,
   label => 'Allowed OS',
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add an OS'},
   tags => { after_element => \&help,
             help => 'List of OS which will be allowed to be registered via the self service portal.' },
   fingerbank_model => "fingerbank::Model::Device",
  );

has_block definition =>
  (
   render_list => [ qw(id description) ],
  );

has_block status_definition =>
  (
   render_list => [ qw(roles_allowed_to_unregister) ],
  );

has_block device_registration_definition =>
  (
   render_list => [ qw(device_registration_role device_registration_allowed_devices) ],
  );

=head2 options_roles

=cut

sub options_roles {
    my $self = shift;
    my $roles = $self->form->roles;
    return [
        { value => '', label => '' },
        ( map { { value => $_->{name}, label => $_->{name} }} @{$roles // []})
    ];
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
