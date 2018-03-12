package pfappserver::Form::Config::Firewall_SSO;

=head1 NAME

pfappserver::Form::Config::Firewall_SSO - Web form for a floating device

=head1 DESCRIPTION

Form definition to create or update a floating network device.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help',
     'pfappserver::Role::Form::RolesAttribute';

use pf::config;
use pf::file_paths qw($lib_dir);
use pf::util;
use File::Find qw(find);
use pf::constants::firewallsso;

has_field 'id' =>
  (
   type => 'Text',
   label => 'Hostname or IP Address',
   required => 1,
   messages => { required => 'Please specify the hostname or IP of the Firewall' },
  );
has_field 'password' =>
  (
   type => 'ObfuscatedText',
   label => 'Secret or Key',
   required => 1,
   messages => { required => 'You must specify the password or the key' },
  );
has_field 'port' =>
  (
   type => 'PosInteger',
   label => 'Port of the service',
   tags => { after_element => \&help,
             help => 'If you use an alternative port, please specify' },
  );
has_field 'type' =>
  (
   type => 'Select',
   label => 'Firewall Type',
   options_method => \&options_type,
  );
has_field 'categories' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Roles',
   options_method => \&options_categories,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add a role'},
   tags => { after_element => \&help,
             help => 'Nodes with the selected roles will be affected' },
  );

has_field 'uid' =>
  (
   type => 'Select',
   label => 'UID type',
   options_method => \&uid_type,
  );

has_field 'cache_updates' =>
  (
   type => 'Checkbox',
   label => 'Cache updates',
   checkbox_value => 'enabled',
   tags => { after_element => \&help,
             help => 'Enable this to debounce updates to the Firewall.<br/>By default, PacketFence will send a SSO on every DHCP request for every device. Enabling this enables "sleep" periods during which the update is not sent if the informations stay the same.' },
  );

has_field 'cache_timeout' =>
  (
   type => 'PosInteger',
   label => 'Cache timeout',
   checkbox_value => 'enabled',
   tags => { after_element => \&help,
             help => 'Adjust the "Cache timeout" to half the expiration delay in your firewall.<br/>Your DHCP renewal interval should match this value.' },
  );
has_field 'networks' =>
  (
   type => 'Text',
   label => 'Networks on which to do SSO',
   tags => { after_element => \&help,
             help => 'Comma delimited list of networks on which the SSO applies.<br/>Format : 192.168.0.0/24' },
  );

has_field 'username_format' =>
  (
   type => 'Text',
   label => 'Username format',
   default => '$pf_username',
   tags => { after_element => \&help,
             help => 'Defines how to format the username that is sent to your firewall. $username represents the username and $realm represents the realm of your user if applicable. $pf_username represents the unstripped username as it is stored in the PacketFence database. If left empty, it will use the username as stored in PacketFence (value of $pf_username).' },
  );

has_field 'default_realm' =>
  (
   type => 'Text',
   label => 'Default realm',
   tags => { after_element => \&help,
             help => 'The default realm to be used while formatting the username when no realm can be extracted from the username.' },
  );

has_block 'definition' =>
  (
   render_list => [ qw(id type password port categories networks cache_updates cache_timeout username_format default_realm) ],
  );

=head2 Methods

=cut

=head2 uid_type

What UID we have to send to the Firewall , uid or 802.1x username

=cut

sub uid_type {
    return ( { label => "PID", value => "pid" } , { label => "802.1x Username", value => "802.1x" } );
}

=head2 options_type

Dynamically extract the descriptions from the various Firewall modules.

=cut

sub options_type {
    my $self = shift;

    return map{$_ => $_} $pf::constants::firewallsso::FIREWALL_TYPES;
}

=head2 options_categories

=cut

sub options_categories {
    my $self = shift;

    my $result = $self->form->roles;
    my @roles = map { $_->{name} => $_->{name} } @{$result} if ($result);
    return ('' => '', @roles);
}


=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
