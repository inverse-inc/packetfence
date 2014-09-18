package pfappserver::Form::ConfigStore::Provisioning;

=head1 NAME

pfappserver::Form::ConfigStore::Provisioning - Web form for a switch

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

has roles => ( is => 'rw' );

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
   label => 'Set role',
   options_method => \&options_roles,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Select a role'},
   tags => { after_element => \&help,
             help => 'Roles ' },
  );

has_block definition =>
  (
   render_list => [ qw(id type description category) ],
  );

=head2 options_roles

=cut

sub options_roles {
    my $self = shift;
    my @roles = map { $_->{name} => $_->{name} } @{$self->form->roles} if ($self->form->roles);
    return @roles;
}

=head2 ACCEPT_CONTEXT

To automatically add the context to the Form

=cut

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;
    my ($status, $roles) = $c->model('Roles')->list();
    return $self->SUPER::ACCEPT_CONTEXT($c, roles => $roles, @args);
}

=head1 COPYRIGHT

Copyright (C) 2014 Inverse inc.

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
