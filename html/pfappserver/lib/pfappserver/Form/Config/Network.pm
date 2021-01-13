package pfappserver::Form::Config::Network;

=head1 NAME

pfappserver::Form::Interface - Web form for a network

=head1 DESCRIPTION

Form definition to update a default network.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::util;

has 'network' => ( is => 'ro' );

has_field 'network' =>
  (
   type => 'IPAddress',
   label => 'Routed Network',
   required => 1,
   messages => { required => 'Please specify the network.' },
  );

has_field 'type' =>
  (
   type => 'Hidden',
   required => 1,
  );
has_field 'netmask' =>
  (
   type => 'IPAddress',
   label => 'Netmask',
   required => 1,
   messages => { required => 'Please specify the netmask.' },
  );
has_field 'portal_fqdn' =>
  (
   type => 'Text',
   label => 'Portal FQDN',
   messages => { required => "Please specify the FQDN of the portal." },
   tags => { after_element => \&help,
             help => 'Define the FQDN of the portal for this network. Leaving empty will use the FQDN of the PacketFence server' },
  );

has_field 'netflow_accounting_enabled' =>
  (
   type => 'Toggle',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   default => 'disabled',
   label => 'Enable Net Flow Accounting'
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

=head2 validate

Make sure the ending DHCP IP address is after the starting DHCP IP address.

Make sure the max lease time is higher than the default lease time.

=cut

sub validate {
    my $self = shift;

    if ($self->value->{dhcp_start} && $self->value->{dhcp_end}
        && ip2int($self->value->{dhcp_start}) >= ip2int($self->value->{dhcp_end})) {
        $self->field('dhcp_end')->add_error('The ending DHCP address must be greater than the starting DHCP address.');
    }
    if ($self->value->{dhcp_default_lease_time} && $self->value->{dhcp_max_lease_time}
        && $self->value->{dhcp_default_lease_time} > $self->value->{dhcp_max_lease_time}) {
        $self->field('dhcp_max_lease_time')->add_error('The maximum lease time must be greater than the default lease time.');
    }
}

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
