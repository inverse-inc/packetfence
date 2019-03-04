package pf::Switch::Enterasys::D2;

=head1 NAME

pf::Switch::Enterasys::D2 - Object oriented module to parse SNMP traps and manage Enterasys D2 switches

=head1 STATUS

Developed and tested on an Enterasys Standalone D2. 
Firmware version: 1.00.02.0002

It should work on all D2 switches and maybe more.

=cut

use strict;
use warnings;
use Net::SNMP;
use pf::Switch::constants;

use base ('pf::Switch::Enterasys');

sub description { 'Enterasys Standalone D2' }

=head2 supportsWiredAuth

This switch module supports wired MAC authentication.

=cut

sub supportsWiredMacAuth { return $SNMP::TRUE; }

=head1 SUBROUTINES

=head2 _setVlan - set the required vlan on the switch

=cut

# this switch's behavior is so strange.. this sub involved a lot of trial and errors
# maybe the Matrix N3's telnet code would be a safer bet?
sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;
    if (!$self->connectRead()) {
        return 0;
    }
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';                      # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticUntaggedPorts = '1.3.6.1.2.1.17.7.1.4.3.1.4';   # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticEgressPorts   = '1.3.6.1.2.1.17.7.1.4.3.1.2';   # Q-BRIDGE-MIB
    my $result;

    $logger->trace("locking - trying to lock \$switch_locker{".$self->{_ip}."} in _setVlan");
    {
        my $lock = $self->getExclusiveLock();
        $logger->trace("locking - \$switch_locker{".$self->{_ip}."} locked in _setVlan");

        # get current egress and untagged ports
        $self->{_sessionRead}->translate(0);
        $logger->trace("SNMP get_request for dot1qVlanStaticUntaggedPorts and dot1qVlanStaticEgressPorts");
        $result = $self->{_sessionRead}->get_request(
            -varbindlist => [
                "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
                "$OID_dot1qVlanStaticEgressPorts.$newVlan",
                "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
                "$OID_dot1qVlanStaticUntaggedPorts.$newVlan"]
        );
        $self->{_sessionRead}->translate(1);

        # calculate new settings
        my $egressPortsOldVlan = $self->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticEgressPorts.$oldVlan"},
            $ifIndex - 1, 0);
        my $egressPortsVlan = $self->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"},
            $ifIndex - 1, 1);
        my $untaggedPortsOldVlan = $self->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticUntaggedPorts.$oldVlan"},
            $ifIndex - 1, 0);
        my $untaggedPortsVlan = $self->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticUntaggedPorts.$newVlan"},
            $ifIndex - 1, 0 ); # Warning: I set it to zero below because I reverse the bits later!

        # this switch needs untagged port list's bits to be reversed (very odd behaviour for a Q-BRIDGE-MIB)
        $untaggedPortsOldVlan = $self->reverseBitmask($untaggedPortsOldVlan);
        $untaggedPortsVlan = $self->reverseBitmask($untaggedPortsVlan);

        if (!$self->connectWrite()) {
            return 0;
        }

        # it seems that this switch doesn't care about integrity at all 
        # it will overwrite whatever you give it with what was there
        # ALTER THE SET SEQUENCE AT YOUR OWN RISK! This is the result of a painful investigation. 
        $logger->trace("SNMP set_request for egressPorts and untaggedPorts for new VLAN");
        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_dot1qVlanStaticEgressPorts.$newVlan", Net::SNMP::OCTET_STRING, $egressPortsVlan,
                "$OID_dot1qVlanStaticUntaggedPorts.$newVlan", Net::SNMP::OCTET_STRING, $untaggedPortsVlan,
                "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan", Net::SNMP::OCTET_STRING, $untaggedPortsOldVlan,
                "$OID_dot1qVlanStaticEgressPorts.$oldVlan", Net::SNMP::OCTET_STRING, $egressPortsOldVlan,
                "$OID_dot1qPvid.$ifIndex", Net::SNMP::GAUGE32, $newVlan]
        );

        if (!defined($result)) {
            $logger->error("error setting egressPorts and untaggedPorts for old and new vlan: "
                           .$self->{_sessionWrite}->error );
        }

    }
    $logger->trace("locking - \$switch_locker{".$self->{_ip}."} unlocked in _setVlan");
    return (defined($result));
}

=head1 BUGS AND LIMITATIONS

This switch's behaviour was very inconsistent during development, your mileage may vary.

=head2 Setting the VLAN of a port relies (in my opinion) on buggy switch behaviour

If setting the VLAN doesn't work on a newer firmware version try the modules SecureStack_C2, SecureStack_C3 
or Matrix_N3 and let us know how it went.

=head2 Switch accepts multiple untagged VLAN per port when configured through SNMP

This is problematic because on some occasions the untagged vlan port list can become inconsistent with the switch's 
running config. To fix that, clear all untagged VLANs of a port even if the CLI interface doesn't show it. Use: clear 
vlan egress <vlans> <ports>

=head2 SNMPv3 support 

was not tested

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
