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
use pf::SwitchFactory;
use pfappserver::Util::ACLs qw(_validate_acl);

pf::SwitchFactory->preloadAllModules();

has_field 'id' =>
  (
   type => 'Text',
   label => 'Name',
   required => 1,
   messages => { required => 'Please specify a name for the role.' },
   apply => [ 
    {
        check => qr/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/,
        message =>
            "The role name is invalid. The role name can only contain alphanumeric characters, dashes and underscores."
    }
   ]
  );

has_field 'notes' =>
  (
   type => 'Text',
   label => 'Description',
   required => 0,
  );

has_field 'parent_id' =>
  (
   type => 'Select',
   options_method => \&options_parent_id,
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

has_field 'include_parent_acls' => (
    type => 'Toggle',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
    label => 'Include parent ACLs',
);

has_field 'fingerbank_dynamic_access_list' => (
    type => 'Toggle',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
    label => 'Enabled Fingerbank Dynamic AccessList',
);

has_field 'acls' => (
    type => 'TextArea',
    label => 'ACLs',
    validate_method => \&_validate_acl,
);

has_field 'inherit_vlan' => (
    type => 'Toggle',
    label => 'Inherit VLAN',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
    default => 'disabled',
);

has_field 'inherit_role' => (
    type => 'Toggle',
    label => 'Inherit Role',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
    default => 'disabled',
);

has_field 'inherit_web_auth_url' => (
    type => 'Toggle',
    label => 'Inherit Web Auth URL',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
    default => 'disabled',
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

    my $parent_id = $value->{parent_id};
    if (defined $parent_id) {
        if ( $id eq $parent_id) {
            $self->field('parent_id')->add_error('Cannot be your own parent.');
        }
        $parent_id = $ConfigRoles{$parent_id}{parent_id};
        while (defined $parent_id) {
            if ( $id eq $parent_id) {
                $self->field('parent_id')->add_error('Cannot have a parent of your descendents.');
                last;
            }
            $parent_id = $ConfigRoles{$parent_id}{parent_id};
        }

    }

    my $acls = $self->field('acls')->value;
    if (!defined $acls || $acls eq '' ) {
        return;
    }

    $acls = [split(/\n/, $acls)];
    while (my ($switch_id, $data) = each %pf::SwitchFactory::SwitchConfig) {
        my $type = $data->{type};
        next if !defined $type || $type eq '' || $type eq 'PacketFence';
        my $module = pf::SwitchFactory::getModule($type);
        next if !defined $module;
        my $switch = $module->new({ id => $switch_id, %$data});
        my $warnings = $switch->checkRoleACLs($id, $acls);
        if (defined $warnings) {
            $self->add_pf_warning($warnings);
        }
    }

}

=head2 options_parent_id

=cut

sub options_parent_id {
    my $self = shift;
    my $form = $self->form;
    my $id = $form->value->{id} // $form->fif->{id};
    my $no_id = !defined $id || $id eq '';
    my @roles = map { { value => $_->{name}, label => $_->{name} } } grep { $no_id || $_->{name} ne $id }  @{$form->roles} if ($form->roles);
    return @roles;
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
