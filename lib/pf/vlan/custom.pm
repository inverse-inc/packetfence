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
use pf::node qw(node_attributes node_exist node_modify);
use pf::Switch::constants;
use pf::util;
use pf::violation qw(violation_count_trap violation_exist_open violation_view_top);

use pf::authentication;
use pf::Authentication::constants;
use pf::Portal::ProfileFactory;

our $VERSION = 1.04;

=head1 SUBROUTINES

=over

=cut

=item getNormalVlan

Sample getNormalVlan, see pf::vlan for getNormalVlan interface description

=cut

#sub getNormalVlan {
#    #$switch is the switch object (pf::Switch)
#    #$ifIndex is the ifIndex of the computer connected to
#    #$mac is the mac connected
#    #$node_info is the node info hashref (result of pf::node's node_attributes on $mac)
#    #$conn_type is set to the connnection type expressed as the constant in pf::config
#    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
#    #$ssid is the name of the SSID (Be careful: will be empty string if radius non-wireless and undef if not radius)
#    my ($this, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;
#    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
#
#    # Bypass VLAN is configured in node record so we return accordingly
#    if ( defined($node_info->{'bypass_vlan'}) && $node_info->{'bypass_vlan'} ne '' ) {
#        $logger->info("Bypass VLAN '" . $node_info->{'bypass_vlan'} . "' is configured in node $mac record.");
#        return $node_info->{'bypass_vlan'};
#    }
#
#    $logger->debug("Trying to determine VLAN from role.");
#
#    my $role = "";
#
#    # Try MAC_AUTH, then other EAP methods and finally anything else.
#    if ( $connection_type && ($connection_type & $WIRED_MAC_AUTH) == $WIRED_MAC_AUTH ) {
#        $logger->info("Connection type is WIRED_MAC_AUTH. Getting role from node_info" );
#        $role = $node_info->{'category'};
#    } elsif ( $connection_type && ($connection_type & $WIRELESS_MAC_AUTH) == $WIRELESS_MAC_AUTH ) {
#        $logger->info("Connection type is WIRELESS_MAC_AUTH. Getting role from node_info" );
#        $role = $node_info->{'category'};
#
#
#        if (isenabled($node_info->{'autoreg'})) {
#            $logger->info("Device is comming from a secure connection and has been auto registered, we unreg it and forward it to the portal" );
#            $role = 'registration';
#            my %info = (
#                'status' => 'unreg',
#                'autoreg' => 'no',
#            );
#            node_modify($mac,%info);
#        }
#    }
#
#    # If it's an EAP connection with a username, we try to match that username with authentication sources to calculate
#    # the role based on the rules defined in the different authentication sources.
#    # FIRST HIT MATCH
#    elsif ( defined $user_name && $connection_type && ($connection_type & $EAP) == $EAP ) {
#        $logger->debug("EAP connection with a username. Trying to match rules from authentication sources.");
#        my $profile = pf::Portal::ProfileFactory->instantiate($mac);
#        my @sources = ($profile->getInternalSources);
#        my $params = {
#            username => $user_name,
#            connection_type => connection_type_to_str($connection_type),
#            SSID => $ssid,
#        };
#        $role = &pf::authentication::match([@sources], $params, $Actions::SET_ROLE);
#        #Compute autoreg if we use autoreg
#        if (isenabled($node_info->{'autoreg'})) {
#            my $value = &pf::authentication::match([@sources], $params, $Actions::SET_ACCESS_DURATION);
#            if (defined $value) {
#                $logger->trace("No unregdate found - computing it from access duration");
#                $value = access_duration($value);
#            }
#            else {
#                $value = &pf::authentication::match([@sources], $params, $Actions::SET_UNREG_DATE);
#            }
#            if (defined $value) {
#                my %info = (
#                    'unregdate' => $value,
#                    'category' => $role,
#                    'autoreg' => 'yes',
#                );
#                if (defined $role) {
#                    %info = (%info, (category => $role));
#                }
#                node_modify($mac,%info);
#            }
#        }
#    }
#    # If a user based role has been found by matching authentication sources rules, we return it
#    if ( defined($role) && $role ne '' ) {
#        $logger->info("Username was defined '$user_name' - returning user based role '$role'");
#    # Otherwise, we return the node based role matched with the node MAC address
#    } else {
#        $role = $node_info->{'category'};
#        $logger->info("Username was NOT defined or unable to match a role - returning node based role '$role'");
#    }
#    my $vlan = $switch->getVlanByName($role);
#    return ($vlan, $role);
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
