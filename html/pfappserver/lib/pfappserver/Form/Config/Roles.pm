package pfappserver::Form::Config::Roles;

=head1 NAME

pfappserver::Form::Config::Roles - Web form for a role

=head1 DESCRIPTION

Form definition to create or update a role.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw(
    pfappserver::Base::Form::Role::Help
    pfappserver::Role::Form::RolesAttribute
);

use HTTP::Status qw(:constants is_success);

use pf::config qw(%ConfigRoles);
use pf::constants::role qw(@ROLES);

has_field 'id' =>
  (
   type => 'Text',
   label => 'Name',
   required => 1,
   messages => { required => 'Please specify a name for the role.' },
   apply => [ pfappserver::Base::Form::id_validator('role name') ]
  );

has_field 'notes' =>
  (
   type => 'Text',
   label => 'Description',
   required => 0,
  );

has_field 'parent' =>
  (
   type => 'Select',
   options_method => \&options_parent,
   label => 'Parent',
   required => 0,
  );

has_field 'max_nodes_per_pid' =>
  (
   type => 'PosInteger',
   label => 'Max nodes per user',
   default => 0,
   tags => { after_element => \&help,
             help => 'The maximum number of nodes a user having this role can register. A number of 0 means unlimited number of devices.' },
  );

=head2 validate

Make sure none of the reserved names is used.

Make sure the role name is unique.

=cut

sub validate {
    my $self = shift;
    my $value = $self->value;
    my $id = $value->{id} // '';
    if (grep { $_ eq $id  } @ROLES) {
        $self->field('id')->add_error('This is a reserved name.');
    }

    my $parent = $value->{parent};
    if (defined $parent) {
        if ( $id eq $parent) {
            $self->field('parent')->add_error('Cannot be your own parent.');
        }
        $parent = $ConfigRoles{$parent}{parent};
        while (defined $parent) {
            if ( $id eq $parent) {
                $self->field('parent')->add_error('Cannot have a parent of your descendents.');
                last;
            }
            $parent = $ConfigRoles{$parent}{parent};
        }

    }

}

=head2 options_parent

=cut

sub options_parent {
    my $self = shift;
    my $form = $self->form;
    my $id = $form->value->{id} // $form->fif->{id};
    my $no_id = !defined $id || $id eq '';
    my @roles = map { { value => $_->{name}, label => $_->{name} } } grep { $no_id || $_->{name} ne $id }  @{$form->roles} if ($form->roles);
    return @roles;
}

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
