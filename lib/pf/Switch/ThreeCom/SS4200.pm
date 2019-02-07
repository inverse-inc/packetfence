package pf::Switch::ThreeCom::SS4200;

=head1 NAME

pf::Switch::ThreeCom::SS4200 - Object oriented module to access SNMP enabled 3COM Huawei SuperStack 3 Switch - 4200 switches

=head1 SYNOPSIS

The pf::Switch::ThreeCom::SS4200 module implements an object 
oriented interface to access SNMP enabled 
3COM Huawei SuperStack 3 Switch - 4200 switches.

=cut

use strict;
use warnings;
use Net::SNMP;

use base ('pf::Switch::ThreeCom');

sub description { '3COM SS4200' }

sub getVersion {
    my ($self) = @_;
    my $logger = $self->logger;

    my $OID_StackUnitSWVersion
        = '1.3.6.1.4.1.43.10.27.1.1.1.12.1';    #from A3COM-0352-STACK-CONFIG
    if ( !$self->connectRead() ) {
        return 0;
    }

    $logger->trace(
        "SNMP get_request for StackUnitSWVersion: $OID_StackUnitSWVersion");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_StackUnitSWVersion"] );

    if (   ( exists( $result->{"$OID_StackUnitSWVersion"} ) )
        && ( $result->{"$OID_StackUnitSWVersion"} ne 'noSuchInstance' ) )
    {
        return $result->{"$OID_StackUnitSWVersion"};
    } else {
        return 0;
    }
}

sub getDot1dBasePortForThisIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return 0;
    }

    #get Physical port amount
    my $OID_dot1dBaseNumPort = '1.3.6.1.2.1.17.1.2.0';    #from BRIDGE-MIB

    $logger->trace(
        "SNMP get_request for dot1dBaseNumPort : $OID_dot1dBaseNumPort");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_dot1dBaseNumPort"] );

    if ( !( exists( $result->{"$OID_dot1dBaseNumPort"} ) ) ) {
        return 0;
    }

    my $dot1dBaseNumPort = $result->{$OID_dot1dBaseNumPort};

    my $OID_dot1dBasePort        = '1.3.6.1.2.1.17.1.4.1.1';  #from BRIDGE-MIB
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';  #from BRIDGE-MIB

    my $baseOid        = $OID_dot1dBasePort;
    my $nextOid        = $OID_dot1dBasePort;
    my $baseOidIfIndex = $OID_dot1dBasePortIfIndex;
    my $nextOidIfIndex = $OID_dot1dBasePortIfIndex;

    my $ifIndexVal;
    my $phyPortVal;

    my $ifIndexDot1dBasePortHash = {};  #create hash of ifIndex to bridgePort;

    $logger->trace(
        "SNMP get_next_request for dot1dBasePort, dot1dBasePortIfIndex : $OID_dot1dBasePort, $OID_dot1dBasePortIfIndex"
    );

    for ( my $i = 1; $i <= $dot1dBaseNumPort; $i++ ) {
        my $result = $self->{_sessionRead}->get_next_request(
            -varbindlist => [ "$nextOid", "$nextOidIfIndex" ] );

        my $returnOid_0 = ( keys(%$result) )[0];
        my $returnOid_1 = ( keys(%$result) )[1];

        $nextOid
            = Net::SNMP::oid_base_match( $baseOid, $returnOid_0 )
            ? $returnOid_0
            : $returnOid_1;
        $nextOidIfIndex
            = Net::SNMP::oid_base_match( $baseOidIfIndex, $returnOid_1 )
            ? $returnOid_1
            : $returnOid_0;

        $phyPortVal = $result->{$nextOid};
        $ifIndexVal = $result->{$nextOidIfIndex};

        $ifIndexDot1dBasePortHash->{$ifIndexVal} = $phyPortVal;
    }

    return
        defined( $ifIndexDot1dBasePortHash->{$ifIndex} )
        ? $ifIndexDot1dBasePortHash->{$ifIndex}
        : 0;
}

sub getVlan {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';    # Q-BRIDGE-MIB
    if ( !$self->connectRead() ) {
        return 0;
    }

    my $dot1dBasePort = $self->getDot1dBasePortForThisIfIndex($ifIndex);

    $logger->trace(
        "SNMP get_request for dot1qPvid: $OID_dot1qPvid.$dot1dBasePort");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_dot1qPvid.$dot1dBasePort"] );

    return
        exists( $result->{"$OID_dot1qPvid.$dot1dBasePort"} )
        ? $result->{"$OID_dot1qPvid.$dot1dBasePort"}
        : 0;
}

sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return 0;
    }

    my $dot1dBasePort = $self->getDot1dBasePortForThisIfIndex($ifIndex)
        ;    #physical port number
    my $portVlan = $self->getVlan($ifIndex);    #current port's VLAN PVID

    $self->{_sessionRead}->translate(0);

    #get current VLAN Untagged & Egress Port List
    my $OID_dot1qPvid = "1.3.6.1.2.1.17.7.1.4.5.1.1";    #from Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticName
        = "1.3.6.1.2.1.17.7.1.4.3.1.1";                  #from Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticEgressPorts
        = "1.3.6.1.2.1.17.7.1.4.3.1.2";                  #from Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticUntaggedPorts
        = "1.3.6.1.2.1.17.7.1.4.3.1.4";                  #from Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticRowStatus
        = "1.3.6.1.2.1.17.7.1.4.3.1.5";                  #from Q-BRIDGE-MIB

    $logger->trace(
        "SNMP get_request for dot1qVlanStaticName,EgressPorts,UntaggedPorts: $OID_dot1qVlanStaticName.$portVlan"
    );

    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => [
            "$OID_dot1qVlanStaticName.$portVlan",
            "$OID_dot1qVlanStaticEgressPorts.$portVlan",
            "$OID_dot1qVlanStaticUntaggedPorts.$portVlan"
        ]
    );

    if (!(  ( exists( $result->{"$OID_dot1qVlanStaticName.$portVlan"} ) )
            && (exists(
                    $result->{"$OID_dot1qVlanStaticEgressPorts.$portVlan"}
                )
            )
            && (exists(
                    $result->{"$OID_dot1qVlanStaticUntaggedPorts.$portVlan"}
                )
            )
        )
        )
    {
        return 0;
    }

    # manipulate VLAN port list
    my $dot1qVlanStaticName = $result->{"$OID_dot1qVlanStaticName.$portVlan"};
    my $dot1qVlanEgressPorts
        = $self->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticEgressPorts.$portVlan"},
        $dot1dBasePort - 1, 0 );
    my $dot1qVlanUntaggedPorts
        = $self->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticUntaggedPorts.$portVlan"},
        $dot1dBasePort - 1, 0 );

    # Unset port from current VLAN
    if ( !$self->connectWrite() ) {
        return 0;
    }

    $logger->trace("SNMP set_request for unset VLAN");
    $result = $self->{_sessionWrite}->set_request(    #SNMP SET
        -varbindlist => [
            "$OID_dot1qVlanStaticUntaggedPorts.$portVlan",
            Net::SNMP::OCTET_STRING,
            $dot1qVlanUntaggedPorts,                  #Untagged Portlist
            "$OID_dot1qVlanStaticEgressPorts.$portVlan",
            Net::SNMP::OCTET_STRING, $dot1qVlanEgressPorts,   #Egress Portlist
            "$OID_dot1qVlanStaticRowStatus.$portVlan", Net::SNMP::INTEGER, 1
            ]                                                 #vLAN Status
    );

    if ( !defined($result) ) {
        $logger->error(
            "error unsetting Pvid: " . $self->{_sessionWrite}->error );
    }

    # get destination VLAN port list
    $logger->trace(
        "SNMP get_request for dot1qVlanStaticName,EgressPorts,UntaggedPorts   : $OID_dot1qVlanStaticName.$newVlan"
    );

    $result = $self->{_sessionRead}->get_request(
        -varbindlist => [
            "$OID_dot1qVlanStaticName.$newVlan",
            "$OID_dot1qVlanStaticEgressPorts.$newVlan",
            "$OID_dot1qVlanStaticUntaggedPorts.$newVlan"
        ]
    );

    if (!(  ( exists( $result->{"$OID_dot1qVlanStaticName.$newVlan"} ) )
            && (exists(
                    $result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"}
                )
            )
            && (exists(
                    $result->{"$OID_dot1qVlanStaticUntaggedPorts.$newVlan"}
                )
            )
        )
        )
    {
        return 0;
    }

    # manipulate destination VLAN Port List
    $dot1qVlanStaticName = $result->{"$OID_dot1qVlanStaticName.$newVlan"};
    $dot1qVlanEgressPorts
        = $self->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"},
        $dot1dBasePort - 1, 1 );
    $dot1qVlanUntaggedPorts
        = $self->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticUntaggedPorts.$newVlan"},
        $dot1dBasePort - 1, 1 );

    # SNMP Set request for set VLAN
    $logger->trace("SNMP set_request for new VLAN");
    $result = $self->{_sessionWrite}->set_request(    #SNMP SET
        -varbindlist => [
            "$OID_dot1qVlanStaticUntaggedPorts.$newVlan",
            Net::SNMP::OCTET_STRING,
            $dot1qVlanUntaggedPorts,                  #Untagged Portlist
            "$OID_dot1qVlanStaticEgressPorts.$newVlan",
            Net::SNMP::OCTET_STRING, $dot1qVlanEgressPorts,   #Egress Portlist
            "$OID_dot1qVlanStaticRowStatus.$newVlan", Net::SNMP::INTEGER, 1
            ]                                                 #vLAN Status
    );

    if ( !defined($result) ) {
        $logger->error(
            "error setting new Vlan: " . $self->{_sessionWrite}->error );
    }

    # SNMP Set request for Update PVID
    $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_dot1qPvid.$dot1dBasePort", Net::SNMP::GAUGE,
            $newVlan ]                                        #Set Port PVID
    );
    if ( !defined($result) ) {
        $logger->error(
            "error setting Pvid: " . $self->{_sessionWrite}->error );
    }

    return ( defined($result) );
}

=head1 BUGS AND LIMITATIONS

setvlan does not work with default VLAN ID 1

=head1 AUTHOR

Mr. Chinasee BOONYATANG <chinasee.b@psu.ac.th>

  Prince of Songkla University, Thailand
  http://netserv.cc.psu.ac.th


=head1 COPYRIGHT

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
