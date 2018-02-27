package pfappserver::Form::Config::Provisioning;

=head1 NAME

pfappserver::Form::Config::Provisioning - Web form for a switch

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw (
    pfappserver::Base::Form::Role::Help
    pfappserver::Role::Form::RolesAttribute
    pfappserver::Role::Form::ViolationsAttribute
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

has_field 'non_compliance_violation' =>
  (
   type => 'Select',
   label => 'Non compliance violation',
   options_method => \&options_violations,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'None'},
   tags => { after_element => \&help,
             help => 'Which violation should be raised when non compliance is detected' },
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
   render_list => [ qw(id type description category pki_provider oses) ],
  );

=head2 options_pki_provider

=cut

sub options_pki_provider {
    return { value => '', label => '' }, map { { value => $_, label => $_ } } sort keys %ConfigPKI_Provider;
}

=head2 options_roles

=cut

sub options_roles {
    my $self = shift;
    my @roles = map { $_->{name} => $_->{name} } @{$self->form->roles} if ($self->form->roles);
    return @roles;
}

sub options_violations {
    my $self = shift;
    return [
        map { {value => $_->{id}, label => $_->{desc} } } @{$self->form->violations // []}
    ];
}

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
