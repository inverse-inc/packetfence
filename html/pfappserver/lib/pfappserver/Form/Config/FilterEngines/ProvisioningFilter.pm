package pfappserver::Form::Config::FilterEngines::ProvisioningFilter;

=head1 NAME

pfappserver::Form::Config::FilterEngines::ProvisioningFilter -

=head1 DESCRIPTION

pfappserver::Form::Config::FilterEngines::ProvisioningFilter

=cut

use strict;
use warnings;
use pfappserver::Form::Field::DynamicList;
use pfappserver::Form::Config::FilterEngines;
use pf::config qw(%Config);
use HTML::FormHandler::Moose;
use pf::constants::role qw(@ROLES);
use pf::constants::filters qw(@BASE_FIELDS @NODE_INFO_FIELDS @FINGERBANK_FIELDS @SWITCH_FIELDS @OWNER_FIELDS @SECURITY_EVENT_FIELDS);
use pfconfig::cached_hash;
tie our %ConfigProvisioningFiltersMeta, 'pfconfig::cached_hash', "config::ProvisioningFiltersMeta";
extends 'pfappserver::Form::Config::FilterEngines';
with qw(
    pfappserver::Base::Form::Role::Help
    pfappserver::Base::Form::Role::AllowedOptions
    pfappserver::Role::Form::RolesAttribute
);

sub scopes {
    return map { { value => $_, label => $_ } } qw(
      authorize_enforce
    );
}

has_field 'type' =>
  (
   type => 'Hidden',
   label => 'Provisioning type',
   required => 1,
   messages => { required => 'Please select Provisioning type' },
   default_method => \&option_type,
  );


has_field 'role' => (
    type     => 'Select',
    options_method => \&options_role,
);

has_field 'run_actions' => (
   type => 'Toggle',
   label => 'Run Actions',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   default => 'enabled'
);

has_field 'actions_synchronous' => (
   type => 'Toggle',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   default => 'disabled'
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

my %ADDITIONAL_FIELD_OPTIONS = (
    %pfappserver::Form::Config::FilterEngines::ADDITIONAL_FIELD_OPTIONS
);

sub _additional_field_options {
    return \%ADDITIONAL_FIELD_OPTIONS;
}

sub options_field_names {
    my ($self) = @_;
    my $proto = ref($self) || $self;
    my $type = $proto;
    $type =~ s/^.*:://;
    my $data = $ConfigProvisioningFiltersMeta{$type} // {};
    (
        'compliant_check',
        @NODE_INFO_FIELDS,
        @{$data->{fields} || []}
    );
}

sub option_type {
    my ($field) = @_;
    my $type = ref($field->form);
    $type =~ s/^.*:://;
    return $type;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

