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
);;
use pf::Switch::constants;
use pf::constants::role qw(@ROLES);
use pf::SwitchFactory;
use pf::util;
use List::MoreUtils qw(any);
use pf::ConfigStore::SwitchGroup;
use pf::ConfigStore::Switch;

## Definition
has_field 'id' =>
  (
   type => 'SwitchID',
   label => 'IP Address/MAC Address/Range (CIDR)',
   accept => ['default'],
   required => 1,
   messages => { required => 'Please specify the IP address/MAC address/Range (CIDR) of the switch.' },
  );
has_field 'description' =>
  (
   type => 'Text',
   required_when => { 'id' => sub { $_[0] ne 'default' } },
  );
has_field 'type' =>
  (
   type => 'Select',
   label => 'Type',
   element_class => ['chzn-deselect'],
   required_when => { 'id' => sub { $_[0] eq 'default' } },
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
   required_when => { 'id' => sub { $_[0] eq 'default' } },
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
   default => 'enabled',
   tags => { after_element => \&help,
             help => 'Use CoA when available to deauthenticate the user. When disabled, RADIUS Disconnect will be used instead if it is available.' },
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
has_field 'cliAccess' =>
  (
   type => 'Toggle',
   label => 'CLI Access Enabled',
   tags => { after_element => \&help,
             help => 'Allow this switch to use PacketFence as a radius server for CLI access'},
  );
has_field 'ExternalPortalEnforcement' => (
    type    => 'Toggle',
    label   => 'External Portal Enforcement',
    tags    => {
        after_element   => \&help,
        help            => 'Enable external portal enforcement when supported by network equipment',
    },
);
has_field 'VoIPEnabled' =>
  (
   type => 'Toggle',
   label => 'VoIP',
  );

has_field 'VoIPLLDPDetect' =>
  (
   type => 'Toggle',
   label => 'VoIPLLDPDetect',
   default => undef,
   tags => { after_element => \&help,
             help => 'Detect VoIP with a SNMP request in the LLDP MIB'},
  );

has_field 'VoIPCDPDetect' =>
  (
   type => 'Toggle',
   label => 'VoIPCDPDetect',
   default => undef,
   tags => { after_element => \&help,
             help => 'Detect VoIP with a SNMP request in the CDP MIB'},
  );

has_field 'VoIPDHCPDetect' =>
  (
   type => 'Toggle',
   label => 'VoIPDHCPDetect',
   default => undef,
   tags => { after_element => \&help,
             help => 'Detect VoIP with the DHCP Fingerprint'},
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
has_block 'triggers' =>
  (
   tag => 'div',
   render_list => [
                   map( { ("${_}_trigger") } ($ALWAYS, $PORT, $MAC, $SSID)),
                  ],
   attr => { id => 'templates' },
   class => [ 'hidden' ],
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

## RADIUS
has_block 'radius' =>
  (
   tag => 'div',
   render_list => [
                   'radiusSecret',
                  ],
  );
has_field 'radiusSecret' =>
  (
   type => 'ObfuscatedText',
   label => 'Secret Passphrase',
  );

## SNMP
has_block 'snmp' =>
  (
   tag => 'div',
   render_list => [
                   'SNMPVersion',
                   'SNMPCommunityRead',
                   'SNMPCommunityWrite',
                   'SNMPEngineID',
                   'SNMPUserNameRead',
                   'SNMPAuthProtocolRead',
                   'SNMPAuthPasswordRead',
                   'SNMPPrivProtocolRead',
                   'SNMPPrivPasswordRead',
                   'SNMPUserNameWrite',
                   'SNMPAuthProtocolWrite',
                   'SNMPAuthPasswordWrite',
                   'SNMPPrivProtocolWrite',
                   'SNMPPrivPasswordWrite',
                   'SNMPVersionTrap',
                   'SNMPCommunityTrap',
                   'SNMPUserNameTrap',
                   'SNMPAuthProtocolTrap',
                   'SNMPAuthPasswordTrap',
                   'SNMPPrivProtocolTrap',
                   'SNMPPrivPasswordTrap',
                   'advance',
                  ],
  );

has_block 'advance' =>
  (
   tag => 'div',
   render_list => [ qw(macSearchesMaxNb macSearchesSleepInterval) ],
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
   render_list => [ qw(description type mode group deauthMethod useCoA cliAccess ExternalPortalEnforcement VoIPEnabled VoIPLLDPDetect VoIPCDPDetect VoIPDHCPDetect uplink_dynamic uplink controllerIp disconnectPort coaPort) ],
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
has_block 'cli' =>
  (
   tag => 'div',
   render_list => [
                   'cliTransport',
                   'cliUser',
                   'cliPwd',
                   'cliEnablePwd',
                  ],
  );
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

## Web Services
has_block 'ws' =>
  (
   tag => 'div',
   render_list => [
                   'wsTransport',
                   'wsUser',
                   'wsPwd',
                  ],
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

=head1 METHODS

=head2 options_inlineTrigger

=cut

sub options_inlineTrigger {
    my $self = shift;

    my @triggers = map { $_ => $self->_localize($_) } ($ALWAYS, $PORT, $MAC, $SSID);

    return @triggers;
}

=head2 field_list

Dynamically build text fields for the roles/vlans mapping.

=cut

sub field_list {
    my $self = shift;

    my $list = [];

    # Add VLAN & role mapping for default roles
    foreach my $role (@ROLES) {
        $self->_add_role_mappings($list, $role);
    }

    if (defined $self->roles) {
        foreach my $role (map { $_->{name} } @{$self->roles}) {
            $self->_add_role_mappings($list, $role);
        }
    }

    return $list;
}

=head2 _add_role_mappings

Add VLAN & role mapping for custom roles

=cut

sub _add_role_mappings {
    my ($self, $list, $role) = @_;
    my $text_field = {
        type              => 'Text',
        label             => $role,
        wrap_label_method => \&role_label_wrap,
    };
    foreach my $type (qw(Role Url Vlan)) {
        push(@$list, $role . $type => $text_field);
    }

    my $text_area_field = {
        type              => 'TextArea',
        label             => $role,
        wrap_label_method => \&role_label_wrap,
    };
    push(@$list, $role . 'AccessList' => $text_area_field);
}

sub role_label_wrap {
    my ($self, $label) = @_;
    return $label;
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
    my $placeholders = $id ? pf::ConfigStore::Switch->new->readInherited($id) : undef;

    if (defined $id && $id eq 'default') {
        foreach my $role (@ROLES) {
            $self->field($role.'Vlan')->required(1);
        }
    } elsif ($placeholders) {
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
    my $self = shift;

    my (@vlans, @roles, @access_lists, @urls);
    if ($self->form->roles) {
        @vlans = map { $_.'Vlan' } @ROLES, map { $_->{name} } @{$self->form->roles};
        @roles = map { $_.'Role' } @ROLES, map { $_->{name} } @{$self->form->roles};
        @access_lists = map { $_.'AccessList' } @ROLES, map { $_->{name} } @{$self->form->roles};
        @urls = map { $_.'Url' } @ROLES, map { $_->{name} } @{$self->form->roles};
    }

    return
      [
       { name => 'vlans',
         render_list => \@vlans,
       },
       { name => 'roles',
         render_list => \@roles,
       },
       { name => 'access_lists',
         render_list => \@access_lists,
       },
       { name => 'urls',
         render_list => \@urls,
       }
      ];
}

=head2 options_type

Extract the descriptions from the various Switch modules.

=cut

sub options_type {
    my $self = shift;

    # Sort vendors and switches for display
    my @modules;
    foreach my $vendor (sort keys %pf::SwitchFactory::VENDORS) {
        my $vendors = $pf::SwitchFactory::VENDORS{$vendor};
        my @switches = map {{ value => $_, label => $vendors->{$_} }} sort keys %$vendors;
        push @modules, { group => $vendor,
                         options => \@switches,
                         value => '' };
    }

    return ({group => '', options => [{value => '', label => ''}], value => ''}, @modules);
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
    push @couples, map { $_->{id} => $_->{description} } @groups;

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

    my @triggers;
    my $always = any { $_->{type} eq $ALWAYS } @{$self->value->{inlineTrigger}};

    if ($self->value->{type}) {
        my $type = 'pf::Switch::'. $self->value->{type};
        if ($type->require()) {
            @triggers = map { $_->{type} } @{$self->value->{inlineTrigger}};
            if ( @triggers && !$always) {
                # Make sure the selected switch type supports the selected inline triggers.
                my %capabilities;
                @capabilities{$type->new()->inlineCapabilities()} = ();
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
        } else {
            $self->field('type')->add_error("The chosen type is not supported.");
        }
    } else {
        my $group_name = $self->value->{group} || '';
        my $default = $config->read('default');
        my $group = $groupConfig->read($group_name) || {};
        unless(defined $default->{type} || defined $group->{type}) {
            $self->field('type')->add_error("A type is required");
        }
    }

    unless ($self->has_errors) {
        # Valide the MAC address format of the inline triggers.
        @triggers = grep { $_->{type} eq $MAC } @{$self->value->{inlineTrigger}};
        foreach my $trigger (@triggers) {
            unless (valid_mac($trigger->{value})) {
                $self->field('inlineTrigger')->add_error("Verify the format of the MAC address(es).");
                last;
            }
        }
    }

    if ($self->value->{uplink_dynamic} ne 'dynamic') {
        unless ($self->value->{uplink} && $self->value->{uplink} =~ m/^(\d(,\s*)?)*$/) {
            $self->field('uplink')->add_error("The uplinks must be a list of ports numbers.");
        }
    }
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
