package pfappserver::Form::Config::Switch;

=head1 NAME

pfappserver::Form::Config::Switch - Web form for a switch

=head1 DESCRIPTION

Form definition to create or update a network switch.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use File::Find qw(find);
use File::Spec::Functions;

use pf::config;
use pf::SNMP::constants;
use pf::util;
use List::MoreUtils qw(any);

has 'roles' => ( is => 'ro' );
has 'placeholders' => ( is => 'ro' );

## Definition
has_field 'id' =>
  (
   type => 'IPAddress',
   label => 'IP Address',
   accept => ['default'],
   required => 1,
   messages => { required => 'Please specify the IP address of the switch.' },
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
   element_class => ['chzn-select'],
   required_when => { 'id' => sub { $_[0] ne 'default' } },
   messages => { required => 'Please select the type of the switch.' },
  );
has_field 'mode' =>
  (
   type => 'Select',
   label => 'Mode',
   required => 1,
   tags => { after_element => \&help_list,
             help => '<dt>Testing</dt><dd>pfsetvlan writes in the log files what it would normally do, but it
doesn’t do anything.</dd><dt>Registration</dt><dd>pfsetvlan automatically-register all MAC addresses seen on the switch
ports. As in testing mode, no VLAN changes are done.</dd><dt>Production</dt><dd>pfsetvlan sends the SNMP writes to change the VLAN on the switch ports.</dd>' },
  );
has_field 'deauthMethod' =>
  (
   type => 'Select',
   label => 'Deauthentication Method',
   element_class => ['chzn-deselect'],
  );
has_field 'VoIPEnabled' =>
  (
   type => 'Toggle',
   label => 'VoIP',
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
   type => 'Text',
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
   default => 30,
   tags => {
       after_element => \&help,
       help => 'Maximum number of MAC addresses retrived from a port'
   },
  );

has_field macSearchesSleepInterval  =>
  (
   type => 'PosInteger',
   label => 'Sleep interval',
   default => 2,
   tags => {
       after_element => \&help,
       help => 'Sleep interval between queries of MAC addresses'
   },
  );

has_block definition =>
  (
   render_list => [ qw(description type mode deauthMethod VoIPEnabled uplink_dynamic uplink controllerIp) ],
  );

has_block wrix =>
  (
   render_list => [],
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
   type => 'Text',
   label => 'Auth Password Read',
  );
has_field 'SNMPPrivProtocolRead' =>
  (
   type => 'Text',
   label => 'Priv Protocol Read',
  );
has_field 'SNMPPrivPasswordRead' =>
  (
   type => 'Text',
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
   type => 'Text',
   label => 'Auth Password Write',
  );
has_field 'SNMPPrivProtocolWrite' =>
  (
   type => 'Text',
   label => 'Priv Protocol Write',
  );
has_field 'SNMPPrivPasswordWrite' =>
  (
   type => 'Text',
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
   type => 'Text',
   label => 'Auth Password Trap',
  );
has_field 'SNMPPrivProtocolTrap' =>
  (
   type => 'Text',
   label => 'Priv Protocol Trap',
  );
has_field 'SNMPPrivPasswordTrap' =>
  (
   type => 'Text',
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
   type => 'Text',
   label => 'Password',
  );

has_field 'cliEnablePwd' =>
  (
   type => 'Text',
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
   type => 'Text',
   label => 'Password',
  );

has_field controllerIp =>
  (
    type => 'IPAddress',
    label => 'Controller IP Address',
    tags => {
        after_element => \&help,
        help => 'Use instead this IP address for de-authentication requests. Normally used for WiFi only'
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
    foreach my $role (@SNMP::ROLES) {
        my $field =
          {
           type => 'Text',
           label => $role,
          };
        push(@$list, $role.'Role' => $field);

        # The VLAN mapping for default roles is mandatory for the default switch
        $field =
          {
           type => 'Text',
           label => $role,
           required_when => { 'id' => sub { $_[0] eq 'default' } },
           messages => { required => 'Please specify the corresponding VLAN for each role.' }
          };
        push(@$list, $role.'Vlan' => $field);
    }

    # Add VLAN & role mapping for custom roles
    if (defined $self->roles) {
        foreach my $role (map { $_->{name} } @{$self->roles}) {
            my $field =
              {
               type => 'Text',
               label => $role,
              };
            push(@$list, $role.'Vlan' => $field);
            push(@$list, $role.'Role' => $field);
        }
    }

    return $list;
}

=head2 update_fields

When editing the default switch, set as required the VLANs mapping of the base roles.

For other switches, add placeholders with values from default switch.

=cut

sub update_fields {
    my $self = shift;

    if ($self->{init_object} && $self->init_object->{id} eq 'default') {
        foreach my $role (@SNMP::ROLES) {
            $self->field($role.'Vlan')->required(1);
        }
    }
    elsif ($self->placeholders) {
        foreach my $field ($self->fields) {
            if ($self->placeholders->{$field->name} && length $self->placeholders->{$field->name}) {
                if ($field->type eq 'Select') {
                    if ($field->name eq 'type') {
                        $field->default($self->placeholders->{$field->name});
                    }
                    else {
                        my $val = sprintf "%s (%s)", $self->_localize('Default'), $self->placeholders->{$field->name};
                        $field->element_attr({ 'data-placeholder' => $val });
                    }
                }
                elsif ($field->name ne 'id') {
                    $field->element_attr({ placeholder => $self->placeholders->{$field->name} });
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

    my (@vlans, @roles);
    if ($self->form->roles) {
        @vlans = map { $_.'Vlan' } @SNMP::ROLES, map { $_->{name} } @{$self->form->roles};
        @roles = map { $_.'Role' } @SNMP::ROLES, map { $_->{name} } @{$self->form->roles};
    }

    return
      [
       { name => 'vlans',
         render_list => \@vlans,
       },
       { name => 'roles',
         render_list => \@roles,
       }
      ];
}

=head2 options_type

Dynamically extract the descriptions from the various SNMP modules.

=cut

sub options_type {
    my $self = shift;

    my %paths = ();
    my $wanted = sub {
        if ((my ($module, $pack, $switch) = $_ =~ m/$lib_dir\/((pf\/SNMP\/([A-Z0-9][\w\/]+))\.pm)\z/)) {
            $pack =~ s/\//::/g; $switch =~ s/\//::/g;

            # Parent folder is the vendor name
            my @p = split /::/, $switch;
            my $vendor = shift @p;

            # Only switch types with a 'description' subroutine are displayed
            require $module;
            if ($pack->can('description')) {
                $paths{$vendor} = {} unless ($paths{$vendor});
                $paths{$vendor}->{$switch} = $pack->description;
            }
        }
    };
    find({ wanted => $wanted, no_chdir => 1 }, ("$lib_dir/pf/SNMP"));

    # Sort vendors and switches for display
    my @modules;
    foreach my $vendor (sort keys %paths) {
        my @switches = map {{ value => $_, label => $paths{$vendor}->{$_} }} sort keys %{$paths{$vendor}};
        push @modules, { group => $vendor,
                         options => \@switches };
    }

    return @modules;
}

=head2 options_mode

=cut

sub options_mode {
    my $self = shift;

    my @modes = map { $_ => $self->_localize($_) } @SNMP::MODES;

    return \@modes;
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

    my @transports = map { $_ => $_ } qw/Telnet SSH Serial/;

    return ('' => '', @transports);
}

=head2 options_wsTransport

=cut

sub options_wsTransport {
    my $self = shift;

    my @transports = map { $_ => $_ } qw/HTTP HTTPS/;

    return ('' => '', @transports);
}

=head2 validate

If one of the inline triggers is $ALWAYS, ignore any other trigger.

Make sure the selected switch type supports the selected inline triggers.

Validate the MAC address format of the inline triggers.

Validate the list of uplink ports.

=cut

sub validate {
    my $self = shift;

    my @triggers;
    my $always = any { $_->{type} eq $ALWAYS } @{$self->value->{inlineTrigger}};

    if ($self->value->{type}) {
        my $type = 'pf::SNMP::'. $self->value->{type};
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
