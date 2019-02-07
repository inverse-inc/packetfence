package pf::Switch::Nortel;

=head1 NAME

pf::Switch::Nortel - Object oriented module to access SNMP enabled Nortel switches

=head1 SYNOPSIS

The pf::Switch::Nortel module implements an object oriented interface
to access SNMP enabled Nortel switches.

=head1 BUGS AND LIMITATIONS

=over

=item BayStack stacking issues

Sometimes switches that were previously in a stacked setup will report
security violations as if they were still stacked.
You will notice security authorization made on wrong ifIndexes.
A factory reset / reconfiguration will resolve the situation.
We experienced the issue with a BayStack 470 running 3.7.5.13 but we believe it affects other BayStacks and firmwares.

=item Hard to predict OIDs seen on some variants

We faced issues where some switches (ie ERS2500) insisted on having a board index of 1 when adding a MAC to the security table although for most other operations the board index was 0.
Our attempted fix is to always consider the board index to start with 1 on the operations touching secuirty status (isPortSecurity and authorizeMAC).
Be aware of that if you start to see MAC authorization failures and report the problem to us, we might have to do a per firmware or per device implementation instead.

=back

=cut

use strict;
use warnings;

use Net::SNMP;

use base ('pf::Switch');

use pf::constants;
use pf::constants::role qw($VOICE_ROLE);
use pf::Switch::constants;
use pf::util;

=head1 CAPABILITIES

=over

=item supportsFloatingDevice

=cut

sub supportsFloatingDevice { return $TRUE; }

# special features
sub supportsLldp { return $TRUE; }

#
# %TRAP_NORMALIZERS
# A hash of nortel trap normalizers
# Use the following convention when adding a normalizer
# <nameOfTrapNotificationType>TrapNormalizer
#
our %TRAP_NORMALIZERS = (
   '.1.3.6.1.4.1.45.1.6.2.1.0.5' => 's5EtrSbsMacAccessViolationTrapNormalizer',
);

=back

=head1 METHODS

TODO: This list is incomplete

=over

=cut

sub getVersion {
    my ($self) = @_;
    my $oid_s5ChasVer = '1.3.6.1.4.1.45.1.6.3.1.5.0';
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return '';
    }

    $logger->trace("SNMP get_request for s5ChasVer: $oid_s5ChasVer");

    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_s5ChasVer] );
    if ( exists( $result->{$oid_s5ChasVer} ) && ( $result->{$oid_s5ChasVer} ne 'noSuchInstance' ) ) {
        return $result->{$oid_s5ChasVer};
    }
    return '';
}

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;
    if ( $trapString
        =~ /^BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = INTEGER: \d+\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.7\.\d+ = INTEGER: [^|]+\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.8\.\d+ = INTEGER: [^)]+\)/
        )
    {
        $trapHashRef->{'trapType'} = ( ( $1 == 2 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
    } elsif ( $trapString
        =~ /\|\.1\.3\.6\.1\.4\.1\.45\.1\.6\.5\.3\.12\.1\.3\.(\d+)\.(\d+) = $SNMP::MAC_ADDRESS_FORMAT/) {

        $trapHashRef->{'trapType'} = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = ( $1 - $self->getFirstBoardIndex() ) * $self->getBoardIndexWidth() + $2;
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($3);
        $trapHashRef->{'trapVlan'} = $self->getVlan( $trapHashRef->{'trapIfIndex'} );

        if ($trapHashRef->{'trapIfIndex'} <= 0) {
            $logger->warn(
                "Trap ifIndex is invalid. Should this switch be factory-reset? "
                . "See Nortel's BayStack Stacking issues in module documentation for more information."
            );
        }

        $logger->debug(
            "ifIndex for " . $trapHashRef->{'trapMac'} . " on switch " . $self->{_ip}
            . " is " . $trapHashRef->{'trapIfIndex'}
        );

    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

=item isTrunkPort

Warning: MIB says 1 is access, 2 is trunk but we've encountered other values.

=cut

sub isTrunkPort {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return;
    }

    my $oid_rcVlanPortType = '1.3.6.1.4.1.2272.1.3.3.1.4'; #RC-VLAN-MIB
    $logger->trace("SNMP get_table for rcVlanPortType: $oid_rcVlanPortType");

    my $result = $self->{_sessionRead}->get_request( -varbindlist => ["$oid_rcVlanPortType.$ifIndex"] );

    # Error handling
    if (!defined($result)) {
        $logger->warn("Asking for port information failed with " . $self->{_sessionRead}->error());
        return;
    }

    if (!defined($result->{"$oid_rcVlanPortType.$ifIndex"})) {
        $logger->error("Returned value doesn't exist!");
        return;
    }

    if ($result->{"$oid_rcVlanPortType.$ifIndex"} eq 'noSuchInstance') {
        $logger->warn("Asking for port information failed with noSuchInstance");
        return;
    }

    # it's a trunk
    return $TRUE if ($result->{"$oid_rcVlanPortType.$ifIndex"} == $NORTEL::TRUNK);

    # otherwise
    return $FALSE;
}

sub getTrunkPorts {
    my ($self) = @_;
    my $OID_rcVlanPortType = '1.3.6.1.4.1.2272.1.3.3.1.4'; #RC-VLAN-MIB
    my @trunkPorts;
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return -1;
    }
    $logger->trace("SNMP get_table for rcVlanPortType: $OID_rcVlanPortType");
    my $result = $self->{_sessionRead}->get_table( -baseoid => $OID_rcVlanPortType );
    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            if ( $result->{$key} == $NORTEL::TRUNK ) {
                $key =~ /^$OID_rcVlanPortType\.(\d+)$/;
                push @trunkPorts, $1;
                $logger->info( "Switch " . $self->{_ip} . " trunk port: $1" );
            }
        }
    } else {
        $logger->warn( "Problem while reading rcVlanPortType for switch " . $self->{_ip} );
        return -1;
    }
    return @trunkPorts;
}

sub getUpLinks {
    my ($self) = @_;
    my @upLinks;

    if ( lc(@{ $self->{_uplink} }[0]) eq 'dynamic' ) {
        @upLinks = $self->getTrunkPorts();
    } else {
        @upLinks = @{ $self->{_uplink} };
    }
    return @upLinks;
}

=item setModeTrunk

Set a port as mode access or mode trunk based on ifIndex given.

=cut

sub setModeTrunk {
    my ( $self, $ifIndex, $setTrunk ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port's trunk mode");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return;
    }

    # Using UNTAG_PVID_ONLY instead of ACCESS here because it works under 'strict' VLAN mode
    my $setMode = $setTrunk ? $NORTEL::TRUNK : $NORTEL::UNTAG_PVID_ONLY;

    my $oid_rcVlanPortType = '1.3.6.1.4.1.2272.1.3.3.1.4'; #RC-VLAN-MIB
    $logger->trace("SNMP set_request for rcVlanPortType: $oid_rcVlanPortType");
    my $result = $self->{_sessionWrite}->set_request( -varbindlist =>
        [ "$oid_rcVlanPortType.$ifIndex", Net::SNMP::INTEGER, $setMode ]
    );

    # if $result is defined, it works we can return $TRUE
    return $TRUE if (defined($result));

    # otherwise report failure
    $logger->warn("changing port mode failed with " . $self->{_sessionWrite}->error());
    return;
}

=item getVoiceVlan

In what VLAN should a VoIP device be?

=cut

sub getVoiceVlan {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;

    my $voiceVlan = $self->getVlanByName($VOICE_ROLE);
    if (defined($voiceVlan)) {
        return $voiceVlan;
    }

    # otherwise say it didn't work
    $logger->warn("Voice VLAN was requested but it's not configured!");
    return -1;
}

sub getVlans {
    my $self = shift;
    my $logger = $self->logger;
    my $OID_rcVlanName = '1.3.6.1.4.1.2272.1.3.2.1.2'; #RC-VLAN-MIB
    my $vlans = {};
    if ( !$self->connectRead() ) {
        return $vlans;
    }

    $logger->trace("SNMP get_table for rcVlanName: $OID_rcVlanName");
    my $result
        = $self->{_sessionRead}->get_table( -baseoid => $OID_rcVlanName );

    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            $key =~ /^$OID_rcVlanName\.(\d+)$/;
            $vlans->{$1} = $result->{$key};
        }
    }
    return $vlans;

}

sub isDefinedVlan {
    my ( $self, $vlan ) = @_;
    my $logger = $self->logger;
    my $OID_rcVlanName = '1.3.6.1.4.1.2272.1.3.2.1.2'; #RC-VLAN-MIB
    if ( !$self->connectRead() ) {
        return 0;
    }

    $logger->trace("SNMP get_request for rcVlanName: $OID_rcVlanName.$vlan");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_rcVlanName.$vlan"] );

    return ( defined($result)
            && exists( $result->{"$OID_rcVlanName.$vlan"} )
            && ( $result->{"$OID_rcVlanName.$vlan"} ne 'noSuchInstance' ) );
}

sub getAllVlans {
    my ( $self, @ifIndexes ) = @_;
    my $logger = $self->logger;
    my $vlanHashRef;
    if ( !@ifIndexes ) {
        @ifIndexes = $self->getManagedIfIndexes();
    }

    my $OID_rcVlanPortDefaultVlanId
        = '1.3.6.1.4.1.2272.1.3.3.1.7'; # RC-VLAN-MIB
    if ( !$self->connectRead() ) {
        return $vlanHashRef;
    }
    $logger->trace(
        "SNMP get_table for rcVlanPortDefaultVlanId: $OID_rcVlanPortDefaultVlanId"
    );
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => $OID_rcVlanPortDefaultVlanId );
    foreach my $key ( keys %{$result} ) {
        my $vlan = $result->{$key};
        $key =~ /^$OID_rcVlanPortDefaultVlanId\.(\d+)$/;
        my $ifIndex = $1;
        if ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) {
            $vlanHashRef->{$ifIndex} = $vlan;
        }
    }
    return $vlanHashRef;
}

sub getVlan {
    my ( $self, $ifIndex ) = @_;
    my $OID_rcVlanPortDefaultVlanId
        = '1.3.6.1.4.1.2272.1.3.3.1.7'; # RC-VLAN-MIB
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    $logger->trace(
        "SNMP get_request for rcVlanPortDefaultVlanId: $OID_rcVlanPortDefaultVlanId.$ifIndex"
    );
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => ["$OID_rcVlanPortDefaultVlanId.$ifIndex"] );
    return $result->{"$OID_rcVlanPortDefaultVlanId.$ifIndex"};
}

sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $OID_rcVlanPortMembers = '1.3.6.1.4.1.2272.1.3.2.1.11'; #RC-VLAN-MIB
    my $OID_rcVlanPortDefaultVlanId = '1.3.6.1.4.1.2272.1.3.3.1.7'; #RC-VLAN-MIB
    my $logger = $self->logger;
    my $result;

    if ( !$self->connectRead() ) {
        return 0;
    }
    if ( !$self->connectWrite() ) {
        return 0;
    }

    {
        my $lock = $self->getExclusiveLock();

        $logger->trace("SNMP get_request for rcVlanPortMembers");
        $self->{_sessionRead}->translate(0);
        $result = $self->{_sessionRead}->get_request(
            -varbindlist => [
                "$OID_rcVlanPortMembers.$oldVlan",
                "$OID_rcVlanPortMembers.$newVlan"
            ]
        );
        $self->{_sessionRead}->translate(1);
        my $oldPortMembers = $self->modifyBitmask( $result->{"$OID_rcVlanPortMembers.$oldVlan"}, $ifIndex, 0 );
        my $newPortMembers = $self->modifyBitmask( $result->{"$OID_rcVlanPortMembers.$newVlan"}, $ifIndex, 1 );


        $logger->trace( "SNMP set_request for OID_rcVlanPortMembers: $OID_rcVlanPortMembers");
        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_rcVlanPortMembers.$newVlan", Net::SNMP::OCTET_STRING, $newPortMembers,
                "$OID_rcVlanPortMembers.$oldVlan", Net::SNMP::OCTET_STRING, $oldPortMembers,
                "$OID_rcVlanPortDefaultVlanId.$ifIndex", Net::SNMP::INTEGER, $newVlan
            ]
        );
    }
    $logger->trace( "locking - \$switch_locker{" . $self->{_ip} . "} unlocked in _setVlan" );

    # if $result is defined, it works we can return $TRUE
    return $TRUE if (defined($result));

    # otherwise report failure
    $logger->warn("setting VLAN failed with " . $self->{_sessionWrite}->error());
    return;
}

=item getBoardIndexWidth

How many ifIndex there is per board.
It changed with a firmware upgrade so it is encapsulated per switch module.

Default is 64

=cut

sub getBoardIndexWidth {
    return 64;
}

=item getFirstBoardIndex

First board id varies from one BayStack to another based on what seems to be cosmic rays.
This method is useful to work-around that problem.

Should return either 0 or 1

=cut

sub getFirstBoardIndex {
    my ($self) = @_;
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return 1;
    }

    my $OID_s5SbsAuthCfgBrdIndx = '1.3.6.1.4.1.45.1.6.5.3.10.1.1';
    my $result = $self->{_sessionRead}->get_next_request(-varbindlist => [$OID_s5SbsAuthCfgBrdIndx]);

    my $firstIndx;
    foreach my $key ( sort keys %{$result} ) {
        if ($key =~ /^$OID_s5SbsAuthCfgBrdIndx\.(\d+)/) {
            $firstIndx = $1;
            last;
        }
    }

    if (!defined($firstIndx)) {
        $logger->warn("unable to fetch first board index. Will assume it's 1");
        return 1;
    }

    if ($firstIndx > 1) {
        $logger->warn(
            "first board index is greater than 1. Should this switch be factory-reset? "
            . "See Nortel's BayStack Stacking issues in module documentation for more information."
        );
    }

    return $firstIndx;
}

sub getBoardPortFromIfIndex {
    my ( $self, $ifIndex ) = @_;

    my $board = ($self->getFirstBoardIndex() + int( $ifIndex / $self->getBoardIndexWidth() ));
    my $port = ( $ifIndex % $self->getBoardIndexWidth() );
    return ( $board, $port );
}

=item getBoardPortFromIfIndexForSecurityStatus

We noticed that the security status related OIDs always report their first boardIndex to 1 even though elsewhere
it's all referenced as 0.
I'm unsure if this is a bug or a feature so we created this hook that will always assume 1 as first board index.
To be used by method which read or write to security status related MIBs.

=cut

sub getBoardPortFromIfIndexForSecurityStatus {
    my ( $self, $ifIndex ) = @_;

    my $board = (1 + int( $ifIndex / $self->getBoardIndexWidth() ));
    my $port = ( $ifIndex % $self->getBoardIndexWidth() );

    return ( $board, $port );
}

sub getIfIndexFromBoardPort {
    my ( $self, $board, $port ) = @_;
    return ( ( $board - $self->getFirstBoardIndex() ) * $self->getBoardIndexWidth() + $port );
}

sub getAllSecureMacAddresses {
    my ($self) = @_;
    my $logger = $self->logger;
    my $OID_s5SbsAuthCfgAccessCtrlType = '1.3.6.1.4.1.45.1.6.5.3.10.1.4'; #S5-SWITCH-BAYSECURE-MIB

    my $secureMacAddrHashRef = {};
    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    my $result = $self->{_sessionRead}->get_table( -baseoid => "$OID_s5SbsAuthCfgAccessCtrlType" );
    while ( my ( $oid_including_mac, $ctrlType ) = each( %{$result} ) ) {
        if (( $oid_including_mac =~
/^$OID_s5SbsAuthCfgAccessCtrlType
\.([0-9]+)\.([0-9]+) # boardIndex, portIndex
\.([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) # MAC address
$/x) && ( $ctrlType == 1 )) {

                my $boardIndx = $1;
                my $portIndx = $2;
                my $ifIndex = $self->getIfIndexFromBoardPort( $boardIndx, $portIndx );
                my $oldMac = oid2mac($3);
                push @{ $secureMacAddrHashRef->{$oldMac}->{$ifIndex} }, $self->getVlan($ifIndex);
        }
    }

    return $secureMacAddrHashRef;
}

sub getSecureMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $OID_s5SbsAuthCfgAccessCtrlType = '1.3.6.1.4.1.45.1.6.5.3.10.1.4'; #S5-SWITCH-BAYSECURE-MIB
    my $secureMacAddrHashRef = {};

    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    my ( $boardIndx, $portIndx ) = $self->getBoardPortFromIfIndex($ifIndex);
    my $oldVlan = $self->getVlan($ifIndex);

    $logger->trace(
        "SNMP get_table for s5SbsAuthCfgAccessCtrlType: $OID_s5SbsAuthCfgAccessCtrlType.$boardIndx.$portIndx"
    );

    my $result = $self->{_sessionRead}->get_table( -baseoid => "$OID_s5SbsAuthCfgAccessCtrlType.$boardIndx.$portIndx" );

    while ( my ( $oid_including_mac, $ctrlType ) = each( %{$result} ) ) {
        if (( $oid_including_mac =~
/^$OID_s5SbsAuthCfgAccessCtrlType
\.$boardIndx\.$portIndx # boardIndex, portIndex
\.([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) # MAC address
$/x ) && ( $ctrlType == 1 )) {

                my $oldMac = oid2mac($1);
                push @{ $secureMacAddrHashRef->{$oldMac} }, $oldVlan;
        }
    }

    return $secureMacAddrHashRef;
}

sub getMaxMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    #so that everything runs like on a Cisco
    return 2;
}

sub authorizeMAC {
    my ( $self, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = $self->logger;

    if ( ($deauthMac) && ( !$self->isFakeMac($deauthMac) ) ) {
        $self->_authorizeMAC( $ifIndex, $deauthMac, 0 );
    }
    if ( ($authMac) && ( !$self->isFakeMac($authMac) ) ) {
        $self->_authorizeMAC( $ifIndex, $authMac, 1 );
    }
    return 1;
}

#called with $authorized set to true, creates a new line to authorize the MAC
#when $authorized is set to false, deletes an existing line
sub _authorizeMAC {
    my ( $self, $ifIndex, $mac, $authorize ) = @_;
    my $OID_s5SbsAuthCfgAccessCtrlType = '1.3.6.1.4.1.45.1.6.5.3.10.1.4';
    my $OID_s5SbsAuthCfgStatus = '1.3.6.1.4.1.45.1.6.5.3.10.1.5';
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info( "not in production mode ... we won't delete an entry from the SecureMacAddrTable" );
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    # careful readers will notice that we don't use getBoardPortFromIfIndex here.
    # That's because Nortel thought that it made sense to start BoardIndexes differently for different OIDs
    # on the same switch!!!
    my ( $boardIndx, $portIndx ) = $self->getBoardPortFromIfIndexForSecurityStatus($ifIndex);
    my $cfgStatus = ($authorize) ? 2 : 3;
    my $mac_oid = mac2oid($mac);

    my $result;
    if ($authorize) {
        $logger->trace( "SNMP set_request for s5SbsAuthCfgAccessCtrlType: $OID_s5SbsAuthCfgAccessCtrlType" );
        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_s5SbsAuthCfgAccessCtrlType.$boardIndx.$portIndx.$mac_oid", Net::SNMP::INTEGER, $TRUE,
                "$OID_s5SbsAuthCfgStatus.$boardIndx.$portIndx.$mac_oid", Net::SNMP::INTEGER, $cfgStatus
            ]
        );
    } else {
        $logger->trace( "SNMP set_request for s5SbsAuthCfgStatus: $OID_s5SbsAuthCfgStatus" );
        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_s5SbsAuthCfgStatus.$boardIndx.$portIndx.$mac_oid", Net::SNMP::INTEGER, $cfgStatus
            ]
        );
    }

    return $TRUE if (defined($result));

    $logger->warn("MAC authorize / deauthorize failed with " . $self->{_sessionWrite}->error());
    return;
}

sub isDynamicPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    return 0;
}

sub isStaticPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    return 1;
}


# This function has not been tested on stacked switches !
sub setPortSecurityEnableByIfIndex {
    my ( $self, $ifIndex, $enable ) = @_;
    my $logger = $self->logger;

    my $OID_s5SbsPortSecurityStatus = "1.3.6.1.4.1.45.1.6.5.3.15.0";

    if ( !$self->connectRead() ) {
        return 0;
    }
    if ( !$self->connectWrite() ) {
        return 0;
    }

    $logger->trace("SNMP get_request for OID_s5SbsPortSecurityStatus: $OID_s5SbsPortSecurityStatus");
    $self->{_sessionRead}->translate(0);
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [ "$OID_s5SbsPortSecurityStatus" ] );
    $self->{_sessionRead}->translate(1);

    my $portSecurityStatus = ($enable) ? $TRUE : $FALSE;
    # There's no -1 on $ifIndex, this is not a bug. For some reason ports are offset by 1.
    my $newSecurConfig = $self->modifyBitmask($result->{"$OID_s5SbsPortSecurityStatus"}, $ifIndex, $portSecurityStatus);

    $logger->trace("SNMP set_request for s5SbsPortSecurityStatus: $OID_s5SbsPortSecurityStatus");
    $result = $self->{_sessionWrite}->set_request( -varbindlist => [
        "$OID_s5SbsPortSecurityStatus", Net::SNMP::OCTET_STRING, $newSecurConfig,
    ]);

    # if $result is defined, it works we can return $TRUE
    return $TRUE if (defined($result));

    # otherwise report failure
    $logger->warn("modifying port-security configuration failed on $ifIndex with:" . $self->{_sessionWrite}->error());
    return;
}

sub isPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    my $oid_s5SbsSecurityStatus = '1.3.6.1.4.1.45.1.6.5.3.3';
    my $oid_s5SbsSecurityAction = '1.3.6.1.4.1.45.1.6.5.3.5';
    my $oid_s5SbsCurrentPortSecurStatus = '1.3.6.1.4.1.45.1.6.5.3.11.1.6';

    # careful readers will notice that we don't use getBoardPortFromIfIndex here.
    # That's because Nortel thought that it made sense to start BoardIndexes differently for different OIDs
    # on the same switch!!!
    my ( $boardIndx, $portIndx ) = $self->getBoardPortFromIfIndexForSecurityStatus($ifIndex);

    my $s5SbsSecurityStatus = undef;
    my $s5SbsSecurityAction = undef;
    my $s5SbsCurrentPortSecurStatus = undef;

    if ( !$self->connectRead() ) {
        return 0;
    }

    $logger->trace(
        "SNMP get_next_request for s5SbsSecurityStatus: $oid_s5SbsSecurityStatus and " .
        "s5SbsSecurityAction: $oid_s5SbsSecurityAction"
    );
    my $result = $self->{_sessionRead}->get_next_request( -varbindlist =>
            [ "$oid_s5SbsSecurityStatus", "$oid_s5SbsSecurityAction" ] );
    foreach my $oid ( keys %{$result} ) {
        if ( $oid =~ /^$oid_s5SbsSecurityStatus/ ) {
            $s5SbsSecurityStatus = $result->{$oid};
        } elsif ( $oid =~ /^$oid_s5SbsSecurityAction/ ) {
            $s5SbsSecurityAction = $result->{$oid};
            if ( $s5SbsSecurityAction == 2 ) {
                $logger->warn(
                    "s5SbsSecurityAction is 2 (trap) ... should be 6 (filter and trap)"
                );
            }
        }
    }

    $logger->trace(
        "SNMP get_request for s5SbsCurrentPortSecurStatus: $oid_s5SbsCurrentPortSecurStatus"
    );
    $result = $self->{_sessionRead}->get_request(
        -varbindlist => [
            "$oid_s5SbsCurrentPortSecurStatus.$boardIndx.$portIndx.0.0.0.0.0.0"
        ]
    );
    foreach my $oid ( keys %{$result} ) {
        if ( $oid
            =~ /^${oid_s5SbsCurrentPortSecurStatus}\.${boardIndx}\.${portIndx}\.0\.0\.0\.0\.0\.0/
            )
        {
            $s5SbsCurrentPortSecurStatus = $result->{$oid};
        }
    }

    # error conditions
    return $FALSE if (!defined($s5SbsSecurityStatus) || $s5SbsSecurityStatus eq 'noSuchInstance');
    return $FALSE if (!defined($s5SbsSecurityAction) || $s5SbsSecurityAction eq 'noSuchInstance');

    return (
            $s5SbsSecurityStatus == 1
            && ( $s5SbsSecurityAction == 6 || $s5SbsSecurityAction == 2 )
            && (!defined($s5SbsCurrentPortSecurStatus)
                || $s5SbsCurrentPortSecurStatus eq 'noSuchInstance'
                || $s5SbsCurrentPortSecurStatus >= 2)
    );
}

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
    my $oid_lldpRemPortId = '1.0.8802.1.1.2.1.4.1.1.7';
    my $oid_lldpRemSysDesc = '1.0.8802.1.1.2.1.4.1.1.10';

    if ( !$self->connectRead() ) {
        return @phones;
    }
    $logger->trace(
        "SNMP get_next_request for lldpRemSysDesc: $oid_lldpRemSysDesc");
    my $result = $self->{_sessionRead}
        ->get_next_request( -varbindlist => ["$oid_lldpRemSysDesc"] );
    foreach my $oid ( keys %{$result} ) {
        if ( $oid =~ /^$oid_lldpRemSysDesc\.([0-9]+)\.([0-9]+)\.([0-9]+)$/ ) {
            if ( $ifIndex eq $2 ) {
                my $cache_lldpRemTimeMark = $1;
                my $cache_lldpRemLocalPortNum = $2;
                my $cache_lldpRemIndex = $3;
                if ( $result->{$oid} =~ /^Nortel IP Telephone/ ) {
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
                            =~ /^(?:0x)?([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})(?::..)?$/i
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

sub isVoIPEnabled {
    my ($self) = @_;
    return ( $self->{_VoIPEnabled} == 1 );
}

=item setTagOnVlansByIfIndex

Change VLAN Tag bit on a given ifIndex for all the given VLANs.

Takes an ifIndex, a TRUE/FALSE value (tag or untag), the switch locker to avoid concurrency issues and a list of VLANs.

=cut

sub setTagVlansByIfIndex {
    my ( $self, $ifIndex, $setTo, $switch_locker_ref, @vlans ) = @_;
    my $logger = $self->logger;
    my $OID_rcVlanPortMembers = '1.3.6.1.4.1.2272.1.3.2.1.11'; #RC-VLAN-MIB

    if ( !$self->connectRead() ) {
        return 0;
    }
    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $result;
    {
        my $lock = $self->getExclusiveLock();

        # since all VLANs are located in separated OIDs we need to fetch the portList for each VLAN
        my $fetch_vlan_port_list_ref = [];
        foreach my $vlan (@vlans) {
            push @$fetch_vlan_port_list_ref, "$OID_rcVlanPortMembers.$vlan";
        }

        $logger->trace("SNMP get_request for rcVlanPortMembers");
        $self->{_sessionRead}->translate(0);
        $result = $self->{_sessionRead}->get_request( -varbindlist => $fetch_vlan_port_list_ref );
        $self->{_sessionRead}->translate(1);

        # now we traverse every portList and set the proper port bit to 1 for every VLAN
        my $set_vlan_port_list_ref = [];
        foreach my $vlan (@vlans) {
            my $updated_port_member_list = $self->modifyBitmask(
                $result->{"$OID_rcVlanPortMembers.$vlan"}, $ifIndex, $setTo
            );

            push @$set_vlan_port_list_ref,
                "$OID_rcVlanPortMembers.$vlan", Net::SNMP::OCTET_STRING, $updated_port_member_list;
        }

        $logger->trace( "SNMP set_request for OID_rcVlanPortMembers: $OID_rcVlanPortMembers");
        $result = $self->{_sessionWrite}->set_request(-varbindlist => $set_vlan_port_list_ref);
    }
    $logger->trace( "locking - \$switch_locker{" . $self->{_ip} . "} unlocked in setTaggedVlan" );

    # if $result is defined, it works we can return $TRUE
    return $TRUE if (defined($result));

    # otherwise report failure
    $logger->warn("Tagging VLANs failed with " . $self->{_sessionWrite}->error());
    return;
}

=item removeAllTaggedVlans

Removes all the tagged Vlans on a multi-Vlan port.
Used for floating network devices.

=cut

sub removeAllTaggedVlans {
    my ( $self, $ifIndex, $switch_locker_ref ) = @_;

    my @all_vlans = keys %{$self->getVlans()};
    return $self->setTagVlansByIfIndex($ifIndex, $FALSE, $switch_locker_ref, @all_vlans);
}

=item setTaggedVlans

Tag given VLANs on a given port in a multi-vlan per port config (trunk).
Used for floating network devices.

=cut

sub setTaggedVlans {
    my ( $self, $ifIndex, $switch_locker_ref, @vlans ) = @_;

    $self->removeAllTaggedVlans($ifIndex, $switch_locker_ref);

    return $self->setTagVlansByIfIndex($ifIndex, $TRUE, $switch_locker_ref, @vlans);
}

=item _findTrapNormalizer

find trap normaliziers for pf::Switch::Nortel

=cut

sub _findTrapNormalizer {
    my ($self, $snmpTrapOID, $pdu, $variables) = @_;
    if (exists $TRAP_NORMALIZERS{$snmpTrapOID}) {
        return $TRAP_NORMALIZERS{$snmpTrapOID};
    }
    return undef;
}

=item s5EtrSbsMacAccessViolationTrapNormalizer

normalizer for the s5EtrSbsMacAccessViolation trap

=cut

sub s5EtrSbsMacAccessViolationTrapNormalizer {
    my ($self, $trapInfo) = @_;
    my $logger = $self->logger;
    my ($pdu, $variables) = @$trapInfo;
    my ($variable) = $self->findTrapVarWithBase($variables, '.1.3.6.1.4.1.45.1.6.5.3.12.1.3.');
    return undef unless $variable;
    unless ($variable) {
        $logger->error("Cannot find OID .1.3.6.1.4.1.45.1.6.5.3.12.1.3. in trap");
        return undef;
    }
    my $trapMac = $self->extractMacFromVariable($variable);
    unless ($trapMac) {
        $logger->error("Cannot extract a mac address from OID .1.3.6.1.4.1.45.1.6.5.3.12.1.3.");
        return undef;
    }
    unless ($variable->[0] =~ /^\Q.1.3.6.1.4.1.45.1.6.5.3.12.1.3.\E(\d+)\.(\d+)$/) {
        $logger->error("Cannot extract the board and port index from $variable->[0]");
        return undef;
    }
    my $boardIndex = $1;
    my $portIndex = $2;
    my $trapIfIndex = ( $boardIndex - $self->getFirstBoardIndex() ) * $self->getBoardIndexWidth() + $portIndex;
    if ($trapIfIndex <= 0) {
        $logger->warn(
            "Trap ifIndex is invalid. Should this switch be factory-reset? "
            . "See Nortel's BayStack Stacking issues in module documentation for more information."
        );
    }
    return {
        trapType => 'secureMacAddrViolation',
        trapIfIndex => $trapIfIndex,
        trapVlan => $self->getVlan( $trapIfIndex ),
        trapMac => $trapMac
    };
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
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
USA.

=cut

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
