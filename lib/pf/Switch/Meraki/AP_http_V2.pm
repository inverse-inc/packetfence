package pf::Switch::Meraki::AP_http_V2;

=head1 NAME

pf::Switch::Meraki::AP_http_V2

=head1 SYNOPSIS

The pf::Switch::Meraki::AP_http_V2 module implements an object oriented interface to
manage the external captive portal on Meraki access points

=head1 STATUS

Developed and tested on a MR12 access point

=head1 BUGS AND LIMITATIONS

In the current BETA version, VLAN assignment is broken in Mac Authentication Bypass.
You can work around this by using the following RADIUS filter (conf/radius_filters.conf)

    [your_ssid]
    filter = ssid
    operator = is
    value = Meraki-Mac-Auth-SSID

    [open_ssid_meraki_hack:your_ssid]
    scope = returnRadiusAccessAccept
    merge_answer = no
    answer1 = Airespace-ACL-Name => VLAN$vlan

Then creating a policy named VLANXYZ where XYZ is the VLAN ID you want to assign.

Using this, you will be able to configure the VLAN ids in PacketFence and simply disable the RADIUS filter when the issue is fixed on the Meraki controller. 

=cut

use strict;
use warnings;

use base ('pf::Switch::Cisco::WLC');

=head2 getVersion - obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    $logger->info("we don't know how to determine the version through SNMP !");
    return '1';
}

=head2 returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    return 'Airespace-ACL-Name';
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
