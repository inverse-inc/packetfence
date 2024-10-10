package pfappserver::Form::Config::Switch;

=head1 NAME

pfappserver::Form::Config::Switch - Web form for a switch

=head1 DESCRIPTION

Form definition to create or update a network switch.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw(
    pfappserver::Base::Form::Role::Help
    pfappserver::Role::Form::RolesAttribute
);

use File::Find qw(find);
use File::Spec::Functions;

use pf::config qw(
    $PORT
    $MAC
    $SSID
    $ALWAYS
);
use Cisco::AccessList::Parser;
use pf::Switch::constants;
use pf::constants::role qw(@ROLES);
use pf::SwitchFactory;
use pf::util;
use pf::config qw(%ConfigRoles);
use pf::error qw(is_success);
use List::MoreUtils qw(any uniq);
use pf::ConfigStore::SwitchGroup;
use pf::ConfigStore::Switch;
use pfappserver::Util::ACLs qw(_validate_acl);

## Definition
has_field 'id' =>
  (
   type => 'SwitchID',
   label => 'IP Address/MAC Address/Range (CIDR)',
   accept => ['default'],
   required => 1,
   messages => { required => 'Please specify the IP address/MAC address/Range (CIDR) of the switch.' },
   tags => {
       option_pattern => sub {
           return {
               regex => qq{(([0-9a-fA-f]{2}([:\\.-][0-9a-fA-f]{2}){5})|([0-9a-fA-F]{4}([\\.-][0-9a-fA-F]{4}){2})|([0-9a-fA-F]{12})|((\\d{1,3}(\\.\\d{1,3}){3})(/\\d{1,2})?)|((?=^.{4,253}\$)(^((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\\.)+[a-zA-Z]{2,63}\$))|default)},
               message => "The id must be a MAC, or IP address, or a fqdn.",
           };
       },
   }
  );
has_field 'description' =>
  (
   type => 'Text',
   required => 0,
  );

has_field 'type' =>
  (
   type => 'Select',
   label => 'Type',
   element_class => ['chzn-deselect'],
   messages => { required => 'Please select the type of the switch.' },
  );

has_field 'group' =>
  (
   type => 'Select',
   label => 'Switch Group',
   options_method => \&options_groups,
   element_class => ['chzn-select'],
   tags => { after_element => \&help,
             help => 'Changing the group requires to save to see the new default values' },
  );
has_field 'mode' =>
  (
   type => 'Select',
   label => 'Mode',
   element_class => ['chzn-deselect'],
  );
has_field 'deauthMethod' =>
  (
   type => 'Select',
   label => 'Deauthentication Method',
   element_class => ['chzn-deselect'],
  );

has_field 'useCoA' =>
  (
   type => 'Toggle',
   label => 'Use CoA',
   default => undef,
   tags => { after_element => \&help,
             help => 'Use CoA when available to deauthenticate the user. When disabled, RADIUS Disconnect will be used instead if it is available.' },
  );

has_field 'radiusDeauthUseConnector' =>
  (
   type => 'Toggle',
   default => undef,
  );

has_field 'deauthOnPrevious' =>
  (
   type => 'Toggle',
   default => undef,
  );

has_field 'VlanMap' =>
  (
   type => 'Toggle',
   label => 'Role by VLAN ID',
   default => undef,
  );

has_field 'RoleMap' =>
  (
   type => 'Toggle',
   label => 'Role by Switch Role',
   default => undef,
  );

has_field 'VpnMap' =>
  (
   type => 'Toggle',
   label => 'Role by Vpn Role',
   default => undef,
  );

has_field 'AccessListMap' =>
  (
   type => 'Toggle',
   label => 'Role by access list',
   default => undef,
  );
has_field 'UrlMap' =>
  (
   type => 'Toggle',
   label => 'Role by Web Auth URL',
   default => undef,
  );
has_field 'InterfaceMap' =>
  (
   type => 'Toggle',
   label => 'Interface to apply Role ACL',
   default => undef,
  );
has_field 'cliAccess' =>
  (
   type => 'Toggle',
   label => 'CLI Access Enabled',
   tags => { after_element => \&help,
             help => 'Allow this switch to use PacketFence as a radius server for CLI access'},
  );
has_field 'NetworkMap' =>
  (
   type => 'Toggle',
   label => 'Role by network',
   default => undef,
  );
has_field 'ExternalPortalEnforcement' => (
    type    => 'Toggle',
    default => undef,
);
has_field 'VoIPEnabled' =>
  (
   type => 'Toggle',
   default => undef,
   label => 'VoIP',
  );

has_field 'VoIPLLDPDetect' =>
  (
   type => 'Toggle',
   default => undef,
  );

has_field 'VoIPCDPDetect' =>
  (
   type => 'Toggle',
   default => undef,
  );

has_field 'VoIPDHCPDetect' =>
  (
   type => 'Toggle',
   default => undef,
  );

has_field 'PostMfaValidation' =>
  (
   type => 'Toggle',
   default => undef,
  );

has_field 'uplink_dynamic' =>
  (
   type => 'Checkbox',
   label => 'Dynamic Uplinks',
   checkbox_value => 'dynamic',
   tags => { after_element => \&help,
             help => 'Dynamically lookup uplinks' },
  );
has_field 'uplink' =>
  (
   type => 'Text',
   label => 'Uplinks',
   tags => { after_element => \&help,
             help => 'Comma-separated list of the switch uplinks' },
  );

## Inline mode
has_field 'inlineTrigger' =>
  (
   type => 'Repeatable',
   num_extra => 1, # add extra row that serves as a template
  );
has_field 'inlineTrigger.type' =>
  (
   type => 'Select',
   widget_wrapper => 'None',
   localize_labels => 1,
   options_method => \&options_inlineTrigger,
  );
has_field 'inlineTrigger.value' =>
  (
   type => 'Hidden',
  );
has_field "${ALWAYS}_trigger" =>
  (
   type => 'Hidden',
   default => 1,
  );
has_field "${PORT}_trigger" =>
  (
   type => 'PosInteger',
   do_label => 0,
   wrapper => 0,
   element_class => ['input-mini'],
  );
has_field "${MAC}_trigger" =>
  (
   type => 'MACAddress',
   do_label => 0,
   wrapper => 0,
   #element_class => ['span5'],
  );
has_field "${SSID}_trigger" =>
  (
   type => 'Text',
   do_label => 0,
   wrapper => 0,
   #element_class => ['span5'],
  );

has_field 'radiusSecret' =>
  (
   type => 'ObfuscatedText',
   label => 'Secret Passphrase',
  );

has_field macSearchesMaxNb =>
  (
   type => 'PosInteger',
   label => 'Maximum MAC addresses',
   tags => {
       after_element => \&help,
       help => 'Maximum number of MAC addresses retrived from a port'
   },
  );

has_field macSearchesSleepInterval  =>
  (
   type => 'PosInteger',
   label => 'Sleep interval',
   tags => {
       after_element => \&help,
       help => 'Sleep interval between queries of MAC addresses'
   },
  );

has_block definition =>
  (
   render_list => [ qw(description type mode group deauthMethod useCoA deauthOnPrevious cliAccess ExternalPortalEnforcement VoIPEnabled VoIPLLDPDetect VoIPCDPDetect VoIPDHCPDetect PostMfaValidation uplink_dynamic uplink controllerIp disconnectPort coaPort) ],
  );

has_field 'SNMPUseConnector' =>
  (
   type => 'Toggle',
   default => undef,
  );

  has_field 'SNMPVersion' =>
  (
   type => 'Select',
   label => 'Version',
   element_class => ['chzn-deselect'],
  );
has_field 'SNMPCommunityRead' =>
  (
   type => 'Text',
   label => 'Community Read',
  );
has_field 'SNMPCommunityWrite' =>
  (
   type => 'Text',
   label => 'Community Write',
  );
has_field 'SNMPEngineID' =>
  (
   type => 'Text',
   label => 'Engine ID',
  );
has_field 'SNMPUserNameRead' =>
  (
   type => 'Text',
   label => 'User Name Read',
  );
has_field 'SNMPAuthProtocolRead' =>
  (
   type => 'Text',
   label => 'Auth Protocol Read',
  );
has_field 'SNMPAuthPasswordRead' =>
  (
   type => 'ObfuscatedText',
   label => 'Auth Password Read',
  );
has_field 'SNMPPrivProtocolRead' =>
  (
   type => 'Text',
   label => 'Priv Protocol Read',
  );
has_field 'SNMPPrivPasswordRead' =>
  (
   type => 'ObfuscatedText',
   label => 'Priv Password Read',
  );
has_field 'SNMPUserNameWrite' =>
  (
   type => 'Text',
   label => 'User Name Write',
  );
has_field 'SNMPAuthProtocolWrite' =>
  (
   type => 'Text',
   label => 'Auth Protocol Write',
  );
has_field 'SNMPAuthPasswordWrite' =>
  (
   type => 'ObfuscatedText',
   label => 'Auth Password Write',
  );
has_field 'SNMPPrivProtocolWrite' =>
  (
   type => 'Text',
   label => 'Priv Protocol Write',
  );
has_field 'SNMPPrivPasswordWrite' =>
  (
   type => 'ObfuscatedText',
   label => 'Priv Password Write',
  );
has_field 'SNMPVersionTrap' =>
  (
   type => 'Select',
   label => 'Version Trap',
   element_class => ['chzn-deselect'],
   options_method => \&options_SNMPVersion,
  );
has_field 'SNMPCommunityTrap' =>
  (
   type => 'Text',
   label => 'Community Trap',
  );
has_field 'SNMPUserNameTrap' =>
  (
   type => 'Text',
   label => 'User Name Trap',
  );
has_field 'SNMPAuthProtocolTrap' =>
  (
   type => 'Text',
   label => 'Auth Protocol Trap',
  );
has_field 'SNMPAuthPasswordTrap' =>
  (
   type => 'ObfuscatedText',
   label => 'Auth Password Trap',
  );
has_field 'SNMPPrivProtocolTrap' =>
  (
   type => 'Text',
   label => 'Priv Protocol Trap',
  );
has_field 'SNMPPrivPasswordTrap' =>
  (
   type => 'ObfuscatedText',
   label => 'Priv Password Trap',
  );

## CLI
has_field 'cliTransport' =>
  (
   type => 'Select',
   label => 'Transport',
   element_class => ['chzn-deselect'],
  );
has_field 'cliUser' =>
  (
   type => 'Text',
   label => 'Username',
  );
has_field 'cliPwd' =>
  (
   type => 'ObfuscatedText',
   label => 'Password',
  );

has_field 'cliEnablePwd' =>
  (
   type => 'ObfuscatedText',
   label => 'Enable Password',
  );

has_field 'wsTransport' =>
  (
   type => 'Select',
   label => 'Transport',
   element_class => ['chzn-deselect'],
  );
has_field 'wsUser' =>
  (
   type => 'Text',
   label => 'Username',
  );
has_field 'wsPwd' =>
  (
   type => 'ObfuscatedText',
   label => 'Password',
  );

has_field controllerIp =>
  (
    type => 'IPAddress',
    label => 'Controller IP Address',
    tags => {
        after_element => \&help,
        help => 'Use instead this IP address for de-authentication requests. Normally used for Wi-Fi only'
    },
  );

has_field disconnectPort =>
  (
    type => 'PosInteger',
    label => 'Disconnect Port',
    tags => {
        after_element => \&help_list,
        help => 'For Disconnect request, if we have to send to another port'
    },
  );

has_field coaPort =>
  (
    type => 'PosInteger',
    label => 'CoA Port',
    tags => {
        after_element => \&help_list,
        help => 'For CoA request, if we have to send to another port'
    },
  );

has_field UsePushACLs => (
    type => 'Toggle',
);

has_field UseDownloadableACLs => (
    type => 'Toggle',
);

has_field DownloadableACLsLimit => (
    type => 'PosInteger',
);

has_field ACLsLimit => (
    type => 'PosInteger',
);

sub addRoleMapping {
    my ($namespace, $key, $additional_info) = @_;
    has_field "$namespace" => (
        type => 'Repeatable',
    );

    has_field "$namespace.$key" => (
        type => 'Text',
        required => 0,
        @{$additional_info // []},
    );

    has_field "$namespace.role" => (
        type => 'SelectSuggested',
        options_method => \&options_roles,
        required => 1,
    );
}

addRoleMapping("VlanMapping", "vlan");
addRoleMapping("UrlMapping", "url");
addRoleMapping("ControllerRoleMapping", "controller_role");
addRoleMapping("AccessListMapping", "accesslist");
addRoleMapping("VpnMapping", "vpn");
addRoleMapping("NetworkMapping", "network");
addRoleMapping("NetworkFromMapping", "networkfrom");
addRoleMapping("InterfaceMapping", "interface");

sub _validate_acl_switch {
    my ($field) = @_;
    my $switch = $field->form->getSwitch();
    if ($switch) {
       my $role_field = $field->parent()->field('role');
       my $error = $switch->checkRoleACLs(
           $role_field->value,
           [split /\n/, $field->value],
       );
       if ($error) {
           $field->add_error($error->{message});
       }
    }
}

sub getSwitch {
    my ($self) = @_;
    my $type_field = $self->field('type');
    my $type = $type_field->value;
    if (!defined $type) {
        return undef;
    }

    my $value = $self->value;
    my $module = pf::SwitchFactory::getModule($type);
    if ($module->require() ) {
        return $module->new($value);
    }

    return undef;
}

sub options_roles {
    my $self = shift;
    my @roles = map {  { label => $_, value  => $_ } } (@ROLES, map { $_->{name} }  @{$self->form->roles // []});
    return @roles;
}

=head1 METHODS

=head2 options_inlineTrigger

=cut

sub options_inlineTrigger {
    my $self = shift;

    my @triggers = map { $_ => $self->_localize($_) } ($ALWAYS, $PORT, $MAC, $SSID);

    return @triggers;
}

=head2 update_fields

When editing the default switch, set as required the VLANs mapping of the base roles.

For other switches, add placeholders with values from default switch.

=cut

sub update_fields {
    my ($self, $init_object) = @_;
    $init_object ||= $self->init_object;
    my $id = $init_object->{id} if $init_object;
    my $inherit_from = $init_object->{group} || "default";
    my $cs = pf::ConfigStore::Switch->new;
    my $placeholders = $id ? $cs->readInherited($id) : $cs->read($inherit_from);

    if ($placeholders) {
        foreach my $field ($self->fields) {
            my $name = $field->name;
            my $placeholder = $placeholders->{$name};
            if (defined $placeholder && length $placeholder) {
                if ($field->type eq 'Select') {
                    my $val = sprintf "%s (%s)", $self->_localize('Default'), $placeholder;
                    $field->element_attr({ 'data-placeholder' => $val });
                } elsif (
                    # if there is no value defined in the switch and the place holder is defined
                    # We check that it is not disabled because of special cases like uplink_dynamic
                    ( ( !defined($init_object->{$field->name}) && !pf::util::isdisabled($placeholder) )
                    # or that the value in the switch is enabled
                        || pf::util::isenabled($field->value) )
                    # we only apply this to Checkbox and Toggle
                    && ($field->type eq "Checkbox" || $field->type eq "Toggle") ) {
                    $field->element_attr({ checked => "checked" });
                } elsif ($name ne 'id') {
                    $field->element_attr({ placeholder => $placeholder });
                }
            }
        }
    }
    $self->SUPER::update_fields();
}


=head2 build_block_list

Dynamically build the block list of the roles mapping.

=cut

sub build_block_list {
    return [];
}

=head2 options_type

Extract the descriptions from the various Switch modules.

=cut

sub options_type {
    return pf::SwitchFactory::form_options();
}

=head2 options_groups

Extract the switch groups from the configuration

=cut

sub options_groups {
    my $self = shift;
    my @couples;
    push @couples, ('' => 'None');
    my $cs = pf::ConfigStore::SwitchGroup->new;
    my @groups = @{$cs->readAll("id")};
    push @couples, map { $_->{id} => "$_->{id} - ($_->{description})" } @groups;

    return @couples;
}

=head2 options_mode

=cut

sub options_mode {
    my $self = shift;

    my @modes = map { $_ => $self->_localize($_) } @SNMP::MODES;

    return ('' => '', @modes);
}

=head2 options_deauthMethod

=cut

sub options_deauthMethod {
    my $self = shift;

    my @methods = map { $_ => $_ } @SNMP::METHODS;

    return ('' => '', @methods);
}

=head2 options_vclose

=cut

sub options_SNMPVersion {
    my $self = shift;

    my @versions = map { $_ => "v$_" } @SNMP::VERSIONS;

    return ('' => '', @versions);
}

=head2 options_cliTransport

=cut

sub options_cliTransport {
    my $self = shift;

    my @transports = map { $_ => $_ } qw/Telnet SSH/;

    return ('' => '', @transports);
}

=head2 options_wsTransport

=cut

sub options_wsTransport {
    my $self = shift;

    my @transports = map { {label => uc($_), value =>  $_ } } qw/http https/;

    return ({label => '' ,value => '' }, @transports);
}

=head2 options_ACLs

=cut

sub options_ACLs {
    my $self = shift;

    my @options = map { {label => $_, value =>  $_ } } qw/pushACLs downloadableACLs/;

    return ({label => '' ,value => '' }, @options);
}

=head2 validate

If one of the inline triggers is $ALWAYS, ignore any other trigger.

Make sure the selected switch type supports the selected inline triggers.

Validate the MAC address format of the inline triggers.

Validate the list of uplink ports.

=cut

sub validate {
    my $self = shift;
    my $config = pf::ConfigStore::Switch->new;
    my $groupConfig = pf::ConfigStore::SwitchGroup->new;
    tie my %TemplateSwitches, 'pfconfig::cached_hash', 'config::TemplateSwitches';
    my $value = $self->value;

    my @triggers;
    my $always = any { $_->{type} eq $ALWAYS } @{$value->{inlineTrigger}};
    my $type = $value->{type};
    if ($type) {
        my $switch = $self->getSwitch();
        if ($switch) {
            @triggers = map { $_->{type} } @{$value->{inlineTrigger}};
            if ( @triggers && !$always) {
                # Make sure the selected switch type supports the selected inline triggers.
                my %capabilities;
                @capabilities{$switch->inlineCapabilities()} = ();
                if (keys %capabilities) {
                    my @unsupported = grep {!exists $capabilities{$_} } @triggers;
                    if (@unsupported) {
                        $self->field('type')->add_error("The chosen type doesn't support the following trigger(s): "
                                                        . join(', ', @unsupported));
                    }
                } else {
                    $self->field('type')->add_error("The chosen type doesn't support inline mode.");
                }
            }

            my $warnings = $switch->checkRolesACLs(\%ConfigRoles);
            if (defined $warnings) {
                $self->add_pf_warning(@$warnings);
            }

            $self->validateAccessListMapping($switch);

        } else {
            $self->field('type')->add_error("The chosen type (" . $type . ") is not supported.");
        }

        my $id = $value->{id};
        if ($id) {
            $self->validateFqdnId($id, $type);
        }
    } else {
        my $group_name = $value->{group} || '';
        my $default = $config->read('default');
        my $group = $groupConfig->read($group_name) || {};
        unless(defined $default->{type} || defined $group->{type}) {
            $self->field('type')->add_error("A type is required");
        }
        my $type = $group->{type} // $default->{type};
        $self->validateFqdnId($value->{id}, $type);
    }

    unless ($self->has_errors) {
        # Valide the MAC address format of the inline triggers.
        @triggers = grep { $_->{type} eq $MAC } @{$value->{inlineTrigger}};
        foreach my $trigger (@triggers) {
            unless (valid_mac($trigger->{value})) {
                $self->field('inlineTrigger')->add_error("Verify the format of the MAC address(es).");
                last;
            }
        }
    }

    # Temporarily disabled as new admin sends uplink_dynamic as undef which has this evaluated everytime although the inherited value might be 'dynamic'
    # The frontend does a validation of this requirement
    #if ($self->value->{uplink_dynamic} ne 'dynamic') {
    #    unless ($self->value->{uplink} && $self->value->{uplink} =~ m/^(\d(,\s*)?)*$/) {
    #        $self->field('uplink')->add_error("The uplinks must be a list of ports numbers.");
    #    }
    #}
}

sub validateFqdnId {
    my ($self, $id, $type) = @_;
    if (defined $id && defined $type && valid_fqdn($id) && $type ne 'Aruba::Instant') {
        $self->field('id')->add_error("The chosen type does not supported a fqdn as an id.");
    }
}

sub validateAccessListMapping {
    my ($self, $switch) = @_;
    my $accessListMapping = $self->field('AccessListMapping');
    for my $parent ($accessListMapping->fields()) {
       my $role_field = $parent->field('role');
       my $accesslist_field = $parent->field('accesslist');
       my $error = $switch->checkRoleACLs(
           $role_field->value,
           [split /\n/, $accesslist_field->value],
       );
       if ($error) {
           $accesslist_field->add_error($error->{message});
       }
   }
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
