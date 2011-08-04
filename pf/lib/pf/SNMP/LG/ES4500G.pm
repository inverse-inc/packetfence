package pf::SNMP::LG::ES4500G;

=head1 NAME

pf::SNMP::LG::ES4500G - Object oriented module to access and configure LG-Ericsson iPECS ES-4500G series.

=head1 STATUS

=over

=Link UP / DOWN

Seems to have a firmware bug that doesn't send traps on interfaces down.
Tested using operating code version 1.2.3.2 and links UP/DOWN traps enabled.

=item Port-security

Supported using operating code version 1.2.3.2

=item MAC-Authentication / 802.1X

The hardware support it.

=back

=cut

use strict;
use warnings;
use diagnostics;

use Log::Log4perl;
use Net::SNMP;

use pf::config;
use pf::util;

use base ('pf::SNMP::LG');

# CAPABILITIES
# access technology supported
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
sub supportsSnmpTraps { return $FALSE; }


sub authorizeMAC {
    my ( $this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_dot1qStaticUnicastStatus = '1.3.6.1.2.1.17.7.1.3.1.1.4';           # Q-BRIDGE MIB
    my $OID_dot1qStaticUnicastAllowedToGoTo = '1.3.6.1.2.1.17.7.1.3.1.1.3';    # Q-BRIDGE MIB

    if ( !$this->isProductionMode() ) {
        $logger->info("Not in production mode ... we won't add or delete a static entry in the MAC address table");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    # Deauthorize MAC address from old location
    if ( $deauthMac && !$this->isFakeMac($deauthMac) ) {

        my $mac_oid = mac2oid($deauthMac);

        # LOG: Trace
        $logger->trace(
            "SNMP set_request for OID_dot1qStaticUnicastStatus: " .
            "( $OID_dot1qStaticUnicastStatus.$deauthVlan.$mac_oid.0 i $SNMP::Q_BRIDGE::INVALID )"
        );
        # SNMP request
        my $result = $this->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_dot1qStaticUnicastStatus.$deauthVlan.$mac_oid.0", Net::SNMP::INTEGER, $SNMP::Q_BRIDGE::INVALID
        ] );
        # LOG: Info
        $logger->info(
            "Deauthorizing $deauthMac ( $mac_oid ) on ifIndex $ifIndex, vlan $deauthVlan"
        );
    }

    # Authorize MAC address at new location
    if ( $authMac && !$this->isFakeMac($authMac) ) {

        my $mac_oid = mac2oid($authMac);
        my $portList = $this->createPortListWithOneItem($ifIndex);

        # LOG: Trace
        $logger->trace(
            "SNMP set_request for OID_dot1qStaticUnicastStatus: " .
            "( $OID_dot1qStaticUnicastStatus.$authVlan.$mac_oid.0 i $SNMP::Q_BRIDGE::PERMANENT )"
        );
        $logger->trace(
            "SNMP set_request for OID_dot1qStaticUnicastAllowedToGoTo: " .
            "( $OID_dot1qStaticUnicastAllowedToGoTo.$authVlan.$mac_oid.0 s $portList )"
        );
        # SNMP request
        my $result = $this->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_dot1qStaticUnicastStatus.$authVlan.$mac_oid.0", Net::SNMP::INTEGER, $SNMP::Q_BRIDGE::PERMANENT,
            "$OID_dot1qStaticUnicastAllowedToGoTo.$authVlan.$mac_oid.0", Net::SNMP::OCTET_STRING, $portList
        ] );
        #LOG: Info
        $logger->info(
            "Authorizing $authMac ( $mac_oid ) on ifIndex $ifIndex, vlan $authVlan"
        );
    }

    return 1;    
}


sub getVersion {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_swProdVersion = '1.3.6.1.4.1.572.17389.14500.1.1.5.4.0';    # iPECS_ES-4500G MIB

    if ( !$this->connectRead() ) {
        return '';
    }

    # LOG: Trace
    $logger->trace(
        "SNMP get_request for swProdVersion: $OID_swProdVersion"
    );
    # SNMP request
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$OID_swProdVersion] );

    return ( $result->{$OID_swProdVersion} || '' );
}


sub isPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_portSecPortStatus = '1.3.6.1.4.1.572.17389.14500.1.17.2.1.1.2';    # iPECS_ES-4500G MIB

    if ( !$this->connectRead() ) {
        return 0;
    }

    $logger->trace("SNMP get_request for portSecPortStatus: $OID_portSecPortStatus.$ifIndex");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [ "$OID_portSecPortStatus.$ifIndex" ] );
    return ( exists(
             $result->{"$OID_portSecPortStatus.$ifIndex"} )
        && ( $result->{"$OID_portSecPortStatus.$ifIndex"} ne 'noSuchInstance' )
        && ( $result->{"$OID_portSecPortStatus.$ifIndex"} ne 'noSuchObject' )
        && ( $result->{"$OID_portSecPortStatus.$ifIndex"} == 1 ) );
}

sub _setVlan {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';                       # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticUntaggedPorts = '1.3.6.1.2.1.17.7.1.4.3.1.4';    # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticEgressPorts = '1.3.6.1.2.1.17.7.1.4.3.1.2';      # Q-BRIDGE-MIB
    
    if ( !$this->isProductionMode() ) {
        $logger->info(
                "The switch isn't in production mode (Do nothing): " .
                "Should set ifIndex $ifIndex to VLAN $newVlan" );
        return 1;
    }

    my $result;

    my $dot1dBasePort = $this->getDot1dBasePortForThisIfIndex($ifIndex);
    if ( !defined($dot1dBasePort) ) {
        return 0;
    }

    if ( !$this->connectRead() ) {
        return 0;
    }    

    # Get current egress and untagged ports
    # LOG: Trace
    $logger->trace(
            "SNMP get_request for dot1qVlanStaticEgressPorts: " .
            "( $OID_dot1qVlanStaticEgressPorts.$oldVlan )" );
    $logger->trace(
            "SNMP get_request for dot1qVlanStaticEgressPorts: " .
            "( $OID_dot1qVlanStaticEgressPorts.$newVlan )" );
    $logger->trace(
            "SNMP get_request for dot1qVlanStaticUntaggedPorts: " .
            "( $OID_dot1qVlanStaticUntaggedPorts.$oldVlan )" );
    $logger->trace(
            "SNMP get_request for dot1qVlanStaticUntaggedPorts: " .
            "( $OID_dot1qVlanStaticUntaggedPorts.$newVlan )" );
    # SNMP request
    $this->{_sessionRead}->translate(0);    
    $result = $this->{_sessionRead}->get_request( -varbindlist => [
            "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
            "$OID_dot1qVlanStaticEgressPorts.$newVlan",
            "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
            "$OID_dot1qVlanStaticUntaggedPorts.$newVlan" ] );
    $this->{_sessionRead}->translate(1);

    # Calculate new settings
    my $egressPortsOldVlan = $this->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticEgressPorts.$oldVlan"}, $dot1dBasePort - 1, 0 );
    my $egressPortsVlan = $this->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"}, $dot1dBasePort - 1, 1 );
    my $untaggedPortsOldVlan = $this->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticUntaggedPorts.$oldVlan"}, $dot1dBasePort - 1, 0 );
    my $untaggedPortsVlan = $this->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticUntaggedPorts.$newVlan"}, $dot1dBasePort - 1, 1 );

    if ( !$this->connectWrite() ) {
        return 0;
    }

    # Setting egressPorts and untaggedPorts for new vlan
    # LOG: Trace
    $logger->trace(
            "SNMP set_request for OID_dot1qVlanStaticEgressPorts: " .
            "( $OID_dot1qVlanStaticEgressPorts.$newVlan s $egressPortsVlan )" );
    $logger->trace(
            "SNMP set_request for OID_dot1qVlanStaticUntaggedPorts: " .
            "( $OID_dot1qVlanStaticUntaggedPorts.$newVlan s $untaggedPortsVlan )" );
    # SNMP request
    $result = $this->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_dot1qVlanStaticEgressPorts.$newVlan", Net::SNMP::OCTET_STRING, $egressPortsVlan ,
            "$OID_dot1qVlanStaticUntaggedPorts.$newVlan", Net::SNMP::OCTET_STRING, $untaggedPortsVlan ] );
    # Result
    #
    # FIXME: Always returning an error but everything's allright on the switch.
    # pfsetvlan(5) ERROR: Error setting egressPorts and untaggedPorts for new vlan: Received commitFailed(14) error-status at error-index 1
    if ( !defined($result) ) {
        $logger->error( 
                "Error setting egressPorts and untaggedPorts for new vlan: " .
                $this->{_sessionWrite}->error );
    }

    # Changing port PVID for new vlan
    # LOG: Trace
    $logger->trace(
            "SNMP set_request for OID_dot1qPvid: " .
            "( $OID_dot1qPvid.$ifIndex u $newVlan )" );
    # SNMP request
    $result = $this->{_sessionWrite}->set_request( -varbindlist => [ 
            "$OID_dot1qPvid.$ifIndex", Net::SNMP::GAUGE32, $newVlan ] );
    # Result
    if ( !defined($result) ) {
        $logger->error( 
                "Error changing port PVID for new vlan: " .
                $this->{_sessionWrite}->error );
    }

    # Setting egressPorts and untaggedPorts for old vlan
    # LOG: Trace
    $logger->trace(
            "SNMP set_request for OID_dot1qVlanStaticEgressPorts: " .
            "( $OID_dot1qVlanStaticEgressPorts.$oldVlan s $egressPortsOldVlan )" );
    $logger->trace(
            "SNMP set_request for OID_dot1qVlanStaticUntaggedPorts: " .
            "( $OID_dot1qVlanStaticUntaggedPorts.$oldVlan s $untaggedPortsOldVlan )" );
    # SNMP request
    $result = $this->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_dot1qVlanStaticEgressPorts.$oldVlan", Net::SNMP::OCTET_STRING, $egressPortsOldVlan ,
            "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan", Net::SNMP::OCTET_STRING, $untaggedPortsOldVlan ] );
    # Result
    if ( !defined($result) ) {
        $logger->error(
                "Error setting egressPorts and untaggedPorts for old vlan: " .
                $this->{_sessionWrite}->error );
    }

    # if we are in port security mode we need to authorize the MAC in the new VLAN (and deauthorize the old stuff)
    # because this switch's port-security secure MAC address table is VLAN aware
    # Same behaviour/code as for Foundry switches
    if ( $this->isPortSecurityEnabled($ifIndex) ) {
        my $auth_result = $this->authorizeCurrentMacWithNewVlan($ifIndex, $newVlan, $oldVlan);
        
        if ( ( !defined($auth_result) ) || ( $auth_result != 1 ) ) {
            $logger->warn("Couldn't authorize MAC for new VLAN: no secure mac");
        }
    }

    return ( defined($result) );
}


sub getAllSecureMacAddresses {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_dot1qStaticUnicastAllowedToGoTo = '1.3.6.1.2.1.17.7.1.3.1.1.3';    # Q-BRIDGE MIB

    my $secureMacAddrHashRef = {};
    
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    # LOG: Trace
    $logger->trace(
            "SNMP get_table for dot1qStaticUnicastAllowedToGoTo: " .
            "( $OID_dot1qStaticUnicastAllowedToGoTo )" );
    # SNMP request
    $this->{_sessionRead}->translate(0);
    my $result = $this->{_sessionRead}->get_table( -baseoid => 
            "$OID_dot1qStaticUnicastAllowedToGoTo" );
    $this->{_sessionRead}->translate(1);

    while ( my $oid_including_mac = each( %{$result} ) ) {
        
        # here is an example for port ethernet 1/16 
        # result is HEX and $y is bits
        #
        # the length of result varies based on SMC model, 480 bits on 8xxx and 64 bits on 6xxx
        # in hex: result = 0x0001000000000000000000...
        # in bit port_list: $port_list = 0000 0000 0000 0001 0000 0000 ....
        # in this example then $ifIndex = 16

        my $port_list = unpack("B*", $result->{$oid_including_mac});
        
        # Iterate through all ports enabled for that entry
        while( $port_list =~ /1/g ) {
            my $ifIndex = pos($port_list);

            if ( $oid_including_mac =~
                    /^$OID_dot1qStaticUnicastAllowedToGoTo\.              # oid
                    ([0-9]+)\.                                            # vlan
                    ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.    # mac in oid format
                    [0-9]+                                                # unknown
                    /x ) {
                
                my $vlan = $1;
                my $mac = oid2mac($2);
                push @{ $secureMacAddrHashRef->{$mac}->{$ifIndex} }, $vlan;
            }
        }
    }

    return $secureMacAddrHashRef;
}


sub getDot1dBasePortForThisIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_dot1dBaseNumPort = '1.3.6.1.2.1.17.1.2.0';    # BRIDGE MIB 

   if ( !$this->connectRead() ) {
        return 0;
    }

    # Get physical port amount
    # LOG: Trace
    $logger->trace(
            "SNMP get_request for dot1dBaseNumPort: " .
            "( $OID_dot1dBaseNumPort )" );
    # SNMP request
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [
            "$OID_dot1dBaseNumPort"] );
    # Result
    if ( !( exists( $result->{"$OID_dot1dBaseNumPort"} ) ) ) {
        return 0;
    }

    my $dot1dBaseNumPort = $result->{$OID_dot1dBaseNumPort};

    my $dot1dBasePort = 0;

    if ( ( $ifIndex > 0 ) && ( $ifIndex <= $dot1dBaseNumPort ) ) {
        $dot1dBasePort = $ifIndex;
    }

    return $dot1dBasePort;
}


=head1 AUTHOR

Derek Wuelfrath <dwuelfrath@inverse.ca>

Francois Gaudreault <fgaudreault@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2006-2011 Inverse inc.

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
