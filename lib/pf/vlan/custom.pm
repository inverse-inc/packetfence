package pf::vlan::custom;

=head1 NAME

pf::vlan::custom - Object oriented module for VLAN isolation oriented functions 

=head1 SYNOPSIS

The pf::vlan::custom module implements VLAN isolation oriented functions that are custom 
to a particular setup.

This module extends pf::vlan

=cut

use strict;
use warnings;
use Log::Log4perl;

use base ('pf::vlan');
use pf::config;
use pf::node qw(node_attributes node_add_simple node_exist);
use pf::util;
use pf::violation qw(violation_count_trap violation_exist_open violation_view_top);

our $VERSION = 1.03;

=head1 SUBROUTINES

=over

=cut

=item getNormalVlan

Sample getNormalVlan, see pf::vlan for getNormalVlan interface description

=cut
#sub getNormalVlan {
#    #$switch is the switch object (pf::SNMP)
#    #$ifIndex is the ifIndex of the computer connected to
#    #$mac is the mac connected
#    #$node_info is the node info hashref (result of pf::node's node_attributes on $mac)
#    #$conn_type is set to the connnection type expressed as the constant in pf::config 
#    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
#    #$ssid is the name of the SSID (Be careful: will be empty string if radius non-wireless and undef if not radius)
#    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;
#    my $logger = Log::Log4perl->get_logger();
#
#    # custom example: admin category
#    # return customVlan5 to nodes in the admin category
#    if (defined($node_info->{'category'}) && lc($node_info->{'category'}) eq "admin") {
#        return $switch->getVlanByName('customVlan5');
#    }
#
#    # custom example: simple guest user 
#    # return guestVlan for pid=guest
#    if (defined($node_info->{pid}) && $node_info->{pid} =~ /^guest$/i) {
#        return $switch->getVlanByName('guestVlan');
#    }
#
#    # custom example: enforce a node's bypass VLAN 
#    # If node record has a bypass_vlan prefer it over normalVlan 
#    # Note: It might be made the default behavior one day
#    if (defined($node_info->{'bypass_vlan'}) && $node_info->{'bypass_vlan'} ne '') {
#        return $node_info->{'bypass_vlan'};
#    }
#    
#    # custom example: VLAN by SSID
#    # return customVlan1 if SSID is 'PacketFenceRocks'
#    if (defined($ssid) && $ssid eq 'PacketFenceRocks') {
#        return $switch->getVlanByName('customVlan1');
#    }  
#        
#    return $switch->getVlanByName('normalVlan');
#}

=item shouldAutoRegister

Sample shouldAutoRegister, see pf::vlan for shouldAutoRegister interface description

=cut
# Note: if you add more examples here, remember to sync them in pf::vlan::custom
#sub shouldAutoRegister {
#    #$mac is MAC address
#    #$switch_in_autoreg_mode is set to 1 if switch is in registration mode
#    #$violation_autoreg is set to 1 if called from a violation with autoreg action
#    #$isPhone is set to 1 if device is considered an IP Phone.
#    #$conn_type is set to the connnection type expressed as the constant in pf::config
#    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
#    #$ssid is set to the wireless ssid (will be empty if radius and not wireless, undef if not radius)
#    my ($this, $mac, $switch_in_autoreg_mode, $violation_autoreg, $isPhone, $conn_type, $user_name, $ssid, $eap_type) = @_;
#    my $logger = Log::Log4perl->get_logger();
#
#    $logger->trace("asked if should auto-register device");
#    # handling switch-config first because I think it's the most important to honor
#    if (defined($switch_in_autoreg_mode) && $switch_in_autoreg_mode) {
#        $logger->trace("returned yes because it's from the switch's config");
#        return 1;
#
#    # if we have a violation action set to autoreg
#    } elsif (defined($violation_autoreg) && $violation_autoreg) {
#        $logger->trace("returned yes because it's from a violation with action autoreg");
#        return 1;
#    }
#
#    if ($isPhone) {
#        $logger->trace("returned yes because it's an ip phone");
#        return $isPhone;
#    }
#
#    # custom example: auto-register 802.1x users
#    # Since they already have validated credentials through EAP to do 802.1X
#    if (defined($conn_type) && (($conn_type & $EAP) == $EAP)) {
#        $logger->trace("returned yes because it's a 802.1X client that successfully authenticated already");
#        return 1;
#    }
#    
#    # otherwise don't autoreg
#    return 0;
#}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
