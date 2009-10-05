package pf::SNMP::ThreeCom::SS4500;

=head1 NAME

pf::SNMP::ThreeCom::SS4500 - Object oriented module to access SNMP enabled 3COM Huawei SuperStack 3 Switch - 4500 switches

=head1 SYNOPSIS

The pf::SNMP::ThreeCom::SS4500 module implements an object 
oriented interface to access SNMP enabled 
3COM Huawei SuperStack 3 Switch - 4500 switches.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;
use Net::Telnet;
use base ('pf::SNMP::ThreeCom');
use constant MAC_TYPE_STATIC => 6;

=head1 SUBROUTINES

=over

=cut

sub getVersion {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_hwLswSlotSoftwareVersion
        = '1.3.6.1.4.1.43.45.1.2.23.1.18.4.3.1.6.0.0'
        ;    #from A3COM-HUAWEI-DEVICE-MIB
    if ( !$this->connectRead() ) {
        return 0;
    }

    $logger->trace(
        "SNMP get_request for hwLswSlotSoftwareVersion: $OID_hwLswSlotSoftwareVersion"
    );
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_hwLswSlotSoftwareVersion"] );

    if (   ( exists( $result->{"$OID_hwLswSlotSoftwareVersion"} ) )
        && ( $result->{"$OID_hwLswSlotSoftwareVersion"} ne 'noSuchInstance' )
        )
    {
        return $result->{"$OID_hwLswSlotSoftwareVersion"};
    } else {
        return 0;
    }
}

#TODO this implementation is broken, it returns an integer instead of vlan name
sub getVlans {
    my $this                = shift;
    my $logger              = Log::Log4perl::get_logger( ref($this) );
    my $OID_hwdot1qVlanName = '1.3.6.1.4.1.43.45.1.2.23.1.2.1.1.1.1'
        ;    #from A3COM-HUAWEI-LswVLAN-MIB
    my $vlans = {};
    if ( !$this->connectRead() ) {
        return $vlans;
    }

    $logger->trace(
        "SNMP get_table for hwdot1qVlanName: $OID_hwdot1qVlanName");
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => $OID_hwdot1qVlanName );

    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            $key =~ /^$OID_hwdot1qVlanName\.(\d+)$/;
            $vlans->{$1} = $result->{$key};
        }
    }
    return $vlans;
}

sub isDefinedVlan {
    my ( $this, $vlan ) = @_;
    my $logger               = Log::Log4perl::get_logger( ref($this) );
    my $OID_hwdot1qVlanIndex = '1.3.6.1.4.1.43.45.1.2.23.1.2.1.1.1.1'
        ;    #from A3COM-HUAWEI-LswVLAN-MIB
    if ( !$this->connectRead() ) {
        return 0;
    }

    $logger->trace(
        "SNMP get_request for hwdot1qVlanIndex: $OID_hwdot1qVlanIndex.$vlan");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_hwdot1qVlanIndex.$vlan"] );

    return (   defined($result)
            && exists( $result->{"$OID_hwdot1qVlanIndex.$vlan"} )
            && (
            $result->{"$OID_hwdot1qVlanIndex.$vlan"} ne 'noSuchInstance' ) );
}

sub getDot1dBasePortForThisIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger                  = Log::Log4perl::get_logger( ref($this) );
    my $OID_hwifXXBasePortIndex = '1.3.6.1.4.1.43.45.1.2.23.1.1.1.1.10.'
        . $ifIndex;    #from A3COM-HUAWEI-LswINF-MIB

    if ( !$this->connectRead() ) {
        return 0;
    }

    $logger->trace(
        "SNMP get_request for hwifXXBasePortIndex: $OID_hwifXXBasePortIndex");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_hwifXXBasePortIndex"] );

    if (   ( exists( $result->{"$OID_hwifXXBasePortIndex"} ) )
        && ( $result->{"$OID_hwifXXBasePortIndex"} ne 'noSuchInstance' ) )
    {
        return $result->{
            "$OID_hwifXXBasePortIndex"};    #return port number (Integer)
    } else {
        return 0;                           #no port return
    }
}

=item * getIfIndexForThisDot1dBasePort - returns ifIndex for a given "normal" port number (dot1d)

=cut
sub getIfIndexForThisDot1dBasePort {
    my ( $this, $dot1dBasePort ) = @_; 
    my $logger = Log::Log4perl::get_logger(ref($this));
    # port number into ifIndex
    my $OID_dot1dBasePortIfIndex = '.1.3.6.1.2.1.17.1.4.1.2.'.$dot1dBasePort; # from BRIDGE-MIB

    if ( !$this->connectRead() ) {
        return 0;
    }

    $logger->trace(
        "SNMP get_request for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_dot1dBasePortIfIndex"] );

    if (exists($result->{"$OID_dot1dBasePortIfIndex"})) {   
        return $result->{"$OID_dot1dBasePortIfIndex"};    #return ifIndex (Integer)
    } else {
        return 0; #no ifIndex returned
    }
}

sub getVlan {
    my ( $this, $ifIndex ) = @_;
    my $logger        = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';           # Q-BRIDGE-MIB
    if ( !$this->connectRead() ) {
        return 0;
    }

    $logger->trace("SNMP get_request for dot1qPvid: $OID_dot1qPvid.$ifIndex");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_dot1qPvid.$ifIndex"] );

    return $result->{"$OID_dot1qPvid.$ifIndex"};
}

sub _setVlan {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectRead() ) {
        return 0;
    }

    my $dot1dBasePort = $this->getDot1dBasePortForThisIfIndex($ifIndex)
        ;    #physical port number
    my $OID_hwdot1qVlanName = '1.3.6.1.4.1.43.45.1.2.23.1.2.1.1.1.2'
        ;    # VLAN Name from A3COM-HUAWEI-LswVLAN-MIB
    my $OID_hwdot1qVlanPortList = '1.3.6.1.4.1.43.45.1.2.23.1.2.1.1.1.3'
        ;    #VLAN Port List from A3COM-HUAWEI-LswVLAN-MIB

    $this->{_sessionRead}->translate(0);
    $logger->trace(
        "SNMP get_request for hwdot1qVlanName: $OID_hwdot1qVlanName.$newVlan"
    );
    $logger->trace(
        "SNMP get_request for hwdot1qVlanPortsList: $OID_hwdot1qVlanPortList.$newVlan"
    );
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [
            "$OID_hwdot1qVlanName.$newVlan",
            "$OID_hwdot1qVlanPortList.$newVlan"
        ]
    );

    if (!(     ( exists( $result->{"$OID_hwdot1qVlanName.$newVlan"} ) )
            && ( exists( $result->{"$OID_hwdot1qVlanPortList.$newVlan"} ) )
        )
        )
    {
        return 0;
    }

    my $vlanName = $result->{"$OID_hwdot1qVlanName.$newVlan"
        };    # String of VLAN Name (ex. VLAN 0001, VLAN 0100 etc.)

    my $byteNum = int( ( $dot1dBasePort - 1 ) / 8 );
    $byteNum += 1;

    my $bitNum = ( 16 * $byteNum ) - 7 - $dot1dBasePort;

    my $vlanPortList
        = $this->modifyBitmask(
        $result->{"$OID_hwdot1qVlanPortList.$newVlan"},
        $bitNum - 1, 1 );

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $currentMAC = undef;
    if ($this->isPortSecurityEnabled($ifIndex)) {
        my @MACs = $this->_getMacAtIfIndex($ifIndex);
        if (scalar(@MACs) == 1) {
            $currentMAC = $MACs[0];
        }
    }

    $logger->trace("SNMP set_request for Pvid for new VLAN");
    $result = $this->{_sessionWrite}->set_request(    #SNMP SET
        -varbindlist => [
            "$OID_hwdot1qVlanName.$newVlan",
            Net::SNMP::OCTET_STRING,
            $vlanName,
            "$OID_hwdot1qVlanPortList.$newVlan",
            Net::SNMP::OCTET_STRING,
            $vlanPortList
        ]
    );

    if ( !defined($result) ) {
        $logger->error(
            "error setting Pvid: " . $this->{_sessionWrite}->error );
    } else {
        if (defined( $currentMAC )) {
            $this->authorizeMAC($ifIndex,0,$currentMAC,$newVlan,$newVlan);
        }
    }

    return ( defined($result) );
}

sub isPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # a3com-huawei-port-security.mib
    my $OID_h3cSecurePortSecurityControl
        = '1.3.6.1.4.1.43.45.1.10.2.26.1.1.1.0';
    my $OID_h3cSecurePortMode = '1.3.6.1.4.1.43.45.1.10.2.26.1.2.1.1.1';
    my $OID_h3cSecureIntrusionAction
        = '1.3.6.1.4.1.43.45.1.10.2.26.1.2.1.1.3';

    if ( !$this->connectRead() ) {
        return 0;
    }

    #determine if port-security if enabled
    $logger->trace(
        "SNMP get_request for h3cSecurePortSecurityControl, h3cSecurePortMode and h3cSecureIntrusionAction: $OID_h3cSecurePortSecurityControl, $OID_h3cSecurePortMode.$ifIndex, $OID_h3cSecureIntrusionAction.$ifIndex"
    );
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [
            "$OID_h3cSecurePortSecurityControl",
            "$OID_h3cSecurePortMode.$ifIndex",
            "$OID_h3cSecureIntrusionAction.$ifIndex"
        ]
    );
    return (   exists( $result->{"$OID_h3cSecurePortSecurityControl"} )
            && ( $result->{"$OID_h3cSecurePortSecurityControl"} == 1 )
            && exists( $result->{"$OID_h3cSecurePortMode.$ifIndex"} )
            && ( $result->{"$OID_h3cSecurePortMode.$ifIndex"} == 4 )
            && exists( $result->{"$OID_h3cSecureIntrusionAction.$ifIndex"} )
            && ( $result->{"$OID_h3cSecureIntrusionAction.$ifIndex"} == 6 ) );
}

sub authorizeMAC {
    my ( $this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger  = Log::Log4perl::get_logger( ref($this) );
    my $session = undef;

    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't modify static MAC addresses"
        );
        return 1;
    }

    eval {
        $session = new Net::Telnet( Host => $this->{_ip}, Timeout => 20 );

        #$session->input_log('/tmp/test.txt');
        $session->waitfor('/Username:/');
        $session->print( $this->{_cliUser} );
        $session->waitfor('/Password:/');
        $session->print( $this->{_cliPwd} );
        $session->waitfor('/>/');
    };
    if ($@) {
        $logger->info(
            "ERROR: Can not connect to switch $this->{'_ip'} using Telnet");
        return 0;
    }

    my $ifDesc = $this->getIfDesc($ifIndex);
    if ($deauthMac) {
        # do not deauthorize a fake MAC. It is useless for this switch.
        if (!$this->isFakeMac($deauthMac)) {
            
            $deauthMac =~ s/://g;
            $deauthMac
                = substr( $deauthMac, 0, 4 ) . '-'
                . substr( $deauthMac, 4, 4 ) . '-'
                . substr( $deauthMac, 8, 4 );
            $logger->trace("system-view");
            $session->print("system-view");
            $session->waitfor('/\]/');
            $logger->trace("interface $ifDesc");
            $session->print("interface $ifDesc");
            $session->waitfor('/\]/');
            $logger->trace("undo mac-address static $deauthMac vlan $deauthVlan");
            $session->print(
                "undo mac-address static $deauthMac vlan $deauthVlan");
            $session->waitfor('/\]/');
            $logger->trace("return");
            $session->print("return");
            $session->waitfor('/>/');
        }
    }
    if ($authMac) {
        # do not authorize a fake MAC. It is useless for this switch.
        if (!$this->isFakeMac($authMac)) {

            $authMac =~ s/://g;
            $authMac
                = substr( $authMac, 0, 4 ) . '-'
                . substr( $authMac, 4, 4 ) . '-'
                . substr( $authMac, 8, 4 );
            $logger->trace("system-view");
            $session->print("system-view");
            $session->waitfor('/\]/');
            $logger->trace("interface $ifDesc");
            $session->print("interface $ifDesc");
            $session->waitfor('/\]/');
            $logger->trace("mac-address static $authMac vlan $authVlan");
            $session->print("mac-address static $authMac vlan $authVlan");
            $session->waitfor('/\]/');
            $logger->trace("return");
            $session->print("return");
            $session->waitfor('/>/');
        }
    }

    $session->close();
    return 1;
}

=item * getAllSecureMacAddresses

Method that fetches all the secure (staticly assigned) MAC addresses for a given switch.

Returns a hash table with mac, ifIndex, vlan

=cut
# TODO this method does a lot of lookups and could be optimized further by breaking some interface contracts
sub getAllSecureMacAddresses {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    # Status of all MAC addresses
    my $OID_hwdot1qTpFdbSetStatus = '1.3.6.1.4.1.43.45.1.2.23.1.3.2.1.3'; # from A3COM-HUAWEI-LswMAM-MIB
    # Port number of all MAC addresses
    my $OID_hwdot1qTpFdbSetPort = '1.3.6.1.4.1.43.45.1.2.23.1.3.2.1.2'; # from A3COM-HUAWEI-LswMAM-MIB

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace("SNMP get_table for hwdot1qTpFdbSetStatus: $OID_hwdot1qTpFdbSetStatus");

    # read the whole mac to port association and put it in a hashmap for later
    my $result = $this->{_sessionRead}->get_table( -baseoid => "$OID_hwdot1qTpFdbSetPort" );
    my $macPort = {};
    foreach my $macOidPort ( keys %{$result} ) {
        if ($macOidPort =~ /^$OID_hwdot1qTpFdbSetPort\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/) {
            my $mac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x", $2, $3, $4, $5, $6, $7 );
            $macPort->{$mac} = $result->{$macOidPort};
        }
    }
    
    if (!%{$macPort}) {
        $logger->error("Something went wrong fetching the MAC to port association table");
        return $secureMacAddrHashRef;
    }
    
    $result = $this->{_sessionRead}->get_table( -baseoid => "$OID_hwdot1qTpFdbSetStatus" );
    foreach my $vlanMacOidStatus ( keys %{$result} ) {

        # we are only interested by static entries
        if ( $result->{$vlanMacOidStatus} ==  MAC_TYPE_STATIC) {

            if ( $vlanMacOidStatus =~ /^$OID_hwdot1qTpFdbSetStatus\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/) {   

                # TODO: consider building an oid2mac in util
                my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x", $2, $3, $4, $5, $6, $7 );
                my $oldVlan = $1;
                my $ifIndex = $this->getIfIndexForThisDot1dBasePort($macPort->{$oldMac});
                push @{ $secureMacAddrHashRef->{$oldMac}->{$ifIndex} }, $oldVlan;
            }
        }
    }

    return $secureMacAddrHashRef;
}

=item * getSecureMacAddresses

Method that fetches all the secure (staticly assigned) MAC addresses for a given ifIndex.

Returns a hash table with mac, vlan

=cut
sub getSecureMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    # OID holds Vlan and MAC. The result is dot1dPort
    my $OID_hwdot1qTpFdbSetPort = '1.3.6.1.4.1.43.45.1.2.23.1.3.2.1.2'; #from A3COM-HUAWEI-LswMAM-MIB
    # OID holds Vlan and MAC. The result is mac type
    my $OID_hwdot1qTpFdbSetStatus = '1.3.6.1.4.1.43.45.1.2.23.1.3.2.1.3'; #from A3COM-HUAWEI-LswMAM-MIB

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    my $dot1dBasePort = $this->getDot1dBasePortForThisIfIndex($ifIndex);

    # fetch all the MACs based on port
    my @macOnTargetPort;
    $logger->trace("SNMP get_table for hwdot1qTpFdbSetPort: $OID_hwdot1qTpFdbSetPort");
    my $result = $this->{_sessionRead}->get_table(-baseoid => "$OID_hwdot1qTpFdbSetPort");
    foreach my $macOidPort (keys %{$result}) {
        if ($result->{$macOidPort} == $dot1dBasePort) {
            $macOidPort =~ /^$OID_hwdot1qTpFdbSetPort\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/;
            # TODO: consider building an oid2mac in util
            my $mac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x", $2, $3, $4, $5, $6, $7 );
            $logger->trace("Interested by MAC: $mac on Port $dot1dBasePort (ifIndex: $ifIndex)");
            push(@macOnTargetPort,$mac);
        }
    }

    # Grab all vlans, MACs and status (static, dynamic, etc.)
    $logger->trace("SNMP get_table for hwdot1qTpFdbSetStatus: $OID_hwdot1qTpFdbSetStatus");
    $result = $this->{_sessionRead}->get_table(-baseoid => "$OID_hwdot1qTpFdbSetStatus");
    foreach my $vlanMacOidStatus ( keys %{$result} ) {
        # we are only interested by static entries
        if ( $result->{$vlanMacOidStatus} ==  MAC_TYPE_STATIC) {
            # grabbing Vlan and Mac
            if ( $vlanMacOidStatus =~ /^$OID_hwdot1qTpFdbSetStatus\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/) {   
                # TODO: consider building an oid2mac in util
                my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x", $2, $3, $4, $5, $6, $7 );
                my $oldVlan = $1;

                # we were interested by that port and port is in secure mode
                if (grep($_ eq $oldMac, @macOnTargetPort)) { #this means "Is $oldMac in @macOnTargetPort array?"

                    $logger->trace("On ifIndex $ifIndex, MAC: $oldMac is in secure mode on vlan $oldVlan (Port $dot1dBasePort)");
                    push @{ $secureMacAddrHashRef->{$oldMac} }, int($oldVlan);
                }
            }
        }
    }

    return $secureMacAddrHashRef;
}
=back

=head1 BUGS AND LIMITATIONS

setvlan does not work with default VLAN ID 1

=head1 AUTHOR

Mr. Chinasee BOONYATANG <chinasee.b@psu.ac.th>

Mr.Ponpitak SANTIPAPTAWON	<ponpitak.s@psu.ac.th>

  Prince of Songkla University, Thailand
  http://netserv.cc.psu.ac.th

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2006-2009 Inverse inc.

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
