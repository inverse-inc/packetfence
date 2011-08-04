package pf::SNMP::Netgear::FSM726v1;

=head1 NAME

pf::SNMP::Netgear::FSM726v1

=head1 DESCRIPTION

Object oriented module to parse SNMP traps and access SNMP enabled manageable 
Netgear FSM726 / FMS726S version 1 switches.

=head1 STATUS

=over

=item Support

Currently supports:
  - linkUp / linkDown mode
  - Port security

=item Firmware requirement

Developped and tested using firmware (Software Version) 2.6.5 (6035)

=back

=cut

use strict;
use warnings;
use diagnostics;

use POSIX;
use Log::Log4perl;
use Net::SNMP;

use pf::SNMP::constants;
use pf::util;

use base ('pf::SNMP::Netgear');

=head1 SUBROUTINES
            
=over

=cut


=item parseTrap - parse SNMP traps received from the switch

Returns an hashref with the trapType and trap informations

=cut
sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $trapHashRef;

    # link up / down
    if ( $trapString =~ /BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+)/ ) {
        $trapHashRef -> {'trapType'} = ( ( $1 == 3 ) ? "up" : "down" );
        $trapHashRef -> {'trapIfIndex'} = $2;

        # Forcing deauth on port down
        # The MAC address needs to be unauthorized from the port otherwise this MAC will stay 
        # authorized on the VLAN and no more traps will show up.
        # Needed to handle multiple ports devices (if the device will not always be plugged in the same port).
        if ( $1 == 2 ) { $this->forceDeauthOnPortChange( $2 ) };

    # secure MAC address violation
    } elsif ( $trapString =~ 
            /BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.[0-9]+ = INTEGER: ([0-9]+)\|\.1\.3\.6\.1\.4\.1\.4526\.1\.2\.16\.1\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ = Hex-STRING: ([0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2})/ ) {
        $trapHashRef -> {'trapType'} = 'secureMacAddrViolation';
        $trapHashRef -> {'trapIfIndex'} = $1;
        $trapHashRef -> {'trapMac'} = lc($2);
        $trapHashRef -> {'trapMac'} =~ s/ /:/g;
        $trapHashRef -> {'trapVlan'} = $this->getVlan( $trapHashRef->{'trapIfIndex'} );

    # unhandled traps
    } else {
        $logger->debug("trap currently no handled");
        $trapHashRef->{'trapType'} = 'unknown';
    } 

    return $trapHashRef;
}


=item getVlan - returns the port PVID

=cut

sub getVlan {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    
    my $OID_configPortDefaultVlanId = '1.3.6.1.4.1.4526.1.1.11.6.1.12';    # NETGEAR-MIB

    my $dot1dBasePort = $ifIndex;

    if ( !defined($dot1dBasePort) ) {
        return '';
    }    

    if ( !$this->connectRead() ) {
        return 0;
    }

    $logger->trace("SNMP get_request for configPortDefaultVlanId: $OID_configPortDefaultVlanId.$dot1dBasePort");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => ["$OID_configPortDefaultVlanId.$dot1dBasePort"] );

    return $result->{"$OID_configPortDefaultVlanId.$dot1dBasePort"};
}


sub getDot1dBasePortForThisIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectRead() ) {
        return 0;
    }

    #get Physical port amount
    my $OID_dot1dBaseNumPort = '1.3.6.1.2.1.17.1.2.0';    #from BRIDGE-MIB

    $logger->trace("SNMP get_request for dot1dBaseNumPort : $OID_dot1dBaseNumPort");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => ["$OID_dot1dBaseNumPort"] );

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


=item setAdminStatus - shutdown or enable port

Use the auto negotiation setting to force the port to shuts because the admin status doesn't do the trick. 

=cut

sub setAdminStatus {
    my ( $this, $ifIndex, $status ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_configPortAutoNegotiation = '1.3.6.1.4.1.4526.1.1.11.6.1.14';    # NETGEAR-MIB

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port configPortAutoNegotiation");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    $logger->trace( "SNMP set_request for configPortAutoNegotiation: $OID_configPortAutoNegotiation.$ifIndex = $status" );
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_configPortAutoNegotiation.$ifIndex", Net::SNMP::INTEGER, $status ] );

    return ( defined($result) );
}


=item _setVlan - 

Create a new port / vlan association, change the PVID and destroy the old port / vlan association

=cut

sub _setVlan {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    
    my $OID_vlanPortStatus = '1.3.6.1.4.1.4526.1.1.13.2.1.3';            # NETGEAR-MIB
    my $OID_configPortDefaultVlanId = '1.3.6.1.4.1.4526.1.1.11.6.1.12';  # NETGEAR-MIB
    my $result;

    if ( !$this->isProductionMode() ) {
        $logger->info( "Should set ifIndex $ifIndex to VLAN $newVlan but the switch is not in production -> Do nothing" );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    # Needed
    $this->forceDeauthOnPortChange( $ifIndex );

    # change port PVID
    $logger->trace("SNMP set_request for configPortDefaultVlanId: $OID_configPortDefaultVlanId");
    $result = $this->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_configPortDefaultVlanId.$ifIndex", Net::SNMP::INTEGER, $newVlan ] );

    if ( !defined($result) ) {
        $logger->error( "error setting egressPorts and untaggedPorts for old and new vlan: "
                . $this->{_sessionWrite}->error );
    }

    # destroy the old port / vlan association
    $logger->trace("SNMP set_request for vlanPortStatus: $OID_vlanPortStatus");
    $result = $this->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_vlanPortStatus.$ifIndex.$oldVlan", Net::SNMP::INTEGER, $SNMP::DESTROY ] );

    if ( !defined($result) ) {
        $logger->error("error setting egressPorts and untaggedPorts for old and new vlan: "
                . $this->{_sessionWrite}->error );
    }

    # create a new port / vlan association
    $logger->trace("SNMP set_request for vlanPortStatus: $OID_vlanPortStatus");
    $result = $this->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_vlanPortStatus.$ifIndex.$newVlan", Net::SNMP::INTEGER, $SNMP::CREATE_AND_GO ] );

    if ( !defined($result) ) {
        $logger->error( "error setting egressPorts and untaggedPorts for old and new vlan: " 
            . $this->{_sessionWrite}->error );
    }

    return ( defined($result) );
}


=item authorizeMAC - authorize / deauthorize the MAC address on a given port

=cut

sub authorizeMAC {
    my ( $this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_trustedMacStatus = '1.3.6.1.4.1.4526.1.1.15.1.1.3';    # NETGEAR-MIB

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't add or delete a static entry in the MAC address table");  
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    # Authorize a MAC address on a given port
    if ( $authMac && !$this->isFakeMac($authMac) ) {
        my $mac_oid = mac2oid($authMac);
        my $oid = "$OID_trustedMacStatus.$ifIndex.$mac_oid";

        $logger->trace("SNMP set_request for trustedMacStatus: $OID_trustedMacStatus");
        my $result = $this->{_sessionWrite}->set_request( -varbindlist => [ "$oid", Net::SNMP::INTEGER, $SNMP::CREATE_AND_GO ] );
        $logger->info("Authorizing $authMac ($mac_oid) on ifIndex $ifIndex, vlan $authVlan");
    }

    # Deauthorize a MAC address on a given port
    if ( $deauthMac && !$this->isFakeMac($deauthMac) ) {
        my $mac_oid = mac2oid($deauthMac);
        my $oid = "$OID_trustedMacStatus.$ifIndex.$mac_oid";

        $logger->trace("SNMP set_request for trustedMacStatus: $OID_trustedMacStatus");
        my $result = $this->{_sessionWrite}->set_request( -varbindlist => [ "$oid", Net::SNMP::INTEGER, $SNMP::DESTROY ] );
        $logger->info("Deauthorizing $deauthMac ($mac_oid) on ifIndex $ifIndex, vlan $deauthVlan");
    }

    return 1;
}


sub forceDeauthOnPortChange {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_trustedMacAddress = '1.3.6.1.4.1.4526.1.1.15.1.1.2';
    my $OID_trustedMacStatus = '1.3.6.1.4.1.4526.1.1.15.1.1.3';

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't add or delete a static entry in the MAC address table");  
        return 1;
    }

    if ( !$this->connectRead() ) {
        return 0;
    }

    $this->{_sessionRead}->translate(0);
    $logger->trace("SNMP get_table for trustedMacAddress: $OID_trustedMacAddress");
    my $result = $this->{_sessionRead}->get_table( -baseoid => "$OID_trustedMacAddress.$ifIndex" );
    $this->{_sessionRead}->translate(1);

    while ( my $oid_including_mac = each( %{$result} ) ) {
        if ( ( $oid_including_mac =~
                /^$OID_trustedMacAddress\.                                             # query OID
                [0-9]+\.                                                               # port.
                ([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)             # MAC in OID format
                /x )
                && ( $1 != '2' ) && ( $2 != '0' ) && ( $3 != '0' ) ) {

            my $mac_oid = $1 . '.' . $2 . '.' . $3 . '.' . $4 . '.' . $5 . '.' . $6;
            my $mac = oid2mac($mac_oid);
            
            if ( !$this->connectWrite() ) {
                return 0;
            }

            $logger->trace("SNMP set_request for OID_trustedMacStatus: $OID_trustedMacAddress");
            my $result = $this->{_sessionWrite}->set_request( -varbindlist => [ "$OID_trustedMacStatus.$ifIndex.$mac_oid", Net::SNMP::INTEGER, $SNMP::DESTROY ]);
            $logger->info("Deauthorizing $mac ($mac_oid) on ifIndex $ifIndex");
        }
    }

    return 1;
}


sub getSecureMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    
    my $OID_trustedMacAddress = '1.3.6.1.4.1.4526.1.1.15.1.1.2';
    my $secureMacAddrHashRef = {};
    
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    $this->{_sessionRead}->translate(0);
    $logger->trace("SNMP get_table for trustedMacAddress: $OID_trustedMacAddress");
    my $result = $this->{_sessionRead}->get_table( -baseoid => "$OID_trustedMacAddress.$ifIndex" );
    $this->{_sessionRead}->translate(1);

    while ( my $oid_including_mac = each( %{$result} ) ) {

            if ($oid_including_mac =~
                /^$OID_trustedMacAddress\.                                    # query OID
                [0-9]+\.                                                      # ifIndex
                ([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)    # MAC in OID format
                /x) {

                my $mac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x", $1, $2, $3, $4, $5, $6 );
                my $vlan = $this->getVlan($ifIndex);

                push @{$secureMacAddrHashRef->{$mac}}, $vlan;
            }
    }
    return $secureMacAddrHashRef;
}


sub getAllSecureMacAddresses {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    
    my $OID_trustedMacAddress = '1.3.6.1.4.1.4526.1.1.15.1.1.2';
    my $secureMacAddrHashRef = {};
    
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    $this->{_sessionRead}->translate(0);
    $logger->trace("SNMP get_table for trustedMacAddress: $OID_trustedMacAddress");
    my $result = $this->{_sessionRead}->get_table( -baseoid => "$OID_trustedMacAddress" );
    $this->{_sessionRead}->translate(1);

    while ( my $oid_including_mac = each( %{$result} ) ) {
        if ($oid_including_mac =~
                /^$OID_trustedMacAddress\.                                   # query OID
                ([0-9]+)\.                                                   # ifIndex
                ([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)   # MAC in OID format
                /x) {

            my $ifIndex = $1;
            my $mac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x", $2, $3, $4, $5, $6, $7 );
            my $vlan = $this->getVlan($ifIndex);

            push @{$secureMacAddrHashRef->{$mac}->{$ifIndex}}, $vlan;
        }        
    }

    return $secureMacAddrHashRef;
}

=back

=head1 AUTHOR

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
