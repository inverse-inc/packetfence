package pf::Switch::Netgear::GS110;

=head1 NAME

pf::Switch::Netgear::GS110 - Object oriented module to access and configure NETGEAR GS108Tv2/GS110TP switches.

=head1 STATUS

=over

=item Link up/down

These switches only support link up/down SNMP enforcement

=back

=head1 BUGS AND LIMITATIONS

There can be a lag of up to a minute before changes made via SNMP are reflected
in the switch's own web management interface.

We make only one set per SNMP packet because while multiple set requests are
acknowledged, changes after the first are not actually made.

VLANs 1-3 should be avoided because they have hard-coded behavior (vlan 1 is
always available via GVRP) or mean something else to NETGEAR (automatic guest
and voice VLANs).

=cut

use strict;
use warnings;

use pf::log;
use Net::SNMP;

use pf::Switch::constants;

use base ('pf::Switch::Netgear');

sub description { 'Netgear GS110' }

=head1 METHODS

=over

=item getVersion

=cut

sub getVersion {
    my ( $self ) = @_;
    my $logger = get_logger();

    my $OID_version = "1.3.6.1.2.1.47.1.1.1.1.10.1";    # Provided by snmpbulkwalk the switch

    if ( !$self->connectRead() ) {
        return;
    }

    $logger->trace("SNMP get_request for OID_version: ( $OID_version )");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [
        "$OID_version"
    ] );
    $result = $result->{"$OID_version"};

    # Error handling
    if ( !defined($result) ) {
        $logger->warn("Asking for software version failed with " . $self->{_sessionRead}->error());
        return;
    }
    if ( !defined($result->{"$OID_version"}) ) {
        $logger->error("Returned value doesn't exists!");
        return;
    }
    if ( $result->{"$OID_version"} eq 'noSuchInstance' ) {
        $logger->warn("Asking for software version failed with noSuchInstance");
        return;
    }

    return $result->{"$OID_version"};
}

=item parseTrap

=cut

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $logger = get_logger();

    my $trapHashRef;

    # link up/down traps
    if ( $trapString =~
            /BEGIN\ VARIABLEBINDINGS\ [^|]+[|]\.
            1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0               # SNMP notification
            \ =\ OID:\ \.                               
            1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])             # link UP(4) DOWN(3) trap
            \|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.([0-9]+)    # ifIndex
            /x ) {
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
    } 
    # unhandled traps
    else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }

    return $trapHashRef;
}

=item _setVlan

=cut

sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = get_logger();

    if ( !$self->isProductionMode() ) {
        $logger->info("The switch isn't in production mode (Do nothing): Should set ifIndex $ifIndex to VLAN $newVlan");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return;
    }

    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';    # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticUntaggedPorts
        = '1.3.6.1.2.1.17.7.1.4.3.1.4';                  # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticEgressPorts
        = '1.3.6.1.2.1.17.7.1.4.3.1.2';                  # Q-BRIDGE-MIB
    my $result;

    {
        my $lock = $self->getExclusiveLock();

        # get current egress and untagged ports
        $self->{_sessionRead}->translate(0);
        $logger->trace(
            "SNMP get_request for dot1qVlanStaticUntaggedPorts and dot1qVlanStaticEgressPorts"
        );
        $result = $self->{_sessionRead}->get_request(
            -varbindlist => [
                "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
                "$OID_dot1qVlanStaticEgressPorts.$newVlan",
                "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
                "$OID_dot1qVlanStaticUntaggedPorts.$newVlan"
            ]
        );

        # calculate new settings
        my $egressPortsOldVlan
            = $self->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticEgressPorts.$oldVlan"},
            $ifIndex - 1, 0 );
        my $egressPortsVlan
            = $self->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"},
            $ifIndex - 1, 1 );
        my $untaggedPortsOldVlan
            = $self->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticUntaggedPorts.$oldVlan"},
            $ifIndex - 1, 0 );
        my $untaggedPortsVlan
            = $self->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticUntaggedPorts.$newVlan"},
            $ifIndex - 1, 1 );
        $self->{_sessionRead}->translate(1);

        # set all values
        if ( !$self->connectWrite() ) {
            return 0;
        }
        $logger->info(
            "SNMP set_request for dot1qPvid, dot1qVlanStaticUntaggedPorts and dot1qVlanStaticEgressPorts: $newVlan $untaggedPortsOldVlan $egressPortsOldVlan $egressPortsVlan $untaggedPortsVlan"
        );

        # NETGEAR bug: If bind more than one variable in the same set session,
        # all will be parsed and acknowledged, but only the first OID will
        # actually change. Hence the tedious series of five sessions below.

        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_dot1qPvid.$ifIndex", Net::SNMP::GAUGE, $newVlan
        ]);
        if ( !defined($result) ) {
            $logger->error("Error setting PVID $newVlan on ifIndex $ifIndex: " . $self->{_sessionWrite}->error);
        } else {
            $logger->info("Set PVID $newVlan on ifIndex $ifIndex");
        }

        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan", Net::SNMP::OCTET_STRING, $untaggedPortsOldVlan,
        ]);
        if ( !defined($result) ) {
            $logger->error("Error setting untagged mask on old vlan $oldVlan: " . $self->{_sessionWrite}->error);
        } else {
            $logger->info("Set untagged mask on old vlan $oldVlan");
        }

        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_dot1qVlanStaticEgressPorts.$oldVlan", Net::SNMP::OCTET_STRING, $egressPortsOldVlan,,
        ]);
        if ( !defined($result) ) {
            $logger->error("Error setting tagged egress mask on old vlan $oldVlan: " . $self->{_sessionWrite}->error);
        } else {
            $logger->info("Set tagged egress mask on old vlan $oldVlan");
        }

        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_dot1qVlanStaticUntaggedPorts.$newVlan", Net::SNMP::OCTET_STRING, $untaggedPortsVlan,
        ]);
        if ( !defined($result) ) {
            $logger->error("Error setting untagged mask on new vlan $newVlan: " . $self->{_sessionWrite}->error);
        } else {
            $logger->info("Set untagged mask on new vlan $newVlan");
        }

        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_dot1qVlanStaticEgressPorts.$newVlan", Net::SNMP::OCTET_STRING, $egressPortsVlan,,
        ]);     
        if ( !defined($result) ) {
            $logger->error("Error setting tagged egress mask on new vlan $newVlan: " . $self->{_sessionWrite}->error);
        } else {
            $logger->info("Set tagged egress mask on new vlan $newVlan");
        }

    }
    $logger->trace( "locking - \$switch_locker{"
            . $self->{_ip}
            . "} unlocked in _setVlan" );
    return ( defined($result) );

}

=back

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
