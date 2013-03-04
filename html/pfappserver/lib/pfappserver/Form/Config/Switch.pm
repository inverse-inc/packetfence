package pfappserver::Form::Config::Switch;

=head1 NAME

pfappserver::Form::Config::Switch - Web form for a switch

=head1 DESCRIPTION

Form definition to create or update a network switch.

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';
with 'pfappserver::Form::Widget::Theme::Pf';

use File::Find qw(find);
use File::Spec::Functions;

use pf::config;
use pf::SNMP::constants;

has '+field_name_space' => ( default => 'pfappserver::Form::Field' );
has '+widget_name_space' => ( default => 'pfappserver::Form::Widget' );
has '+language_handle' => ( builder => 'get_language_handle_from_ctx' );

has 'roles' => ( is => 'ro' );

## Definition
has_field 'ip' =>
  (
   type => 'IPAddress',
   label => 'IP Address',
   required => 1,
   messages => { required => 'Please specify the IP address of the switch.' },
  );
has_field 'type' =>
  (
   type => 'Select',
   label => 'Type',
   required => 1,
  );
has_field 'mode' =>
  (
   type => 'Select',
   label => 'Mode',
   required => 1,
   element_class => ['chzn-select'],
   tags => { after_element => \&help_list,
             help => '<dt>Testing</dt><dd>pfsetvlan writes in the log files what it would normally do, but it
doesn’t do anything.</dd><dt>Registration</dt><dd>pfsetvlan automatically-register all MAC addresses seen on the switch
ports. As in testing mode, no VLAN changes are done.</dd><dt>Production</dt><dd>pfsetvlan sends the SNMP writes to change the VLAN on the switch ports.</dd>' },
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

## RADIUS
has_block 'radius' =>
  (
   tag => 'div',
   render_list => [
                   'deauthMethod',
                   'radiusSecret',
                  ],
  );
has_field 'deauthMethod' =>
  (
   type => 'Select',
   label => 'Deauthentication Method',
   required => 1,
   messages => { required => 'Please specify the deauthentication method.' },
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
                   'SNMPAuthProtocolTrap',
                   'SNMPAuthPasswordTrap',
                   'SNMPPrivProtocolTrap',
                   'SNMPPrivPasswordTrap',
                  ],
  );
has_field 'SNMPVersion' =>
  (
   type => 'Select',
   label => 'Version',
   default => '3',
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
   type => 'Text',
   label => 'Version Trap',
  );
has_field 'SNMPCommunityTrap' =>
  (
   type => 'Text',
   label => 'Community Trap',
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
   type => 'Toggle',
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

=head2 field_list

Dynamically build text fields for the roles/vlans mapping.

=cut

sub field_list {
    my $self = shift;

    my $list = [];

    foreach my $role (@{$self->roles}) {
        my $field =
          {
           type => 'Text',
           label => $role->{name},
           #required => 1,
           #messages => { required => 'Please specify the corresponding VLAN for each role.' }
          };
        push(@$list, $role->{name}.'Vlan' => $field);
        push(@$list, $role->{name}.'Role' => $field);
    }

    return $list;
}

=head2 build_block_list

Dynamically build the block list of the roles.

=cut

sub build_block_list {
    my $self = shift;

    my (@vlans, @roles);
    if ($self->form->roles) {
        @vlans = map { $_->{name}.'Vlan' } @{$self->form->roles};
        @roles = map { $_->{name}.'Role' } @{$self->form->roles};
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

            # Call the 'description' subroutine
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

    return \@modules;
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

    return @methods;
}

=head2 options_vclose

=cut

sub options_SNMPVersion {
    my $self = shift;

    my @versions = map { $_ => "v$_" } @SNMP::VERSIONS;

    return \@versions;
}

sub options_cliTransport {
    my $self = shift;

    my @transports = map { $_ => $_ } qw/Telnet SSH Serial/;

    return ('' => '', @transports);
}

sub options_wsTransport {
    my $self = shift;

    my @transports = map { $_ => $_ } qw/HTTP HTTPS/;

    return ('' => '', @transports);
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
