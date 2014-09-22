package pfappserver::Form::Config::AdminRoles;

=head1 NAME

pfappserver::Form::Config::AdminRoles - Web form for an admin role

=head1 DESCRIPTION

Form definition to create or update an admin role

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::admin_roles;
use pf::log;

has roles => ( is => 'rw', default => sub { [] } );

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Role Name',
   required => 1,
   messages => { required => 'Please specify the name of the admin role.' },
  );
has_field 'description' =>
  (
   type => 'Text',
   required => 1,
   messages => { required => 'Please specify the description of the admin role.' },
  );
has_field 'actions' =>
  (
   type => 'DynamicTable',
   label => 'Actions',
   do_label => 0,
   'num_when_empty' => 2,
  );
has_field 'actions.contains' =>
  (
   type => 'Select',
   options_method => \&options_actions,
   widget_wrapper => 'DynamicTableRow',
  );

has_field 'allowed_roles' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Allowed roles',
   options_method => \&options_roles,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add a role' },
   tags => { after_element => \&help,
             help => 'List of roles available to the admin user. If none are provided then all roles are available' },
  );

has_field 'allowed_access_levels' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Allowed access levels',
   options_method => \&options_allowed_access_levels,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add a admin roles' },
   tags => { after_element => \&help,
             help => 'List of access levels available to the admin user. If none are provided then all access levels are available' },
  );

has_field 'allowed_access_durations' =>
  (
   type => 'Text',
   multiple => 1,
   label => 'Allowed access durations',
   element_attr => {'data-placeholder' => 'Click to add a admin roles' },
   tags => { after_element => \&help,
             help => 'A comma seperated list of access durations available to the admin user. If none are provided then the configured values are used'},
  );

sub build_do_form_wrapper{ 0 }

sub options_actions {
    my $self = shift;

    my %groups;
    my @options;

    map {
        m/^(.+?)(_(READ|CREATE|UPDATE|DELETE|SET_ROLE|SET_ACCESS_DURATION|SET_UNREG_DATE|SET_ACCESS_LEVEL|MARK_AS_SPONSOR))?$/;
        $groups{$1} = [] unless $groups{$1};
        push(@{$groups{$1}}, { value => $_, label => $self->_localize($_) })
    } @ADMIN_ACTIONS;

    @options = map {
        { group => $self->_localize($_), options => $groups{$_} }
    } sort keys %groups;

    return \@options;
};

=head2 options_allowed_access_levels

TODO: documention

=cut

sub options_allowed_access_levels {
    my ($self) = @_;
    return  [map { { label => $_, value => $_ } } keys %ADMIN_ROLES];
}

=head2 options_roles

=cut

sub options_roles {
    my $self = shift;
    my @roles = map { { label => $_->{name}, value => $_->{name} } } @{$self->form->roles} if ($self->form->roles);
    return \@roles;
}

=head2 ACCEPT_CONTEXT

To automatically add the context to the Form

=cut

sub ACCEPT_CONTEXT {
    my ($class, $c, @args) = @_;
    my ($status, $roles) = $c->model('Roles')->list();
    return $class->SUPER::ACCEPT_CONTEXT($c, roles => $roles, @args);
}


=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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
