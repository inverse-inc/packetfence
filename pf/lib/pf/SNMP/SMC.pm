package pf::SNMP::SMC;

=head1 NAME

pf::SNMP::SMC - Object oriented module to access SNMP enabled SMC switches

=head1 SYNOPSIS

The pf::SNMP::SMC module implements an object oriented interface
to access SNMP enabled SMC switches.

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP');
use POSIX;
use Log::Log4perl;
use Data::Dumper;

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    #link up/down
    if ( $trapString =~ /BEGIN VARIABLEBINDINGS [^|]+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])\|.1.3.6.1.2.1.2.2.1.1.([0-9]+)/) {
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;

    # Old link status trap form
    } elsif ( $trapString =~ /BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = /) {
        $trapHashRef->{'trapType'} = ( ( $1 == 2 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;

    } elsif ( $trapString =~ m/BEGIN VARIABLEBINDINGS .+ OID: \.1\.3\.6\.1\.4\.1\.202\.20\.[0-9]+\.2\.1\.0\.36\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.[0-9]+ = INTEGER: ([0-9]+)\|\.1\.3\.6\.1\.4\.1\.202\.20\.[0-9]+\.1\.14\.2\.29\.0 = Hex-STRING: ([0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2})/) {   
        $trapHashRef->{'trapType'}    = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1;
        $trapHashRef->{'trapMac'}     = lc($2);
        $trapHashRef->{'trapMac'} =~ s/ /:/g;
        $trapHashRef->{'trapVlan'} = $this->getVlan( $trapHashRef->{'trapIfIndex'} );

    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub _setVlan {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';                    # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticUntaggedPorts = '1.3.6.1.2.1.17.7.1.4.3.1.4'; # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticEgressPorts = '1.3.6.1.2.1.17.7.1.4.3.1.2';   # Q-BRIDGE-MIB
    my $result;

    # get current egress and untagged ports
    $this->{_sessionRead}->translate(0);
    $logger->trace("SNMP get_request for dot1qVlanStaticUntaggedPorts and dot1qVlanStaticEgressPorts");
    $result = $this->{_sessionRead}->get_request( -varbindlist => [
            "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
            "$OID_dot1qVlanStaticEgressPorts.$newVlan",
            "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
            "$OID_dot1qVlanStaticUntaggedPorts.$newVlan" ] );

    my $dot1dBasePort = $this->getDot1dBasePortForThisIfIndex($ifIndex);
    if ( !defined($dot1dBasePort) ) {
        return 0;
    }

    # calculate new settings
    my $egressPortsOldVlan = $this->modifyBitmask( 
	$result->{"$OID_dot1qVlanStaticEgressPorts.$oldVlan"}, $dot1dBasePort - 1, 0 );
    my $egressPortsVlan = $this->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"}, $dot1dBasePort - 1, 1 );
    my $untaggedPortsOldVlan = $this->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticUntaggedPorts.$oldVlan"}, $dot1dBasePort - 1, 0 );
    my $untaggedPortsVlan = $this->modifyBitmask(
        $result->{"$OID_dot1qVlanStaticUntaggedPorts.$newVlan"}, $dot1dBasePort - 1, 1 );
    $this->{_sessionRead}->translate(1);

    # set all values
    if ( !$this->connectWrite() ) {
        return 0;
    }

    $logger->trace("SNMP set_request for egressPorts and untaggedPorts for old and new VLAN ");

    #add port to new VLAN untagged & egress
    $result = $this->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_dot1qVlanStaticEgressPorts.$newVlan", Net::SNMP::OCTET_STRING, $egressPortsVlan,
            "$OID_dot1qVlanStaticUntaggedPorts.$newVlan", Net::SNMP::OCTET_STRING, $untaggedPortsVlan ] );

    if ( !defined($result) ) {
        $logger->error( "error setting egressPorts and untaggedPorts for old and new vlan: " 
		. $this->{_sessionWrite}->error );
    }

    #change port PVID
    $result = $this->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_dot1qPvid.$ifIndex", Net::SNMP::GAUGE32, $newVlan ] );

    if ( !defined($result) ) {
        $logger->error( "error setting egressPorts and untaggedPorts for old and new vlan: "
                . $this->{_sessionWrite}->error );
    }

    #remove port from old VLAN untagged & egress
    $result = $this->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan", Net::SNMP::OCTET_STRING, $untaggedPortsOldVlan,
            "$OID_dot1qVlanStaticEgressPorts.$oldVlan", Net::SNMP::OCTET_STRING, $egressPortsOldVlan ]);

    if ( !defined($result) ) {
        $logger->error("error setting egressPorts and untaggedPorts for old and new vlan: "
                . $this->{_sessionWrite}->error );
    }

    # if we are in port security mode we need to authorize the MAC in the new VLAN (and deauthorize the old stuff)
    # because this switch's port-security secure MAC address table is VLAN aware
    # Same behaviour/code as for Foundry switches
    if ($this->isPortSecurityEnabled($ifIndex)) {

        my $auth_result = $this->_authorizeCurrentMacWithNewVlan($ifIndex, $newVlan, $oldVlan);
        if (!defined($auth_result) || $auth_result != 1) {
            $logger->warn("couldn't authorize MAC for new VLAN: no secure mac");
        }
    }

    return ( defined($result) );
}

=item _authorizeCurrentMacWithNewVlan - authorize MAC already in secure table on a new VLAN (and deauth on old)
Same code as in Foundry.pm
=cut
sub _authorizeCurrentMacWithNewVlan {
    my ($this, $ifIndex, $newVlan, $oldVlan) = @_;

    my $secureTableHashRef = $this->getSecureMacAddresses($ifIndex);

    # hash is valid and has one MAC
    my $valid = (ref($secureTableHashRef) eq 'HASH');
    my $mac_count = scalar(keys %{$secureTableHashRef});
    if ($valid && $mac_count == 1) {

        # normal case
        # grab MAC
        my $mac = (keys %{$secureTableHashRef})[0];
        $this->authorizeMAC($ifIndex, $mac, $mac, $oldVlan, $newVlan);
        return 1;
    } elsif ($valid && $mac_count > 1) {

        # VoIP case
        # check every MAC
        foreach my $mac (keys %{$secureTableHashRef}) {

            # for every MAC check every VLAN
            foreach my $vlan (@{$secureTableHashRef->{$mac}}) {
                # is VLAN equals to old VLAN
                if ($vlan == $oldVlan) {
                    # then we need to remove that MAC from that VLAN
                    $this->authorizeMAC($ifIndex, $mac, $mac, $oldVlan, $newVlan);
                }
            }
        }
        return 1;
    }
    return;
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

sub getAllSecureMacAddresses {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1qStaticUnicastAllowedToGoTo = '1.3.6.1.2.1.17.7.1.3.1.1.3';
    #my $hpSecCfgAddrGroupIndex = 1;

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    $this->{_sessionRead}->translate(0);
    $logger->trace("SNMP get_table for dot1qStaticUnicastAllowedToGoTo: $OID_dot1qStaticUnicastAllowedToGoTo");
    my $result = $this->{_sessionRead}->get_table( -baseoid => "$OID_dot1qStaticUnicastAllowedToGoTo" );
    $this->{_sessionRead}->translate(1);

    while ( my $oid_including_mac = each( %{$result} ) ) {
        # here is an example for port ethernet 1/16 
        # result is HEX and $y is bits
        #
	# result = 0x000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
        # $y = 0000 0000 0000 0001 0000 0000 ....
        # $ifIndex = 16

        my $y = unpack("B*", $result->{$oid_including_mac});
        my $ifIndex = index($y, '1') + 1;

        if ( $oid_including_mac =~ /^$OID_dot1qStaticUnicastAllowedToGoTo\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)/ )
        {
	    my $vlan = $1;
            my $mac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x", $2, $3, $4, $5, $6, $7 );
            push @{ $secureMacAddrHashRef->{$mac}->{$ifIndex} }, $vlan;
        }
    }
    return $secureMacAddrHashRef;
}

sub getSecureMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1qStaticUnicastAllowedToGoTo = '1.3.6.1.2.1.17.7.1.3.1.1.3';

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    $this->{_sessionRead}->translate(0);
    $logger->trace("SNMP get_table for dot1qStaticUnicastAllowedToGoTo: $OID_dot1qStaticUnicastAllowedToGoTo");
    my $result = $this->{_sessionRead}->get_table( -baseoid => "$OID_dot1qStaticUnicastAllowedToGoTo" );
    $this->{_sessionRead}->translate(1);

    # we need a 60 bytes (480 bits) string
    my @bits = split //, ("0" x 480);
    $bits[$ifIndex - 1] = "1";
    my $ifIndexMask = join ('', @bits);

    while ( my $oid_including_mac = each( %{$result} ) ) {
        my $y = unpack("B*", $result->{$oid_including_mac});
        my $ifIndex = index($y, '1') + 1;

        if ( $y eq $ifIndexMask ) {
            if ( $oid_including_mac =~ /^$OID_dot1qStaticUnicastAllowedToGoTo\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)/ )
            {   
                my $vlan = $1;
                my $mac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x", $2, $3, $4, $5, $6, $7 );
		push @{$secureMacAddrHashRef->{$mac}}, $vlan;
                return $secureMacAddrHashRef;
            }
        }
    }
    return $secureMacAddrHashRef;
}

sub authorizeMAC {
    my ( $this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1qStaticUnicastStatus = '1.3.6.1.2.1.17.7.1.3.1.1.4';
    my $OID_dot1qStaticUnicastAllowedToGoTo = '1.3.6.1.2.1.17.7.1.3.1.1.3';
    
    # Add a static entry for 00-00-00-00-00-0F on ethernet 1/5 in VLAN 1
    # snmpset ... 1.3.6.1.2.1.17.7.1.3.1.1.4.1.0.0.0.0.0.255.0 i 3  
    #               dot1qStaticUnicastStatus.x.y.y.y.y.y.y.0     3: permanent
    #                                index = x.y.y.y.y.y.y       x = VLAN     y = MAC-address entry
    # snmpset ... 1.3.6.1.2.1.17.7.1.3.1.1.3.1.0.0.0.0.0.255.0 x 080000
    #        dot1qStaticUnicastAllowedToGoTo.x.y.y.y.y.y.y.0     080000 = 0000 1000 0000 0000 0000 0000  means int 1/5 
    #
    # Remove static entry 00-00-00-00-00-0F
    # snmpset ... 1.3.6.1.2.1.17.7.1.3.1.1.4.4.2.0.0.0.0.0.255.0 i 2 
    #               dot1qStaticUnicastStatus.x.y.y.y.y.y.y.0       2: deletepermanent

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't add or delete a static entry in the MAC address table");  
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    if ($deauthMac) {
        #convert MAC into decimal
        my $MACHex = $deauthMac;
        my @MACArray = split( /:/, $MACHex );
        my $MACDec = '';
        foreach my $hexPiece (@MACArray) {
            if ( $MACDec ne '' ) {
                $MACDec .= ".";
            }
            $MACDec .= hex($hexPiece);
        }

        $logger->trace("SNMP set_request for OID_dot1qStaticUnicastStatus");
        my $result = $this->{_sessionWrite}->set_request( -varbindlist => [
        	"$OID_dot1qStaticUnicastStatus.$deauthVlan.$MACDec.0", Net::SNMP::INTEGER, 2 ]);
        $logger->info("Deauthorizing $MACDec on ifIndex $ifIndex, vlan $deauthVlan");
    }

    if ($authMac) {
        #convert MAC into decimal
        my $MACHex = $authMac;
        my @MACArray = split( /:/, $MACHex );
        my $MACDec = '';
        foreach my $hexPiece (@MACArray) {
            if ( $MACDec ne '' ) {
                $MACDec .= ".";  
            }
            $MACDec .= hex($hexPiece);
        }

        my $switch_locker_ref; 
        $this->setVlan($ifIndex, $authVlan, $deauthVlan, $switch_locker_ref);
   
        $logger->trace("SNMP set_request for OID_dot1qStaticUnicastStatus");

        # we need a 60 bytes (480 bits) string
        my @bits = split //, ("0" x 480);
        $bits[$ifIndex - 1] = "1";
        my $ifIndexMask = join ('', @bits);
        my $value = pack("B*", $ifIndexMask);

        $logger->trace("SNMP set_request for OID_dot1qStaticUnicastAllowedToGoTo");
        my $result = $this->{_sessionWrite}->set_request( -varbindlist => [
		"$OID_dot1qStaticUnicastStatus.$authVlan.$MACDec.0", Net::SNMP::INTEGER, 3,
		"$OID_dot1qStaticUnicastAllowedToGoTo.$authVlan.$MACDec.0", Net::SNMP::OCTET_STRING, $value ]);
        $logger->info("Authorizing $MACDec on ifIndex $ifIndex, vlan $authVlan");
    }
    return 1;
}

=head1 AUTHOR

Mr. Chinasee BOONYATANG <chinasee.b@psu.ac.th>

  Prince of Songkla University, Thailand
  http://netserv.cc.psu.ac.th

=head1 COPYRIGHT

Copyright (C) 2006-2008 Inverse inc.

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
