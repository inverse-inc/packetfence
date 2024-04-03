package pf::Switch::Juniper::Junos_v13_x;

=head1 NAME

pf::SNMP::Juniper::Junos_v13_x - Object oriented module to manage Juniper's EX Series switches

=head1 STATUS

Supports
 MAC Authentication (MAC RADIUS in Juniper's terms)
 802.1X

Developed and tested on Juniper ex2200 running on JUNOS 12.6
Tested on ex4200 running on JUNOS 13.2

=head1 BUGS AND LIMITATIONS

=head2 VoIP is only supported in untagged mode

VoIP devices will use the defined voiceVlan but in untagged mode.
A computer and a phone in the same port can still be on two different VLANs since Juniper supports multiple VLANs per port.

=head2 VSTP and RADIUS dynamic VLAN assignment

Currently, these two technologies cannot be enabled at the same time on the ports and VLANs on which PacketFence is enabled.

=cut

use strict;
use warnings;

use base ('pf::Switch::Juniper::Junos_v12_x');

use pf::constants;
sub description { 'Junos v13.x' }

use pf::SwitchSupports qw(
    WiredMacAuth
    WiredDot1x
    RadiusVoip
    RoleBasedEnforcement
    FloatingDevice
    MABFloatingDevices
    ~AccessListBasedEnforcement
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
