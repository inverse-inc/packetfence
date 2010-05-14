package pf::SNMP::Cisco::Catalyst_2950;

=head1 NAME

pf::SNMP::Cisco::Catalyst_2950 - Object oriented module to access SNMP enabled Cisco Catalyst 2950 switches

=head1 SYNOPSIS

The pf::SNMP::Cisco::Catalyst_2950 module implements an object oriented interface
to access SNMP enabled Cisco::Catalyst_2950 switches.

=head1 STATUS

The minimum required firmware version is 12.1(22)EA10.

=head1 BUGS AND LIMITATIONS
 
We got reports that it doesn't work with SNMPv3

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP::Cisco');
use Log::Log4perl;
use Carp;
use Net::Appliance::Session;
use Net::SNMP;
use Data::Dumper;

use pf::config;
# importing switch constants
use pf::SNMP::constants;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=cut
sub getMinOSVersion {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return '12.1(22)EA10';
}

sub getManagedPorts {
    my $this       = shift;
    my $logger     = Log::Log4perl::get_logger( ref($this) );
    my $oid_ifType = '1.3.6.1.2.1.2.2.1.3';                     # MIB: ifTypes
    my $oid_ifName = '1.3.6.1.2.1.31.1.1.1.1';
    my @nonUpLinks;
    my @UpLinks = $this->getUpLinks();    # fetch the UpLink list

    if ( !$this->connectRead() ) {
        return @nonUpLinks;
    }
    $logger->trace("SNMP get_table for ifType: $oid_ifType");
    my $ifTypes = $this->{_sessionRead}
        ->get_table(    # fetch the ifTypes list of the ports
        -baseoid => $oid_ifType
        );
    if ( defined($ifTypes) ) {

        foreach my $port ( keys %{$ifTypes} ) {
            if ( $ifTypes->{$port} == 6 )
            {           # skip non ethernetCsmacd port type

                $port =~ /^$oid_ifType\.(\d+)$/;
                if ( grep( { $_ == $1 } @UpLinks ) == 0 ) {    # skip UpLinks

                    my $portVlan = $this->getVlan($1);
                    if ( defined $portVlan ) {    # skip port with no VLAN

                        my $port_type = $this->getVmVlanType($1);
                        if ( ( $port_type == 1 ) || ( $port_type == 4 ) )
                        {                         # skip non static

                            if (grep(
                                    { $_ == $portVlan } @{ $this->{_vlans} } )
                                != 0 )
                            {    # skip port in a non-managed VLAN
                                $logger->trace(
                                    "SNMP get_request for ifName: $oid_ifName.$1"
                                );
                                my $ifNames
                                    = $this->{_sessionRead}->get_request(
                                    -varbindlist =>
                                        ["$oid_ifName.$1"]    # MIB: ifNames
                                    );
                                push @nonUpLinks,
                                    $ifNames->{"$oid_ifName.$1"};
                            }
                        }
                    }
                }
            }
        }
    }
    return @nonUpLinks;
}

#obtain hashref from result of getMacAddr
sub _getIfDescMacVlan {
    my ( $this, @macAddr ) = @_;
    my $ifDescMacVlan;
    foreach my $line ( grep( {/DYNAMIC/} @macAddr ) ) {
        my ( $vlan, $mac, $ifDesc ) = unpack( "A4x4A14x16A*", $line );
        $mac =~ s/\./:/g;
        $mac
            = uc(
                  substr( $mac, 0, 2 ) . ':'
                . substr( $mac, 2,  5 ) . ':'
                . substr( $mac, 7,  5 ) . ':'
                . substr( $mac, 12, 2 ) );
        if ( !( $vlan =~ /ALL/i ) ) {
            push @{ $ifDescMacVlan->{$ifDesc}->{$mac} }, int($vlan);
        }
    }
    return $ifDescMacVlan;
}

=item clearMacAddressTable

Warning: this method should _never_ be called in a thread. Net::Appliance::Session is not thread 
safe: 

L<http://www.cpanforum.com/threads/6909/>

=cut
sub clearMacAddressTable {
    my ( $this, $ifIndex, $vlan ) = @_;
    my $command;
    my $session;
    my $oid_ifName = '1.3.6.1.2.1.31.1.1.1.1';
    my $logger     = Log::Log4perl::get_logger( ref($this) );

    eval {
        $session = Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 5,
            Transport => $this->{_cliTransport}
        );
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );
        $session->begin_privileged( $this->{_cliEnablePwd} );
    };

    if ($@) {
        $logger->error(
            "ERROR: Can not connect to switch $this->{'_ip'} using "
                . $this->{_cliTransport} );
        return 0;
    }

    # First we fetch ifName(ifIndex)
    if ( !$this->connectRead() ) {
        return 0;
    }
    $logger->trace("SNMP get_request for ifName: $oid_ifName");
    my $ifNames = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$oid_ifName.$ifIndex"] );
    my $port = $ifNames->{"$oid_ifName.$ifIndex"};

    # then we clear the table with for ifDescr
    $command = "clear mac-address-table interface $port vlan $vlan";

    eval { $session->cmd( String => $command, Timeout => '10' ); };
    if ($@) {
        $logger->error(
            "ERROR: Error while clearing MAC Address table on port $ifIndex for switch $this->{'_ip'} using "
                . $this->{_cliTransport} );
        $session->close();
        return;
    }
    $session->close();
    return 1;
}

sub getAllSecureMacAddresses {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.2.1.4';

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for cpsSecureMacAddrRowStatus: $oid_cpsSecureMacAddrRowStatus"
    );
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsSecureMacAddrRowStatus" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$oid_cpsSecureMacAddrRowStatus\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x",
                $2, $3, $4, $5, $6, $7 );
            my $ifIndex = $1;
            my $oldVlan = $this->getVlan($ifIndex);
            push @{ $secureMacAddrHashRef->{$oldMac}->{$ifIndex} }, $oldVlan;
        }
    }

    return $secureMacAddrHashRef;
}

sub isDynamicPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger                   = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.2.1.2';

    if ( !$this->connectRead() ) {
        return 0;
    }
    if ( !$this->isPortSecurityEnabled($ifIndex) ) {
        $logger->debug("port security is not enabled");
        return 0;
    }

    $logger->trace(
        "SNMP get_table for cpsSecureMacAddrType: $oid_cpsSecureMacAddrType");
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsSecureMacAddrType.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $result->{$oid_including_mac} == 1 ) {
            return 0;
        }
    }

    return 1;
}

sub isStaticPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger                   = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.2.1.2';

    if ( !$this->connectRead() ) {
        return 0;
    }
    if ( !$this->isPortSecurityEnabled($ifIndex) ) {
        $logger->debug("port security is not enabled");
        return 0;
    }

    $logger->trace(
        "SNMP get_table for cpsSecureMacAddrType: $oid_cpsSecureMacAddrType");
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsSecureMacAddrType.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $result->{$oid_including_mac} == 1 ) {
            return 1;
        }
    }

    return 0;
}

sub getSecureMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.2.1.4';

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for cpsSecureMacAddrRowStatus: $oid_cpsSecureMacAddrRowStatus"
    );
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsSecureMacAddrRowStatus.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$oid_cpsSecureMacAddrRowStatus\.$ifIndex\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x",
                $1, $2, $3, $4, $5, $6 );
            my $oldVlan = $this->getVlan($ifIndex);
            push @{ $secureMacAddrHashRef->{$oldMac} }, $oldVlan;
        }
    }

    return $secureMacAddrHashRef;
}

sub authorizeMAC {
    my ( $this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.2.1.4';

    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't add an entry to the SecureMacAddrTable"
        );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $voiceVlan = $this->getVoiceVlan($ifIndex);
    if ( ( $deauthVlan == $voiceVlan ) || ( $authVlan == $voiceVlan ) ) {
        $logger->error(
            "ERROR: authorizeMAC called with voice VLAN .... this should not have happened ... we won't add an entry to the SecureMacAddrTable"
        );
        return 1;
    }

    my @oid_value;
    if ($deauthMac) {
        my @macArray = split( /:/, $deauthMac );
        my $completeOid = $oid_cpsSecureMacAddrRowStatus . "." . $ifIndex;
        foreach my $macPiece (@macArray) {
            $completeOid .= "." . hex($macPiece);
        }
        push @oid_value, ( $completeOid, Net::SNMP::INTEGER, 6 );
    }
    if ($authMac) {
        my @macArray = split( /:/, $authMac );
        my $completeOid = $oid_cpsSecureMacAddrRowStatus . "." . $ifIndex;
        foreach my $macPiece (@macArray) {
            $completeOid .= "." . hex($macPiece);
        }
        push @oid_value, ( $completeOid, Net::SNMP::INTEGER, 4 );
    }

    if ( scalar(@oid_value) > 0 ) {
        $logger->trace("SNMP set_request for cpsSecureMacAddrRowStatus");
        my $result = $this->{_sessionWrite}
            ->set_request( -varbindlist => \@oid_value );
    }
    return 1;
}

sub getMaxMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    #CISCO-PORT-SECURITY-MIB
    my $OID_cpsIfPortSecurityEnable = '1.3.6.1.4.1.9.9.315.1.2.1.1.1';
    my $OID_cpsIfMaxSecureMacAddr   = '1.3.6.1.4.1.9.9.315.1.2.1.1.3';

    if ( !$this->connectRead() ) {
        return -1;
    }

    #determine if port security is enabled
    $logger->trace(
        "SNMP get_request for cpsIfPortSecurityEnable: $OID_cpsIfPortSecurityEnable.$ifIndex"
    );
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_cpsIfPortSecurityEnable.$ifIndex" ] );
    if (( !exists( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} ) )
        || ( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} eq
            'noSuchInstance' )
        )
    {
        $logger->error("ERROR: could not obtain cpsIfPortSecurityEnable");
        return -1;
    }
    if ( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} != 1 ) {
        $logger->debug("cpsIfPortSecurityEnable is not true");
        return -1;
    }

    #determine max number of MAC addresses allowed
    $logger->trace(
        "SNMP get_request for cpsIfMaxSecureMacAddr: $OID_cpsIfMaxSecureMacAddr.$ifIndex"
    );
    $result = $this->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_cpsIfMaxSecureMacAddr.$ifIndex" ] );
    if (( !exists( $result->{"$OID_cpsIfMaxSecureMacAddr.$ifIndex"} ) )
        || ( $result->{"$OID_cpsIfMaxSecureMacAddr.$ifIndex"} eq
            'noSuchInstance' )
        )
    {
        $logger->error("ERROR: could not obtain cpsIfMaxSecureMacAddr");
        return -1;
    }
    return $result->{"$OID_cpsIfMaxSecureMacAddr.$ifIndex"};

}

=item ping

Warning: this method should _never_ be called in a thread. Net::Appliance::Session is not thread 
safe: 

L<http://www.cpanforum.com/threads/6909/>

=cut
sub ping {
    my ( $this, $ip ) = @_;
    my $session;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    eval {
        $session = Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 5,
            Transport => $this->{_cliTransport}
        );
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );
    };

    if ($@) {
        $logger->error(
            "ERROR: Can not connect to switch $this->{'_ip'} using "
                . $this->{_cliTransport} );
        return 1;
    }

    if ( !$session->begin_privileged( $this->{_cliEnablePwd} ) ) {
        $logger->error( "ERROR: Cannot enable: " . $session->errmsg );
        $session->close();
        return 1;
    }

    $session->cmd("ping $ip timeout 0 repeat 1");
    $session->close();

    return 1;
}

=item supportsFloatingDevice - Does this switch type supports floating network devices ?

Only Catalyst 2900XL and 3500XL does not so far...

=cut
sub supportsFloatingDevice {
    my ( $this ) = @_;

    return 1;
}

=item enablePortSecurityByIfIndex - configure the port with port-security settings

With no VoIP
 switchport port-security maximum 1 vlan access
 switchport port-security
 switchport port-security violation restrict
 switchport port-security mac-adress xxxx.xxxx.xxxx

With VoIP
 switchport port-security maximum 2
 switchport port-security maximum 1 vlan access
 switchport port-security
 switchport port-security violation restrict
 switchport port-security mac-adress xxxx.xxxx.xxxx

=cut
sub enablePortSecurityByIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $maxSecureMacTotal;
    my $maxSecureMacVlanAccess = 1;

    if ($this->isVoIPEnabled()) {

        # switchport port-security maximum 2
        $maxSecureMacTotal = 2;
        $this->setPortSecurityMaxSecureMacAddrByIfIndex($ifIndex,$maxSecureMacTotal);

        # switchport port-security maximum 1 vlan access
        $this->setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex($ifIndex,$maxSecureMacVlanAccess);
    } else {

        # switchport port-security maximum 1
        $maxSecureMacTotal = 1;
        $this->setPortSecurityMaxSecureMacAddrByIfIndex($ifIndex,$maxSecureMacTotal);
    }

    # switchport port-security violation restrict
    $this->setPortSecurityViolationActionByIfIndex($ifIndex, $CISCO::DROPNOTIFY);

    # switchport port-security mac-adress xxxx.xxxx.xxxx
    my $macToAuthorize;
    my @macArray = $this->_getMacAtIfIndex($ifIndex);
    if ( !@macArray ) {
        $macToAuthorize = $this->generateFakeMac(0, $ifIndex);
    } else {
        $macToAuthorize = $macArray[0];
    }
    my $vlan = $this->getVlan($ifIndex);
    $this->authorizeMAC( $ifIndex, undef, $macToAuthorize, $vlan, $vlan);

    # switchport port-security
    $this->setPortSecurityEnableByIfIndex($ifIndex, $TRUE);
    return 1;
}

=item disablePortSecurityByIfIndex - remove all the port-security settings on a port

=cut
sub disablePortSecurityByIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # no switchport port-security
    if (! $this->setPortSecurityEnableByIfIndex($ifIndex, $FALSE)) {
        $logger->error("An error occured while disablling port-security on ifIndex $ifIndex");
        return 0;
    }

    # no switchport port-security violation restrict
    if (! $this->setPortSecurityViolationActionByIfIndex($ifIndex, $CISCO::SHUTDOWN)) {
        $logger->error("An error occured while disablling port-security violation restrict in ifIndex $ifIndex");
        return 0;
    }

    # no switchport port-security mac-adress xxxx.xxxx.xxxx
    my $secureMacHashRef = $this->getSecureMacAddresses($ifIndex);
    my $valid = (ref($secureMacHashRef) eq 'HASH');
    my $mac_count = scalar(keys %{$secureMacHashRef});
    if ($valid && $mac_count == 1) {
        my $macToDeAuthorize = (keys %{$secureMacHashRef})[0];
        my $vlan = $this->getVlan($ifIndex);
        if (! $this->authorizeMAC( $ifIndex, $macToDeAuthorize, undef, $vlan, $vlan)) {
            $logger->error("An error occured while de-authorizing $macToDeAuthorize on ifIndex $ifIndex");
            return 0;
        }
    }

    return 1;
}

=item setPortSecurityEnableByIfIndex - enable/disable port-security on a port

=cut
sub setPortSecurityEnableByIfIndex {
    my ( $this, $ifIndex, $enable ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->warn("Should set IfPortSecurityEnable on $ifIndex to $enable but the switch is not in production -> Do nothing");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_cpsIfPortSecurityEnable = '1.3.6.1.4.1.9.9.315.1.2.1.1.1';
    my $truthValue = $enable ? $SNMP::TRUE : $SNMP::FALSE;

    $logger->trace("SNMP set_request for cpsIfPortSecurityEnable: $OID_cpsIfPortSecurityEnable");
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_cpsIfPortSecurityEnable.$ifIndex", Net::SNMP::INTEGER, $truthValue ] );
    return ( defined($result) );
}

=item setPortSecurityMaxSecureMacAddrByIfIndex 

Sets the global (data + voice) maximum number of MAC addresses for port-security on a port

=cut
sub setPortSecurityMaxSecureMacAddrByIfIndex {
    my ( $this, $ifIndex, $maxSecureMac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->warn("Should set IfMaxSecureMacAddr on $ifIndex to $maxSecureMac but the switch is not in production -> Do nothing");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_cpsIfMaxSecureMacAddr = '1.3.6.1.4.1.9.9.315.1.2.1.1.3';

    $logger->trace("SNMP set_request for IfMaxSecureMacAddr: $OID_cpsIfMaxSecureMacAddr");
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_cpsIfMaxSecureMacAddr.$ifIndex", Net::SNMP::INTEGER, $maxSecureMac ] );
   return ( defined($result) );
}

=item setPortSecurityMaxSecureMacAddrVlanByIfIndex 

Sets the maximum number of MAC addresses on the data vlan for port-security on a port

=cut
sub setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex {
    my ( $this, $ifIndex, $maxSecureMac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->warn("Should set IfMaxSecureMacAddrPerVlan on $ifIndex to $maxSecureMac but the switch is not in production -> Do nothing");
        return 1;
    }

    my $ifName = $this->getIfName($ifIndex);
    if ($ifName eq '') {
        $logger->error( "Can not read ifName for ifIndex $ifIndex, Port-Security maximum can not be set on data Vlan");
        return 0;
    }

    my $session;
    eval {
        $session = Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 5,
            Transport => $this->{_cliTransport}
        );
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );
        $session->begin_privileged( $this->{_cliEnablePwd} );
        $session->begin_configure();
        $session->cmd( String => "int $ifName", Timeout => '10' );
        $session->cmd( String => "switchport port-security max $maxSecureMac vlan access", Timeout => '10' );
        $session->end_configure();
        $session->close();
    };

    if ($@) {
        $logger->error("Error while configuring switchport port-security max $maxSecureMac vlan access on ifIndex "
                       . "$ifIndex. Error message: $!");
        return 0;
    }
    return 1;
}

=item setPortSecurityViolationActionByIfIndex 

Tells the switch what to do when the number of MAC addresses on the port has exceeded the maximum: shut down the port, send a trap or only allow traffic from the secure port and drop packets from other MAC addresses

=cut
sub setPortSecurityViolationActionByIfIndex {
    my ( $this, $ifIndex, $action ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->warn("Should set IfViolationAction on $ifIndex to $action but the switch is not in production -> Do nothing");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_cpsIfViolationAction = '1.3.6.1.4.1.9.9.315.1.2.1.1.8';

    $logger->trace("SNMP set_request for IfViolationAction: $OID_cpsIfViolationAction");
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_cpsIfViolationAction.$ifIndex", Net::SNMP::INTEGER, $action ] );
    return ( defined($result) );

}

=item setTaggedVlan 

Allows all the tagged Vlans on a multi-Vlan port. Used for floating network devices only 

=cut
sub setTaggedVlan {
    my ( $this, $ifIndex, @vlans ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    
    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port vlanTrunkPortVlansEnabled");
        return 1;
    }   
    
    if (! @vlans) {
        $logger->error("Tagged Vlan list is empty. Cannot set the tagged Vlans on trunk port $ifIndex");
        return 0;
    }   
        
    if ( !$this->connectWrite() ) {
        return 0;
    }       
         
    my $OID_vlanTrunkPortVlansEnabled   = '1.3.6.1.4.1.9.9.46.1.6.1.1.4';
    my $OID_vlanTrunkPortVlansEnabled2k = '1.3.6.1.4.1.9.9.46.1.6.1.1.17';
    my $OID_vlanTrunkPortVlansEnabled3k = '1.3.6.1.4.1.9.9.46.1.6.1.1.18';
    my $OID_vlanTrunkPortVlansEnabled4k = '1.3.6.1.4.1.9.9.46.1.6.1.1.19';
        
    @vlans = sort(@vlans);
        
    # we support only vlans <= 1024 on Cisco's
    if ($vlans[length(@vlans) - 1] > 1024) {
        $logger->warn("We do not support Tagged Vlans > 1024 for now on Cisco switches. Sorry... but we could support" .
                      " them, interested in sponsoring the feature?");
    }  

    my $bitString = $this->_buildBitString(@vlans);
    my $taggedVlanMembers = pack("B*", $bitString);
        
    $logger->trace("SNMP set_request for OID_vlanTrunkPortVlansEnabled: $OID_vlanTrunkPortVlansEnabled");
    my $result = $this->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_vlanTrunkPortVlansEnabled.$ifIndex", Net::SNMP::OCTET_STRING, $taggedVlanMembers,
            "$OID_vlanTrunkPortVlansEnabled2k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 0 x 1024),
            "$OID_vlanTrunkPortVlansEnabled3k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 0 x 1024),
            "$OID_vlanTrunkPortVlansEnabled4k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 0 x 1024) ] );
    return defined($result);
}   

=item _buildBitString - generates bitString to allow Vlans on a port. 

To allow Vlan 1 we need to set 40 00 00 00 00 00 ... 00 so we output zeros everywhere but at vlans position

=cut
sub _buildBitString {
    my ($this, @vlans ) = @_;
    my $bitString = '0';

    for (my $i = 1; $i < 1024; $i++) {
        if ($vlans[0] == $i) {
            $bitString .= '1';
            shift(@vlans);
        } else {
            $bitString .= '0';
        }
    }
    return $bitString;
}

=item removeAllTaggedVlan 

Removes all the tagged Vlans on a multi-Vlan port. Used for floating network devices only 

=cut
sub removeAllTaggedVlan {
    my ( $this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port OID_vlanTrunkPortVlansEnabled");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $OID_vlanTrunkPortVlansEnabled   = '1.3.6.1.4.1.9.9.46.1.6.1.1.4';
    my $OID_vlanTrunkPortVlansEnabled2k = '1.3.6.1.4.1.9.9.46.1.6.1.1.17';
    my $OID_vlanTrunkPortVlansEnabled3k = '1.3.6.1.4.1.9.9.46.1.6.1.1.18';
    my $OID_vlanTrunkPortVlansEnabled4k = '1.3.6.1.4.1.9.9.46.1.6.1.1.19';

    # to reset the tagged Vlans we need to:
    # - set 7F FF ... FF to OID_vlanTrunkPortVlansEnabled   
    # - set FF FF ... FF to OID_vlanTrunkPortVlansEnabled2k   
    # - set FF FF ... FF to OID_vlanTrunkPortVlansEnabled3k   
    # - set FF FF ... FE to OID_vlanTrunkPortVlansEnabled4k   
    my $bitString = '0';
    my $bitString4k = '1';
    for (my $i = 1; $i < 1023; $i++) {
        $bitString .= '1';
        $bitString4k .= '1';
    }
    $bitString .= '1';
    $bitString4k .= '0';

    my $taggedVlanMembers = pack("B*", $bitString);
    my $taggedVlanMembers4k = pack("B*", $bitString4k);

    my $result = $this->{_sessionWrite}->set_request( -varbindlist => [
        "$OID_vlanTrunkPortVlansEnabled.$ifIndex", Net::SNMP::OCTET_STRING, $taggedVlanMembers,
        "$OID_vlanTrunkPortVlansEnabled2k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 1 x 1024),
        "$OID_vlanTrunkPortVlansEnabled3k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 1 x 1024),
        "$OID_vlanTrunkPortVlansEnabled4k.$ifIndex", Net::SNMP::OCTET_STRING, $taggedVlanMembers4k ] );

    my $returnValue = ( defined($result) );

    return $returnValue;
}

=item enablePortConfigAsTrunk - sets port as multi-Vlan port

=cut
sub enablePortConfigAsTrunk {
    my ($this, $mac, $switch_port, $taggedVlans)  = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # switchport mode trunk
    $logger->info("Setting port $switch_port as trunk.");
    if (! $this->setModeTrunk($switch_port, $TRUE)) {
        $logger->error("An error occured while enabling port $switch_port as multi-vlan (trunk)");
        return 0;
    }

    # switchport trunk allowed vlan x,y,z
    $logger->info("Allowing tagged Vlans on port $switch_port");
    if (! $this->setTaggedVlan($switch_port, split(",", $taggedVlans)) ) {
        $logger->error("An error occured while allowing tagged Vlans on trunk port $switch_port");
        return 0;
    }

    # FIXME
    # this is one of the ugliest hack I did... For a mysterious reason if we don't wait 5 sec between the moment we set 
    # the port as trunk and the moment we enable linkdown traps, the switch port starts a never ending linkdown/linkup 
    # trap cycle. The problem would probably not occur if we could enable only linkdown traps without linkup. 
    # But we can't on Cisco's...
    sleep(5);

    return 1;
}

=item disablePortConfigAsTrunk - sets port as non multi-Vlan port

=cut
sub disablePortConfigAsTrunk {
    my ($this, $switch_port) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # switchport mode access
    $logger->info("Setting port $switch_port as non trunk.");
    if (! $this->setModeTrunk($switch_port, $FALSE)) {
        $logger->error("An error occured while disabling port $switch_port as multi-vlan (trunk)");
        return 0;
    }

    # no switchport trunk allowed vlan
    # this setting is not necessary but we thought it would ease the reading of the port configuration if we remove
    # all the tagged vlan when they are not in use (port no longer trunk)
    $logger->info("Disabling tagged Vlans on port $switch_port");
    if (! $this->removeAllTaggedVlan($switch_port)) {
        $logger->warn("An minor issue occured while disabling tagged Vlans on trunk port $switch_port " .
                      "but the port should work.");
    }

    return 1;
}

=back

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

Regis Balzard <rbalzard@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2006-2008,2010 Inverse inc.

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
