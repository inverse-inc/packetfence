package pf::Switch::ThreeCom::SS4500;

=head1 NAME

pf::Switch::ThreeCom::SS4500

=head1 SYNOPSIS

The pf::Switch::ThreeCom::SS4500 module implements an object
oriented interface to manage 3COM Huawei SuperStack 3 Switch - 4500 switches.

=head1 STATUS

=over

=item Supports

=over

=item linkUp / linkDown mode

=item port-security (maybe broken! see below)

=back

=back

Developed and tested on Switch 4200G firmware version 3.02.04s56 and 3.02.00s56

=head1 BUGS AND LIMITATIONS

=over

=item VLAN ID 1

This switch cannot assign VLAN ID 1 to a port.
It is recommended that you try to avoid using this VLAN as a VLAN managed by PacketFence.

=item Port-Security could be broken

Because of the problem documented in L<pf::Switch::ThreeCom::Switch_4200G> we think that port-security might
be broken on the SS4500.
If you try it out, please let us know the status.

=back

=head1 ROOM FOR IMPROVEMENT

=over

=item Performance: Use secure table instead of Fdb

The Fdb is too large because it will hold all exposed MAC on all the VLANs.
There's a smaller "secure" table but you can only use it if the port is in
"port-security autolearn" so the Fdb was used instead.
Maybe we can switch to use autolearn with forced 02:00... addresses to fill the learning table.

=back

=cut

use strict;
use warnings;
use Net::SNMP;

use base ('pf::Switch::ThreeCom');

use pf::Switch::constants;
use pf::util;

sub description { '3COM SS4500' }

=head1 SUBROUTINES

=over

=cut

=item Switch capabilities

=cut

sub supportsWiredMacAuth { return $SNMP::TRUE; } 
sub supportsRadiusVoip { return $SNMP::TRUE; }
sub supportsLldp { return $SNMP::TRUE; }


sub getVersion {
    my ($self) = @_;
    my $logger = $self->logger;

    my $OID_hwLswSlotSoftwareVersion = '1.3.6.1.4.1.43.45.1.2.23.1.18.4.3.1.6.0.0'; #from A3COM-HUAWEI-DEVICE-MIB
    if ( !$self->connectRead() ) {
        return 0;
    }

    $logger->trace( "SNMP get_request for hwLswSlotSoftwareVersion: $OID_hwLswSlotSoftwareVersion");
    my $result = $self->{_sessionRead} ->get_request( -varbindlist => ["$OID_hwLswSlotSoftwareVersion"] );

    if ( ( exists( $result->{"$OID_hwLswSlotSoftwareVersion"} ) )
        && ( $result->{"$OID_hwLswSlotSoftwareVersion"} ne 'noSuchInstance' )) {
        return $result->{"$OID_hwLswSlotSoftwareVersion"};
    } else {
        return 0;
    }
}

#TODO this implementation is broken, it returns an integer instead of vlan name
sub getVlans {
    my $self                = shift;
    my $logger              = $self->logger;
    my $OID_hwdot1qVlanName = '1.3.6.1.4.1.43.45.1.2.23.1.2.1.1.1.1'; #from A3COM-HUAWEI-LswVLAN-MIB
    my $vlans = {};
    if ( !$self->connectRead() ) {
        return $vlans;
    }

    $logger->trace("SNMP get_table for hwdot1qVlanName: $OID_hwdot1qVlanName");
    my $result = $self->{_sessionRead} ->get_table( -baseoid => $OID_hwdot1qVlanName );

    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            $key =~ /^$OID_hwdot1qVlanName\.(\d+)$/;
            $vlans->{$1} = $result->{$key};
        }
    }
    return $vlans;
}

sub isDefinedVlan {
    my ( $self, $vlan ) = @_;
    my $logger               = $self->logger;
    my $OID_hwdot1qVlanIndex = '1.3.6.1.4.1.43.45.1.2.23.1.2.1.1.1.1'; #from A3COM-HUAWEI-LswVLAN-MIB
    if ( !$self->connectRead() ) {
        return 0;
    }

    $logger->trace( "SNMP get_request for hwdot1qVlanIndex: $OID_hwdot1qVlanIndex.$vlan");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => ["$OID_hwdot1qVlanIndex.$vlan"] );

    return (defined($result)
        && exists( $result->{"$OID_hwdot1qVlanIndex.$vlan"} )
        && ( $result->{"$OID_hwdot1qVlanIndex.$vlan"} ne 'noSuchInstance' )
    );
}

sub getDot1dBasePortForThisIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger                  = $self->logger;
    my $OID_hwifXXBasePortIndex = '1.3.6.1.4.1.43.45.1.2.23.1.1.1.1.10.' . $ifIndex; #from A3COM-HUAWEI-LswINF-MIB

    if ( !$self->connectRead() ) {
        return 0;
    }

    $logger->trace( "SNMP get_request for hwifXXBasePortIndex: $OID_hwifXXBasePortIndex");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => ["$OID_hwifXXBasePortIndex"] );

    if (( exists( $result->{"$OID_hwifXXBasePortIndex"} ) )
        && ( $result->{"$OID_hwifXXBasePortIndex"} ne 'noSuchInstance' ) ) {

        return $result->{"$OID_hwifXXBasePortIndex"}; #return port number (Integer)
    } else {
        return 0; #no port return
    }
}

=item getIfIndexForThisDot1dBasePort

returns ifIndex for a given "normal" port number (dot1d)

=cut

sub getIfIndexForThisDot1dBasePort {
    my ( $self, $dot1dBasePort ) = @_;
    my $logger = $self->logger;
    # port number into ifIndex
    my $OID_dot1dBasePortIfIndex = '.1.3.6.1.2.1.17.1.4.1.2.'.$dot1dBasePort; # from BRIDGE-MIB

    if ( !$self->connectRead() ) {
        return 0;
    }

    $logger->trace( "SNMP get_request for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => ["$OID_dot1dBasePortIfIndex"] );

    if (exists($result->{"$OID_dot1dBasePortIfIndex"})) {
        return $result->{"$OID_dot1dBasePortIfIndex"}; #return ifIndex (Integer)
    } else {
        return 0; #no ifIndex returned
    }
}

sub getVlan {
    my ( $self, $ifIndex ) = @_;
    my $logger        = $self->logger;
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';           # Q-BRIDGE-MIB
    if ( !$self->connectRead() ) {
        return 0;
    }

    $logger->trace("SNMP get_request for dot1qPvid: $OID_dot1qPvid.$ifIndex");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => ["$OID_dot1qPvid.$ifIndex"] );

    return $result->{"$OID_dot1qPvid.$ifIndex"};
}

=item _setVlan

Note: setting a VLAN empties the static MAC table for the port.
Because of this, in port-security mode, the MAC authorization process will take two intrusion traps
before adding the correct MAC to the correct VLAN.

=cut

sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return 0;
    }

    my $dot1dBasePort = $self->getDot1dBasePortForThisIfIndex($ifIndex); # physical port number
    my $OID_hwdot1qVlanPortList = '1.3.6.1.4.1.43.45.1.2.23.1.2.1.1.1.3'; #VLAN Port List from A3COM-HUAWEI-LswVLAN-MIB

    $logger->trace( "SNMP get_request for hwdot1qVlanPortsList: $OID_hwdot1qVlanPortList.$newVlan");

    $self->{_sessionRead}->translate(0);
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [ "$OID_hwdot1qVlanPortList.$newVlan" ]);
    $self->{_sessionRead}->translate(1);

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $portListPosition = $self->getPortListPositionFromDot1dBasePort($dot1dBasePort);
    my $vlanPortList = $self->modifyBitmask( $result->{"$OID_hwdot1qVlanPortList.$newVlan"}, $portListPosition - 1, 1 );
    $logger->trace("SNMP set_request on hwdot1qVlanName and hwdot1qVlanPortList to assign new VLAN");
    $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_hwdot1qVlanPortList.$newVlan", Net::SNMP::OCTET_STRING, $vlanPortList ]
    );

    if ( !defined($result) ) {
        $logger->error("error setting PVID to new vlan: " . $self->{_sessionWrite}->error );
    }

    return ( defined($result) );
}

sub isPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    # a3com-huawei-port-security.mib
    my $OID_h3cSecurePortSecurityControl = '1.3.6.1.4.1.43.45.1.10.2.26.1.1.1.0';
    my $OID_h3cSecurePortMode = '1.3.6.1.4.1.43.45.1.10.2.26.1.2.1.1.1';
    my $OID_h3cSecureIntrusionAction = '1.3.6.1.4.1.43.45.1.10.2.26.1.2.1.1.3';

    if ( !$self->connectRead() ) {
        return 0;
    }

    #determine if port-security if enabled
    $logger->trace(
        "SNMP get_request for h3cSecurePortSecurityControl, h3cSecurePortMode and h3cSecureIntrusionAction: "
        . "$OID_h3cSecurePortSecurityControl, $OID_h3cSecurePortMode.$ifIndex, $OID_h3cSecureIntrusionAction.$ifIndex"
    );

    my $result = $self->{_sessionRead}->get_request(
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

=item getPortListPositionFromDot1dBasePort

This switch does something fancy with PortList bit order.
This method hides that complexity.

=cut

sub getPortListPositionFromDot1dBasePort {
    my ($self, $dot1dBasePort) = @_;

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

=item authorizeMAC

Authorize and deauthorize MAC addresses. A core component of port-security handling.

=cut

sub authorizeMAC {
    my ( $self, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger  = $self->logger;

    return $self->_authorizeMacWithSnmp($ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan);
}

=item _authorizeMacWithSnmp

Authorize / De-authorize MAC Addresses using SNMP.
Uses the Fdb and static entries instead of port-security table because port-security MAC entries are only valid for
ports in autolearn mode.

=cut

sub _authorizeMacWithSnmp {
    my ( $self, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger  = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info( "not in production mode ... we won't modify static MAC addresses");
        return 1;
    }

    # from A3COM-HUAWEI-LswMAM-MIB
    my $oid_hwdot1qTpFdbSetPort = '1.3.6.1.4.1.43.45.1.2.23.1.3.2.1.2';
    my $oid_hwdot1qTpFdbSetStatus = '1.3.6.1.4.1.43.45.1.2.23.1.3.2.1.3';
    my $oid_hwdot1qTpFdbSetOperate = '1.3.6.1.4.1.43.45.1.2.23.1.3.2.1.4';

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $dot1dBasePort = $self->getDot1dBasePortForThisIfIndex($ifIndex); # physical port number
    if ($deauthMac && !$self->isFakeMac($deauthMac)) {

        my $mac_oid = mac2oid($deauthMac);

        $logger->info("Deauthorizing $deauthMac on ifIndex $ifIndex and vlan $deauthVlan");
        $logger->trace(
            "SNMP set_request for oid_hwdot1qTpFdbSetPort, oid_hwdot1qTpFdbSetStatus and oid_hwdot1qTpFdbSetOperate"
        );
        my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
            "$oid_hwdot1qTpFdbSetPort.$deauthVlan.$mac_oid", Net::SNMP::INTEGER, $dot1dBasePort,
            "$oid_hwdot1qTpFdbSetStatus.$deauthVlan.$mac_oid", Net::SNMP::INTEGER, $THREECOM::STATIC,
            "$oid_hwdot1qTpFdbSetOperate.$deauthVlan.$mac_oid", Net::SNMP::INTEGER, $THREECOM::DELETE,
        ]);
        if (!defined($result)) {
            $logger->warn(
                "SNMP error tyring to perform auth. This could be normal. "
                . "Error message: ".$self->{_sessionWrite}->error());
        }
    }

    if ($authMac && !$self->isFakeMac($authMac)) {

        # Warning: this may seem counter-intuitive but I'm authorizing the new MAC on the old VLAN
        # because the switch won't accept it for a VLAN that doesn't exist on that port.
        # When changed by _setVlan later, the MAC will be re-authorized on the right VLAN
        my $vlan = $self->getVlan($ifIndex);
        my $mac_oid = mac2oid($authMac);

        $logger->info(
            "Authorizing $authMac on ifIndex $ifIndex and vlan $vlan "
            . "(don't worry if VLAN is not ok, it'll be re-assigned later)"
        );
        $logger->trace(
            "SNMP set_request for oid_hwdot1qTpFdbSetPort, oid_hwdot1qTpFdbSetStatus and oid_hwdot1qTpFdbSetOperate"
        );
        my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
            "$oid_hwdot1qTpFdbSetPort.$vlan.$mac_oid", Net::SNMP::INTEGER, $dot1dBasePort,
            "$oid_hwdot1qTpFdbSetStatus.$vlan.$mac_oid", Net::SNMP::INTEGER, $THREECOM::STATIC,
            "$oid_hwdot1qTpFdbSetOperate.$vlan.$mac_oid", Net::SNMP::INTEGER, $THREECOM::ADD,
        ]);
        if (!defined($result)) {
            $logger->error(
                "SNMP error tyring to perform auth. This could be normal. "
                . "Error message: ".$self->{_sessionWrite}->error());
            return 0;
        }
    }
    return 1;
}

=item _authorizeMacWithTelnet

Uses "mac-address static" instead of "mac-address security" because the latter only work if port is in autolearn

=cut

sub _authorizeMacWithTelnet {
    my ( $self, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger  = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info( "not in production mode ... we won't modify static MAC addresses");
        return 1;
    }

    # Warning: this generates a warning on empty password
    my $session;
    eval {
        require Net::Telnet;
        $session = new Net::Telnet( Host => $self->{_ip}, Timeout => 20 );

        #$session->input_log('/tmp/test.txt');
        $session->waitfor('/Username:/');
        $session->print( $self->{_cliUser} );
        $session->waitfor('/Password:/');
        $session->print( $self->{_cliPwd} );
        $session->waitfor('/>/');
    };
    if ($@) {
        $logger->warn("ERROR: Can not connect to switch " . $self->{'_id'} . " using Telnet");
        return 0;
    }

    my $ifDesc = $self->getIfDesc($ifIndex);
    # do not deauthorize a fake MAC. It is useless for this switch.
    if ($deauthMac && !$self->isFakeMac($deauthMac)) {

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
        $session->print("undo mac-address static $deauthMac vlan $deauthVlan");
        $session->waitfor('/\]/');
        $logger->trace("return");
        $session->print("return");
        $session->waitfor('/>/');
    }

    # do not authorize a fake MAC. It is useless for this switch.
    if ($authMac && !$self->isFakeMac($authMac)) {

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

    $session->close();
    return 1;
}

=item getAllSecureMacAddresses

Method that fetches all the secure (staticly assigned) MAC addresses for a given switch.

Returns a hash table with mac, ifIndex, vlan

=cut

# TODO the Fdb is usually very large, we should grab the Fdb only for the VLANs in the switches' managed VLANs
sub getAllSecureMacAddresses {
    my ($self) = @_;
    my $logger = $self->logger;
    # Status of all MAC addresses
    my $OID_hwdot1qTpFdbSetStatus = '1.3.6.1.4.1.43.45.1.2.23.1.3.2.1.3'; # from A3COM-HUAWEI-LswMAM-MIB
    # Port number of all MAC addresses
    my $OID_hwdot1qTpFdbSetPort = '1.3.6.1.4.1.43.45.1.2.23.1.3.2.1.2'; # from A3COM-HUAWEI-LswMAM-MIB

    my $secureMacAddrHashRef = {};
    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    $logger->trace("SNMP get_table for hwdot1qTpFdbSetStatus: $OID_hwdot1qTpFdbSetStatus");

    # read the whole mac to port association and put it in a hashmap for later
    my $result = $self->{_sessionRead}->get_table( -baseoid => "$OID_hwdot1qTpFdbSetPort" );
    my $macPort = {};
    foreach my $macOidPort ( keys %{$result} ) {
        if ($macOidPort =~ /^$OID_hwdot1qTpFdbSetPort
            \.([0-9]+)\.                                                # VLAN tag
            (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})      # MAC in OID format
        $/x) {

            my $mac = oid2mac($2);
            $macPort->{$mac} = $result->{$macOidPort};
        }
    }

    if (!%{$macPort}) {
        $logger->warn("Something went wrong fetching the MAC to port association table");
        return $secureMacAddrHashRef;
    }

    $result = $self->{_sessionRead}->get_table( -baseoid => "$OID_hwdot1qTpFdbSetStatus" );
    foreach my $vlanMacOidStatus ( keys %{$result} ) {

        # we are only interested by static entries
        if ( $result->{$vlanMacOidStatus} ==  $THREECOM::STATIC ) {

            if ( $vlanMacOidStatus =~ /^$OID_hwdot1qTpFdbSetStatus
                \.([0-9]+)\.                                                # VLAN tag
                (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})      # MAC in OID format
            $/x) {

                my $oldMac = oid2mac($2);
                my $oldVlan = $1;
                my $ifIndex = $self->getIfIndexForThisDot1dBasePort($macPort->{$oldMac});
                push @{ $secureMacAddrHashRef->{$oldMac}->{$ifIndex} }, $oldVlan;
            }
        }
    }
    return $secureMacAddrHashRef;
}

=item getSecureMacAddresses

Method that fetches all the secure (staticly assigned) MAC addresses for a given ifIndex.

Returns a hash table with mac, vlan

=cut

# TODO the Fdb is usually very large, we should grab the Fdb only for the VLANs in the switches' managed VLANs
sub getSecureMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    # OID holds Vlan and MAC. The result is dot1dPort
    my $OID_hwdot1qTpFdbSetPort = '1.3.6.1.4.1.43.45.1.2.23.1.3.2.1.2'; #from A3COM-HUAWEI-LswMAM-MIB
    # OID holds Vlan and MAC. The result is mac type
    my $OID_hwdot1qTpFdbSetStatus = '1.3.6.1.4.1.43.45.1.2.23.1.3.2.1.3'; #from A3COM-HUAWEI-LswMAM-MIB

    my $secureMacAddrHashRef = {};
    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    my $dot1dBasePort = $self->getDot1dBasePortForThisIfIndex($ifIndex);

    # fetch all the MACs based on port
    my @macOnTargetPort;
    $logger->trace("SNMP get_table for hwdot1qTpFdbSetPort: $OID_hwdot1qTpFdbSetPort");
    my $result = $self->{_sessionRead}->get_table(-baseoid => "$OID_hwdot1qTpFdbSetPort");
    foreach my $macOidPort (keys %{$result}) {
        if ($result->{$macOidPort} == $dot1dBasePort) {
            $macOidPort =~ /^$OID_hwdot1qTpFdbSetPort
                \.([0-9]+)\.                                                # VLAN tag
                (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})      # MAC in OID format
            $/x;
            my $mac = oid2mac($2);
            $logger->trace("Interested by MAC: $mac on Port $dot1dBasePort (ifIndex: $ifIndex)");
            push(@macOnTargetPort,$mac);
        }
    }

    # Grab all vlans, MACs and status (static, dynamic, etc.)
    $logger->trace("SNMP get_table for hwdot1qTpFdbSetStatus: $OID_hwdot1qTpFdbSetStatus");
    $result = $self->{_sessionRead}->get_table(-baseoid => "$OID_hwdot1qTpFdbSetStatus");
    foreach my $vlanMacOidStatus ( keys %{$result} ) {
        # we are only interested by static entries
        if ( $result->{$vlanMacOidStatus} ==  $THREECOM::STATIC ) {
            # grabbing Vlan and Mac
            if ( $vlanMacOidStatus =~ /^$OID_hwdot1qTpFdbSetStatus
                \.([0-9]+)\.                                                # VLAN tag
                (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})      # MAC in OID format
            $/x) {

                my $oldMac = oid2mac($2);
                my $oldVlan = $1;

                # we were interested by that port and port is in secure mode
                if (grep($_ eq $oldMac, @macOnTargetPort)) { #this means "Is $oldMac in @macOnTargetPort array?"

                    $logger->trace(
                        "On ifIndex $ifIndex, MAC: $oldMac is in secure mode on vlan $oldVlan (Port $dot1dBasePort)"
                    );
                    push @{ $secureMacAddrHashRef->{$oldMac} }, int($oldVlan);
                }
            }
        }
    }

    return $secureMacAddrHashRef;
}

=item _getLLDPIndex

We extract the LLDP index from SNMP request to the switch

=cut

sub _getLLDPIndex {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return 0;
    }
    
    my $OID_ifDesc = "1.3.6.1.2.1.31.1.1.1.1.$ifIndex";
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [ "$OID_ifDesc" ] );
    my $desc = $result->{"1.3.6.1.2.1.31.1.1.1.1.$ifIndex"};

    $desc =~ /(\d+)$/;

    return $1;
}

=item getPhonesLLDPAtIfIndex

Using SNMP and LLDP we determine if there is VoIP connected on the switch port
=cut

sub getPhonesLLDPAtIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my @phones;
    if ( !$self->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch "
                . $self->{_ip}
                . ". getPhonesLLDPAtIfIndex will return empty list." );
        return @phones;
    }

    my $index = $self->_getLLDPIndex($ifIndex);

    my $oid_lldpRemPortId = '1.0.8802.1.1.2.1.4.1.1.7';
    my $oid_lldpRemSysDesc = '1.0.8802.1.1.2.1.4.1.1.10';

    if ( !$self->connectRead() ) {
        return @phones;
    }
    sleep(4);
    $logger->trace(
        "SNMP get_next_request for lldpRemSysDesc: $oid_lldpRemSysDesc");
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => $oid_lldpRemSysDesc );
    foreach my $oid ( keys %{$result} ) {
        if ( $oid =~ /^$oid_lldpRemSysDesc\.([0-9]+)\.([0-9]+)\.([0-9]+)$/ ) {
            if ( $index eq $2 ) {
                my $cache_lldpRemTimeMark = $1;
                my $cache_lldpRemLocalPortNum = $2;
                my $cache_lldpRemIndex = $3;
                if ( $result->{$oid} =~ /phone/i ) {
                    $logger->trace(
                        "SNMP get_request for lldpRemPortId: $oid_lldpRemPortId.$cache_lldpRemTimeMark.$cache_lldpRemLocalPortNum.$cache_lldpRemIndex"
                    );
                    my $MACresult = $self->{_sessionRead}->get_request(
                        -varbindlist => [
                            "$oid_lldpRemPortId.$cache_lldpRemTimeMark.$cache_lldpRemLocalPortNum.$cache_lldpRemIndex"
                        ]
                    );
                    if ($MACresult
                        && ($MACresult->{
                                "$oid_lldpRemPortId.$cache_lldpRemTimeMark.$cache_lldpRemLocalPortNum.$cache_lldpRemIndex"
                            }
                            =~ /^([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})/i
                        )
                        )
                    {
                        push @phones, lc("$1:$2:$3:$4:$5:$6");
                    }
                }
            }
        }
    }
    return @phones;
}

=item isVoIPEnabled

Returns 1 if VoIP is enabled

=cut

sub isVoIPEnabled {
    my ($self) = @_;
    return ( $self->{_VoIPEnabled} == 1 );
}

=back

=head1 AUTHOR

Mr. Chinasee BOONYATANG <chinasee.b@psu.ac.th>

Mr.Ponpitak SANTIPAPTAWON <ponpitak.s@psu.ac.th>

Prince of Songkla University, Thailand
http://netserv.cc.psu.ac.th

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
