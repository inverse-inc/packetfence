package pfappserver::Form::Portal::Profile;

=head1 NAME

pfappserver::Form::Portal::Profile

=head1 DESCRIPTION

Portal profile.

=cut

use pf::authentication;

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';

# Form fields
has_field 'id' =>
  (
   type => 'Text',
   label => 'Profile Name',
   required => 1,
   apply => [ { check => qr/^[a-zA-Z0-9][a-zA-Z0-9\._-]*$/ } ],
  );
has_field 'description' =>
  (
   type => 'Text',
   label => 'Profile Description',
   required => 1,
  );
has_field 'filter' =>
  (
   type => 'ProfileFilter',
   label => 'Filter',
   required => 1,
  );
has_field 'guest_self_reg' =>
  (
   type => 'Toggle',
   label => 'Enable Self Registration',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
  );
has_field 'guest_modes' =>
  (
    'type' => 'Select',
    'label' => 'Modes',
    'multiple'=> 1,
    'element_class' => ['chzn-select', 'input-xlarge'],
    'element_attr' => {'data-placeholder' => 'Click to add'},
  );
has_field 'billing_engine' =>
  (
   type => 'Toggle',
   label => 'Enable Billing Engine',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
  );

=head1 METHODS

=head2 options_guest_modes

=cut

sub options_guest_modes {
    my $self = shift;

    my $types = availableAuthenticationSourceTypes('external');
    return map { { value => $_, label => $_ } } @$types;
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
