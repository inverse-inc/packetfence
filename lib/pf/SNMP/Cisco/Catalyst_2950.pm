package pf::SNMP::Cisco::Catalyst_2950;

=head1 NAME

pf::SNMP::Cisco::Catalyst_2950 - Object oriented module to access and configure Cisco Catalyst 2950 switches

=head1 STATUS

The minimum required firmware version is 12.1(22)EA10.

=over 

=item Supports

=over

=item 802.1X with or without VoIP

=item Port-Security without VoIP

=item MAC notifications with VoIP

=back
 
=item Untested

=over

=item RADIUS VoIP authorization (we relied on CDP discovery instead)

=back

=back

This module extends pf::SNMP::Cisco.

=head1 BUGS AND LIMITATIONS

=over

=item Problematic firmware versions

We got reports that 12.1(22)EA13 is buggy. 
Not sending port-security traps under uncertain circumstances.
 
=item 802.1X
 
802.1X doesn't support Dynamic VLAN Assignments over RADIUS.
We had to work around that limitation by setting the VLAN using SNMP instead.
Also, we realized that we need to do a shut / no-shut on the port in order for the client to properly re-authenticate.
This has nasty side-effects when used with VoIP (client don't re-DHCP automatically).

=item No MAC-Authentication Bypass support

These switches don't support MAB (what we call MAC-Authentication in 
PacketFence) and so their 802.1X support is a lot less attractive because of 
that. Briefly it means that devices that don't support 802.1X can't coexist
with 802.1X capable devices with the same port config.

https://supportforums.cisco.com/thread/216455

=item SNMPv3

SNMPv3 support is broken for link-up / link-down and MAC Notification modes. 
Cisco didn't implement SNMPv3 context support for this IOS line and it is required to query the MAC address table. 
See #1284.

=item VLAN enforcement on trunk ports through SSH

On trunk ports, we need to clear the MAC address table when performing a 
VLAN change (however this assumption might need to get revisited). 
Clearing MAC is done over CLI (Telnet / SSH) and currently under SSH it is 
broken. Because we don't recommend users securing trunk ports with NAC and
since Telnet works fine, this is a low priority issue. See #1371 for more 
details.

=back

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;

use base ('pf::SNMP::Cisco');
use Log::Log4perl;
use Carp;
use Net::Appliance::Session;
use Net::SNMP;
use Data::Dumper;

use pf::config;
use pf::locationlog;
sub description { 'Cisco Catalyst 2950' }

# importing switch constants
use pf::SNMP::constants;
use pf::util;
use pf::vlan::custom $VLAN_API_LEVEL;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=cut

# CAPABILITIES
sub supportsFloatingDevice { return $TRUE; }
# access technology supported
sub supportsWiredDot1x { return $TRUE; }
sub supportsRadiusDynamicVlanAssignment { return $FALSE; }
sub supportsRadiusVoip { return $TRUE; }
# special features
sub supportsLldp { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }

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
            if ( $ifTypes->{$port} == $SNMP::ETHERNET_CSMACD )
            {           # skip non ethernetCsmacd port type

                $port =~ /^$oid_ifType\.(\d+)$/;
                if ( grep( { $_ == $1 } @UpLinks ) == 0 ) {    # skip UpLinks

                    my $portVlan = $this->getVlan($1);
                    if ( defined $portVlan ) {    # skip port with no VLAN

                        my $port_type = $this->getVmVlanType($1);
                        if ( ( $port_type == 1 ) || ( $port_type == 4 ) )
                        {                         # skip non static

                            if (grep(
                                    { $_ == $portVlan } values %{ $this->{_vlans} } )
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

Warning: this code doesn't support elevating to privileged mode. See #900 and #1370.

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
        # Session not already privileged are not supported at this point. See #1370
        # $session->begin_privileged( $this->{_cliEnablePwd} );
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

Warning: this code doesn't support elevating to privileged mode. See #900 and #1370.

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

    # Session not already privileged are not supported at this point. See #1370
    #if ( !$session->begin_privileged( $this->{_cliEnablePwd} ) ) {
    #    $logger->error( "ERROR: Cannot enable: " . $session->errmsg );
    #    $session->close();
    #    return 1;
    #}

    $session->cmd("ping $ip timeout 0 repeat 1");
    $session->close();

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
    if ($valid && $mac_count >= 1) {
        foreach my $macToDeAuthorize (keys %{$secureMacHashRef}) {
            my $vlan = $this->getVlan($ifIndex);
            if (! $this->authorizeMAC( $ifIndex, $macToDeAuthorize, undef, $vlan, $vlan)) {
                $logger->error("An error occured while de-authorizing $macToDeAuthorize on ifIndex $ifIndex");
                return 0;
            }
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

=item setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex

Wraps around _setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex by spawning
a process to call it thus working around bug #1369: thread crash with 
floating network devices with VoIP through SSH transport

=cut
sub setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex {
    my ( $this, $ifIndex, $maxSecureMac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # we spawn a shell to workaround a thread safety bug in Net::Appliance::Session when using SSH transport
    # http://www.cpanforum.com/threads/6909

    my $command = 
        "/usr/local/pf/bin/pfcmd_vlan -switch $this->{_ip} "
        . "-runSwitchMethod _setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex $ifIndex $maxSecureMac"
    ;

    $logger->info("spawning a pfcmd_vlan process to set 'switchport port-security maximum $maxSecureMac vlan access'");
    pf_run($command);
    return $TRUE;
}

=item _setPortSecurityMaxSecureMacAddrVlanByIfIndex 

Sets the maximum number of MAC addresses on the data vlan for port-security on a port

Warning: this method should _never_ be called in a thread. Net::Appliance::Session is not thread safe: 

L<http://www.cpanforum.com/threads/6909/>

Warning: this code doesn't support elevating to privileged mode. See #900 and #1370.

=cut
sub _setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex {
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
    };

    if ($@) {
        $logger->error("Error connecting to " . $this->{'_ip'} . " using ".$this->{_cliTransport} . ". Error: $!");
    }

    # Session not already privileged are not supported at this point. See #1370
    # are we in enabled mode?
    #if (!$session->in_privileged_mode()) {

    #    # let's try to enable
    #    if (!$session->enable($this->{_cliEnablePwd})) {
    #        $logger->error("Cannot get into privileged mode on ".$this->{'ip'}.
    #                       ". Are you sure you provided enable password in configuration?");
    #        $session->close();
    #        return 0;
    #    }
    #}

    eval {
        $session->cmd(String => "conf t", Timeout => '10');
        $session->cmd(String => "int $ifName", Timeout => '10');
        $session->cmd(String => "switchport port-security maximum $maxSecureMac vlan access", Timeout => '10');
        $session->cmd(String => "end", Timeout => '10');
    };

    if ($@) {
        $logger->error("Error while configuring switchport port-security maximum $maxSecureMac vlan access on ifIndex "
                       . "$ifIndex. Error message: $!");
        $session->close();
        return 0;
    }

    $session->close();
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

=item setTaggedVlans

Allows all the tagged Vlans on a multi-Vlan port. Used for floating network devices only 

=cut
sub setTaggedVlans {
    my ( $this, $ifIndex, $switch_locker, @vlans ) = @_;
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
    
    my @bits = split //, ("0" x 1024);
    foreach my $t (@vlans) {
        if ($t > 1024) {
            $logger->warn("We do not support Tagged Vlans > 1024 for now on Cisco switches. Sorry... but we could! " .
                      "interested in sponsoring the feature?");
        } else {
            $bits[$t] = "1";
        }
    }
    my $bitString = join ('', @bits);

    my $taggedVlanMembers = pack("B*", $bitString);
        
    $logger->trace("SNMP set_request for OID_vlanTrunkPortVlansEnabled: $OID_vlanTrunkPortVlansEnabled");
    my $result = $this->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_vlanTrunkPortVlansEnabled.$ifIndex", Net::SNMP::OCTET_STRING, $taggedVlanMembers,
            "$OID_vlanTrunkPortVlansEnabled2k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 0 x 1024),
            "$OID_vlanTrunkPortVlansEnabled3k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 0 x 1024),
            "$OID_vlanTrunkPortVlansEnabled4k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 0 x 1024) ] );
    return defined($result);
}   

=item removeAllTaggedVlans 

Removes all the tagged Vlans on a multi-Vlan port. Used for floating network devices only 

=cut
sub removeAllTaggedVlans {
    my ( $this, $ifIndex, $switch_locker) = @_;
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

    $logger->trace("SNMP set_request for OID_vlanTrunkPortVlansEnabled: $OID_vlanTrunkPortVlansEnabled");
    my $result = $this->{_sessionWrite}->set_request( -varbindlist => [
        "$OID_vlanTrunkPortVlansEnabled.$ifIndex", Net::SNMP::OCTET_STRING, $taggedVlanMembers,
        "$OID_vlanTrunkPortVlansEnabled2k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 1 x 1024),
        "$OID_vlanTrunkPortVlansEnabled3k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 1 x 1024),
        "$OID_vlanTrunkPortVlansEnabled4k.$ifIndex", Net::SNMP::OCTET_STRING, $taggedVlanMembers4k ] );

    my $returnValue = ( defined($result) );

    return $returnValue;
}

=item enablePortConfigAsTrunk - sets port as multi-Vlan port

Overriding default enablePortConfigAsTrunk to fix a race issue with Cisco

=cut
sub enablePortConfigAsTrunk {
    my ($this, $mac, $switch_port, $switch_locker, $taggedVlans)  = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # switchport mode trunk
    $logger->info("Setting port $switch_port as trunk.");
    if (! $this->setModeTrunk($switch_port, $TRUE)) {
        $logger->error("An error occured while enabling port $switch_port as multi-vlan (trunk)");
        return 0;
    }

    # switchport trunk allowed vlan x,y,z
    $logger->info("Allowing tagged Vlans on port $switch_port");
    if (! $this->setTaggedVlans($switch_port, $switch_locker, split(",", $taggedVlans)) ) {
        $logger->error("An error occured while allowing tagged Vlans on trunk port $switch_port");
        return 0;
    }

    # FIXME
    # this is a hack that should be removed. For a mysterious reason if we don't wait 5 sec between the moment we set 
    # the port as trunk and the moment we enable linkdown traps, the switch port starts a never ending linkdown/linkup 
    # trap cycle. The problem would probably not occur if we could enable only linkdown traps without linkup. 
    # But we can't on Cisco's...
    sleep(5);

    return 1;
}

=item NasPortToIfIndex

Translate RADIUS NAS-Port into switch's ifIndex.

=cut
sub NasPortToIfIndex {
    my ($this, $NAS_port) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this)); 

    # 50017 is ifIndex 17
    if ($NAS_port =~ s/^500//) {
        return $NAS_port;
    } else {
        $logger->warn("Unknown NAS-Port format. ifIndex translation could have failed. "
            ."VLAN re-assignment and switch/port accounting will be affected.");
    }
    return $NAS_port;
}   
    
=item getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut
sub getVoipVsa {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    return ('Cisco-AVPair' => "device-traffic-class=voice");
}

=item dot1xPortReauthenticate

Because of the incomplete 802.1X support of this switch, 
instead of issuing a re-negociation here we bounce if there's no VoIP device 
or set the VLAN and log if there is a VoIP device.

=cut
sub dot1xPortReauthenticate {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    $logger->info(
        "802.1X renegociation on this switch is not compatible with PacketFence. "
        . "If there's VoIP we will bounce the port otherwise we will re-assign VLAN directly. "
        . "If it doesn't work open a bug report with your hardware type. "
        . "switch: $this->{_ip} ifIndex: $ifIndex"
    );

    # TODO extract the following behavior in a method call in pf::vlan so it can be overridden easily
    # by following behavior I mean the "don't bounce on VoIP violations" behavior

    # If VoIP isn't enabled on this switch: bounce
    if (!$this->isVoIPEnabled()) {
        $logger->debug("VoIP is diabled on switch at $this->{_ip}. Will bounce ifIndex $ifIndex.");
        return $this->bouncePort($ifIndex);
    }

    # If there's no phone on the ifIndex, we also bounce
    my $hasPhone = $this->hasPhoneAtIfIndex($ifIndex);
    if ( !$hasPhone ) {
        $logger->debug("No VoIP is currently connected at $this->{_ip} ifIndex $ifIndex. Boucing ifIndex.");
        return $this->bouncePort($ifIndex);
    }

    # there's a phone, we need to fetch the MAC on the ifIndex in order to do a setVlan!
    my @locationlog = locationlog_view_open_switchport_no_VoIP( $this->{_ip}, $ifIndex );
    if (!(@locationlog) || !defined($locationlog[0]->{'mac'}) || ($locationlog[0]->{'mac'} eq '' )) {
        $logger->warn(
            "802.1X renegociation requested on $this->{_ip} ifIndex $ifIndex but can't determine non VoIP MAC"
        );
        return;
    }
    
    $logger->debug(
        "A VoIP phone is currently connected at $this->{_ip} ifIndex $ifIndex so the port will not be bounced. " . 
        "Changing VLAN and leaving everything as it is."
    );

    my $mac = $locationlog[0]->{'mac'};
    my $vlan_obj = new pf::vlan::custom();
    my ($vlan,$wasInline) = $vlan_obj->fetchVlanForNode($mac, $this, $ifIndex, $WIRED_802_1X);

    $this->_setVlan(
        $ifIndex, 
        $vlan,
        undef, 
        # TODO passing an empty switchlocker is not the best thing to do...
        {}
    );

    require pf::violation;
    my @violations = pf::violation::violation_view_open_desc($mac);
    if ( scalar(@violations) > 0 ) {
        my %message;
        $message{'subject'} = "VLAN isolation of $mac behind VoIP phone";
        $message{'message'} = "The following computer has been isolated behind a VoIP phone\n";
        $message{'message'} .= "MAC: $mac\n";

        require pf::node;
        my $node_info = pf::node::node_attributes($mac);
        $message{'message'} .= "Owner: " . $node_info->{'pid'} . "\n";
        $message{'message'} .= "Computer Name: " . $node_info->{'computername'} . "\n";
        $message{'message'} .= "Notes: " . $node_info->{'notes'} . "\n";
        $message{'message'} .= "Switch: " . $this->{'_ip'} . "\n";
        $message{'message'} .= "Port (ifIndex): " . $ifIndex . "\n\n";
        $message{'message'} .= "The violation details are\n";

        foreach my $violation (@violations) {
            $message{'message'} .= "Description: " . $violation->{'description'} . "\n";
            $message{'message'} .= "Start: " . $violation->{'start_date'} . "\n";
        }
        $logger->info("sending email to admin regarding isolation of $mac behind VoIP phone");
        pfmailer(%message);
    }
}

=item getPhonesLLDPAtIfIndex

Return list of MACs found through LLDP on a given ifIndex.

If this proves to be generic enough, it could be promoted to L<pf::SNMP>.
In that case, create a generic ifIndexToLldpLocalPort also.

=cut
sub getPhonesLLDPAtIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # if can't SNMP read abort
    return if ( !$this->connectRead() );

    #Transfer ifIndex to LLDP index
    my $lldpPort = $this->ifIndexToLldpLocalPort($ifIndex);
    if (!defined($lldpPort)) {
        $logger->info("Unable to lookup LLDP port from IfIndex. LLDP VoIP detection will not work. Is LLDP enabled?");
        return;
    }

    my $oid_lldpRemPortId = '1.0.8802.1.1.2.1.4.1.1.7';
    my $oid_lldpRemSysCapEnabled = '1.0.8802.1.1.2.1.4.1.1.12';

    $logger->trace(
        "SNMP get_next_request for lldpRemSysCapEnabled: "
        . "$oid_lldpRemSysCapEnabled.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort"
    );
    my $result = $this->{_sessionRead}->get_table(
        -baseoid => "$oid_lldpRemSysCapEnabled.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort"
    );
    # Cap entries look like this:
    # iso.0.8802.1.1.2.1.4.1.1.12.0.10.29 = Hex-STRING: 24 00
    # We want to validate that the telephone capability bit is turned on.
    my @phones = ();
    foreach my $oid ( keys %{$result} ) {

        # grab the lldpRemIndex
        if ( $oid =~ /^$oid_lldpRemSysCapEnabled\.[0-9]+\.$lldpPort\.([0-9]+)$/ ) {

            my $lldpRemIndex = $1;

            # make sure that what is connected is a VoIP phone based on lldpRemSysCapEnabled information
            if ( $this->getBitAtPosition($result->{$oid}, $SNMP::LLDP::TELEPHONE) ) {
                # we have a phone on the port. Get the MAC
                $logger->trace(
                    "SNMP get_request for lldpRemPortId: "
                    . "$oid_lldpRemPortId.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort.$lldpRemIndex"
                );
                my $portIdResult = $this->{_sessionRead}->get_request(
                    -varbindlist => [
                        "$oid_lldpRemPortId.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort.$lldpRemIndex"
                    ]
                );
                next if (!defined($portIdResult));
                if ($portIdResult->{"$oid_lldpRemPortId.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort.$lldpRemIndex"}
                        =~ /^0x([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})$/i) {
                    push @phones, lc("$1:$2:$3:$4:$5:$6");
                }
            }
        }
    }
    return @phones;
}

=item ifIndexToLldpLocalPort

Translate an ifIndex into an LLDP Local Port number.

We use ifDescr to lookup the lldpRemLocalPortNum in the lldpLocPortDesc table.

=cut
sub ifIndexToLldpLocalPort {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # if can't SNMP read abort
    return if ( !$this->connectRead() );

    my $ifDescr = $this->getIfDesc($ifIndex);
    return if (!defined($ifDescr) || $ifDescr eq '');

    my $oid_lldpLocPortDesc = '1.0.8802.1.1.2.1.3.7.1.4'; # from LLDP-MIB

    $logger->trace("SNMP get_table for lldpLocPortDesc: $oid_lldpLocPortDesc");
    my $result = $this->{_sessionRead}->get_table( -baseoid => $oid_lldpLocPortDesc);
    # here's what we are getting here. Looking for the last element of the OID: lldpRemLocalPortNum
    # iso.0.8802.1.1.2.1.3.7.1.4.10 = STRING: "FastEthernet1/0/8"
    # iso.0.8802.1.1.2.1.3.7.1.4.11 = STRING: "FastEthernet1/0/9"
    # iso.0.8802.1.1.2.1.3.7.1.4.12 = STRING: "FastEthernet1/0/10"
    # iso.0.8802.1.1.2.1.3.7.1.4.13 = STRING: "FastEthernet1/0/11"
    foreach my $entry ( keys %{$result} ) {
        if ( $result->{$entry} eq $ifDescr ) {
            if ( $entry =~ /^$oid_lldpLocPortDesc\.([0-9]+)$/ ) {
                return $1;
            }
        }
    }

    # nothing found
    return;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
