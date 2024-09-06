package pfappserver::Form::Config::Provisioning;

=head1 NAME

pfappserver::Form::Config::Provisioning - Web form for a switch

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
use pfconfig::cached_hash;
tie our %Rules, 'pfconfig::cached_hash', 'resource::provisioning_rules';
extends 'pfappserver::Base::Form';
with qw (
    pfappserver::Base::Form::Role::Help
    pfappserver::Role::Form::RolesAttribute
    pfappserver::Role::Form::SecurityEventsAttribute
);

use pf::config qw(%ConfigPKI_Provider);

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Provisioning ID',
   required => 1,
   messages => { required => 'Please specify the ID of the Provisioning entry.' },
   apply => [ pfappserver::Base::Form::id_validator('provisioning ID') ]
  );

has_field 'description' =>
  (
   type => 'Text',
   messages => { required => 'Please specify the Description Provisioning entry.' },
  );

has_field 'type' =>
  (
   type => 'Hidden',
   label => 'Provisioning type',
   required => 1,
   messages => { required => 'Please select Provisioning type' },
   default_method => \&default_type,
  );

has_field 'sync_pid',
  (
   type => 'Toggle',
   label => 'Sync PID',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   tags => { after_element => \&help,
             help => 'Whether or not the PID (username) should be synchronized from the provisioner to PacketFence.' },
   default => 'disabled',
  );

has_field 'enforce',
  (
   type => 'Toggle',
   label => 'Enforce',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   tags => { after_element => \&help,
             help => 'Whether or not the provisioner should be enforced. This will trigger checks to validate the device is compliant with the provisioner during RADIUS authentication and on the captive portal.' },
   default => 'enabled',
  );

has_field 'autoregister',
  (
   type => 'Toggle',
   label => 'Auto register',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   tags => { after_element => \&help,
             help => 'Whether or not devices should be automatically registered on the network if they are authorized in the provisioner.' },
   default => 'disabled',
  );

has_field 'apply_role',
  (
   type => 'Toggle',
   label => 'Apply role',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   tags => { after_element => \&help,
             help => 'When enabled, this will apply the configured role to the endpoint if it is authorized in the provisioner.' },
   default => 'disabled',
  );


has_field 'role_to_apply' =>
  (
   type => 'Select',
   label => 'Role to apply',
   options_method => \&options_roles,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a role'},
   tags => { after_element => \&help,
             help => 'When "Apply role" is enabled, this defines the role to apply when the device is authorized with the provisioner.' },
  );

has_field 'category' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Roles',
   options_method => \&options_roles,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a role'},
   tags => { after_element => \&help,
             help => 'Nodes with the selected roles will be affected' },
  );

has_field 'oses' =>
  (
   type => 'FingerbankSelect',
   multiple => 1,
   label => 'OS',
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add an OS'},
   tags => { after_element => \&help,
             help => 'Nodes with the selected OS will be affected' },
   fingerbank_model => "fingerbank::Model::Device",
  );

has_field 'rules' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Roles',
   options_method => \&options_rules,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a rule'},
   tags => { after_element => \&help,
             help => 'Rules to be applied' },
  );

has_field 'non_compliance_security_event' =>
  (
   type => 'Select',
   label => 'Non compliance security_event',
   options_method => \&options_security_events,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'None'},
   tags => { after_element => \&help,
             help => 'Which security event should be raised when non compliance is detected' },
  );

has_field 'pki_provider' =>
  (
   type => 'Select',
   label => 'PKI Provider',
   options_method => \&options_pki_provider,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'None'},
  );

has_block definition =>
  (
   render_list => [ qw(id type description category pki_provider oses apply_role role_to_apply autoregister) ],
  );


=head2 default_type

Returns the default type of the Provisioning

=cut

sub default_type {
    my ($field) = @_;
    my $type = ref($field->form);
    $type =~ s/^pfappserver::Form::Config::Provisioning:://;
    return $type;
}

=head2 options_pki_provider

=cut

sub options_pki_provider {
    return { value => '', label => '' }, map { { value => $_, label => $_ } } sort keys %ConfigPKI_Provider;
}

=head2 options_rules

=cut

sub options_rules {
    my $self = shift;
    my $type = ref($self) || $self;
    $type =~ s/^pfappserver::Form::Config::Provisioning:://;
    return map { {value => $_, label => $_} } @{$Rules{$self->type_alias($type)} // []};
}

=head2 options_roles

=cut

sub options_roles {
    my $self = shift;
    my @roles;
    @roles = map { $_->{name} => $_->{name} } @{$self->form->roles} if ($self->form->roles);
    return @roles;
}

sub options_security_events {
    my $self = shift;
    return [
        map { {value => $_->{id}, label => $_->{desc} } } @{$self->form->security_events // []}
    ];
}

sub type_alias {
    my ($self, $value) = @_;
    return $value;
}

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;
