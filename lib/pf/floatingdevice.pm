package pf::floatingdevice;

=head1 NAME

pf::floatingdevice - module to manage the floating network devices.

=cut

=head1 DESCRIPTION

pf::floatingdevice contains the functions necessary to manage the floating network devices.
A floating network device is a device that PacketFence does not manage as a regular device.

This code was originally added to support mobile Access Points. 
When an AP is plugged, PacketFence should:

=over

=item - let/allow all the MAC addresses that will be connected to the AP (disable mac-notifications and port-security traps)

=item - configure the port as multi-vlan (trunk) and set PVID and tagged VLANs on the port

=back

When an AP is unplugged, PacketFence should reconfigure the port like before the AP was plugged

In order to simplify things at first, we decided that 
FLOATING NETWORK DEVICES SHOULD ONLY BE PLUGGED IN PORT CONFIGURED WITH PORT_SECURITY!

Here is how it works:

=over

=item - floating network devices have to be identified using their MAC address (in conf/floating_network_device.conf)

=item - linkup/linkdown traps are not enabled on the switches, only port-security traps are.

=item - when PF receives a port-security violation trap, it checks if the device is a floating network device. if so, 
PF changes the port configuration so that:

=over 

=item - it disables port-security

=item - it sets the PVID

=item - it eventually sets the port as multi-vlan (trunk) and sets the tagged Vlans

=item - it enables linkdown traps

=back

=item - when PF receives a linkdown trap, it checks if the last device plugged is a floating network device. If so,
 PF changes the port configuration so that: 

=over

=item - it enables port-security

=item - it disables linkdown traps

=back

=back

=head1 CONFIGURATION AND ENVIRONMENT

Read F<pf.conf> and F<floating_network_device.conf> configuration files.

=cut

use strict;
use warnings;

use Log::Log4perl;
use Readonly;

use pf::config;
use pf::locationlog;

=head1 SUBROUTINES
            
=over   
            
=item new 

Get an instance of the pf::floatingdevice object

=cut
sub new {
    my $logger = Log::Log4perl::get_logger("pf::floatingdevice");
    $logger->debug("instantiating new pf::floatingdevice object");
    my ($class, %argv) = @_;
    my $this = bless {}, $class;
    return $this;
}

=item enablePortConfig 

Change port configuration to disable port-security, set PVID and set port as multi-vlan if necessary

=cut
sub enablePortConfig {

# FIXME
# we have to change the error handling in case we leave the function before we enable Linkup/down traps
# cause in this case there would be any traps enabled anymore... 


    my ($this, $mac, $switch, $switch_port, $switch_locker_ref) = @_;
    my $logger = Log::Log4perl::get_logger('pf::floatingdevice');

    # Since PF only manages floating network devices plugged in ports configured with port-security
    # all the switches with no port-security won't work here. 
    if (! $switch->supportsFloatingDevice()) {
        $logger->error("Floating devices are not supported on switch type " . ref($switch));
        return 0;
    }

    $logger->info("Disabling port-security on port $switch_port");
    if (! $switch->disablePortSecurityByIfIndex($switch_port)) {
        $logger->error("An error occured while disabling port-security on port $switch_port");
        return 0;
    }

    # if port should be trunk
    if ( $ConfigFloatingDevices{$mac}{'trunkPort'}) {
        if (! $switch->enablePortConfigAsTrunk($mac, $switch_port, $switch_locker_ref, 
            $ConfigFloatingDevices{$mac}{'taggedVlan'})) {
            return 0;
        }
    }

    # switchport trunk native vlan x 
    # OR switchport access vlan x
    my $vlan = $ConfigFloatingDevices{$mac}{'pvid'};
    $logger->info("Setting PVID as $vlan on port $switch_port.");
    if (! $switch->setVlan( $switch_port, $vlan, $switch_locker_ref, $mac )) {
        $logger->info("An error occured while setting PVID as $vlan on port $switch_port.");
        return 0;
    }

    # snmp traps enable linkup/linkdown
    $logger->info("Enabling LinkDown traps on port $switch_port");
    if (! $switch->enableIfLinkUpDownTraps($switch_port) ) {
        $logger->info("An error occured while enabling LinkDown traps on port $switch_port");
        return 0;
    }

    return 1;
}

=item disablePortConfig 

Reset port configuration to enable port-security and remove multi-vlan settings (if there are some)

=cut
sub disablePortConfig {

# FIXME
# we have to change the error handling in case we leave the function before we enable port-security traps
# cause in this case there would be any traps enabled anymore... 

    my ($this, $mac, $switch, $switch_port, $switch_locker_ref) = @_;
    my $logger = Log::Log4perl::get_logger('pf::floatingdevice');

    if (! $switch->supportsFloatingDevice()) {
        $logger->error("Floating devices are not supported on switch type " . ref($switch));
        return 0;
    }

    # no snmp traps enable linkup/linkdown
    $logger->info("Disabling LinkDown traps on port $switch_port");
    if (! $switch->disableIfLinkUpDownTraps($switch_port) ) {
        $logger->error("An error occured while disabling LinkDown traps on port $switch_port");
        return 0;
    }

    # we check the actual port configuration rather than reading $ConfigFloatingDevices{$mac}{'trunkPort'} in the flat
    # file, just in case the flat file has changed 
    if ($switch->isTrunkPort($switch_port)) {
        if (! $switch->disablePortConfigAsTrunk($switch_port, $switch_locker_ref)) {
            return 0;
        }
    }

    $logger->info("Setting port $switch_port to MAC detection Vlan.");
    if (! $switch->setMacDetectionVlan( $switch_port, $switch_locker_ref )) {
        $logger->warn("An minor issue occured while setting port $switch_port to MAC detection Vlan " .
                      "but the port should work.");
    }

    $logger->info("Enabling port-security on port $switch_port");
    if (! $switch->enablePortSecurityByIfIndex($switch_port)) {
        $logger->error("An error occured while enabling port-security on port $switch_port");
        return 0;
    }

    return 1;
}

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
