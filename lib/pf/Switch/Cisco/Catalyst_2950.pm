package pf::Switch::Cisco::Catalyst_2950;

=head1 NAME

pf::Switch::Cisco::Catalyst_2950 - Object oriented module to access and configure Cisco Catalyst 2950 switches

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

This module extends pf::Switch::Cisco.

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

use base ('pf::Switch::Cisco');
use Carp;
use Net::SNMP;
use Data::Dumper;

use pf::constants;
use pf::config qw(
    $ROLE_API_LEVEL
    $MAC
    $PORT
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);
use pf::locationlog;
sub description { 'Cisco Catalyst 2950' }

# importing switch constants
use pf::Switch::constants;
use pf::util;
use pf::config::util;
use pf::role::custom $ROLE_API_LEVEL;
use pf::Connection::ProfileFactory;

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
    my $self   = shift;
    my $logger = $self->logger;
    return '12.1(22)EA10';
}

sub getManagedPorts {
    my $self       = shift;
    my $logger     = $self->logger;
    my $oid_ifType = '1.3.6.1.2.1.2.2.1.3';                     # MIB: ifTypes
    my $oid_ifName = '1.3.6.1.2.1.31.1.1.1.1';
    my @nonUpLinks;
    my @UpLinks = $self->getUpLinks();    # fetch the UpLink list

    if ( !$self->connectRead() ) {
        return @nonUpLinks;
    }
    $logger->trace("SNMP get_table for ifType: $oid_ifType");
    my $ifTypes = $self->{_sessionRead}
        ->get_table(    # fetch the ifTypes list of the ports
        -baseoid => $oid_ifType
        );
    if ( defined($ifTypes) ) {

        foreach my $port ( keys %{$ifTypes} ) {
            if ( $ifTypes->{$port} == $SNMP::ETHERNET_CSMACD )
            {           # skip non ethernetCsmacd port type

                $port =~ /^$oid_ifType\.(\d+)$/;
                if ( grep( { $_ == $1 } @UpLinks ) == 0 ) {    # skip UpLinks

                    my $portVlan = $self->getVlan($1);
                    if ( defined $portVlan ) {    # skip port with no VLAN

                        my $port_type = $self->getVmVlanType($1);
                        if ( ( $port_type == 1 ) || ( $port_type == 4 ) )
                        {                         # skip non static

                            if (grep(
                                    { $_ == $portVlan } values %{ $self->{_vlans} } )
                                != 0 )
                            {    # skip port in a non-managed VLAN
                                $logger->trace(
                                    "SNMP get_request for ifName: $oid_ifName.$1"
                                );
                                my $ifNames
                                    = $self->{_sessionRead}->get_request(
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
    my ( $self, @macAddr ) = @_;
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
    my ( $self, $ifIndex, $vlan ) = @_;
    my $command;
    my $session;
    my $oid_ifName = '1.3.6.1.2.1.31.1.1.1.1';
    my $logger     = $self->logger;

    eval {
        require Net::Appliance::Session;
        $session = Net::Appliance::Session->new(
            Host      => $self->{_ip},
            Timeout   => 5,
            Transport => $self->{_cliTransport}
        );
        $session->connect(
            Name     => $self->{_cliUser},
            Password => $self->{_cliPwd}
        );
        # Session not already privileged are not supported at this point. See #1370
        # $session->begin_privileged( $self->{_cliEnablePwd} );
    };

    if ($@) {
        $logger->error(
            "ERROR: Can not connect to switch $self->{'_ip'} using "
                . $self->{_cliTransport} );
        return 0;
    }

    # First we fetch ifName(ifIndex)
    if ( !$self->connectRead() ) {
        return 0;
    }
    $logger->trace("SNMP get_request for ifName: $oid_ifName");
    my $ifNames = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$oid_ifName.$ifIndex"] );
    my $port = $ifNames->{"$oid_ifName.$ifIndex"};

    # then we clear the table with for ifDescr
    $command = "clear mac-address-table interface $port vlan $vlan";

    eval { $session->cmd( String => $command, Timeout => '10' ); };
    if ($@) {
        $logger->error(
            "ERROR: Error while clearing MAC Address table on port $ifIndex for switch $self->{'_ip'} using "
                . $self->{_cliTransport} );
        $session->close();
        return;
    }
    $session->close();
    return 1;
}

sub getAllSecureMacAddresses {
    my ($self) = @_;
    my $logger = $self->logger;
    my $oid_cpsSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.2.1.4';

    my $secureMacAddrHashRef = {};
    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for cpsSecureMacAddrRowStatus: $oid_cpsSecureMacAddrRowStatus"
    );
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsSecureMacAddrRowStatus" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$oid_cpsSecureMacAddrRowStatus\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x",
                $2, $3, $4, $5, $6, $7 );
            my $ifIndex = $1;
            my $oldVlan = $self->getVlan($ifIndex);
            push @{ $secureMacAddrHashRef->{$oldMac}->{$ifIndex} }, $oldVlan;
        }
    }

    return $secureMacAddrHashRef;
}

sub isDynamicPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger                   = $self->logger;
    my $oid_cpsSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.2.1.2';

    if ( !$self->connectRead() ) {
        return 0;
    }
    if ( !$self->isPortSecurityEnabled($ifIndex) ) {
        $logger->debug("port security is not enabled");
        return 0;
    }

    $logger->trace(
        "SNMP get_table for cpsSecureMacAddrType: $oid_cpsSecureMacAddrType");
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsSecureMacAddrType.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $result->{$oid_including_mac} == 1 ) {
            return 0;
        }
    }

    return 1;
}

sub isStaticPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger                   = $self->logger;
    my $oid_cpsSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.2.1.2';

    if ( !$self->connectRead() ) {
        return 0;
    }
    if ( !$self->isPortSecurityEnabled($ifIndex) ) {
        $logger->debug("port security is not enabled");
        return 0;
    }

    $logger->trace(
        "SNMP get_table for cpsSecureMacAddrType: $oid_cpsSecureMacAddrType");
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsSecureMacAddrType.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $result->{$oid_including_mac} == 1 ) {
            return 1;
        }
    }

    return 0;
}

sub getSecureMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $oid_cpsSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.2.1.4';

    my $secureMacAddrHashRef = {};
    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for cpsSecureMacAddrRowStatus: $oid_cpsSecureMacAddrRowStatus"
    );
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsSecureMacAddrRowStatus.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$oid_cpsSecureMacAddrRowStatus\.$ifIndex\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x",
                $1, $2, $3, $4, $5, $6 );
            my $oldVlan = $self->getVlan($ifIndex);
            push @{ $secureMacAddrHashRef->{$oldMac} }, $oldVlan;
        }
    }

    return $secureMacAddrHashRef;
}

sub authorizeMAC {
    my ( $self, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = $self->logger;
    my $oid_cpsSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.2.1.4';

    if ( !$self->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't add an entry to the SecureMacAddrTable"
        );
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $voiceVlan = $self->getVoiceVlan($ifIndex);
    if ( ( $deauthVlan == $voiceVlan ) || ( $authVlan == $voiceVlan ) ) {
        $logger->error(
            "ERROR: authorizeMAC called with voice VLAN .... this should not have happened ... we won't add an entry to the SecureMacAddrTable"
        );
        return 1;
    }

    my @oid_value;
    if ($deauthMac) {
        my $completeOid = $oid_cpsSecureMacAddrRowStatus . "." . $ifIndex . "." . mac2dec($deauthMac);
        push @oid_value, ( $completeOid, Net::SNMP::INTEGER, 6 );
    }

    if ($authMac) {
        my $completeOid = $oid_cpsSecureMacAddrRowStatus . "." . $ifIndex . "." . mac2dec($authMac);
        push @oid_value, ( $completeOid, Net::SNMP::INTEGER, 4 );
    }

    if ( scalar(@oid_value) > 0 ) {
        $logger->trace("SNMP set_request for cpsSecureMacAddrRowStatus");
        my $result = $self->{_sessionWrite}->set_request( -varbindlist => \@oid_value );
        if (!$result) {
             $logger->error("SNMP error tyring to perform auth of $authMac "
                                          . "Error message: ".$self->{_sessionWrite}->error());
            return 0;
        }
    }

    return 1;
}

sub getMaxMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    #CISCO-PORT-SECURITY-MIB
    my $OID_cpsIfPortSecurityEnable = '1.3.6.1.4.1.9.9.315.1.2.1.1.1';
    my $OID_cpsIfMaxSecureMacAddr   = '1.3.6.1.4.1.9.9.315.1.2.1.1.3';

    if ( !$self->connectRead() ) {
        return -1;
    }

    #determine if port security is enabled
    $logger->trace(
        "SNMP get_request for cpsIfPortSecurityEnable: $OID_cpsIfPortSecurityEnable.$ifIndex"
    );
    my $result = $self->{_sessionRead}->get_request(
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
    $result = $self->{_sessionRead}->get_request(
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

{  # disable warnings to get unit tests to pass
no warnings;
sub ping {
    my ( $self, $ip ) = @_;
    my $session;
    my $logger = $self->logger;

    eval {
        require Net::Appliance::Session;
        $session = Net::Appliance::Session->new(
            Host      => $self->{_ip},
            Timeout   => 5,
            Transport => $self->{_cliTransport}
        );
        $session->connect(
            Name     => $self->{_cliUser},
            Password => $self->{_cliPwd}
        );
    };

    if ($@) {
        $logger->error(
            "ERROR: Can not connect to switch $self->{'_ip'} using "
                . $self->{_cliTransport} );
        return 1;
    }

    # Session not already privileged are not supported at this point. See #1370
    #if ( !$session->begin_privileged( $self->{_cliEnablePwd} ) ) {
    #    $logger->error( "ERROR: Cannot enable: " . $session->errmsg );
    #    $session->close();
    #    return 1;
    #}

    $session->cmd("ping $ip timeout 0 repeat 1");
    $session->close();

    return 1;
}
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
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    my $maxSecureMacTotal;
    my $maxSecureMacVlanAccess = 1;

    if ($self->isVoIPEnabled()) {

        # switchport port-security maximum 2
        $maxSecureMacTotal = 2;
        $self->setPortSecurityMaxSecureMacAddrByIfIndex($ifIndex,$maxSecureMacTotal);

        # switchport port-security maximum 1 vlan access
        $self->setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex($ifIndex,$maxSecureMacVlanAccess);
    } else {

        # switchport port-security maximum 1
        $maxSecureMacTotal = 1;
        $self->setPortSecurityMaxSecureMacAddrByIfIndex($ifIndex,$maxSecureMacTotal);
    }

    # switchport port-security violation restrict
    $self->setPortSecurityViolationActionByIfIndex($ifIndex, $CISCO::DROPNOTIFY);

    # switchport port-security mac-adress xxxx.xxxx.xxxx
    my $macToAuthorize;
    my @macArray = $self->_getMacAtIfIndex($ifIndex);
    if ( !@macArray ) {
        $macToAuthorize = $self->generateFakeMac(0, $ifIndex);
    } else {
        $macToAuthorize = $macArray[0];
    }
    my $vlan = $self->getVlan($ifIndex);
    $self->authorizeMAC( $ifIndex, undef, $macToAuthorize, $vlan, $vlan);

    # switchport port-security
    $self->setPortSecurityEnableByIfIndex($ifIndex, $TRUE);
    return 1;
}

=item disablePortSecurityByIfIndex - remove all the port-security settings on a port

=cut

sub disablePortSecurityByIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    # no switchport port-security
    if (! $self->setPortSecurityEnableByIfIndex($ifIndex, $FALSE)) {
        $logger->error("An error occured while disablling port-security on ifIndex $ifIndex");
        return 0;
    }

    # no switchport port-security violation restrict
    if (! $self->setPortSecurityViolationActionByIfIndex($ifIndex, $CISCO::SHUTDOWN)) {
        $logger->error("An error occured while disablling port-security violation restrict in ifIndex $ifIndex");
        return 0;
    }

    # no switchport port-security mac-adress xxxx.xxxx.xxxx
    my $secureMacHashRef = $self->getSecureMacAddresses($ifIndex);
    my $valid = (ref($secureMacHashRef) eq 'HASH');
    my $mac_count = scalar(keys %{$secureMacHashRef});
    if ($valid && $mac_count >= 1) {
        foreach my $macToDeAuthorize (keys %{$secureMacHashRef}) {
            my $vlan = $self->getVlan($ifIndex);
            if (! $self->authorizeMAC( $ifIndex, $macToDeAuthorize, undef, $vlan, $vlan)) {
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
    my ( $self, $ifIndex, $enable ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->warn("Should set IfPortSecurityEnable on $ifIndex to $enable but the switch is not in production -> Do nothing");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_cpsIfPortSecurityEnable = '1.3.6.1.4.1.9.9.315.1.2.1.1.1';
    my $truthValue = $enable ? $SNMP::TRUE : $SNMP::FALSE;

    $logger->trace("SNMP set_request for cpsIfPortSecurityEnable: $OID_cpsIfPortSecurityEnable");
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_cpsIfPortSecurityEnable.$ifIndex", Net::SNMP::INTEGER, $truthValue ] );
    return ( defined($result) );
}

=item setPortSecurityMaxSecureMacAddrByIfIndex

Sets the global (data + voice) maximum number of MAC addresses for port-security on a port

=cut

sub setPortSecurityMaxSecureMacAddrByIfIndex {
    my ( $self, $ifIndex, $maxSecureMac ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->warn("Should set IfMaxSecureMacAddr on $ifIndex to $maxSecureMac but the switch is not in production -> Do nothing");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_cpsIfMaxSecureMacAddr = '1.3.6.1.4.1.9.9.315.1.2.1.1.3';

    $logger->trace("SNMP set_request for IfMaxSecureMacAddr: $OID_cpsIfMaxSecureMacAddr");
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_cpsIfMaxSecureMacAddr.$ifIndex", Net::SNMP::INTEGER, $maxSecureMac ] );
   return ( defined($result) );
}

=item setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex

Wraps around _setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex by spawning
a process to call it thus working around bug #1369: thread crash with
floating network devices with VoIP through SSH transport

=cut

sub setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex {
    my ( $self, $ifIndex, $maxSecureMac ) = @_;
    my $logger = $self->logger;

    # we spawn a shell to workaround a thread safety bug in Net::Appliance::Session when using SSH transport
    # http://www.cpanforum.com/threads/6909

    my $command =
        "/usr/local/pf/bin/pfcmd_vlan -switch $self->{_ip} "
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
    my ( $self, $ifIndex, $maxSecureMac ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->warn("Should set IfMaxSecureMacAddrPerVlan on $ifIndex to $maxSecureMac but the switch is not in production -> Do nothing");
        return 1;
    }

    my $ifName = $self->getIfName($ifIndex);
    if ($ifName eq '') {
        $logger->error( "Can not read ifName for ifIndex $ifIndex, Port-Security maximum can not be set on data Vlan");
        return 0;
    }

    my $session;
    eval {
        require Net::Appliance::Session;
        $session = Net::Appliance::Session->new(
            Host      => $self->{_ip},
            Timeout   => 5,
            Transport => $self->{_cliTransport}
        );
        $session->connect(
            Name     => $self->{_cliUser},
            Password => $self->{_cliPwd}
        );
    };

    if ($@) {
        $logger->error("Error connecting to " . $self->{'_ip'} . " using ".$self->{_cliTransport} . ". Error: $!");
    }

    # Session not already privileged are not supported at this point. See #1370
    # are we in enabled mode?
    #if (!$session->in_privileged_mode()) {

    #    # let's try to enable
    #    if (!$session->enable($self->{_cliEnablePwd})) {
    #        $logger->error("Cannot get into privileged mode on ".$self->{'ip'}.
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
    my ( $self, $ifIndex, $action ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->warn("Should set IfViolationAction on $ifIndex to $action but the switch is not in production -> Do nothing");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_cpsIfViolationAction = '1.3.6.1.4.1.9.9.315.1.2.1.1.8';

    $logger->trace("SNMP set_request for IfViolationAction: $OID_cpsIfViolationAction");
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_cpsIfViolationAction.$ifIndex", Net::SNMP::INTEGER, $action ] );
    return ( defined($result) );

}

=item setTaggedVlans

Allows all the tagged Vlans on a multi-Vlan port. Used for floating network devices only

=cut

sub setTaggedVlans {
    my ( $self, $ifIndex, $switch_locker, @vlans ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port vlanTrunkPortVlansEnabled");
        return 1;
    }

    if (! @vlans) {
        $logger->error("Tagged Vlan list is empty. Cannot set the tagged Vlans on trunk port $ifIndex");
        return 0;
    }

    if ( !$self->connectWrite() ) {
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
    my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
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
    my ( $self, $ifIndex, $switch_locker) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port OID_vlanTrunkPortVlansEnabled");
        return 1;
    }

    if ( !$self->connectWrite() ) {
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
    my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
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
    my ($self, $mac, $switch_port, $switch_locker, $taggedVlans)  = @_;
    my $logger = $self->logger;

    # switchport mode trunk
    $logger->info("Setting port $switch_port as trunk.");
    if (! $self->setModeTrunk($switch_port, $TRUE)) {
        $logger->error("An error occured while enabling port $switch_port as multi-vlan (trunk)");
        return 0;
    }

    # switchport trunk allowed vlan x,y,z
    $logger->info("Allowing tagged Vlans on port $switch_port");
    if (! $self->setTaggedVlans($switch_port, $switch_locker, split(",", $taggedVlans)) ) {
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
    my ($self, $NAS_port) = @_;
    my $logger = $self->logger;

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
    my ($self) = @_;
    my $logger = $self->logger;

    return ('Cisco-AVPair' => "device-traffic-class=voice");
}

=item dot1xPortReauthenticate

Because of the incomplete 802.1X support of this switch,
instead of issuing a re-negociation here we bounce if there's no VoIP device
or set the VLAN and log if there is a VoIP device.

=cut

sub dot1xPortReauthenticate {
    my ($self, $ifIndex, $mac) = @_;
    my $logger = $self->logger;

    $logger->info(
        "802.1X renegociation on this switch is not compatible with PacketFence. "
        . "If there's VoIP we will bounce the port otherwise we will re-assign VLAN directly. "
        . "If it doesn't work open a bug report with your hardware type. "
        . "switch: $self->{_ip} ifIndex: $ifIndex"
    );

    # TODO extract the following behavior in a method call in pf::role so it can be overridden easily
    # by following behavior I mean the "don't bounce on VoIP violations" behavior

    # If VoIP isn't enabled on this switch: bounce
    if (!$self->isVoIPEnabled()) {
        $logger->debug("VoIP is diabled on switch at $self->{_ip}. Will bounce ifIndex $ifIndex.");
        return $self->bouncePort($ifIndex);
    }

    # If there's no phone on the ifIndex, we also bounce
    my $hasPhone = $self->hasPhoneAtIfIndex($ifIndex);
    if ( !$hasPhone ) {
        $logger->debug("No VoIP is currently connected at $self->{_ip} ifIndex $ifIndex. Boucing ifIndex.");
        return $self->bouncePort($ifIndex);
    }

    # there's a phone, we need to fetch the MAC on the ifIndex in order to do a setVlan!
    my @locationlog = locationlog_view_open_switchport_no_VoIP( $self->{_ip}, $ifIndex );
    if (!(@locationlog) || !defined($locationlog[0]->{'mac'}) || ($locationlog[0]->{'mac'} eq '' )) {
        $logger->warn(
            "802.1X renegociation requested on $self->{_ip} ifIndex $ifIndex but can't determine non VoIP MAC"
        );
        return;
    }

    $logger->debug(
        "A VoIP phone is currently connected at $self->{_ip} ifIndex $ifIndex so the port will not be bounced. " .
        "Changing VLAN and leaving everything as it is."
    );

    $mac = $locationlog[0]->{'mac'};
    my $role_obj = new pf::role::custom();

    my $role = $role_obj->fetchRoleForNode({ mac => $mac, node_info => pf::node::node_attributes($mac), switch => $self, ifIndex => $ifIndex, connection_type => $WIRED_802_1X, profile => pf::Connection::ProfileFactory->instantiate($mac)});
    my $vlan = $self->getVlanByName($role->{role});
    $self->_setVlan(
        $ifIndex,
        $vlan,
        undef,
        # TODO passing an empty switchlocker is not the best thing to do...
        {}
    );

    require pf::security_event;
    my @security_events = pf::security_event::security_event_view_open_desc($mac);
    if ( scalar(@security_events) > 0 ) {
        my %message;
        $message{'subject'} = "VLAN isolation of $mac behind VoIP phone";
        $message{'message'} = "The following computer has been isolated behind a VoIP phone\n";
        $message{'message'} .= "MAC: $mac\n";

        require pf::node;
        my $node_info = pf::node::node_attributes($mac);
        $message{'message'} .= "Owner: " . $node_info->{'pid'} . "\n";
        $message{'message'} .= "Computer Name: " . $node_info->{'computername'} . "\n";
        $message{'message'} .= "Notes: " . $node_info->{'notes'} . "\n";
        $message{'message'} .= "Switch: " . $self->{'_ip'} . "\n";
        $message{'message'} .= "Port (ifIndex): " . $ifIndex . "\n\n";
        $message{'message'} .= "The security event details are\n";

        foreach my $security_event (@security_events) {
            $message{'message'} .= "Description: " . $security_event->{'description'} . "\n";
            $message{'message'} .= "Start: " . $security_event->{'start_date'} . "\n";
        }
        $logger->info("sending email to admin regarding isolation of $mac behind VoIP phone");
        pfmailer(%message);
    }
}

=item getPhonesLLDPAtIfIndex

Return list of MACs found through LLDP on a given ifIndex.

If this proves to be generic enough, it could be promoted to L<pf::Switch>.
In that case, create a generic ifIndexToLldpLocalPort also.

=cut

sub getPhonesLLDPAtIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    # if can't SNMP read abort
    return if ( !$self->connectRead() );

    #Transfer ifIndex to LLDP index
    my $lldpPort = $self->ifIndexToLldpLocalPort($ifIndex);
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
    my $result = $self->{_sessionRead}->get_table(
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
            if ( $self->getBitAtPosition($result->{$oid}, $SNMP::LLDP::TELEPHONE) ) {
                # we have a phone on the port. Get the MAC
                $logger->trace(
                    "SNMP get_request for lldpRemPortId: "
                    . "$oid_lldpRemPortId.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort.$lldpRemIndex"
                );
                my $portIdResult = $self->{_sessionRead}->get_request(
                    -varbindlist => [
                        "$oid_lldpRemPortId.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort.$lldpRemIndex"
                    ]
                );
                next if (!defined($portIdResult));
                if ($portIdResult->{"$oid_lldpRemPortId.$CISCO::DEFAULT_LLDP_REMTIMEMARK.$lldpPort.$lldpRemIndex"}
                        =~ /^(?:0x)?([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})(?::..)?$/i) {
                    push @phones, lc("$1:$2:$3:$4:$5:$6");
                }
            }
        }
    }
    return @phones;
}

=item getIfIndexByNasPortId

Fetch the ifindex on the switch by NAS-Port-Id radius attribute

=cut

sub getIfIndexByNasPortId {
    my ($self, $ifDesc_param) = @_;

    if ( !$self->connectRead() || !defined($ifDesc_param)) {
        return 0;
    }

    my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';
    my $ifDescHashRef;
    my $result = $self->cachedSNMPTable([-baseoid => $OID_ifDesc]);
    foreach my $key ( keys %{$result} ) {
        my $ifDesc = $result->{$key};
        if ( $ifDesc =~ /^$ifDesc_param$/i ) {
            $key =~ /^$OID_ifDesc\.(\d+)$/;
            return $1;
        }
    }
}

=item getRelayAgentInfoOptRemoteIdSub

Return the RelayAgentInfoOptRemoteIdSub to match with switch mac in dhcp option 82

=cut

sub getRelayAgentInfoOptRemoteIdSub {
    my ($self) = @_;
    my $oid_cdsRelayAgentInfoOptRemoteIdSub = '1.3.6.1.4.1.9.9.380.1.1.8.0';
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return undef;
    }
    $logger->trace("SNMP get_request for cdsRelayAgentInfoOptRemoteIdSub: $oid_cdsRelayAgentInfoOptRemoteIdSub");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => [$oid_cdsRelayAgentInfoOptRemoteIdSub] );
    my $cdsRelayAgentInfoOptRemoteIdSub = $result->{$oid_cdsRelayAgentInfoOptRemoteIdSub};
    $cdsRelayAgentInfoOptRemoteIdSub =~ s/^0x//i;
    my $mac = clean_mac($cdsRelayAgentInfoOptRemoteIdSub);
    return $mac if ($mac);
}

=back

=head1 AUTHOR

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
