package pfappserver::Form::Config::FloatingDevice;

=head1 NAME

pfappserver::Form::Config::FloatingDevice - Web form for a floating device

=head1 DESCRIPTION

Form definition to create or update a floating network device.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;

## Definition
has_field 'id' =>
  (
   type => 'MACAddress',
   label => 'MAC Address',
   accept => ['default'],
   required => 1,
   messages => { required => 'Please specify the MAC address of the floating device.' },
   tags => {
     option_patterns => sub {
       [
         {
           name  => "Mac Address",
           regex => "[0-9A-Fa-f][0-9A-Fa-f](:[0-9A-Fa-f][0-9A-Fa-f]){5}",
         },
       ]
     }
   }
  );
has_field 'ip' =>
  (
   type => 'IPAddress',
   label => 'IP Address',
  );
has_field 'pvid' =>
  (
   type => 'PosInteger',
   label => 'Native VLAN',
   required => 1,
   tags => { after_element => \&help,
             help => 'VLAN in which PacketFence should put the port' },
  );
has_field 'trunkPort' =>
  (
   type => 'Checkbox',
   label => 'Trunk Port',
   checkbox_value => 'yes',
   tags => { after_element => \&help,
             help => 'The port must be configured as a muti-vlan port' },
  );
has_field 'taggedVlan' =>
  (
   type => 'Text',
   label => 'Tagged VLANs',
   tags => { after_element => \&help,
             help => 'Comma separated list of VLANs. If the port is a multi-vlan, these are the VLANs that have to be tagged on the port.' },
  );

=head2 Methods

=over

=item validate

Make sure some tagged VLANs are defined when trunk port is enabled.

=cut

sub validate {
    my $self = shift;

    if ($self->value->{'trunkPort'} eq 'yes') {
        unless ($self->value->{'taggedVlan'} =~ m/^(\d+,)*\d+$/) {
            $self->field('taggedVlan')->add_error("Please specify the VLANs to be tagged on the port.");
        }
    }
}

=back

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
