package pfappserver::Form::Config::AdminRoles;

=head1 NAME

pfappserver::Form::Config::AdminRoles - Web form for an admin role

=head1 DESCRIPTION

Form definition to create or update an admin role

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw(
    pfappserver::Base::Form::Role::Help
    pfappserver::Role::Form::RolesAttribute
    pfappserver::Base::Form::Role::AllowedOptions
);

use pf::admin_roles;
use pf::constants::admin_roles qw(@ADMIN_ACTIONS);
use pf::Authentication::constants;

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
   label => 'Allowed user roles',
   options_method => \&options_roles,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add a role' },
   tags => { after_element => \&help,
             help => 'List of roles available to the admin user to assign to a user. If none are provided then all roles are available' },
  );

has_field 'allowed_node_roles' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Allowed node roles',
   options_method => \&options_roles,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add a role' },
   tags => { after_element => \&help,
             help => 'List of roles available to the admin user to assign to a node. If none are provided then all roles are available' },
  );

has_field 'allowed_access_levels' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Allowed user access levels',
   options_method => \&options_allowed_access_levels,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add a admin roles' },
   tags => { after_element => \&help,
             help => 'List of access levels available to the admin user. If none are provided then all access levels are available' },
  );

has_field 'allowed_actions' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Allowed actions',
   options_method => \&options_allowed_actions,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add an action' },
   tags => { after_element => \&help,
             help => 'List of actions available to the admin user. If none are provided then all actions are available' },
  );

has_field 'allowed_unreg_date' =>
  (
   type => 'DatePicker',
   label => 'Maximum allowed unregistration date',
   tags => { after_element => \&help,
             help => 'The maximal unregistration date that can be set.' },
  );

has_field 'allowed_access_durations' =>
  (
   type => 'Text',
   multiple => 1,
   label => 'Allowed user access durations',
   element_attr => {'data-placeholder' => 'Click to add a admin roles' },
   tags => { after_element => \&help,
             help => 'A comma seperated list of access durations available to the admin user. If none are provided then the default access durations are used'},
  );

sub build_do_form_wrapper{ 0 }

sub options_actions {
    my $self = shift;

    my %groups;
    my @options;
    foreach my $role (@ADMIN_ACTIONS) {
        $role =~ m/^(.+?)(_(WRITE|READ|CREATE|UPDATE|DELETE|SET_ROLE|SET_ACCESS_DURATION|SET_UNREG_DATE|SET_ACCESS_LEVEL|SET_TIME_BALANCE|SET_BANDWIDTH_BALANCE|MARK_AS_SPONSOR|CREATE_MULTIPLE|READ_SPONSORED|SET_TENANT_ID))?$/;
        $groups{$1} = [] unless $groups{$1};
        push(@{$groups{$1}}, { value => $role, label => $self->_localize($role) })
    }

    @options = map {
        { group => $self->_localize($_), options => $groups{$_}, value => '' }
    } sort keys %groups;

    return \@options;
};

=head2 options_allowed_access_levels

The list of allowed access levels

=cut

sub options_allowed_access_levels {
    my ($self) = @_;
    return map { { value => $_, label => $_ } } $self->form->allowed_access_levels();
}

=head2 options_roles

=cut

sub options_roles {
    my $self = shift;
    my @roles = map { { label => $_->{name}, value => $_->{name} } } @{$self->form->roles || []};
    return \@roles;
}

=head2 options_allowed_actions

=cut

sub options_allowed_actions {
    my ($self) = @_;
    return map { { value => $_, label => $_ } } $self->form->allowed_actions();
}

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
