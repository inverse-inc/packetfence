package pfappserver::Form::Node;

=head1 NAME

pfappserver::Form::Node - Web form for a node

=head1 DESCRIPTION

Form definition to create or update a node.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::AllowedOptions';

use HTTP::Status qw(is_error);
use pf::config qw(%Config);
use pf::log;

# Form select options
has 'roles' => ( is => 'ro' );
has 'status' => ( is => 'ro' );
has 'readonly' => ( is => 'ro', lazy => 1, builder => '_build_readonly');

# Form fields
has_field 'mac' =>
  (
   type => 'MACAddress',
   label => 'MAC',
   required => 1,
  );
has_field 'pid' =>
  (
   type => 'Text',
   label => 'Owner',
   element_attr => {'data-provide' => 'typeahead',
                    'placeholder' => $Config{node_import}{pid}},
  );
has_field 'status' =>
  (
   type => 'Select',
   label => 'Status',
   element_class => ['chzn-select'],
  );
has_field 'category_id' =>
  (
   type => 'Select',
   label => 'Role',
   options_method => \&get_role_options,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'No role'},
  );
has_field 'bypass_role_id' =>
  (
   type => 'Select',
   label => 'Bypass Role',
   options_method => \&get_role_options,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'No role'},
  );
has_field 'regdate' =>
  (
   type => 'Uneditable',
   label => 'Registration',
  );
has_field 'unregdate' =>
  (
   type => '+DateTimePicker',
   label => 'Unregistration',
  );
has_field 'time_balance' =>
  (
   type => 'PosInteger',
   label => 'Remaining Access Time',
  );
has_field 'bandwidth_balance' =>
  (
   type => 'PosInteger',
   label => 'Remaining Bandwidth',
  );
has_field 'notes' =>
  (
   type => 'TextArea',
   label => 'Notes',
  );
has_field 'computername' =>
  (
   type => 'Uneditable',
   label => 'Name',
  );
has_field 'voip' =>
  (
   type => 'Checkbox',
   label => 'Voice Over IP',
   checkbox_value => 'yes',
   input_without_param => 'no',
  );
has_field 'last_dot1x_username' =>
  (
   type => 'Uneditable',
   label => '802.1X Username',
  );
has_field 'bypass_vlan' =>
  (
   type => 'Text',
   label => 'Bypass VLAN',
  );

# Fingerprinting related fields
has_field 'user_agent' =>
  (
   type => 'Uneditable',
   label => 'User Agent',
  );
has_field 'dhcp_fingerprint' =>
  (
   type => 'Uneditable',
   label => 'DHCP fingerprint',
  );
has_field 'dhcp_vendor' =>
  (
   type => 'Uneditable',
   label => 'DHCP Vendor',
  );
has_field 'dhcp6_fingerprint' =>
  (
   type => 'Uneditable',
   label => 'DHCPv6 Fingerprint',
  );
has_field 'dhcp6_enterprise' =>
  (
   type => 'Uneditable',
   label => 'DHCPv6 Enterprise',
  );
has_field 'device_type' =>
  (
   type => 'Uneditable',
   label => 'Device Type',
  );
has_field 'device_class' =>
 (
   type => 'Uneditable',
   label => 'Device class',
 );
has_field 'fingerbank_info' =>
  (
   type => 'Compound', # virtual field to access the 'fingerbank_info' hash
  );
has_field 'fingerbank_info.device_fq' =>
 (
   type => 'Uneditable',
   label => 'Fully qualified device name',
 );
has_field 'fingerbank_info.version' =>
 (
   type => 'Uneditable',
   label => 'Version',
 );
has_field 'fingerbank_info.score' =>
 (
   type => 'Uneditable',
   label => 'Score',
 );
has_field 'fingerbank_info.mobile' =>
 (
   type => 'Toggle',
   label => 'Mobile',
   element_attr => {disabled => 1},
 );
#/ END fingerprinting related fields
 
=head2 options_status

=cut

sub options_status {
    my $self = shift;

    # $self->status comes from pfappserver::Model::Node->availableStatus
    my @status = map { $_ => $self->_localize($_) } @{$self->status} if ($self->status);

    return @status;
}

=head2 options_category_id

=cut

sub options_category_id {
    my $self = shift;

    # $self->roles comes from pfappserver::Model::Roles
    my @roles = map { $_->{category_id} => $_->{name} } @{$self->roles} if ($self->roles);

    return ('' => '', @roles);
}

=head2 options_bypass_role_id

=cut

sub options_bypass_role_id {
    my $self = shift;
    return $self->options_category_id();
}

=head2 validate

Make sure the specified user ID (pid) exists

=cut

sub validate {
    my $self = shift;

    if ($self->value->{pid}) {
        my ($status, $result) = $self->form->ctx->model('User')->read($self->form->ctx, [$self->value->{pid}]);
        if (is_error($status)) {
            $self->field('pid')->add_error("The specified user doesn't exist.");
        }
    }
}

=head2 get_role_options

Get role options

=cut

sub get_role_options {
    my ($self) = @_;
    my $logger = get_logger();
    my $form   = $self->form;
    my $name   = $self->name;
    my $previous_role = $self->init_value // '';
    $logger->trace(sub {"Previous role '$previous_role' for '$name'"});
    my %allowed_node_roles = map {$_ => undef} $form->_get_allowed_options('allowed_node_roles');
    my @roles;
    my @all_roles = @{$form->roles // []};

    if (keys %allowed_node_roles) {
        @roles =
          map {{value => $_->{category_id}, label => $_->{name}}}
          grep {exists $allowed_node_roles{$_->{name}} || $previous_role eq $_->{category_id}} @all_roles;
    }
    else {
        @roles = map {{value => $_->{category_id}, label => $_->{name}}} @all_roles;
    }
    return ({label => '', value => ''}, @roles);
}

=head2 build_update_subfields

Mark fields as readonly when the user is allowed to deal with the role

=cut

sub build_update_subfields {
    my ($self) = @_;
    my $readonly = $self->readonly;
    return {
        all => { readonly => $readonly, disabled => $readonly },
    };
}

=head2 _build_readonly

Verify if the node is should be readonly

=cut

sub _build_readonly {
    my ($self) = @_;
    my $init_object = $self->init_object;
    return undef unless defined $init_object;
    my $role = $self->init_object->{category};
    return undef unless defined $role;
    my %allowed_node_roles = map {$_ => undef} $self->_get_allowed_options('allowed_node_roles');
    return
        keys %allowed_node_roles == 0     ? undef
      : exists $allowed_node_roles{$role} ? undef
      :                                     1;
}

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
