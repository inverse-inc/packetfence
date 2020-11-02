package pfappserver::Form::Config::RemoteProfile;

=head1 NAME

pfappserver::Form::Config::RemoteProfile - Web form for a floating device

=head1 DESCRIPTION

Form definition to create or update realm.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw (
    pfappserver::Base::Form::Role::Help
    pfappserver::Role::Form::RolesAttribute
);

use pf::config qw(%ConfigAuthenticationLdap %ConfigEAP);
use pf::authentication;
use pf::util;
use pf::ConfigStore::Domain;

## Definition
has_field 'id' =>
  (
    type => 'Text',
    required => 1,
    apply => [ pfappserver::Base::Form::id_validator('profile') ],
    tags => {
       option_pattern => \&pfappserver::Base::Form::id_pattern,
    },
  );

has_field 'description' =>
  (
    type => 'Text',
    required => 1,
  );

has_field 'status' =>
  (
    type => 'Toggle',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
    default => 'enabled'
  );

has_field 'basic_filter_type' =>
  (
    type => 'Select',
    default => 'filter_role',
    options_method => sub {map { { value => $_, label => $_ } } qw(filter_device filter_user filter_role)}
  );

has_field 'basic_filter_value' =>
  (
    type => 'Text',
  );

has_field 'allow_communication_same_role' =>
  (
    type => 'Toggle',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
    default => 'enabled'
  );

has_field 'allow_communication_to_roles' =>
  (
   type => 'Select',
   options_method => \&options_roles,
  );

sub options_roles {
    my $self = shift;
    my @roles = map { $_->{name} => $_->{name} } @{$self->form->roles} if ($self->form->roles);
    return @roles;
}

=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
