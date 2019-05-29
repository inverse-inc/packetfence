package pfappserver::Form::Config::Network::Routed;

=head1 NAME

pfappserver::Form::Interface - Web form for a routed network

=head1 DESCRIPTION

Form definition to create or update a routed network.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Network';
with 'pfappserver::Base::Form::Role::Help';

use pfappserver::Model::Config::Network;
use HTTP::Status qw(:constants is_success);
use pf::config;

has_field 'network' =>
  (
   type => 'IPAddress',
   label => 'Routed Network',
   required => 1,
   messages => { required => 'Please specify the network.' },
  );
has_field 'gateway' =>
  (
   type => 'IPAddress',
   label => 'Client Gateway',
   required_when => { 'fake_mac_enabled' => sub { $_[0] ne '1' } },
   messages => { required => 'Please specify the gateway.' },
  );
has_field 'netmask' =>
  (
   type => 'IPAddress',
   label => 'Netmask',
   required => 1,
   messages => { required => 'Please specify the netmask.' },
  );
has_field 'type' =>
  (
   type => 'Select',
   label => 'Network type',
   required => 1,
   options => [
        { value => '',label => ''},
        { value => $pf::config::NET_TYPE_VLAN_ISOL, label => 'Isolation'},
        { value => $pf::config::NET_TYPE_VLAN_REG, label => 'Registration'},
        { value => $pf::config::NET_TYPE_DNS_ENFORCEMENT, label => 'DNS Enforcement'},
        { value => $pf::config::NET_TYPE_INLINE_L3, label => 'Inline Layer 3'},
   ]
  );
has_field 'next_hop' =>
  (
   type => 'IPAddress',
   label => 'Router IP',
   required => 1,
   messages => { required => 'Please specify the router IP address.' },
   tags => { after_element => \&help,
             help => 'IP address of the router to reach this network' },
  );

has_field 'fake_mac_enabled' =>
  (
   type => 'Toggle',
   checkbox_value => 1,
   unchecked_value => 0,
   default => 0,
   label => 'Fake MAC Address',
   );

has_field 'nat_enabled' => (
    type => 'Toggle',
    checkbox_value => 1,
    unchecked_value => 0,
    default => 1,
    label => 'Enable NATting',
);

has_field 'coa' => (
    type => 'Toggle',
    checkbox_value => "enabled",
    unchecked_value => "disabled",
    default => "disabled",
    label => 'Enable CoA',
);

has_field 'dhcpd' =>
  (
   type => 'Toggle',
   checkbox_value => "enabled",
   unchecked_value => "disabled",
   default => "enabled",
   label => 'DHCP server',
   );

=head2 update_fields

Set the default network value

=cut

sub update_fields {
    my $self = shift;

    $self->SUPER::update_fields();
    $self->field('network')->default($self->network) if ($self->network);
}

=head2 validate

Make sure the network address is not already defined.

Make sure the router IP has a gateway.

=cut

sub validate {
    my $self = shift;
    require pfappserver::Model::Interface;
    $self->SUPER::validate();

    my $network_model = pfappserver::Model::Config::Network->new;
    my $interface_model = pfappserver::Model::Interface->new;

    if ($self->network && $self->network ne $self->value->{network} || !$self->network) {
        # Build a list of existing networks
        my ($status, $result) = $network_model->readAllIds();
        if (is_success($status)) {
            my %networks = map { $_ => 1 } @$result;
            if (defined $networks{$self->value->{network}}) {
                $self->field('network')->add_error('This network is already defined.');
            }
        }
    }
    my $interface = $interface_model->interfaceForDestination($self->value->{next_hop});
    unless ($interface) {
        $self->field('next_hop')->add_error("The router IP has no gateway on a network interface.");
    }
    elsif ( $self->value->{type} eq $pf::config::NET_TYPE_INLINE_L3 ) {
        if ( $interface_model->getEnforcement($interface) ne $pf::config::NET_TYPE_INLINE_L2 ) {
             $self->field('next_hop')->add_error("Inline Layer 3 network can only be defined behind a Inline Layer 2 network.");
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
