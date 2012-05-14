package pf::SNMP::Cisco::Aironet_WDS;
=head1 NAME

pf::SNMP::Cisco::Aironet_WDS - Object oriented module to parse SNMP traps 
and manage Cisco Aironet configured in Wireless Domain Services (WDS) mode.

=head1 STATUS

This module is implements little changes on top of L<pf::SNMP::Cisco::WLC>. 
You should also consult its documentation if you experience issues.

Tested on an Aironet WDS on IOS 12.3.8JEC3

=cut
use strict;
use warnings;

use Log::Log4perl;
use Net::SNMP;

use base ('pf::SNMP::Cisco::WLC');

use pf::util qw(format_mac_as_cisco);

=item deauthenticateMac
    
De-authenticate a MAC address from wireless network (including 802.1x).
    
Diverges from L<pf::SNMP::Cisco::WLC> in the following aspects:

=over

=item No Service-Type

=item Called-Station-Id in the Cisco format (aabb.ccdd.eeff)

=back

=cut
# The Service-Type entry was causing the WDS enabled Aironet to crash (IOS 12.3.8JEC3)
sub deauthenticateMac {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    $mac = format_mac_as_cisco($mac);
    return $self->radiusDisconnect( $mac, { 'Calling-Station-Id' => $mac, } );
}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
