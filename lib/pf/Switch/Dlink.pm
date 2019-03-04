package pf::Switch::Dlink;

=head1 NAME

pf::Switch::Dlink - Object oriented module to access SNMP enabled Dlink switches

=head1 SYNOPSIS

The pf::Switch::Dlink module implements an object oriented interface
to access SNMP enabled Dlink switches.

=cut

use strict;
use warnings;

use base ('pf::Switch');
use Net::SNMP;

use pf::Switch::constants;
use pf::util;

sub getVersion {
    my ($self) = @_;
    my $oid_swDlinkEquipmentCapacitySwVersion
        = '1.3.6.1.4.1.171.12.11.1.9.4.1.8.1';
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace(
        "SNMP get_request for oid_swDlinkEquipmentCapacitySwVersion: $oid_swDlinkEquipmentCapacitySwVersion"
    );
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => [$oid_swDlinkEquipmentCapacitySwVersion] );
    my $runtimeSwVersion
        = ( $result->{$oid_swDlinkEquipmentCapacitySwVersion} || '' );

    return $runtimeSwVersion;
}

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;

    if ( $trapString
        =~ /BEGIN VARIABLEBINDINGS [^|]+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])\|.1.3.6.1.2.1.2.2.1.1.([0-9]+)/
        )
    {
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;

    # Trap format augmented by [12] in some OIDs to support DES 3550
    } elsif ( $trapString
        =~ /BEGIN VARIABLEBINDINGS [^|]+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.4\.1\.171\.11\.64\.[12]\.2\.15\.0\.3\|\.1\.3\.6\.1\.4\.1\.171\.11\.64\.[12]\.2\.15\.1 = Hex-STRING: ([0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2})/
        )
    {
        $trapHashRef->{'trapType'} = 'mac';
        if ( $1 == 1 ) {
            $trapHashRef->{'trapOperation'} = 'learnt';
        } elsif ( $1 == 2 ) {
            $trapHashRef->{'trapOperation'} = 'removed';
        } else {
            $trapHashRef->{'trapOperation'} = 'unknown';
        }
        $trapHashRef->{'trapMac'}     = lc($2);
        $trapHashRef->{'trapIfIndex'} = $4;

        $trapHashRef->{'trapMac'}     =~ s/ /:/g;
        $trapHashRef->{'trapIfIndex'} =~ s/ //g;
        $trapHashRef->{'trapIfIndex'} = hex( $trapHashRef->{'trapIfIndex'} );
        $trapHashRef->{'trapVlan'}
            = $self->getVlan( $trapHashRef->{'trapIfIndex'} );

    } elsif ($trapString =~ /[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.4\.1\.171\.10\.73\.30\.13\.22[|]\.1\.3\.6\.1\.4\.1\.171\.10\.73\.30\.9\.1\.1\.1 = $SNMP::MAC_ADDRESS_FORMAT/) {

        $trapHashRef->{'trapType'} = 'dot11Deauthentication';
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($1);

    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';    # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticUntaggedPorts
        = '1.3.6.1.2.1.17.7.1.4.3.1.4';                  # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticEgressPorts
        = '1.3.6.1.2.1.17.7.1.4.3.1.2';                  # Q-BRIDGE-MIB
    my $result;

    my $dot1dBasePort = $self->getDot1dBasePortForThisIfIndex($ifIndex);
    if ( !defined($dot1dBasePort) ) {
        return 0;
    }

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
        $logger->trace(
            "SNMP set_request for dot1qPvid, dot1qVlanStaticUntaggedPorts and dot1qVlanStaticEgressPorts"
        );
        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
                Net::SNMP::OCTET_STRING,
                $untaggedPortsOldVlan,
                "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
                Net::SNMP::OCTET_STRING,
                $egressPortsOldVlan,
                "$OID_dot1qVlanStaticEgressPorts.$newVlan",
                Net::SNMP::OCTET_STRING,
                $egressPortsVlan,
                "$OID_dot1qVlanStaticUntaggedPorts.$newVlan",
                Net::SNMP::OCTET_STRING,
                $untaggedPortsVlan
            ]
        );

        if ( !defined($result) ) {
            $logger->error(
                "error setting VLAN: " . $self->{_sessionWrite}->error );
        }
    }
    $logger->trace( "locking - \$switch_locker{"
            . $self->{_id}
            . "} unlocked in _setVlan" );
    return ( defined($result) );

}

sub isLearntTrapsEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    return 1;
}

=head1 AUTHOR

Treker Chen <treker.chen@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2008 Treker Chen
Copyright (C) 2005-2019 Inverse inc.

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
