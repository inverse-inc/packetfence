package pf::SNMP::H3C;

=head1 NAME

pf::SNMP::H3C - Object oriented module to access and configure enabled H3C switches.

=head1 STATUS

=over

=item Hardware

- Developped and tested on S5120-28C-PWR-EI using firmware 5.20 (2208P01)

=item Port-security problems

- Once a mac-address is authorized on a vlan on a port, the same mac-address won't triggers any violation 
on another port in the same vlan.
- VoIP devices needs to be authorized on both tagged (voice) and untagged (data) phone otherwise, intrusion traps
are generated for the phone mac-address on the data vlan due to the CDP/LLDP traffic.
- Can't find a correct MIB to successfully set a vlan on hybrid ports.

=item Port-security "solutions"

- Try using dynamic statements that will age out after a certain period of time. This period of time is way too long when the device is behind a phone
- Need to authorize the phone mac-address on both vlan (tagged and untagged/PVID) and use the mac-vlan statement to assign an untagged vlan for the device behind the phone soo we won't have to reauthorize the phone mac-address at each vlan change.
- Nothing...

=back

=cut

use strict;
use warnings;

use base ('pf::SNMP');

use Log::Log4perl;
use Net::SNMP;
use POSIX;

use pf::config;
use pf::radius::constants;
use pf::SNMP::constants;
use pf::util;


=head1 SUPPORTED TECHNOLOGIES

=over

=item supportsRadiusVoip

This switch module supports VoIP authorization over RADIUS.
Use getVoipVsa to return specific RADIUS attributes for VoIP to work.

=cut
sub supportsRadiusVoip { return $TRUE; }

=item supportsWiredDot1x

This switch module supports wired 802.1x authentication.

=cut
sub supportsWiredDot1x { return $TRUE; }

=item supportsWiredAuth

This switch module supports wired MAC authentication.

=cut
sub supportsWiredMacAuth { return $TRUE; }

=back

=cut


=head1 SUBROUTINES

=over

=item authorizeMAC

Authorize / Deauthorize a MAC address on a given port/vlan combination

=cut
sub authorizeMAC {
    my ( $this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_hh3cdot1qTpFdbSetPort = '1.3.6.1.4.1.25506.8.35.3.2.1.2';       # HP A-Series MIBs (hh3c-slat-mam)
    my $OID_hh3cdot1qTpFdbSetStatus = '1.3.6.1.4.1.25506.8.35.3.2.1.3';     # HP A-Series MIBs (hh3c-slat-mam)
    my $OID_hh3cdot1qTpFdbSetOperate = '1.3.6.1.4.1.25506.8.35.3.2.1.4';    # HP A-Series MIBs (hh3c-slat-mam)

    if ( !$this->isProductionMode() ) {
        $logger->info( "The switch isn't in production mode (Do nothing): " .
                "Should deauthorize MAC $deauthMac on ifIndex $ifIndex / vlan $deauthVlan " .
                "and authorize MAC $authMac on ifIndex $ifIndex / vlan $authVlan"
        );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

   if ( $deauthMac ) {
        my $mac_oid = mac2oid($deauthMac);

        $logger->trace( "SNMP set_request for OID_hh3cdot1qTpFdbSetPort, OID_hh3cdot1qTpFdbSetStatus, " .
                "OID_hh3cdot1qTpFdbSetOperate: ( " .
                "$OID_hh3cdot1qTpFdbSetPort.$deauthVlan.$mac_oid i $ifIndex " .
                "$OID_hh3cdot1qTpFdbSetStatus.$deauthVlan.$mac_oid i $H3C::STATIC " .
                "$OID_hh3cdot1qTpFdbSetOperate.$deauthVlan.$mac_oid i $H3C::DELETE )"
        );
        my $result = $this->{_sessionWrite}->set_request( -varbindlist => [
                "$OID_hh3cdot1qTpFdbSetPort.$deauthVlan.$mac_oid", Net::SNMP::INTEGER, $ifIndex,
                "$OID_hh3cdot1qTpFdbSetStatus.$deauthVlan.$mac_oid", Net::SNMP::INTEGER, $H3C::STATIC,
                "$OID_hh3cdot1qTpFdbSetOperate.$deauthVlan.$mac_oid", Net::SNMP::INTEGER, $H3C::DELETE
        ]);
        if ( !defined($result) ) {
            $logger->error(
                    "Error deauthorizing $deauthMac ( $mac_oid ) on ifIndex $ifIndex, vlan $deauthVlan: " .
                    $this->{_sessionWrite}->error()
            );
        } else {
            $logger->info( "Deauthorizing $deauthMac ( $mac_oid ) on ifIndex $ifIndex, vlan $deauthVlan" );
        }
    }

    if ( $authMac ) {
        # Warning: this may seem counter-intuitive but we authorize the new MAC on the current VLAN because the switch
        # won't accept it for a VLAN that doesn't exist on that port.
        # The _setVlan will force a reauthorization on the correct vlan because the switch clear the static MAC entries
        # on VLAN change.

        my $mac_oid = mac2oid($authMac);

        if ( $authVlan != $this->getVoiceVlan($ifIndex) ) {
            $authVlan = $this->getVlan($ifIndex);
        }

        $logger->trace( "SNMP set_request for OID_hh3cdot1qTpFdbSetPort, OID_hh3cdot1qTpFdbSetStatus and " .
                "OID_hh3cdot1qTpFdbSetOperate: ( " .
                "$OID_hh3cdot1qTpFdbSetPort.$authVlan.$mac_oid i $ifIndex " .
                "$OID_hh3cdot1qTpFdbSetStatus.$authVlan.$mac_oid i $H3C::STATIC " .
                "$OID_hh3cdot1qTpFdbSetOperate.$authVlan.$mac_oid i $H3C::ADD )"
        );
        my $result = $this->{_sessionWrite}->set_request( -varbindlist => [
                "$OID_hh3cdot1qTpFdbSetPort.$authVlan.$mac_oid", Net::SNMP::INTEGER, $ifIndex,
                "$OID_hh3cdot1qTpFdbSetStatus.$authVlan.$mac_oid", Net::SNMP::INTEGER, $H3C::STATIC,
                "$OID_hh3cdot1qTpFdbSetOperate.$authVlan.$mac_oid", Net::SNMP::INTEGER, $H3C::ADD
        ]);
        if ( !defined($result) ) {
            $logger->error(
                    "Error authorizing $authMac ( $mac_oid ) on ifIndex $ifIndex, vlan $authVlan: " .
                    $this->{_sessionWrite}->error );
        } else {
            $logger->info( "Authorizing $authMac ( $mac_oid ) on ifIndex $ifIndex, vlan $authVlan" );
        }
    }

    return 1;
}

=item getIfIndexForThisDot1dBasePort

Returns ifIndex for a given "normal" port number (dot1d)
Same as pf::SNMP::ThreeCom::SS4500
TODO: consider subclassing ThreeCom to avoid code duplication

=cut
sub getIfIndexForThisDot1dBasePort {
    my ( $this, $dot1dBasePort ) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    # port number into ifIndex
    my $OID_dot1dBasePortIfIndex = '.1.3.6.1.2.1.17.1.4.1.2.'.$dot1dBasePort; # from BRIDGE-MIB

    if ( !$this->connectRead() ) {
        return 0;
    }

    $logger->trace( "SNMP get_request for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => ["$OID_dot1dBasePortIfIndex"] );

    if (exists($result->{"$OID_dot1dBasePortIfIndex"})) {
        return $result->{"$OID_dot1dBasePortIfIndex"}; #return ifIndex (Integer)
    } else {
        return 0; #no ifIndex returned
    }
}

=item getPortListPositionFromDot1dBasePort

TODO: May not be necessary... problematic... see _setVlan

This switch does something fancy with PortList bit order. 
This method hides that complexity.

=cut
sub getPortListPositionFromDot1dBasePort {
    my ($this, $dot1dBasePort) = @_;

    # dot1dBasePort to PortList conversion
    # they an unfamiliar conversion technique where bit order is the opposite of what I'm used to
    # port  1 means PortList position  8 
    # port  8 means PortList position  1 
    # port  9 means PortList position 16
    # port 16 means PortList position  9
    # ...
    my $byteNum = int( ( $dot1dBasePort - 1 ) / 8 ) + 1;
    return ( 16 * $byteNum ) - 7 - $dot1dBasePort;
}

=item getVersion

Returns the software version of the slot.

=cut
sub getVersion {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    my $OID_hh3cLswSysVersion = '1.3.6.1.4.1.25506.8.35.18.1.4';    # from HH3C-LSW-DEV-ADM-MIB
    my $slotNumber = '0';

    if ( !$this->connectRead() ) {
        return;
    }

    $logger->trace( "SNMP get_request for OID_hh3cLswSysVersion: ( $OID_hh3cLswSysVersion.$slotNumber )" );
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [ "$OID_hh3cLswSysVersion.$slotNumber" ] );
    $result = $result->{"$OID_hh3cLswSysVersion.$slotNumber"};

    if ( (exists($result->{"$OID_hh3cLswSysVersion.$slotNumber"}))
             && ($result->{"$OID_hh3cLswSysVersion.$slotNumber"} ne 'noSuchInstance') ) {
        return $result->{"$OID_hh3cLswSysVersion.$slotNumber"};
    } 

    # Error handling
    if ( !defined($result) ) {
        $logger->warn("Asking for software version failed with " . $this->{_sessionRead}->error());
        return;
    }

    if ( !defined($result->{"$OID_hh3cLswSysVersion.$slotNumber"}) ) {
        $logger->error("Returned value doesn't exist!");
        return;
    }

    if ( $result->{"$OID_hh3cLswSysVersion.$slotNumber"} eq 'noSuchInstance' ) {
        $logger->warn("Asking for software version failed with noSuchInstance");
        return;
    }
}

=item getVlan

Get the vlan (PVID) associated to a switchport

=cut
sub getVlan {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';   # Q-BRIDGE MIB

    if ( !$this->connectRead() ) {
        return 0;
    }

    $logger->trace( "SNMP get_request for OID_dot1qPvid: ( $OID_dot1qPvid.$ifIndex )" );
    my $result = $this->{_sessionRead}->get_request( -varbindlist => ["$OID_dot1qPvid.$ifIndex"] );

    return $result->{"$OID_dot1qPvid.$ifIndex"};
}

=item getVoipVsa {

Returns RADIUS attributes for voip phone devices.

=cut
sub getVoipVsa {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    return (
        'Tunnel-Type'               => $RADIUS::VLAN,
        'Tunnel-Medium-Type'        => $RADIUS::ETHERNET,
        'Tunnel-Private-Group-ID'   => $this->getVlanByName('voiceVlan'),
    );
}

=item isPortSecurityEnabled

Verify if PortSecurity is enabled on a given switchport

=cut
sub isPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    return 1==1;

    my $OID_hh3cSecurePortSecurityControl = '1.3.6.1.4.1.25506.2.26.1.1.1';    # HP A-Series MIBs (hh3c-port-security)
    my $OID_hh3cSecurePortMode = '1.3.6.1.4.1.25506.2.26.1.2.1.1.1';           # HP A-Series MIBs (hh3c-port-security)
    my $OID_hh3cSecureIntrusionAction = '1.3.6.1.4.1.25506.2.26.1.2.1.1.3';    # HP A-Series MIBs (hh3c-port-security)

    if ( !$this->connectRead() ) {
        return 0;
    }

    $logger->trace( "SNMP get_request for OID_hh3cSecurePortSecurityControl, OID_hh3cSecurePortMode and " .
            "OID_hh3cSecureIntrusionAction: ( $OID_hh3cSecurePortSecurityControl " .
            "$OID_hh3cSecurePortMode.$ifIndex $OID_hh3cSecureIntrusionAction.$ifIndex )"
    );
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [
            "$OID_hh3cSecurePortSecurityControl",
            "$OID_hh3cSecurePortMode.$ifIndex",
            "$OID_hh3cSecureIntrusionAction.$ifIndex"
    ]);

    return (   exists( $result->{"$OID_hh3cSecurePortSecurityControl"} )
            && ( $result->{"$OID_hh3cSecurePortSecurityControl"} == 1 )
            && exists( $result->{"$OID_hh3cSecurePortMode.$ifIndex"} )
            && ( $result->{"$OID_hh3cSecurePortMode.$ifIndex"} == 4 )
            && exists( $result->{"$OID_hh3cSecureIntrusionAction.$ifIndex"} )
            && ( $result->{"$OID_hh3cSecureIntrusionAction.$ifIndex"} == 6 ) );
}

=item isVoIPEnabled

Supports VoIP if enabled.

=cut
sub isVoIPEnabled {
    my ($self) = @_;
    return ( $self->{_VoIPEnabled} == 1 );
}

=item NasPortToIfIndex

Same as pf::SNMP::ThreeCom::Switch_4200G
TODO: consider subclassing ThreeCom to avoid code duplication

=cut
sub NasPortToIfIndex {
    my ($this, $nas_port) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # 4096 NAS-Port slots are reserved per physical ports, 
    # I'm assuming that each client will get a +1 so I translate all of them into the same ifIndex
    # Also there's a large offset (16781312), couldn't find where it is coming from...
    my $port = ceil(($nas_port - $THREECOM::NAS_PORT_OFFSET) / $THREECOM::NAS_PORTS_PER_PORT_RANGE);
    if ($port > 0) {

        # TODO we should think about caching or pre-computation here
        my $ifIndex = $this->getIfIndexForThisDot1dBasePort($port);

        # return if defined and an int
        return $ifIndex if (defined($ifIndex) && $ifIndex =~ /^\d+$/);
    }

    # error reporting
    $logger->warn(
        "Unknown NAS-Port format. ifIndex translation could have failed. "
        . "VLAN re-assignment and switch/port accounting will be affected."
    );
    return $nas_port;
}

=item parseTrap - parse SNMP traps received from the switch

Returns an hashref with the trapType and trap informations

=cut
sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $trapHashRef;

    # link up /down
    if ( $trapString =~
            /BEGIN\ VARIABLEBINDINGS\ [^|]+[|]\.
            1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0             # SNMP notification
            \ =\ OID:\ \.
            1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])           # link UP(4) DOWN(3) trap
            \|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.([0-9]+)  # ifIndex
            /x ) {
        $trapHashRef -> {'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef -> {'trapIfIndex'} = $2;

    # secure MAC violation
    } elsif ( $trapString =~
            /BEGIN\ VARIABLEBINDINGS\ [^|]+[|]\.
            1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0                             # SNMP notification
            \ =\ OID:\ 
            \.1\.3\.6\.1\.4\.1\.25506\.2\.26\.1\.3\.2                   # secure MAC violation trap
            \|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.[0-9]+\ =\ 
            INTEGER:\ ([0-9]+)                                          # ifIndex
            \|\.1\.3\.6\.1\.4\.1\.25506\.2\.26\.1\.2\.2\.1\.1\.[0-9]+
            \.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+            # Encoded MAC address
            \.([0-9]+)\ =\                                              # VLAN
            $SNMP::MAC_ADDRESS_FORMAT                                   # MAC address
            /x ) {
        $trapHashRef -> {'trapType'} = 'secureMacAddrViolation';
        $trapHashRef -> {'trapIfIndex'} = $1;
        $trapHashRef -> {'trapVlan'} = $2;
        $trapHashRef -> {'trapMac'} = parse_mac_from_trap($3);

    # unhandled traps
    } else {
        $logger -> debug("trap currently not handled");
        $trapHashRef -> {'trapType'} = 'unknown';
    }

    return $trapHashRef;
}

=item _setVlan

TODO: Problematic... won't work

=cut
sub _setVlan {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $OID_hh3cdot1qVlanPorts  = '1.3.6.1.4.1.25506.8.35.2.1.1.1.3';   # HP A-Series MIBs (hh3c-splat-vlan)
    my $OID_dot1qPvid           = '1.3.6.1.2.1.17.7.1.4.5.1.1';         # Q-BRIDGE MIB
    my $result;

    my $portPosition = $this->getPortListPositionFromDot1dBasePort($ifIndex);

    if ( !$this->connectWrite() ) {
        return 0;
    }

    $result = $this->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_dot1qPvid.$ifIndex", Net::SNMP::GAUGE32, $newVlan
    ]);
    if( !defined($result) ) {
        $logger->error("Error modifying port PVID: " . $this->{_sessionWrite}->error);
    }



    if ( !$this->connectRead() ) {
        return 0;
    }
    $this->{_sessionRead}->translate(0);

    $logger->trace( "SNMP get_request for OID_hh3cdot1qVlanPorts: ( $OID_hh3cdot1qVlanPorts.$newVlan )" );

    $result = $this->{_sessionRead}->get_request( -varbindlist => [ "$OID_hh3cdot1qVlanPorts.$newVlan" ]);

    my $vlanPortList = $this->modifyBitmask( $result->{"$OID_hh3cdot1qVlanPorts.$newVlan"}, $portPosition, 1 );

    if ( !$this->connectWrite() ) {
        return 0;
    }

    $result = $this->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_hh3cdot1qVlanPorts.$newVlan", Net::SNMP::OCTET_STRING, $vlanPortList ]);
    if ( !defined($result) ) {
        $logger->error("Error modifying vlan port list: " . $this->{_sessionWrite}->error);
    }

    return ( defined($result) );
}


=back

=head1 AUTHOR

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

=head1 LICENCE

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
