package pf::Switch::Cisco;

=head1 NAME

pf::Switch::Cisco

=cut

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Data::Dumper;
use base ('pf::Switch');
use pf::log;
use Net::SNMP;
use Try::Tiny;

use pf::constants;
# importing switch constants
use pf::Switch::constants;
use pf::util;
use pf::util::radius qw(perform_coa);

# CAPABILITIES
# special features
sub supportsSaveConfig { return $TRUE; }
sub supportsCdp { return $TRUE; }

#
# %TRAP_NORMALIZERS
# A hash of cisco trap normalizers
# Use the following convention when adding a normalizer
# <nameOfTrapNotificationType>TrapNormalizer
#
our %TRAP_NORMALIZERS = (
    '.1.3.6.1.4.1.9.9.315.0.0.1' => 'cpsSecureMacAddrViolationTrapNormalizer',
    '.1.3.6.1.4.1.9.9.315.0.0.2' => 'cpsTrunkSecureMacAddrViolationTrapNormalizer',
    '.1.3.6.1.4.1.9.9.215.2.0.1' => 'cmnMacChangedNotificationTrapNormalizer',
);

=head1 SUBROUTINES

TODO: This list is incomplete

=over

=cut

sub getVersion {
    my ($self)       = @_;
    my $oid_sysDescr = '1.3.6.1.2.1.1.1.0';
    my $logger       = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysDescr: $oid_sysDescr");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => [$oid_sysDescr] );
    my $sysDescr = ( $result->{$oid_sysDescr} || '' );
    if ( $sysDescr =~ m/V(\d{1}\.\d{2}\.\d{2})/ ) {
        return $1;
    } elsif ( $sysDescr =~ m/Version (\d+\.\d+\([^)]+\)[^,\s]*)(,|\s)+/ ) {
        return $1;
    } else {
        return $sysDescr;
    }
}

sub isNewerVersionThan {
    my ( $self, $versionToCompareToString ) = @_;
    my $currentVersion = $self->getVersion();
    my @detectedOSVersionArray;
    if ( $currentVersion =~ /^(\d+)\.(\d+)\(([0-9]+)[^0-9)]*\)(.+)$/ ) {
        @detectedOSVersionArray = ( $1, $2, $3, $4 );
        my @versionToCompareToArray;
        if ( $versionToCompareToString
            =~ /^(\d+)\.(\d+)\(([0-9]+)[^0-9)]*\)(.+)$/ )
        {
            @versionToCompareToArray = ( $1, $2, $3, $4 );
            if ( $detectedOSVersionArray[3] =~ /^([A-Za-z]+)(\d+)([a-z]?)$/ )
            {
                my $d1 = $1;
                my $d2 = $2;
                my $d3 = $3;
                if ( $versionToCompareToArray[3]
                    =~ /^([A-Za-z]+)(\d+)([a-z]?)$/ )
                {
                    my $c1 = $1;
                    my $c2 = $2;
                    my $c3 = $3;
                    if (!(     ( $d1 lt $c1 )
                            || ( ( $d1 eq $c1 ) && ( $d2 < $c2 ) )
                            || (   ( $d1 eq $c1 )
                                && ( $d2 == $c2 )
                                && ( $d3 lt $c3 ) )
                        )
                        )
                    {
                        $detectedOSVersionArray[3]  = 'b';
                        $versionToCompareToArray[3] = 'a';
                    } else {
                        $detectedOSVersionArray[3]  = 'a';
                        $versionToCompareToArray[3] = 'b';
                    }
                }
            }
            return !(
                ( $detectedOSVersionArray[0] < $versionToCompareToArray[0] )
                || ((   $detectedOSVersionArray[0]
                        == $versionToCompareToArray[0]
                    )
                    && ( $detectedOSVersionArray[1]
                        < $versionToCompareToArray[1] )
                )
                || ((   $detectedOSVersionArray[0]
                        == $versionToCompareToArray[0]
                    )
                    && ( $detectedOSVersionArray[1]
                        == $versionToCompareToArray[1] )
                    && ( $detectedOSVersionArray[2]
                        < $versionToCompareToArray[2] )
                )
                || ((   $detectedOSVersionArray[0]
                        == $versionToCompareToArray[0]
                    )
                    && ( $detectedOSVersionArray[1]
                        == $versionToCompareToArray[1] )
                    && ( $detectedOSVersionArray[2]
                        == $versionToCompareToArray[2] )
                    && ( $detectedOSVersionArray[3]
                        lt $versionToCompareToArray[3] )
                )
            );
        }
    }
    return 0;
}

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;

    #link up/down
    if ( $trapString
        =~ /BEGIN VARIABLEBINDINGS [^|]+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])\|.1.3.6.1.2.1.2.2.1.1.([0-9]+)/
        )
    {
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;

    } elsif ( $trapString
        =~ /^BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = INTEGER: /
        )
    {
        $trapHashRef->{'trapType'} = ( ( $1 == 2 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
        # CISCO-MAC-NOTIFICATION-MIB cmnHistMacChangedMsg
    } elsif (
        ( $trapString
            =~ /BEGIN VARIABLEBINDINGS [^|]+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.4\.1\.9\.9\.215\.2\.0\.1\|\.1\.3\.6\.1\.4\.1\.9\.9\.215\.1\.1\.8\.1\.2\.[0-9]+ = Hex-STRING: ([0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2})/
        ) || ( $trapString
            =~ /BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.4\.1\.9\.9\.215\.1\.1\.8\.1\.2\.[0-9]+ = Hex-STRING: ([0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2})/
        ) )
    {
        $trapHashRef->{'trapType'} = 'mac';
        if ( $1 == 1 ) {
            $trapHashRef->{'trapOperation'} = 'learnt';
        } elsif ( $1 == 2 ) {
            $trapHashRef->{'trapOperation'} = 'removed';
        } else {
            $trapHashRef->{'trapOperation'} = 'unknown';
        }
        $trapHashRef->{'trapVlan'}    = $2;
        $trapHashRef->{'trapMac'}     = lc($3);
        $trapHashRef->{'trapIfIndex'} = $4;
        $trapHashRef->{'trapVlan'} =~ s/ //g;
        $trapHashRef->{'trapVlan'} = hex( $trapHashRef->{'trapVlan'} );
        $trapHashRef->{'trapIfIndex'} =~ s/ //g;
        $trapHashRef->{'trapIfIndex'} = hex( $trapHashRef->{'trapIfIndex'} );
        $trapHashRef->{'trapMac'} =~ s/ /:/g;

        #convert the dot1dBasePort into an ifIndex
        my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';   #BRIDGE-MIB
        my $dot1dBasePort = $trapHashRef->{'trapIfIndex'};

        #populate list of Vlans we must potentially connect to to
        #convert the dot1dBasePort into an ifIndex
        my @vlansToTest = ();
        push @vlansToTest, $trapHashRef->{'trapVlan'};
        foreach my $currentVlan ( values %{ $self->{_vlans} } ) {
            if ( $currentVlan != $trapHashRef->{'trapVlan'} )
            {
                push @vlansToTest, $currentVlan;
            }
        }
        my $found   = 0;
        my $vlanPos = 0;
        my $vlans   = $self->getVlans();
        while ( ( $vlanPos < scalar(@vlansToTest) ) && ( $found == 0 ) ) {
            my $currentVlan = $vlansToTest[$vlanPos];
            my $result      = undef;

            if ( exists( $vlans->{$currentVlan} ) ) {

                #issue correct SNMP query depending on SNMP version
                if ( $self->{_SNMPVersion} eq '3' ) {
                    if ( $self->connectRead() ) {
                        $logger->trace(
                            "SNMP get_request for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex.$dot1dBasePort"
                        );
                        $result = $self->{_sessionRead}->get_request(
                            -varbindlist =>
                                ["$OID_dot1dBasePortIfIndex.$dot1dBasePort"],
                            -contextname => "vlan_$currentVlan"
                        );
                        # FIXME: calling "private" method to unset context. See #1284 or upstream rt.cpan.org:72075.
                        $self->{_sessionRead}->{_context_name} = undef;
                    }
                } else {
                    my ( $sessionReadVlan, $sessionReadVlanError )
                        = Net::SNMP->session(
                        -hostname  => $self->{_ip},
                        -version   => $self->{_SNMPVersion},
                        -retries   => 1,
                        -timeout   => 2,
                        -maxmsgsize => 4096,
                        -community => $self->{_SNMPCommunityRead} . '@'
                            . $currentVlan
                        );
                    if ( defined($sessionReadVlan) ) {
                        $logger->trace(
                            "SNMP get_request for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex.$dot1dBasePort"
                        );
                        $result
                            = $sessionReadVlan->get_request( -varbindlist =>
                                ["$OID_dot1dBasePortIfIndex.$dot1dBasePort"]
                            );
                    } else {
                        $logger->debug(
                            "cannot connect to obtain do1dBasePortIfIndex information in VLAN $currentVlan"
                        );
                    }
                }

                #did we get a result ?
                if (defined($result)
                    && (exists(
                            $result->{
                                "$OID_dot1dBasePortIfIndex.$dot1dBasePort"}
                        )
                    )
                    && ( $result->{"$OID_dot1dBasePortIfIndex.$dot1dBasePort"}
                        ne 'noSuchInstance' )
                    )
                {
                    $trapHashRef->{'trapIfIndex'} = $result->{
                        "$OID_dot1dBasePortIfIndex.$dot1dBasePort"};
                    $logger->debug(
                        "converted dot1dBasePort $dot1dBasePort into ifIndex "
                            . $trapHashRef->{'trapIfIndex'}
                            . " in vlan $currentVlan" );
                    $found = 1;
                } else {
                    $logger->debug(
                        "cannot convert dot1dBasePort $dot1dBasePort into ifIndex in VLAN $currentVlan - "
                            . ( scalar(@vlansToTest) - $vlanPos - 1 )
                            . " more vlans to try" );
                }
            }
            $vlanPos++;
        }
        if ( $found == 0 ) {
            $logger->error(
                "could not convert dot1dBasePort into ifIndex in any VLAN. Setting trapType to unknown"
            );
            $trapHashRef->{'trapType'} = 'unknown';
        }

        # CISCO-PORT-SECURITY-MIB cpsSecureMacAddrViolation
    } elsif (
        ( $trapString
        =~ /BEGIN VARIABLEBINDINGS .+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.4\.1\.9\.9\.315\.0\.0\.1[|]\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.([0-9]+) = .+[|]\.1\.3\.6\.1\.4\.1\.9\.9\.315\.1\.2\.1\.1\.10\.[0-9]+ = $SNMP::MAC_ADDRESS_FORMAT/
        ) || ( $trapString
        =~ /BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.([0-9]+) = .+[|]\.1\.3\.6\.1\.4\.1\.9\.9\.315\.1\.2\.1\.1\.10\.[0-9]+ = $SNMP::MAC_ADDRESS_FORMAT/) ) {

        $trapHashRef->{'trapType'}    = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1;
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($2);
        $trapHashRef->{'trapVlan'} = $self->getVlan( $trapHashRef->{'trapIfIndex'} );

        # CISCO-PORT-SECURITY-MIB cpsTrunkSecureMacAddrViolation
    } elsif ( $trapString
        =~ /BEGIN VARIABLEBINDINGS .+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.4\.1\.9\.9\.315\.0\.0\.2[|]\.1\.3\.6\.1\.2\.1\.31\.1\.1\.1\.1\.([0-9]+) = .+[|]\.1\.3\.6\.1\.4\.1\.9\.9\.315\.1\.2\.1\.1\.10\.[0-9]+ = $SNMP::MAC_ADDRESS_FORMAT/ ) {

        $trapHashRef->{'trapType'} = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1;
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($2);
        $trapHashRef->{'trapVlan'} = $self->getVlan( $trapHashRef->{'trapIfIndex'} );

    #  IEEE802dot11-MIB dot11DeauthenticateReason + dot11DeauthenticateStation
    } elsif ( $trapString
        =~ /\.1\.2\.840\.10036\.1\.1\.1\.17\.[0-9]+ = INTEGER: [0-9]+[|]\.1\.2\.840\.10036\.1\.1\.1\.18\.[0-9]+ = $SNMP::MAC_ADDRESS_FORMAT/ ) {

        $trapHashRef->{'trapType'} = 'dot11Deauthentication';
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($1);

    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub getAllVlans {
    my ( $self, @ifIndexes ) = @_;
    my $logger = $self->logger;
    my $vlanHashRef;
    if ( !@ifIndexes ) {
        @ifIndexes = $self->getManagedIfIndexes();
    }

    my $OID_vmVlan
        = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB
    my $OID_vlanTrunkPortNativeVlan
        = '1.3.6.1.4.1.9.9.46.1.6.1.1.5';    #CISCO-VTP-MIB

    if ( !$self->connectRead() ) {
        return $vlanHashRef;
    }
    $logger->trace("SNMP get_table for vmVlan: $OID_vmVlan");
    my $result = $self->{_sessionRead}->get_table( -baseoid => $OID_vmVlan );
    foreach my $key ( keys %{$result} ) {
        my $vlan = $result->{$key};
        $key =~ /^$OID_vmVlan\.(\d+)$/;
        my $ifIndex = $1;
        if (   ( $vlan ne 'noSuchInstance' )
            && ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) )
        {
            $vlanHashRef->{$ifIndex} = $vlan;
        }
    }
    if ( scalar( keys(%$vlanHashRef) ) < scalar(@ifIndexes) ) {
        $logger->trace(
            "SNMP get_table for vlanTrunkPortNativeVlan: $OID_vlanTrunkPortNativeVlan"
        );
        $result = $self->{_sessionRead}
            ->get_table( -baseoid => $OID_vlanTrunkPortNativeVlan );
        foreach my $key ( keys %{$result} ) {
            my $vlan = $result->{$key};
            $key =~ /^$OID_vlanTrunkPortNativeVlan\.(\d+)$/;
            my $ifIndex = $1;
            if (   ( $vlan ne 'noSuchInstance' )
                && ( !exists( $vlanHashRef->{$ifIndex} ) )
                && ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) )
            {
                $vlanHashRef->{$ifIndex} = $vlan;
            }
        }
    }
    return $vlanHashRef;
}

sub getVoiceVlan {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_vmVoiceVlanId
        = '1.3.6.1.4.1.9.9.68.1.5.1.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->trace(
        "SNMP get_request for vmVoiceVlanId: $OID_vmVoiceVlanId.$ifIndex");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_vmVoiceVlanId.$ifIndex"] );
    if ( exists( $result->{"$OID_vmVoiceVlanId.$ifIndex"} )
        && ( $result->{"$OID_vmVoiceVlanId.$ifIndex"} ne 'noSuchInstance' ) )
    {
        return $result->{"$OID_vmVoiceVlanId.$ifIndex"};
    } else {
        return -1;
    }
}

# TODO: if ifIndex doesn't exist, an error should be given
# to reproduce: bin/pfcmd_vlan -getVlan -ifIndex 999 -switch <ip>
sub getVlan {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_vmVlan = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->trace("SNMP get_request for vmVlan: $OID_vmVlan.$ifIndex");

    my $result = $self->{_sessionRead}->get_request( -varbindlist => ["$OID_vmVlan.$ifIndex"] );
    if ( exists( $result->{"$OID_vmVlan.$ifIndex"} ) && ( $result->{"$OID_vmVlan.$ifIndex"} ne 'noSuchInstance' ) ) {
        return $result->{"$OID_vmVlan.$ifIndex"};
    } else {

        #this is a trunk port - try to get the trunk ports native VLAN
        my $OID_vlanTrunkPortNativeVlan
            = '1.3.6.1.4.1.9.9.46.1.6.1.1.5';    #CISCO-VTP-MIB
        $logger->trace(
            "SNMP get_request for vlanTrunkPortNativeVlan: $OID_vlanTrunkPortNativeVlan.$ifIndex"
        );
        my $result = $self->{_sessionRead}->get_request(
            -varbindlist => ["$OID_vlanTrunkPortNativeVlan.$ifIndex"] );
        return $result->{"$OID_vlanTrunkPortNativeVlan.$ifIndex"};
    }
}

sub isLearntTrapsEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_cmnMacAddrLearntEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.1';
    $logger->trace(
        "SNMP get_request for cmnMacAddrLearntEnable: $OID_cmnMacAddrLearntEnable"
    );
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_cmnMacAddrLearntEnable.$ifIndex" ] );
    return (
        exists( $result->{"$OID_cmnMacAddrLearntEnable.$ifIndex"} )
            && ( $result->{"$OID_cmnMacAddrLearntEnable.$ifIndex"} ne 'noSuchInstance' )
            && ( $result->{"$OID_cmnMacAddrLearntEnable.$ifIndex"} ne 'noSuchObject' )
            && ( $result->{"$OID_cmnMacAddrLearntEnable.$ifIndex"} == 1 )
    );
}

sub setLearntTrapsEnabled {

    #1 means 'enabled', 2 means 'disabled'
    my ( $self, $ifIndex, $trueFalse ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_cmnMacAddrLearntEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.1';
    $logger->trace(
        "SNMP set_request for cmnMacAddrLearntEnable: $OID_cmnMacAddrLearntEnable"
    );
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_cmnMacAddrLearntEnable.$ifIndex", Net::SNMP::INTEGER,
            $trueFalse
        ]
    );
    return ( defined($result) );
}

sub isRemovedTrapsEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_cmnMacAddrRemovedEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.2';
    $logger->debug(
        "SNMP get_request for cmnMacAddrRemovedEnable: $OID_cmnMacAddrRemovedEnable"
    );
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_cmnMacAddrRemovedEnable.$ifIndex" ] );
    return (
        exists( $result->{"$OID_cmnMacAddrRemovedEnable.$ifIndex"} )
            && ( $result->{"$OID_cmnMacAddrRemovedEnable.$ifIndex"} ne
            'noSuchInstance' )
            && ( $result->{"$OID_cmnMacAddrRemovedEnable.$ifIndex"} == 1 )
    );
}

sub setRemovedTrapsEnabled {

    #1 means 'enabled', 2 means 'disabled'
    my ( $self, $ifIndex, $trueFalse ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_cmnMacAddrRemovedEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.2';
    $logger->trace(
        "SNMP set_request for cmnMacAddrRemovedEnable: $OID_cmnMacAddrRemovedEnable"
    );
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_cmnMacAddrRemovedEnable.$ifIndex", Net::SNMP::INTEGER,
            $trueFalse
        ]
    );
    return ( defined($result) );
}

sub isPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    #CISCO-PORT-SECURITY-MIB
    my $OID_cpsIfPortSecurityEnable = '1.3.6.1.4.1.9.9.315.1.2.1.1.1';

    if ( !$self->connectRead() ) {
        return 0;
    }

    #determine if port security is enabled
    $logger->trace(
        "SNMP get_request for cpsIfPortSecurityEnable: $OID_cpsIfPortSecurityEnable.$ifIndex"
    );
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_cpsIfPortSecurityEnable.$ifIndex" ] );
    return (
        exists( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} )
            && ( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} ne
            'noSuchInstance' )
            && ( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} ne
            'noSuchObject' )
            && ( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} == 1 )
    );
}

sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $removedTrapsEnabled = $self->isRemovedTrapsEnabled($ifIndex);
    if ($removedTrapsEnabled) {
        $logger->debug("disabling removed traps for port $ifIndex before VLAN change");
        $self->setRemovedTrapsEnabled( $ifIndex, $SNMP::FALSE );
    }

    my $result;
    if ( $self->isTrunkPort($ifIndex) ) {

        $result = $self->setTrunkPortNativeVlan($ifIndex, $newVlan);

        #expirer manuellement la mac-address-table
        $self->clearMacAddressTable( $ifIndex, $oldVlan );

    } else {
        my $OID_vmVlan = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB
        $logger->trace("SNMP set_request for vmVlan: $OID_vmVlan");
        $result = $self->{_sessionWrite}->set_request( -varbindlist =>[
            "$OID_vmVlan.$ifIndex", Net::SNMP::INTEGER, $newVlan ] );
    }
    my $returnValue = ( defined($result) );

    if ($removedTrapsEnabled) {
        $logger->debug("re-enabling removed traps for port $ifIndex after VLAN change");
        $self->setRemovedTrapsEnabled( $ifIndex, $SNMP::TRUE );
    }

    return $returnValue;
}

=item setTrunkPortNativeVlan - sets PVID on a trunk port

=cut

sub setTrunkPortNativeVlan {
    my ( $self, $ifIndex, $newVlan ) = @_;
    my $logger = $self->logger;

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $result;
    my $OID_vlanTrunkPortNativeVlan = '1.3.6.1.4.1.9.9.46.1.6.1.1.5';    #CISCO-VTP-MIB
    $logger->trace("SNMP set_request for vlanTrunkPortNativeVlan: $OID_vlanTrunkPortNativeVlan");
    $result = $self->{_sessionWrite}->set_request( -varbindlist => [
        "$OID_vlanTrunkPortNativeVlan.$ifIndex", Net::SNMP::INTEGER, $newVlan] );

    return $result;

}

# fetch port type
# 1 => static
# 2 => dynamic
# 3 => multivlan
# 4 => trunk
sub getVmVlanType {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_vmVlanType
        = '1.3.6.1.4.1.9.9.68.1.2.2.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->trace(
        "SNMP get_request for vmVlanType: $OID_vmVlanType.$ifIndex");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_vmVlanType.$ifIndex"] );
    if ( exists( $result->{"$OID_vmVlanType.$ifIndex"} )
        && ( $result->{"$OID_vmVlanType.$ifIndex"} ne 'noSuchInstance' ) )
    {
        return $result->{"$OID_vmVlanType.$ifIndex"};
    } elsif ( $self->isTrunkPort($ifIndex) ) {
        return 4;
    } else {
        return 0;
    }
}

sub setVmVlanType {
    my ( $self, $ifIndex, $type ) = @_;
    my $logger = $self->logger;
    $logger->info( "setting port $ifIndex vmVlanType from "
            . $self->getVmVlanType($ifIndex)
            . " to $type" );
    if ( !$self->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't change this port VmVlanType"
        );
        return 1;
    }
    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_vmVlanType
        = '1.3.6.1.4.1.9.9.68.1.2.2.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->trace("SNMP set_request for vmVlanType: $OID_vmVlanType");
    my $result = $self->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_vmVlanType.$ifIndex", Net::SNMP::INTEGER, $type ] );
    return ( defined($result) );
}

=item getMacBridgePortHash

Cisco is very fancy about fetching it's VLAN information. In SNMPv3 the context
is used to specify a VLAN and in SNMPv1/2c an @<vlan> is appended to the
read-only community name when reading.

=cut

sub getMacBridgePortHash {
    my $self              = shift;
    my $vlan              = shift || '';
    my %macBridgePortHash = ();
    my $logger            = $self->logger;
    my $OID_dot1dTpFdbPort       = '1.3.6.1.2.1.17.4.3.1.2';    #BRIDGE-MIB
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB

    if ( !$self->connectRead() ) {
        return %macBridgePortHash;
    }

    #obtain ifPhysAddress array
    my $OID_ifPhysAddress = '1.3.6.1.2.1.2.2.1.6';
    $logger->trace("SNMP get_table for ifPhysAddress: $OID_ifPhysAddress");
    my $result
        = $self->{_sessionRead}->get_table( -baseoid => $OID_ifPhysAddress );
    my %ifPhysAddressHash;
    foreach my $key ( keys %{$result} ) {
        $key =~ /^$OID_ifPhysAddress\.(\d+)$/;
        my $ifIndex = $1;
        my $mac     = $result->{$key};
        if ( $mac
            =~ /0x([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})/i
            )
        {
            $mac = uc("$1:$2:$3:$4:$5:$6");
            $ifPhysAddressHash{$mac} = $ifIndex;
        }
    }

    #connect to switch with the right VLAN information
    $result = undef;
    my %dot1dBasePortIfIndexHash;

    #issue correct SNMP query depending on SNMP version
    if ( $self->{_SNMPVersion} eq '3' ) {
        $logger->trace(
            "SNMP v3 get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex"
        );
        $result = $self->{_sessionRead}->get_table(
            -baseoid     => $OID_dot1dBasePortIfIndex,
            -contextname => "vlan_$vlan"
        );
        foreach my $key ( keys %{$result} ) {
            $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
            $dot1dBasePortIfIndexHash{$1} = $result->{$key};
        }
        $logger->trace(
            "SNMP v3 get_table for dot1dTpFdbPort: $OID_dot1dTpFdbPort");
        $result = $self->{_sessionRead}->get_table(
            -baseoid     => $OID_dot1dTpFdbPort,
            -contextname => "vlan_$vlan"
        );
        # FIXME: calling "private" method to unset context. See #1284 or upstream rt.cpan.org:72075.
        $self->{_sessionRead}->{_context_name} = undef;
    } else {
        my ( $sessionReadVlan, $sessionReadVlanError ) = Net::SNMP->session(
            -hostname  => $self->{_ip},
            -version   => $self->{_SNMPVersion},
            -retries   => 1,
            -timeout   => 2,
            -maxmsgsize => 4096,
            -community => $self->{_SNMPCommunityRead} . '@' . $vlan
        );

        if ( defined($sessionReadVlan) ) {

            #get dot1dBasePort to ifIndex association
            $logger->trace(
                "SNMP get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex"
            );
            $result = $sessionReadVlan->get_table(
                -baseoid => $OID_dot1dBasePortIfIndex );
            foreach my $key ( keys %{$result} ) {
                $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
                $dot1dBasePortIfIndexHash{$1} = $result->{$key};
            }
            $logger->trace(
                "SNMP get_table for dot1dTpFdbPort: $OID_dot1dTpFdbPort");
            $result = $sessionReadVlan->get_table(
                -baseoid => $OID_dot1dTpFdbPort );
        } else {
            $logger->error(
                "cannot connect to obtain do1dBasePortIfIndex information in VLAN $vlan"
            );
        }
    }

    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            if ( exists $dot1dBasePortIfIndexHash{ $result->{$key} } ) {
                $key
                    =~ /^$OID_dot1dTpFdbPort\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
                my $mac = sprintf( "%02X:%02X:%02X:%02X:%02X:%02X",
                    $1, $2, $3, $4, $5, $6 );
                if ( !exists( $ifPhysAddressHash{$mac} ) ) {
                    $macBridgePortHash{$mac}
                        = $dot1dBasePortIfIndexHash{ $result->{$key} };
                }
            }
        }
    }

    return %macBridgePortHash;
}

sub getIfIndexForThisMac {
    my ( $self, $mac ) = @_;
    my $logger   = $self->logger;
    my @macParts = split( ':', $mac );
    my @uplinks  = $self->getUpLinks();
    my $OID_dot1dTpFdbPort       = '1.3.6.1.2.1.17.4.3.1.2';    #BRIDGE-MIB
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB

    my $oid
        = $OID_dot1dTpFdbPort . "."
        . hex( $macParts[0] ) . "."
        . hex( $macParts[1] ) . "."
        . hex( $macParts[2] ) . "."
        . hex( $macParts[3] ) . "."
        . hex( $macParts[4] ) . "."
        . hex( $macParts[5] );

    foreach my $vlan ( values %{ $self->{_vlans} } ) {
        my $result = undef;

        $logger->trace(
            "SNMP get_request for dot1dTpFdbPort: $oid on switch $self->{'_ip'}, VLAN $vlan"
        );

        if ( $self->{_SNMPVersion} eq '3' ) {
            $result = $self->{_sessionRead}->get_request(
                -varbindlist => [$oid],
                -contextname => "vlan_$vlan"
            );
            if ( defined($result) ) {
                my $dot1dPort = $result->{$oid};
                my $oid       = $OID_dot1dBasePortIfIndex . "." . $dot1dPort;
                my $result    = $self->{_sessionRead}->get_request(
                    -varbindlist => [$oid],
                    -contextname => "vlan_$vlan"
                );
                if (   ( defined($result) )
                    && ( grep( { $_ == $result->{$oid} } @uplinks ) == 0 ) )
                {
                    return $result->{$oid};
                }
            }
            # FIXME: calling "private" method to unset context. See #1284 or upstream rt.cpan.org:72075.
            $self->{_sessionRead}->{_context_name} = undef;

        } else {

            #connect to switch with the right VLAN information
            my ( $sessionReadVlan, $sessionReadVlanError )
                = Net::SNMP->session(
                -hostname  => $self->{_ip},
                -version   => $self->{_SNMPVersion},
                -retries   => 1,
                -timeout   => 2,
                -maxmsgsize => 4096,
                -community => $self->{_SNMPCommunityRead} . '@' . $vlan
                );

            if ( defined($sessionReadVlan) ) {
                $result
                    = $sessionReadVlan->get_request( -varbindlist => [$oid] );
                if ( defined($result) ) {
                    my $dot1dPort = $result->{$oid};
                    my $oid    = $OID_dot1dBasePortIfIndex . "." . $dot1dPort;
                    my $result = $sessionReadVlan->get_request(
                        -varbindlist => [$oid] );
                    if (   ( defined($result) )
                        && ( grep( { $_ == $result->{$oid} } @uplinks ) == 0 )
                        )
                    {
                        return $result->{$oid};
                    }
                }
            } else {
                $logger->error(
                    "cannot connect to obtain do1dTpFdbPort information in VLAN $vlan"
                );
            }
        }

    }
    return -1;
}

sub isMacInAddressTableAtIfIndex {
    my ( $self, $mac, $ifIndex ) = @_;
    my $logger = $self->logger;
    my @macParts = split( ':', $mac );
    my $OID_dot1dTpFdbPort       = '1.3.6.1.2.1.17.4.3.1.2';    #BRIDGE-MIB
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB

    my $oid
        = $OID_dot1dTpFdbPort . "."
        . hex( $macParts[0] ) . "."
        . hex( $macParts[1] ) . "."
        . hex( $macParts[2] ) . "."
        . hex( $macParts[3] ) . "."
        . hex( $macParts[4] ) . "."
        . hex( $macParts[5] );

    my $vlan = $self->getVlan($ifIndex);

    if ( $self->{_SNMPVersion} eq '3' ) {
        my $result = $self->{_sessionRead}->get_request(
            -varbindlist => [$oid],
            -contextname => "vlan_$vlan"
        );
        if ( defined($result) ) {
            my $dot1dPort = $result->{$oid};
            my $oid       = $OID_dot1dBasePortIfIndex . "." . $dot1dPort;
            $logger->trace(
                "SNMP get_request for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex"
            );
            my $result = $self->{_sessionRead}->get_request(
                -varbindlist => [$oid],
                -contextname => "vlan_$vlan"
            );
            if ( $result->{$oid} == $ifIndex ) {
                $logger->debug(
                    "mac $mac found on switch $self->{'_ip'}, VLAN $vlan, ifIndex $ifIndex"
                );
                return 1;
            }
        }
        # FIXME: calling "private" method to unset context. See #1284 or upstream rt.cpan.org:72075.
        $self->{_sessionRead}->{_context_name} = undef;

    } else {

        #connect to switch with the right VLAN information
        my ( $sessionReadVlan, $sessionReadVlanError ) = Net::SNMP->session(
            -hostname  => $self->{_ip},
            -version   => $self->{_SNMPVersion},
            -retries   => 1,
            -timeout   => 2,
            -maxmsgsize => 4096,
            -community => $self->{_SNMPCommunityRead} . '@' . $vlan
        );

        if ( defined($sessionReadVlan) ) {
            $logger->trace(
                "SNMP get_request for dot1dBasePortIfIndex: $oid on switch $self->{'_ip'}, VLAN $vlan"
            );
            my $result
                = $sessionReadVlan->get_request( -varbindlist => [$oid] );
            if ( defined($result) ) {
                my $dot1dPort = $result->{$oid};
                my $oid       = $OID_dot1dBasePortIfIndex . "." . $dot1dPort;
                my $result
                    = $sessionReadVlan->get_request( -varbindlist => [$oid] );
                if ( $result->{$oid} == $ifIndex ) {
                    $logger->debug(
                        "mac $mac found on switch $self->{'_ip'}, VLAN $vlan, ifIndex $ifIndex"
                    );
                    return 1;
                }
            }
        } else {
            $logger->error(
                "cannot connect to obtain do1dTpFdbPort information in VLAN $vlan"
            );
        }
    }

    $logger->debug(
        "MAC $mac could not be found on switch $self->{'_ip'}, VLAN $vlan, ifIndex $ifIndex"
    );
    return 0;
}

sub isTrunkPort {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $OID_vlanTrunkPortDynamicState
        = "1.3.6.1.4.1.9.9.46.1.6.1.1.13";    #CISCO-VTP-MIB
    if ( !$self->connectRead() ) {
        return 0;
    }
    $logger->trace(
        "SNMP get_request for vlanTrunkPortDynamicState: $OID_vlanTrunkPortDynamicState"
    );
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => ["$OID_vlanTrunkPortDynamicState.$ifIndex"] );
    return (
        exists( $result->{"$OID_vlanTrunkPortDynamicState.$ifIndex"} )
            && ( $result->{"$OID_vlanTrunkPortDynamicState.$ifIndex"} ne
            'noSuchInstance' )
            && ( $result->{"$OID_vlanTrunkPortDynamicState.$ifIndex"} == 1 )
    );
}

=item setModeTrunk - sets a port as mode access or mode trunk

=cut

sub setModeTrunk {
    my ( $self, $ifIndex, $enable ) = @_;
    my $logger = $self->logger;
    my $OID_vlanTrunkPortDynamicState = "1.3.6.1.4.1.9.9.46.1.6.1.1.13";    #CISCO-VTP-MIB

    # $mode = 1 -> switchport mode trunk
    # $mode = 2 -> switchport mode access

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port vlanTrunkPortDynamicState");
        return 1;
    }
    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $truthValue = $enable ? $SNMP::TRUE : $SNMP::FALSE;
    $logger->trace("SNMP set_request for vlanTrunkPortDynamicState: $OID_vlanTrunkPortDynamicState");
    my $result = $self->{_sessionWrite}->set_request( -varbindlist => [ "$OID_vlanTrunkPortDynamicState.$ifIndex",
        Net::SNMP::INTEGER, $truthValue ] );
    return ( defined($result) );
}

sub getVlans {
    my ($self)          = @_;
    my $vlans           = {};
    my $oid_vtpVlanName = '1.3.6.1.4.1.9.9.46.1.3.1.1.4.1';    #CISCO-VTP-MIB
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return $vlans;
    }
    $logger->trace("SNMP get_request for vtpVlanName: $oid_vtpVlanName");
    my $result
        = $self->{_sessionRead}->get_table( -baseoid => $oid_vtpVlanName );
    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            $key =~ /^$oid_vtpVlanName\.(\d+)$/;
            $vlans->{$1} = $result->{$key};
        }
    } else {
        $logger->info( "result is not defined at switch " . $self->{_ip} );
    }
    return $vlans;
}

sub isDefinedVlan {
    my ( $self, $vlan ) = @_;
    my $oid_vtpVlanName = '1.3.6.1.4.1.9.9.46.1.3.1.1.4.1';    #CISCO-VTP-MIB
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return 0;
    }
    $logger->trace(
        "SNMP get_request for vtpVlanName: $oid_vtpVlanName.$vlan");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$oid_vtpVlanName.$vlan"] );
    return (   defined($result)
            && exists( $result->{"$oid_vtpVlanName.$vlan"} )
            && ( $result->{"$oid_vtpVlanName.$vlan"} ne 'noSuchInstance' ) );
}

sub isNotUpLink {
    my ( $self, $ifIndex ) = @_;
    return ( grep( { $_ == $ifIndex } $self->getUpLinks() ) == 0 );
}

# FIXME I just refactored that method but I think we should simply get rid
# of the uplinks=... concept. If you've configured access-control on an
# uplink then it's your problem. Anyway we don't do anything on RADIUS based
# requests. I guess this was there at first because of misconfigured up/down
# traps causing concerns.
sub getUpLinks {
    my ( $self ) = @_;
    my $logger = get_logger();

    # not dynamic, return uplink list
    return @{ $self->{_uplink} } if ( lc(@{ $self->{_uplink} }[0]) ne 'dynamic' );

    # dynamic uplink lookup
    if ( !$self->connectRead() ) {
        return -1;
    }

    my $oid_cdpGlobalRun = '1.3.6.1.4.1.9.9.23.1.3.1'; # Is CDP enabled ? MIB: cdpGlobalRun
    $logger->trace("SNMP get_table for cdpGlobalRun: $oid_cdpGlobalRun");
    my $result = $self->{_sessionRead}->get_table( -baseoid => $oid_cdpGlobalRun );
    if (!defined($result)) {
        $logger->warn(
            "Problem while determining dynamic uplinks for switch $self->{_ip}: "
            . "can not read cdpGlobalRun."
        );
        return -1;
    }

    my @cdpRun = values %{$result};
    if ( $cdpRun[0] != 1 ) {
        $logger->warn(
            "Problem while determining dynamic uplinks for switch $self->{_ip}: "
            . "based on the config file, uplinks are dynamic but CDP is not enabled on this switch."
        );
        return -1;
    }

    # CDP is enabled
    my $oid_cdpCacheCapabilities = '1.3.6.1.4.1.9.9.23.1.2.1.1.9';

    # fetch the upLinks. MIB: cdpCacheCapabilities
    $logger->trace("SNMP get_next_request for $oid_cdpCacheCapabilities");
    # we could have chosen another oid since many of them return uplinks.
    $result = $self->{_sessionRead}->get_table(-baseoid => $oid_cdpCacheCapabilities);
    if (!defined($result)) {
        $logger->warn(
            "Problem while determining dynamic uplinks for switch "
            . "$self->{_ip}: can not read cdpCacheCapabilities."
        );
        return -1;
    }

    my @upLinks;
    foreach my $key ( keys %{$result} ) {
        if ( !(hex($result->{$key}) & 0x00000080 )) {
            $key =~ /^$oid_cdpCacheCapabilities\.(\d+)\.\d+$/;
            push @upLinks, $1;
            $logger->debug("upLink: $1");
        }
    }

    return @upLinks;
}

=item getMacAddr

Warning: this method should _never_ be called in a thread. Net::Appliance::Session is not thread
safe:

L<http://www.cpanforum.com/threads/6909/>

=cut

sub getMacAddr {
    my ( $self, @managedPorts ) = @_;
    my $command;
    my $session;
    my @macAddressTable;
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
        return @macAddressTable;
    }

    if ( scalar(@managedPorts) > 0 ) {
        $command = 'show mac-address-table | include '
            . $self->getRegExpFromList(@managedPorts);
    } else {
        $command = 'show mac-address-table';
    }
    $logger->trace("sending CLI command '$command'");
    my @tmp = $session->cmd($command);
    $logger->trace(
        "output of CLI command '$command':\n" . join( "\n", @tmp ) );

    foreach my $line (@tmp) {
        $line =~ s/\n//;
        push @macAddressTable, $line unless ( $line =~ /^$/ );
    }
    $session->close();
    return @macAddressTable;
}

sub getManagedIfIndexes {
    my $self   = shift;
    my $logger = $self->logger;
    my @managedIfIndexes;
    my @tmp_managedIfIndexes = $self->SUPER::getManagedIfIndexes();
    foreach my $ifIndex (@tmp_managedIfIndexes) {
        my $port_type = $self->getVmVlanType($ifIndex);
        if ( ( $port_type == 1 ) || ( $port_type == 4 ) ) {  # skip non static
            push @managedIfIndexes, $ifIndex;
        } else {
            $logger->debug(
                "$ifIndex excluded from managed ifIndexes since its port type is not static"
            );
        }
    }
    return @managedIfIndexes;
}

sub getMacAddrVlan {
    my $self = shift;
    my %macVlan;
    my @managedPorts = $self->getManagedPorts();
    my @macAddr;
    my $logger = $self->logger;

    @macAddr = $self->getMacAddr(@managedPorts);

    my $ifDescMacVlan = $self->_getIfDescMacVlan(@macAddr);

    foreach my $ifDesc ( keys %$ifDescMacVlan ) {
        my @macs = keys %{ $ifDescMacVlan->{$ifDesc} };

        $logger->debug( "port: $ifDesc; number of MACs: " . scalar(@macs) );

        if ( scalar(@macs) == 1 ) {
            $macVlan{ $macs[0] }{'vlan'}
                = ${ $ifDescMacVlan->{$ifDesc}->{ $macs[0] } }[0];
            $macVlan{ $macs[0] }{'ifIndex'} = $ifDesc;
        } elsif ( scalar(@macs) > 1 ) {    # more than 1 MAC => hub
            my $macString = '';
            foreach my $mac (@macs) {
                $macString
                    .= "- $mac (Vlan :"
                    . join( ', ', @{ $ifDescMacVlan->{$ifDesc}->{$mac} } )
                    . ")\n";
            }
            chomp($macString);
            $logger->warn(
                "ALERT: There is a hub on switch $self->{'_ip'} port $ifDesc. We found the following "
                    . scalar(@macs)
                    . " MACs on this port:\n$macString" );
        }
    }
    $logger->debug("Show VLAN and port for every MAC (dumper):");
    $logger->debug( Dumper(%macVlan) );

    return %macVlan;
}

sub getAllMacs {
    my ( $self, @ifIndexes ) = @_;
    my $logger = $self->logger;
    if ( !@ifIndexes ) {
        @ifIndexes = $self->getManagedIfIndexes();
    }
    my $ifIndexVlanMacHashRef;
    my $OID_dot1dTpFdbPort       = '1.3.6.1.2.1.17.4.3.1.2';    #BRIDGE-MIB
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB

    if ( !$self->connectRead() ) {
        return $ifIndexVlanMacHashRef;
    }

    #obtain ifPhysAddress array
    my $OID_ifPhysAddress = '1.3.6.1.2.1.2.2.1.6';
    $logger->trace("SNMP get_table for ifPhysAddress: $OID_ifPhysAddress");
    my $result
        = $self->{_sessionRead}->get_table( -baseoid => $OID_ifPhysAddress );
    my %ifPhysAddressHash;
    foreach my $key ( keys %{$result} ) {
        $key =~ /^$OID_ifPhysAddress\.(\d+)$/;
        my $ifIndex = $1;
        my $mac     = $result->{$key};
        if ( $mac
            =~ /0x([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})/i
            )
        {
            $mac = uc("$1:$2:$3:$4:$5:$6");
            $ifPhysAddressHash{$mac} = $ifIndex;
        }
    }

    my @vlansOnSwitch   = keys %{ $self->getVlans() };
    my @vlansToConsider = values %{ $self->{_vlans} };
    if ( $self->isVoIPEnabled() ) {
        my $OID_vmVoiceVlanId
            = '1.3.6.1.4.1.9.9.68.1.5.1.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
        $logger->trace(
            "SNMP get_table for vmVoiceVlanId: $OID_vmVoiceVlanId");
        $result = $self->{_sessionRead}
            ->get_table( -baseoid => $OID_vmVoiceVlanId );
        foreach my $vlan ( values %{$result} ) {
            if ( grep( { $_ == $vlan } @vlansToConsider ) == 0 ) {
                push @vlansToConsider, $vlan;
            }
        }
    }
    foreach my $vlan (@vlansToConsider) {
        if ( grep( { $_ == $vlan } @vlansOnSwitch ) > 0 ) {

            #connect to switch with the right VLAN information
            $result = undef;
            my %dot1dBasePortIfIndexHash;

            #issue correct SNMP query depending on SNMP version
            if ( $self->{_SNMPVersion} eq '3' ) {
                $logger->trace(
                    "SNMP v3 get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex"
                );
                $result = $self->{_sessionRead}->get_table(
                    -baseoid     => $OID_dot1dBasePortIfIndex,
                    -contextname => "vlan_$vlan"
                );
                foreach my $key ( keys %{$result} ) {
                    $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
                    $dot1dBasePortIfIndexHash{$1} = $result->{$key};
                }
                $logger->trace(
                    "SNMP v3 get_table for dot1dTpFdbPort: $OID_dot1dTpFdbPort"
                );
                $result = $self->{_sessionRead}->get_table(
                    -baseoid     => $OID_dot1dTpFdbPort,
                    -contextname => "vlan_$vlan"
                );
                # FIXME: calling "private" method to unset context. See #1284 or upstream rt.cpan.org:72075.
                $self->{_sessionRead}->{_context_name} = undef;
            } else {
                my ( $sessionReadVlan, $sessionReadVlanError )
                    = Net::SNMP->session(
                    -hostname  => $self->{_ip},
                    -version   => $self->{_SNMPVersion},
                    -retries   => 1,
                    -timeout   => 2,
                    -maxmsgsize => 4096,
                    -community => $self->{_SNMPCommunityRead} . '@' . $vlan
                    );

                if ( defined($sessionReadVlan) ) {

                    #get dot1dBasePort to ifIndex association
                    $logger->trace(
                        "SNMP get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex"
                    );
                    $result = $sessionReadVlan->get_table(
                        -baseoid => $OID_dot1dBasePortIfIndex );
                    foreach my $key ( keys %{$result} ) {
                        $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
                        $dot1dBasePortIfIndexHash{$1} = $result->{$key};
                    }
                    $logger->trace(
                        "SNMP get_table for dot1dTpFdbPort: $OID_dot1dTpFdbPort"
                    );
                    $result = $sessionReadVlan->get_table(
                        -baseoid => $OID_dot1dTpFdbPort );
                } else {
                    $logger->error(
                        "cannot connect to obtain do1dBasePortIfIndex information in VLAN $vlan"
                    );
                }
            }

            if ( defined($result) ) {
                foreach my $key ( keys %{$result} ) {
                    if ( exists $dot1dBasePortIfIndexHash{ $result->{$key} } )
                    {
                        $key
                            =~ /^$OID_dot1dTpFdbPort\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
                        my $mac = sprintf( "%02X:%02X:%02X:%02X:%02X:%02X",
                            $1, $2, $3, $4, $5, $6 );
                        if ( !exists( $ifPhysAddressHash{$mac} ) ) {
                            my $ifIndex = $dot1dBasePortIfIndexHash{ $result
                                    ->{$key} };
                            if ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) {
                                push @{ $ifIndexVlanMacHashRef->{$ifIndex}
                                        ->{$vlan} }, $mac;
                            }
                        }
                    }
                }
            }
        }
    }
    return $ifIndexVlanMacHashRef;
}

sub getHubs {
    my $self = shift;
    my $hubPorts;
    my @macAddr;
    my @managedPorts = $self->getManagedPorts();
    my $logger       = $self->logger;

    if (@managedPorts) {

        @macAddr = $self->getMacAddr(@managedPorts);

        my $ifDescMacVlan = $self->_getIfDescMacVlan(@macAddr);

        foreach my $ifDesc ( keys %$ifDescMacVlan ) {
            my @macs = keys %{ $ifDescMacVlan->{$ifDesc} };
            if ( scalar(@macs) > 1 ) {
                @{ $hubPorts->{$ifDesc} } = @macs;
            }
        }

    }
    return $hubPorts;
}

sub getPhonesCDPAtIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my @phones;
    if ( !$self->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch "
                . $self->{_ip}
                . ". getPhonesCDPAtIfIndex will return empty list." );
        return @phones;
    }
    my $oid_cdpCacheDeviceId = '1.3.6.1.4.1.9.9.23.1.2.1.1.6';
    my $oid_cdpCacheCapabilities = '1.3.6.1.4.1.9.9.23.1.2.1.1.9';
    if ( !$self->connectRead() ) {
        return @phones;
    }
    $logger->trace("SNMP get_next_request for $oid_cdpCacheCapabilities");
    my $result = $self->{_sessionRead}->get_next_request(
        -varbindlist => ["$oid_cdpCacheCapabilities.$ifIndex"] );
    foreach my $oid ( keys %{$result} ) {
        if ( $oid =~ /^$oid_cdpCacheCapabilities\.$ifIndex\.([0-9]+)$/ ) {
            my $cacheDeviceIndex = $1;
             if ( hex($result->{$oid}) & 0x00000080 ) {
                $logger->warn("SNMP get_request for $oid_cdpCacheDeviceId");
                my $MACresult
                    = $self->{_sessionRead}->get_request( -varbindlist =>
                        ["$oid_cdpCacheDeviceId.$ifIndex.$cacheDeviceIndex"]
                    );
                if ($MACresult
                    && ($MACresult->{
                            "$oid_cdpCacheDeviceId.$ifIndex.$cacheDeviceIndex"
                        }
                        =~ /^(SEP|SIP)([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})$/i
                    )
                    )
                {
                    push @phones, lc("$2:$3:$4:$5:$6:$7");
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

=item copyConfig

Copy the configuration.

Source and destination types are defined under ConfigFileType from CISCO-CONFIG-COPY MIB.
Local values are available in L<pf::Switch::constants>.

We could support other destination types if there was motivation to do so.

Notice that we are throwing exceptions in here so make sure to trap them!

Inspired by: http://www.notarus.net/networking/cisco_snmp_config.html#wrmem

=cut

sub copyConfig {
    my ( $self, $src_type, $dest_type, $uri ) = @_;
    my $logger = $self->logger;

    # Validation
    die("Can't connect in SNMP Read to switch " . $self->{_ip}) if (!$self->connectRead());
    die("Can't connect in SNMP Write to switch " . $self->{_ip}) if (!$self->connectWrite());

    my @supported = ($CISCO::STARTUP_CONFIG, $CISCO::RUNNING_CONFIG);
    die("Copy source not supported!") if (!grep $_ eq $src_type, @supported);
    die("Copy destination not supported!") if (!grep $_ eq $dest_type, @supported);

    my $OID_ccCopyProtocol = '1.3.6.1.4.1.9.9.96.1.1.1.1.2';    #CISCO-CONFIG-COPY-MIB
    my $OID_ccCopySourceFileType = '1.3.6.1.4.1.9.9.96.1.1.1.1.3';
    my $OID_ccCopyDestFileType   = '1.3.6.1.4.1.9.9.96.1.1.1.1.4';
    my $OID_ccCopyState          = '1.3.6.1.4.1.9.9.96.1.1.1.1.10';
    my $OID_ccCopyEntryRowStatus = '1.3.6.1.4.1.9.9.96.1.1.1.1.14';
    # Unsupported for now
    #my $OID_ccCopyServerAddress  = '1.3.6.1.4.1.9.9.96.1.1.1.1.5';
    #my $OID_ccCopyFileName       = '1.3.6.1.4.1.9.9.96.1.1.1.1.6';
    #my $OID_ccCopyUserName       = '1.3.6.1.4.1.9.9.96.1.1.1.1.7';
    #my $OID_ccCopyUserPassword   = '1.3.6.1.4.1.9.9.96.1.1.1.1.8';

    # generate random number and make sure the switches copy mechanisms are not already using it
    my ($result, $random);
    my $nb = 0;
    do {
        $nb++;
        $random = 1 + int( rand(1000) );
        $logger->trace("SNMP get_request for ccCopyEntryRowStatus: $OID_ccCopyEntryRowStatus.$random");
        $result = $self->{_sessionRead}->get_request(-varbindlist => [ "$OID_ccCopyEntryRowStatus.$random" ] );
        if ( defined($result) ) {
            $logger->debug("ccCopyTable row $random is already used - let's generate a new random number");
        } else {
            $logger->debug("ccCopyTable row $random is free - starting to create it");
        }
    } while ( ( $nb <= 20 ) && ( defined($result) ) );

    # we couldn't find an unsued copy slot
    if ( $nb == 20 ) {
        die("Unable to find unused entry in ccCopyTable! Can't copy config.");
    }

    my $varbindlist = [
        "$OID_ccCopySourceFileType.$random", Net::SNMP::INTEGER, $src_type,
        "$OID_ccCopyDestFileType.$random", Net::SNMP::INTEGER, $dest_type,
        "$OID_ccCopyEntryRowStatus.$random", Net::SNMP::INTEGER, $SNMP::CREATE_AND_GO,
    ];

    # Not supported for now
    # proto://user:pass@ip/filename with URI parser
    # my ($ip, $user, $pass, $filename) = parsed-uri;
    #    "$OID_ccCopyProtocol.$random", Net::SNMP::INTEGER, 2,
    #    "$OID_ccCopyServerAddress.$random", Net::SNMP::IPADDRESS, $ip,
    #    "$OID_ccCopyUserName.$random", Net::SNMP::OCTET_STRING, $user,
    #    "$OID_ccCopyUserPassword.$random", Net::SNMP::OCTET_STRING, $pass,
    #    "$OID_ccCopyFileName.$random", Net::SNMP::OCTET_STRING, $filename,

    $logger->trace("SNMP set_request to create entry in ccCopyTable: @$varbindlist");

    $result = $self->{_sessionWrite}->set_request( -varbindlist => $varbindlist );
    if ( defined($result) ) {
        $logger->debug("ccCopyTable row $random successfully created");
        $nb = 0;
        do {
            $nb++;
            sleep(1);
            $logger->trace("SNMP get_request for ccCopyState: $OID_ccCopyState.$random");
            $result = $self->{_sessionRead}->get_request( -varbindlist => [ "$OID_ccCopyState.$random" ] );
        } while ( ( $nb <= 120 ) && defined($result) && ( $result->{"$OID_ccCopyState.$random"} == 2 ) );

        if ( $nb == 120 ) {
            die("Config copy operation seems not to complete on " . $self->{_ip});
        }

        $logger->debug("deleting ccCopyTable row $random");
        $logger->trace(
            "SNMP set_request for ccCopyEntryRowStatus: $OID_ccCopyEntryRowStatus.$random"
        );
        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [ "$OID_ccCopyEntryRowStatus.$random", Net::SNMP::INTEGER, $SNMP::DESTROY ]
        );
    } else {
        die("Problem copying configuration on ".$self->{_ip}.": " . $self->{_sessionWrite}->error() );
    }
    return ( defined($result) );
}

=item saveConfig

Save the running config into startup config.
Exact equivalent of doing a 'write mem' on the CLI.

Notice that we are throwing exceptions in here so make sure to trap them!

=cut

sub saveConfig {
    my ($self) = @_;
    $self->copyConfig($CISCO::RUNNING_CONFIG, $CISCO::STARTUP_CONFIG);
}

=item _radiusBounceMac

Using RADIUS Change of Authorization (CoA) defined in RFC3576 to bounce the port where a given MAC is present.

Uses L<pf::util::dhcp> for the low-level RADIUS stuff.

At proof of concept stage. For now using SNMP is still preferred way to bounce a port.

=cut

sub _radiusBounceMac {
    my ( $self, $mac ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform port bounce");
        return 1;
    }

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS CoA-Request on $self->{'_id'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("boucing MAC $mac using RADIUS CoA-Request method");

    # translating to expected format 00-11-22-33-CA-FE
    $mac = uc($mac);
    $mac =~ s/:/-/g;

    my $response;
    my $send_disconnect_to = $self->{'_controllerIp'} || $self->{'_ip'};
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip($send_disconnect_to),
        };

        $response = perform_coa( $connection_info,
            {
                'Acct-Terminate-Cause' => 'Admin-Reset',
                'NAS-IP-Address' => $self->{'_switchIp'},
                'Calling-Station-Id' => $mac,
            },
            [{ 'vendor' => 'Cisco', 'attribute' => 'Cisco-AVPair', 'value' => 'subscriber:command=bounce-host-port' }],
        );
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request: $_");
        $logger->error("Wrong RADIUS secret or unreachable network device...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'CoA-ACK');

    $logger->warn(
        "Unable to perform RADIUS CoA-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=item returnAuthorizeWrite

Return radius attributes to allow write access

=cut

sub returnAuthorizeWrite {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    my $radius_reply_ref;
    my $status;
    $radius_reply_ref->{'Cisco-AVPair'} = 'shell:priv-lvl=15';
    $radius_reply_ref->{'Reply-Message'} = "Switch enable access granted by PacketFence";
    $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with write access");
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeWrite', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];

}

=item returnAuthorizeRead

Return radius attributes to allow read access

=cut

sub returnAuthorizeRead {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    my $radius_reply_ref;
    my $status;
    $radius_reply_ref->{'Cisco-AVPair'} = 'shell:priv-lvl=3';
    $radius_reply_ref->{'Reply-Message'} = "Switch read access granted by PacketFence";
    $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with read access");
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeRead', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=item _findTrapNormalizer

Find the normalizer method for the trap for Cisco switches

=cut

sub _findTrapNormalizer {
    my ($self, $snmpTrapOID, $pdu, $variables) = @_;
    if (exists $TRAP_NORMALIZERS{$snmpTrapOID}) {
        return $TRAP_NORMALIZERS{$snmpTrapOID};
    }
    return undef;
}

=item cpsSecureMacAddrViolationTrapNormalizer

The trap normalizer for cpsSecureMacAddrViolation traps

=cut

sub cpsSecureMacAddrViolationTrapNormalizer {
    my ($self, $trapInfo) = @_;
    my ($pdu, $variables) = @$trapInfo;
    my $ifIndex = $self->getIfIndexFromTrap($variables);
    return {
        trapType => 'secureMacAddrViolation',
        trapIfIndex => $ifIndex,
        trapVlan => $self->getVlan( $ifIndex ),
        trapMac => $self->getMacFromTrapVariablesForOIDBase($variables, '.1.3.6.1.4.1.9.9.315.1.2.1.1.10.'),
    }
}

=item cpsTrunkSecureMacAddrViolationTrapNormalizer

The trap normalizer for cpsTrunkSecureMacAddrViolation traps

=cut

sub cpsTrunkSecureMacAddrViolationTrapNormalizer {
    my ($self, $trapInfo) = @_;
    return $self->cpsSecureMacAddrViolationTrapNormalizer($trapInfo);
}

=item cmnMacChangedNotificationTrapNormalizer

The trap normalizer for cmnMacChangedNotificationTrapNormalizer

=cut

sub cmnMacChangedNotificationTrapNormalizer {
    my ($self, $trapInfo) = @_;
    my ($pdu, $variables) = @$trapInfo;
    my $logger = $self->logger;
    my ($variable) = $self->findTrapVarWithBase($variables, ".1.3.6.1.4.1.9.9.215.1.1.8.1.2.");
    return undef unless $variable;
    return undef unless $variable->[1] =~ /Hex-STRING: ([0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2})/;
    my $trapHashRef = { trapType => 'mac'};
    if ($1 == 1) {
        $trapHashRef->{'trapOperation'} = 'learnt';
    }
    elsif ($1 == 2) {
        $trapHashRef->{'trapOperation'} = 'removed';
    }
    else {
        $trapHashRef->{'trapOperation'} = 'unknown';
    }
    $trapHashRef->{'trapVlan'}    = $2;
    $trapHashRef->{'trapMac'}     = lc($3);
    $trapHashRef->{'trapIfIndex'} = $4;
    $trapHashRef->{'trapVlan'} =~ s/ //g;
    $trapHashRef->{'trapVlan'} = hex($trapHashRef->{'trapVlan'});
    $trapHashRef->{'trapIfIndex'} =~ s/ //g;
    $trapHashRef->{'trapIfIndex'} = hex($trapHashRef->{'trapIfIndex'});
    $trapHashRef->{'trapMac'} =~ s/ /:/g;

    #convert the dot1dBasePort into an ifIndex
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';        #BRIDGE-MIB
    my $dot1dBasePort            = $trapHashRef->{'trapIfIndex'};

    #populate list of Vlans we must potentially connect to to
    #convert the dot1dBasePort into an ifIndex
    my @vlansToTest      = ();
    push @vlansToTest, $trapHashRef->{'trapVlan'};
    foreach my $currentVlan (values %{$self->{_vlans}}) {
        if ($currentVlan != $trapHashRef->{'trapVlan'})
        {
            push @vlansToTest, $currentVlan;
        }
    }
    my $found   = 0;
    my $vlanPos = 0;
    my $vlans   = $self->getVlans();
    while (($vlanPos < scalar(@vlansToTest)) && ($found == 0)) {
        my $currentVlan = $vlansToTest[$vlanPos];
        my $result      = undef;

        if (defined $currentVlan && exists($vlans->{$currentVlan})) {

            #issue correct SNMP query depending on SNMP version
            if ($self->{_SNMPVersion} eq '3') {
                if ($self->connectRead()) {
                    $logger->trace(
                        "SNMP get_request for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex.$dot1dBasePort");
                    $result = $self->{_sessionRead}->get_request(
                        -varbindlist => ["$OID_dot1dBasePortIfIndex.$dot1dBasePort"],
                        -contextname => "vlan_$currentVlan"
                    );

                    # FIXME: calling "private" method to unset context. See #1284 or upstream rt.cpan.org:72075.
                    $self->{_sessionRead}->{_context_name} = undef;
                }
            }
            else {
                my ($sessionReadVlan, $sessionReadVlanError) = Net::SNMP->session(
                    -hostname   => $self->{_ip},
                    -version    => $self->{_SNMPVersion},
                    -retries    => 1,
                    -timeout    => 2,
                    -maxmsgsize => 4096,
                    -community  => $self->{_SNMPCommunityRead} . '@' . $currentVlan
                );
                if (defined($sessionReadVlan)) {
                    $logger->trace(
                        "SNMP get_request for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex.$dot1dBasePort");
                    $result =
                      $sessionReadVlan->get_request(-varbindlist => ["$OID_dot1dBasePortIfIndex.$dot1dBasePort"]);
                }
                else {
                    $logger->debug("cannot connect to obtain do1dBasePortIfIndex information in VLAN $currentVlan");
                }
            }

            #did we get a result ?
            if (   defined($result)
                && (exists($result->{"$OID_dot1dBasePortIfIndex.$dot1dBasePort"}))
                && ($result->{"$OID_dot1dBasePortIfIndex.$dot1dBasePort"} ne 'noSuchInstance'))
            {
                $trapHashRef->{'trapIfIndex'} = $result->{"$OID_dot1dBasePortIfIndex.$dot1dBasePort"};
                $logger->debug("converted dot1dBasePort $dot1dBasePort into ifIndex "
                      . $trapHashRef->{'trapIfIndex'}
                      . " in vlan $currentVlan");
                $found = 1;
            }
            else {
                $logger->debug("cannot convert dot1dBasePort $dot1dBasePort into ifIndex in VLAN $currentVlan - "
                      . (scalar(@vlansToTest) - $vlanPos - 1)
                      . " more vlans to try");
            }
        }
        $vlanPos++;
    }
    if ($found == 0) {
        $logger->error("could not convert dot1dBasePort into ifIndex in any VLAN. Setting trapType to unknown");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
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
