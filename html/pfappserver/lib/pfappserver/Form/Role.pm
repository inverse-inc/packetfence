package pfappserver::Form::Role;

=head1 NAME

pfappserver::Form::Role - Web form for a role

=head1 DESCRIPTION

Form definition to create or update a role.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use HTTP::Status qw(:constants is_success);

use pf::config;

has 'id' => ( is => 'ro' );

has_field 'name' =>
  (
   type => 'Text',
   label => 'Name',
   required => 1,
   messages => { required => 'Please specify a name for the category.' },
  );
has_field 'notes' =>
  (
   type => 'Text',
   label => 'Description',
   required => 0,
  );
has_field 'max_nodes_per_pid' =>
  (
   type => 'PosInteger',
   label => 'Max nodes per user',
   required => 1,
   tags => { after_element => \&help,
             help => 'The maximum number of nodes a user having this role can register.' },
  );

=head2 validate

Make sure none of the reserved names is used.

Make sure the role name is unique.

=cut

sub validate {
    my $self = shift;

    if (grep { $_ eq $self->value->{name} } @SNMP::ROLES) {
        $self->field('name')->add_error('This is a reserved name.');
    }
    elsif ($self->{id} && $self->{id} ne $self->value->{name} || !$self->{id}) {
        # Build a list of existing roles
        my ($status, $result) = $self->ctx->model('Roles')->list();
        if (is_success($status)) {
            my %roles = map { $_->{name} => 1 } @$result;
            if (defined $roles{$self->value->{name}}) {
                $self->field('name')->add_error('This name is already taken.');
            }
        }
    }
}

=head1 COPYRIGHT

Copyright (C) 2012-2013 Inverse inc.

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
