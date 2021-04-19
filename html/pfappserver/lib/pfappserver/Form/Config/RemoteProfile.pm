package pfappserver::Form::Config::RemoteProfile;

=head1 NAME

pfappserver::Form::Config::RemoteProfile - Web form for a floating device

=head1 DESCRIPTION

Form definition to create or update realm.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw (
    pfappserver::Base::Form::Role::Help
    pfappserver::Role::Form::RolesAttribute
);

use pf::config qw(%ConfigAuthenticationLdap %ConfigEAP);
use pf::authentication;
use pf::util;
use pf::ConfigStore::Domain;
use pfappserver::Form::Config::FilterEngines;
use pf::condition_parser qw(parse_condition_string);

## Definition
has_field 'id' =>
  (
    type => 'Text',
    required => 1,
    apply => [ pfappserver::Base::Form::id_validator('profile') ],
    tags => {
       option_pattern => \&pfappserver::Base::Form::id_pattern,
    },
  );

has_field 'description' =>
  (
    type => 'Text',
    required => 1,
  );

has_field 'status' =>
  (
    type => 'Toggle',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
    default => 'enabled'
  );

has_field 'basic_filter_type' =>
  (
    type => 'Select',
    default => '',
    options_method => sub { (
            { value => "", label => "None - use advanced filter" },
            { value => "node_info.mac", label => "Device MAC address" },
            { value => "node_info.pid", label => "Username" },
            { value => "node_info.category", label => "Device Role" },
        ) }
  );

has_field 'basic_filter_value' =>
  (
    type => 'Text',
  );

has_field 'advanced_filter' =>
  (
    type => 'FilterCondition',
  );

has_field 'allow_communication_same_role' =>
  (
    type => 'Toggle',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
  );

has_field 'allow_communication_to_roles' =>
  (
   type => 'Select',
   multiple => 1,
   options_method => \&options_roles,
  );

has_field 'resolve_hostnames_of_peers' =>
  (
    type => 'Toggle',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
  );

has_field 'additional_domains_to_resolve' =>
  (
   type => 'TextArea',
  );

has_field 'internal_domain_to_resolve' =>
  (
   type => 'Text',
  );

has_field 'gateway' =>
  (
    type => 'Toggle',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
  );

has_field 'rbac_ip_filtering' =>
  (
    type => 'Toggle',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
  );

has_field 'routes' =>
  (
   type => 'TextArea',
  );

has_field 'stun_server' =>
  (
    type => 'Text',
  );


sub options_roles {
    my $self = shift;
    my @roles = map { $_->{name} => $_->{name} } @{$self->form->roles} if ($self->form->roles);
    return @roles;
}

sub validate {
    my $self = shift;
    $self->SUPER::validate();

    if($self->field("id")->value eq "default") {
        return;
    }

    my $value = $self->value;
    my $advanced_filter = $value->{advanced_filter};
    my $basic_filter_type = $value->{basic_filter_type};
    my $condition_str = '';
    if (defined $advanced_filter) {
        $condition_str = pf::condition_parser::object_to_str($advanced_filter);
    }

    if(!$basic_filter_type && !$condition_str) {
        $self->field("basic_filter_type")->add_error("You need to specify a basic filter or an advanced filter.");
        $self->field("advanced_filter")->add_error("You need to specify a basic filter or an advanced filter.");
    }

    if($basic_filter_type && $condition_str) {
        $self->field("basic_filter_type")->add_error("You cannot specifiy an advanced filter and a basic filter.");
        $self->field("advanced_filter")->add_error("You cannot specifiy an advanced filter and a basic filter.");
    }

}

sub options_field {
    my ($self) = @_;
    return map { $self->make_field_options($_) } $self->options_field_names();
}

sub make_field_options {
    my ($self, $name) = @_;
    my %options = (
        label => $name,
        value => $name,
        $self->additional_field_options($name),
    );
    return \%options;
}

sub additional_field_options {
    my ($self, $name) = @_;
    my $options = $self->_additional_field_options;
    if (!exists $options->{$name}) {
        return;
    }

    my $more = $options->{$name};
    my $ref = ref $more;
    if ($ref eq 'HASH') {
        return %$more;
    } elsif ($ref eq 'CODE') {
        return $more->($self, $name);
    }

    return;
}

my %ADDITIONAL_FIELD_OPTIONS = (
    %pfappserver::Form::Config::FilterEngines::ADDITIONAL_FIELD_OPTIONS
);

sub _additional_field_options {
    return \%ADDITIONAL_FIELD_OPTIONS;
}

sub options_field_names {
    qw(
        node_info.autoreg
        node_info.bandwidth_balance
        node_info.bypass_role_id
        node_info.bypass_vlan
        node_info.category_id
        node_info.computername
        node_info.detect_date
        node_info.device_class
        node_info.device_manufacturer
        node_info.device_score
        node_info.device_type
        node_info.device_version
        node_info.dhcp6_enterprise
        node_info.dhcp6_fingerprint
        node_info.dhcp_fingerprint
        node_info.dhcp_vendor
        node_info.last_arp
        node_info.last_dhcp
        node_info.last_seen
        node_info.lastskip
        node_info.mac
        node_info.machine_account
        node_info.notes
        node_info.pid
        node_info.regdate
        node_info.sessionid
        node_info.status
        node_info.tenant_id
        node_info.time_balance
        node_info.unregdate
        node_info.user_agent
        node_info.voip
        node_info.bypass_role
        node_info.category
        node_info.last_connection_sub_type
        node_info.last_connection_type
        node_info.last_dot1x_username
        node_info.last_end_time
        node_info.last_ifDesc
        node_info.last_port
        node_info.last_role
        node_info.last_ssid
        node_info.last_start_time
        node_info.last_start_timestamp
        node_info.last_switch
        node_info.last_switch_mac
        node_info.last_vlan
        node_info.realm
        node_info.stripped_user_name
        remote_client.created_at
        remote_client.updated_at
        remote_client.tenant_id
        remote_client.public_key
        remote_client.mac
    );
}

=over

=back

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
