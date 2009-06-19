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

sub authorizeMac {
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

        #$session->dump_log();
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
        $deauthMac =~ s/://g;
        $deauthMac
            = substr( $deauthMac, 0, 4 ) . '-'
            . substr( $deauthMac, 4, 4 ) . '-'
            . substr( $deauthMac, 8, 4 );
        $session->print("system-view");
        $session->waitfor('/\]/');
        $session->print("interface $ifDesc");
        $session->waitfor('/\]/');
        $session->print(
            "undo mac-address static $deauthMac vlan $deauthVlan");
        $session->waitfor('/\]/');
    }
    if ($authMac) {
        $authMac =~ s/://g;
        $authMac
            = substr( $authMac, 0, 4 ) . '-'
            . substr( $authMac, 4, 4 ) . '-'
            . substr( $authMac, 8, 4 );
        $session->print("system-view");
        $session->waitfor('/\]/');
        $session->print("interface $ifDesc");
        $session->waitfor('/\]/');
        $session->print("mac-address static $authMac vlan $deauthVlan");
        $session->waitfor('/\]/');
    }

    $session->close();
    return 1;

}

=head1 BUGS AND LIMITATIONS

setvlan does not work with default VLAN ID 1

=head1 AUTHOR

Mr. Chinasee BOONYATANG <chinasee.b@psu.ac.th>

Mr.Ponpitak SANTIPAPTAWON	<ponpitak.s@psu.ac.th>

  Prince of Songkla University, Thailand
  http://netserv.cc.psu.ac.th

Dominik Gehl <dgehl@inverse.ca>

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
