package pfappserver::Form::Config::Provisioning;

=head1 NAME

pfappserver::Form::Config::Provisioning - Web form for a switch

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;

has roles => ( is => 'rw' );
has oses => ( is => 'rw' );
has violations => ( is => 'rw');

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Provisioning ID',
   required => 1,
   messages => { required => 'Please specify the ID of the Provisioning entry.' },
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
   type => 'Select',
   multiple => 1,
   label => 'OS',
   options_method => \&options_oses,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add an OS'},
   tags => { after_element => \&help,
             help => 'Nodes with the selected OS will be affected' },
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
=head2 options_oses

=cut

sub options_oses {
    my $self = shift;
    return $self->form->oses;
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
    my @violations;
    foreach my $violation (@{$self->form->violations}){
        push @violations, $violation->{id};
        push @violations, $violation->{desc};
    }
    return @violations;
}

=head2 ACCEPT_CONTEXT

To automatically add the context to the Form

=cut

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;
    my ($status, $roles) = $c->model('Roles')->list();
    my @oses = ["Windows" => "Windows",
                "Macintosh" => "Mac OS X",
                "Generic Android" => "Android",
                "Apple iPod, iPhone or iPad" => "Apple iOS device"
               ];
    my (undef, $violations) = $c->model('Config::Violations')->readAll();
    return $self->SUPER::ACCEPT_CONTEXT($c, roles => $roles, oses => @oses, violations => $violations, @args);
}

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
