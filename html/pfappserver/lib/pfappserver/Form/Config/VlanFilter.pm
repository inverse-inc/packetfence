package pfappserver::Form::Config::VlanFilter;

=head1 NAME

pfappserver::Form::Config::VlanFilter -

=head1 DESCRIPTION

pfappserver::Form::Config::VlanFilter

=cut

use strict;
use warnings;
use pfappserver::Form::Field::DynamicList;
use HTML::FormHandler::Moose;
use pf::constants::role qw(@ROLES);
extends 'pfappserver::Base::Form';
with qw(
    pfappserver::Base::Form::Role::Help
    pfappserver::Base::Form::Role::AllowedOptions
    pfappserver::Role::Form::RolesAttribute
);

has_field 'id' => (
    type     => 'Text',
    label    => 'Rule Name',
    required => 1,
);

has_field 'condition' => (
    type => 'Text',
    required => 1,
);

has_field 'scopes' => (
    type     => 'Select',
    multiple => 1,
    options  => [
        map { { value => $_, label => $_ } }
          qw(
          RegistrationRole
          RegisteredRole
          IsolationRole
          InlineRole
          AutoRegister
          NodeInfoForAutoReg
          IsPhone
          )
    ]
);

has_field 'role' => (
    type     => 'Select',
    options_method => \&options_role,
);

=head2 actions

The list of action

=cut

has_field 'actions' => (
    'type' => 'DynamicList',
);

=head2 actions.contains

The definition for the list of actions

=cut

has_field 'actions.contains' => (
    type  => 'ApiAction',
    label => 'Action',
    pfappserver::Form::Field::DynamicList::child_options(),
);

=head2 options_role

=cut

sub options_role {
    my $self = shift;
    return (
        (
            map { { value => $_->{name}, label => $_->{name} } }
              @{ $self->form->roles // [] }
        ),
        ( map { { value => $_, label => $_ } } @ROLES )
    );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;

