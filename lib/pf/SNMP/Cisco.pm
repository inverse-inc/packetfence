package pf::SNMP::Cisco;

=head1 NAME

pf::SNMP::Cisco

=cut

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Data::Dumper;
use base ('pf::SNMP');
use Log::Log4perl;
use Net::SNMP;
use Net::Appliance::Session;
use Try::Tiny;

use pf::config;
# importing switch constants
use pf::SNMP::constants;
use pf::util;
use pf::util::radius qw(perform_coa);

# CAPABILITIES
# special features
sub supportsSaveConfig { return $TRUE; }
sub supportsCdp { return $TRUE; }

=head1 SUBROUTINES

TODO: This list is incomplete

=over

=cut

sub getVersion {
    my ($this)       = @_;
    my $oid_sysDescr = '1.3.6.1.2.1.1.1.0';
    my $logger       = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysDescr: $oid_sysDescr");
    my $result = $this->{_sessionRead}
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
    my ( $this, $versionToCompareToString ) = @_;
    my $currentVersion = $this->getVersion();
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
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );

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
        my $macDetectionVlan = $this->getVlanByName('macDetection');
        push @vlansToTest, $trapHashRef->{'trapVlan'};
        push @vlansToTest, $macDetectionVlan;
        foreach my $currentVlan ( values %{ $this->{_vlans} } ) {
            if (   ( $currentVlan != $trapHashRef->{'trapVlan'} )
                && ( $currentVlan != $macDetectionVlan ) )
            {
                push @vlansToTest, $currentVlan;
            }
        }
        my $found   = 0;
        my $vlanPos = 0;
        my $vlans   = $this->getVlans();
        while ( ( $vlanPos < scalar(@vlansToTest) ) && ( $found == 0 ) ) {
            my $currentVlan = $vlansToTest[$vlanPos];
            my $result      = undef;

            if ( exists( $vlans->{$currentVlan} ) ) {

                #issue correct SNMP query depending on SNMP version
                if ( $this->{_SNMPVersion} eq '3' ) {
                    if ( $this->connectRead() ) {
                        $logger->trace(
                            "SNMP get_request for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex.$dot1dBasePort"
                        );
                        $result = $this->{_sessionRead}->get_request(
                            -varbindlist =>
                                ["$OID_dot1dBasePortIfIndex.$dot1dBasePort"],
                            -contextname => "vlan_$currentVlan"
                        );
                        # FIXME: calling "private" method to unset context. See #1284 or upstream rt.cpan.org:72075.
                        $this->{_sessionRead}->{_context_name} = undef;
                    }
                } else {
                    my ( $sessionReadVlan, $sessionReadVlanError )
                        = Net::SNMP->session(
                        -hostname  => $this->{_ip},
                        -version   => $this->{_SNMPVersion},
                        -retries   => 1,
                        -timeout   => 2,
                        -community => $this->{_SNMPCommunityRead} . '@'
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
        $trapHashRef->{'trapVlan'} = $this->getVlan( $trapHashRef->{'trapIfIndex'} );

        # CISCO-PORT-SECURITY-MIB cpsTrunkSecureMacAddrViolation
    } elsif ( $trapString
        =~ /BEGIN VARIABLEBINDINGS .+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.4\.1\.9\.9\.315\.0\.0\.2[|]\.1\.3\.6\.1\.2\.1\.31\.1\.1\.1\.1\.([0-9]+) = .+[|]\.1\.3\.6\.1\.4\.1\.9\.9\.315\.1\.2\.1\.1\.10\.[0-9]+ = $SNMP::MAC_ADDRESS_FORMAT/ ) {

        $trapHashRef->{'trapType'} = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1;
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($2);
        $trapHashRef->{'trapVlan'} = $this->getVlan( $trapHashRef->{'trapIfIndex'} );

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
    my ( $this, @ifIndexes ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $vlanHashRef;
    if ( !@ifIndexes ) {
        @ifIndexes = $this->getManagedIfIndexes();
    }

    my $OID_vmVlan
        = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB
    my $OID_vlanTrunkPortNativeVlan
        = '1.3.6.1.4.1.9.9.46.1.6.1.1.5';    #CISCO-VTP-MIB

    if ( !$this->connectRead() ) {
        return $vlanHashRef;
    }
    $logger->trace("SNMP get_table for vmVlan: $OID_vmVlan");
    my $result = $this->{_sessionRead}->get_table( -baseoid => $OID_vmVlan );
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
        $result = $this->{_sessionRead}
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
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_vmVoiceVlanId
        = '1.3.6.1.4.1.9.9.68.1.5.1.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->trace(
        "SNMP get_request for vmVoiceVlanId: $OID_vmVoiceVlanId.$ifIndex");
    my $result = $this->{_sessionRead}
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
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_vmVlan = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->trace("SNMP get_request for vmVlan: $OID_vmVlan.$ifIndex");

    my $result = $this->{_sessionRead}->get_request( -varbindlist => ["$OID_vmVlan.$ifIndex"] );
    if ( exists( $result->{"$OID_vmVlan.$ifIndex"} ) && ( $result->{"$OID_vmVlan.$ifIndex"} ne 'noSuchInstance' ) ) {
        return $result->{"$OID_vmVlan.$ifIndex"};
    } else {

        #this is a trunk port - try to get the trunk ports native VLAN
        my $OID_vlanTrunkPortNativeVlan
            = '1.3.6.1.4.1.9.9.46.1.6.1.1.5';    #CISCO-VTP-MIB
        $logger->trace(
            "SNMP get_request for vlanTrunkPortNativeVlan: $OID_vlanTrunkPortNativeVlan.$ifIndex"
        );
        my $result = $this->{_sessionRead}->get_request(
            -varbindlist => ["$OID_vlanTrunkPortNativeVlan.$ifIndex"] );
        return $result->{"$OID_vlanTrunkPortNativeVlan.$ifIndex"};
    }
}

sub isLearntTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_cmnMacAddrLearntEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.1';
    $logger->trace(
        "SNMP get_request for cmnMacAddrLearntEnable: $OID_cmnMacAddrLearntEnable"
    );
    my $result = $this->{_sessionRead}->get_request(
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
    my ( $this, $ifIndex, $trueFalse ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_cmnMacAddrLearntEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.1';
    $logger->trace(
        "SNMP set_request for cmnMacAddrLearntEnable: $OID_cmnMacAddrLearntEnable"
    );
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_cmnMacAddrLearntEnable.$ifIndex", Net::SNMP::INTEGER,
            $trueFalse
        ]
    );
    return ( defined($result) );
}

sub isRemovedTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_cmnMacAddrRemovedEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.2';
    $logger->debug(
        "SNMP get_request for cmnMacAddrRemovedEnable: $OID_cmnMacAddrRemovedEnable"
    );
    my $result = $this->{_sessionRead}->get_request(
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
    my ( $this, $ifIndex, $trueFalse ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_cmnMacAddrRemovedEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.2';
    $logger->trace(
        "SNMP set_request for cmnMacAddrRemovedEnable: $OID_cmnMacAddrRemovedEnable"
    );
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_cmnMacAddrRemovedEnable.$ifIndex", Net::SNMP::INTEGER,
            $trueFalse
        ]
    );
    return ( defined($result) );
}

sub isPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    #CISCO-PORT-SECURITY-MIB
    my $OID_cpsIfPortSecurityEnable = '1.3.6.1.4.1.9.9.315.1.2.1.1.1';

    if ( !$this->connectRead() ) {
        return 0;
    }

    #determine if port security is enabled
    $logger->trace(
        "SNMP get_request for cpsIfPortSecurityEnable: $OID_cpsIfPortSecurityEnable.$ifIndex"
    );
    my $result = $this->{_sessionRead}->get_request(
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
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $removedTrapsEnabled = $this->isRemovedTrapsEnabled($ifIndex);
    if ($removedTrapsEnabled) {
        $logger->debug("disabling removed traps for port $ifIndex before VLAN change");
        $this->setRemovedTrapsEnabled( $ifIndex, $SNMP::FALSE );
    }

    my $result;
    if ( $this->isTrunkPort($ifIndex) ) {

        $result = $this->setTrunkPortNativeVlan($ifIndex, $newVlan);

        #expirer manuellement la mac-address-table
        $this->clearMacAddressTable( $ifIndex, $oldVlan );

    } else {
        my $OID_vmVlan = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB
        $logger->trace("SNMP set_request for vmVlan: $OID_vmVlan");
        $result = $this->{_sessionWrite}->set_request( -varbindlist =>[
            "$OID_vmVlan.$ifIndex", Net::SNMP::INTEGER, $newVlan ] );
    }
    my $returnValue = ( defined($result) );

    if ($removedTrapsEnabled) {
        $logger->debug("re-enabling removed traps for port $ifIndex after VLAN change");
        $this->setRemovedTrapsEnabled( $ifIndex, $SNMP::TRUE );
    }

    return $returnValue;
}

=item setTrunkPortNativeVlan - sets PVID on a trunk port

=cut

sub setTrunkPortNativeVlan {
    my ( $this, $ifIndex, $newVlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $result;
    my $OID_vlanTrunkPortNativeVlan = '1.3.6.1.4.1.9.9.46.1.6.1.1.5';    #CISCO-VTP-MIB
    $logger->trace("SNMP set_request for vlanTrunkPortNativeVlan: $OID_vlanTrunkPortNativeVlan");
    $result = $this->{_sessionWrite}->set_request( -varbindlist => [
        "$OID_vlanTrunkPortNativeVlan.$ifIndex", Net::SNMP::INTEGER, $newVlan] );

    return $result;

}

# fetch port type
# 1 => static
# 2 => dynamic
# 3 => multivlan
# 4 => trunk
sub getVmVlanType {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_vmVlanType
        = '1.3.6.1.4.1.9.9.68.1.2.2.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->trace(
        "SNMP get_request for vmVlanType: $OID_vmVlanType.$ifIndex");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_vmVlanType.$ifIndex"] );
    if ( exists( $result->{"$OID_vmVlanType.$ifIndex"} )
        && ( $result->{"$OID_vmVlanType.$ifIndex"} ne 'noSuchInstance' ) )
    {
        return $result->{"$OID_vmVlanType.$ifIndex"};
    } elsif ( $this->isTrunkPort($ifIndex) ) {
        return 4;
    } else {
        return 0;
    }
}

sub setVmVlanType {
    my ( $this, $ifIndex, $type ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->info( "setting port $ifIndex vmVlanType from "
            . $this->getVmVlanType($ifIndex)
            . " to $type" );
    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't change this port VmVlanType"
        );
        return 1;
    }
    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_vmVlanType
        = '1.3.6.1.4.1.9.9.68.1.2.2.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->trace("SNMP set_request for vmVlanType: $OID_vmVlanType");
    my $result = $this->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_vmVlanType.$ifIndex", Net::SNMP::INTEGER, $type ] );
    return ( defined($result) );
}

=item getMacBridgePortHash

Cisco is very fancy about fetching it's VLAN information. In SNMPv3 the context
is used to specify a VLAN and in SNMPv1/2c an @<vlan> is appended to the
read-only community name when reading.

=cut

sub getMacBridgePortHash {
    my $this              = shift;
    my $vlan              = shift || '';
    my %macBridgePortHash = ();
    my $logger            = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1dTpFdbPort       = '1.3.6.1.2.1.17.4.3.1.2';    #BRIDGE-MIB
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB

    if ( !$this->connectRead() ) {
        return %macBridgePortHash;
    }

    #obtain ifPhysAddress array
    my $OID_ifPhysAddress = '1.3.6.1.2.1.2.2.1.6';
    $logger->trace("SNMP get_table for ifPhysAddress: $OID_ifPhysAddress");
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $OID_ifPhysAddress );
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
    if ( $this->{_SNMPVersion} eq '3' ) {
        $logger->trace(
            "SNMP v3 get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex"
        );
        $result = $this->{_sessionRead}->get_table(
            -baseoid     => $OID_dot1dBasePortIfIndex,
            -contextname => "vlan_$vlan"
        );
        foreach my $key ( keys %{$result} ) {
            $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
            $dot1dBasePortIfIndexHash{$1} = $result->{$key};
        }
        $logger->trace(
            "SNMP v3 get_table for dot1dTpFdbPort: $OID_dot1dTpFdbPort");
        $result = $this->{_sessionRead}->get_table(
            -baseoid     => $OID_dot1dTpFdbPort,
            -contextname => "vlan_$vlan"
        );
        # FIXME: calling "private" method to unset context. See #1284 or upstream rt.cpan.org:72075.
        $this->{_sessionRead}->{_context_name} = undef;
    } else {
        my ( $sessionReadVlan, $sessionReadVlanError ) = Net::SNMP->session(
            -hostname  => $this->{_ip},
            -version   => $this->{_SNMPVersion},
            -retries   => 1,
            -timeout   => 2,
            -community => $this->{_SNMPCommunityRead} . '@' . $vlan
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
    my ( $this, $mac ) = @_;
    my $logger   = Log::Log4perl::get_logger( ref($this) );
    my @macParts = split( ':', $mac );
    my @uplinks  = $this->getUpLinks();
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

    foreach my $vlan ( values %{ $this->{_vlans} } ) {
        my $result = undef;

        $logger->trace(
            "SNMP get_request for dot1dTpFdbPort: $oid on switch $this->{'_ip'}, VLAN $vlan"
        );

        if ( $this->{_SNMPVersion} eq '3' ) {
            $result = $this->{_sessionRead}->get_request(
                -varbindlist => [$oid],
                -contextname => "vlan_$vlan"
            );
            if ( defined($result) ) {
                my $dot1dPort = $result->{$oid};
                my $oid       = $OID_dot1dBasePortIfIndex . "." . $dot1dPort;
                my $result    = $this->{_sessionRead}->get_request(
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
            $this->{_sessionRead}->{_context_name} = undef;

        } else {

            #connect to switch with the right VLAN information
            my ( $sessionReadVlan, $sessionReadVlanError )
                = Net::SNMP->session(
                -hostname  => $this->{_ip},
                -version   => $this->{_SNMPVersion},
                -retries   => 1,
                -timeout   => 2,
                -community => $this->{_SNMPCommunityRead} . '@' . $vlan
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
    my ( $this, $mac, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
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

    my $vlan = $this->getVlan($ifIndex);

    if ( $this->{_SNMPVersion} eq '3' ) {
        my $result = $this->{_sessionRead}->get_request(
            -varbindlist => [$oid],
            -contextname => "vlan_$vlan"
        );
        if ( defined($result) ) {
            my $dot1dPort = $result->{$oid};
            my $oid       = $OID_dot1dBasePortIfIndex . "." . $dot1dPort;
            $logger->trace(
                "SNMP get_request for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex"
            );
            my $result = $this->{_sessionRead}->get_request(
                -varbindlist => [$oid],
                -contextname => "vlan_$vlan"
            );
            if ( $result->{$oid} == $ifIndex ) {
                $logger->debug(
                    "mac $mac found on switch $this->{'_ip'}, VLAN $vlan, ifIndex $ifIndex"
                );
                return 1;
            }
        }
        # FIXME: calling "private" method to unset context. See #1284 or upstream rt.cpan.org:72075.
        $this->{_sessionRead}->{_context_name} = undef;

    } else {

        #connect to switch with the right VLAN information
        my ( $sessionReadVlan, $sessionReadVlanError ) = Net::SNMP->session(
            -hostname  => $this->{_ip},
            -version   => $this->{_SNMPVersion},
            -retries   => 1,
            -timeout   => 2,
            -community => $this->{_SNMPCommunityRead} . '@' . $vlan
        );

        if ( defined($sessionReadVlan) ) {
            $logger->trace(
                "SNMP get_request for dot1dBasePortIfIndex: $oid on switch $this->{'_ip'}, VLAN $vlan"
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
                        "mac $mac found on switch $this->{'_ip'}, VLAN $vlan, ifIndex $ifIndex"
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
        "MAC $mac could not be found on switch $this->{'_ip'}, VLAN $vlan, ifIndex $ifIndex"
    );
    return 0;
}

sub isTrunkPort {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_vlanTrunkPortDynamicState
        = "1.3.6.1.4.1.9.9.46.1.6.1.1.13";    #CISCO-VTP-MIB
    if ( !$this->connectRead() ) {
        return 0;
    }
    $logger->trace(
        "SNMP get_request for vlanTrunkPortDynamicState: $OID_vlanTrunkPortDynamicState"
    );
    my $result = $this->{_sessionRead}->get_request(
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
    my ( $this, $ifIndex, $enable ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_vlanTrunkPortDynamicState = "1.3.6.1.4.1.9.9.46.1.6.1.1.13";    #CISCO-VTP-MIB

    # $mode = 1 -> switchport mode trunk
    # $mode = 2 -> switchport mode access

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port vlanTrunkPortDynamicState");
        return 1;
    }
    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $truthValue = $enable ? $SNMP::TRUE : $SNMP::FALSE;
    $logger->trace("SNMP set_request for vlanTrunkPortDynamicState: $OID_vlanTrunkPortDynamicState");
    my $result = $this->{_sessionWrite}->set_request( -varbindlist => [ "$OID_vlanTrunkPortDynamicState.$ifIndex",
        Net::SNMP::INTEGER, $truthValue ] );
    return ( defined($result) );
}

sub getVlans {
    my ($this)          = @_;
    my $vlans           = {};
    my $oid_vtpVlanName = '1.3.6.1.4.1.9.9.46.1.3.1.1.4.1';    #CISCO-VTP-MIB
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectRead() ) {
        return $vlans;
    }
    $logger->trace("SNMP get_request for vtpVlanName: $oid_vtpVlanName");
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $oid_vtpVlanName );
    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            $key =~ /^$oid_vtpVlanName\.(\d+)$/;
            $vlans->{$1} = $result->{$key};
        }
    } else {
        $logger->info( "result is not defined at switch " . $this->{_ip} );
    }
    return $vlans;
}

sub isDefinedVlan {
    my ( $this, $vlan ) = @_;
    my $oid_vtpVlanName = '1.3.6.1.4.1.9.9.46.1.3.1.1.4.1';    #CISCO-VTP-MIB
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectRead() ) {
        return 0;
    }
    $logger->trace(
        "SNMP get_request for vtpVlanName: $oid_vtpVlanName.$vlan");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$oid_vtpVlanName.$vlan"] );
    return (   defined($result)
            && exists( $result->{"$oid_vtpVlanName.$vlan"} )
            && ( $result->{"$oid_vtpVlanName.$vlan"} ne 'noSuchInstance' ) );
}

sub isNotUpLink {
    my ( $this, $ifIndex ) = @_;
    return ( grep( { $_ == $ifIndex } $this->getUpLinks() ) == 0 );
}

# FIXME I just refactored that method but I think we should simply get rid
# of the uplinks=... concept. If you've configured access-control on an
# uplink then it's your problem. Anyway we don't do anything on RADIUS based
# requests. I guess this was there at first because of misconfigured up/down
# traps causing concerns.
sub getUpLinks {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # not dynamic, return uplink list
    return @{ $this->{_uplink} } if ( lc(@{ $this->{_uplink} }[0]) ne 'dynamic' );

    # dynamic uplink lookup
    if ( !$this->connectRead() ) {
        return -1;
    }

    my $oid_cdpGlobalRun = '1.3.6.1.4.1.9.9.23.1.3.1'; # Is CDP enabled ? MIB: cdpGlobalRun
    $logger->trace("SNMP get_table for cdpGlobalRun: $oid_cdpGlobalRun");
    my $result = $this->{_sessionRead}->get_table( -baseoid => $oid_cdpGlobalRun );
    if (!defined($result)) {
        $logger->warn(
            "Problem while determining dynamic uplinks for switch $this->{_ip}: "
            . "can not read cdpGlobalRun."
        );
        return -1;
    }

    my @cdpRun = values %{$result};
    if ( $cdpRun[0] != 1 ) {
        $logger->warn(
            "Problem while determining dynamic uplinks for switch $this->{_ip}: "
            . "based on the config file, uplinks are dynamic but CDP is not enabled on this switch."
        );
        return -1;
    }

    # CDP is enabled
    my $oid_cdpCachePlateform = '1.3.6.1.4.1.9.9.23.1.2.1.1.8';

    # fetch the upLinks. MIB: cdpCachePlateform
    $logger->trace("SNMP get_table for cdpCachePlateform: $oid_cdpCachePlateform");
    # we could have chosen another oid since many of them return uplinks.
    $result = $this->{_sessionRead}->get_table(-baseoid => $oid_cdpCachePlateform);
    if (!defined($result)) {
        $logger->warn(
            "Problem while determining dynamic uplinks for switch "
            . "$this->{_ip}: can not read cdpCachePlateform."
        );
        return -1;
    }

    my @upLinks;
    foreach my $key ( keys %{$result} ) {
        if ( !( $result->{$key} =~ /^Cisco IP Phone/ ) ) {
            $key =~ /^$oid_cdpCachePlateform\.(\d+)\.\d+$/;
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
    my ( $this, @managedPorts ) = @_;
    my $command;
    my $session;
    my @macAddressTable;
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
        return @macAddressTable;
    }

    if ( scalar(@managedPorts) > 0 ) {
        $command = 'show mac-address-table | include '
            . $this->getRegExpFromList(@managedPorts);
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
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @managedIfIndexes;
    my @tmp_managedIfIndexes = $this->SUPER::getManagedIfIndexes();
    foreach my $ifIndex (@tmp_managedIfIndexes) {
        my $port_type = $this->getVmVlanType($ifIndex);
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
    my $this = shift;
    my %macVlan;
    my @managedPorts = $this->getManagedPorts();
    my @macAddr;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    @macAddr = $this->getMacAddr(@managedPorts);

    my $ifDescMacVlan = $this->_getIfDescMacVlan(@macAddr);

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
                "ALERT: There is a hub on switch $this->{'_ip'} port $ifDesc. We found the following "
                    . scalar(@macs)
                    . " MACs on this port:\n$macString" );
        }
    }
    $logger->debug("Show VLAN and port for every MAC (dumper):");
    $logger->debug( Dumper(%macVlan) );

    return %macVlan;
}

sub getAllMacs {
    my ( $this, @ifIndexes ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !@ifIndexes ) {
        @ifIndexes = $this->getManagedIfIndexes();
    }
    my $ifIndexVlanMacHashRef;
    my $OID_dot1dTpFdbPort       = '1.3.6.1.2.1.17.4.3.1.2';    #BRIDGE-MIB
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB

    if ( !$this->connectRead() ) {
        return $ifIndexVlanMacHashRef;
    }

    #obtain ifPhysAddress array
    my $OID_ifPhysAddress = '1.3.6.1.2.1.2.2.1.6';
    $logger->trace("SNMP get_table for ifPhysAddress: $OID_ifPhysAddress");
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $OID_ifPhysAddress );
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

    my @vlansOnSwitch   = keys %{ $this->getVlans() };
    my @vlansToConsider = values %{ $this->{_vlans} };
    if ( $this->isVoIPEnabled() ) {
        my $OID_vmVoiceVlanId
            = '1.3.6.1.4.1.9.9.68.1.5.1.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
        $logger->trace(
            "SNMP get_table for vmVoiceVlanId: $OID_vmVoiceVlanId");
        $result = $this->{_sessionRead}
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
            if ( $this->{_SNMPVersion} eq '3' ) {
                $logger->trace(
                    "SNMP v3 get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex"
                );
                $result = $this->{_sessionRead}->get_table(
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
                $result = $this->{_sessionRead}->get_table(
                    -baseoid     => $OID_dot1dTpFdbPort,
                    -contextname => "vlan_$vlan"
                );
                # FIXME: calling "private" method to unset context. See #1284 or upstream rt.cpan.org:72075.
                $this->{_sessionRead}->{_context_name} = undef;
            } else {
                my ( $sessionReadVlan, $sessionReadVlanError )
                    = Net::SNMP->session(
                    -hostname  => $this->{_ip},
                    -version   => $this->{_SNMPVersion},
                    -retries   => 1,
                    -timeout   => 2,
                    -community => $this->{_SNMPCommunityRead} . '@' . $vlan
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
    my $this = shift;
    my $hubPorts;
    my @macAddr;
    my @managedPorts = $this->getManagedPorts();
    my $logger       = Log::Log4perl::get_logger( ref($this) );

    if (@managedPorts) {

        @macAddr = $this->getMacAddr(@managedPorts);

        my $ifDescMacVlan = $this->_getIfDescMacVlan(@macAddr);

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
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @phones;
    if ( !$this->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch "
                . $this->{_ip}
                . ". getPhonesCDPAtIfIndex will return empty list." );
        return @phones;
    }
    my $oid_cdpCacheDeviceId = '1.3.6.1.4.1.9.9.23.1.2.1.1.6';
    my $oid_cdpCacheCapabilities = '1.3.6.1.4.1.9.9.23.1.2.1.1.9';
    if ( !$this->connectRead() ) {
        return @phones;
    }
    $logger->trace("SNMP get_next_request for $oid_cdpCacheCapabilities");
    my $result = $this->{_sessionRead}->get_next_request(
        -varbindlist => ["$oid_cdpCacheCapabilities.$ifIndex"] );
    foreach my $oid ( keys %{$result} ) {
        if ( $oid =~ /^$oid_cdpCacheCapabilities\.$ifIndex\.([0-9]+)$/ ) {
            my $cacheDeviceIndex = $1;
             if ( hex($result->{$oid}) & 0x00000080 ) {
                $logger->warn("SNMP get_request for $oid_cdpCacheDeviceId");
                my $MACresult
                    = $this->{_sessionRead}->get_request( -varbindlist =>
                        ["$oid_cdpCacheDeviceId.$ifIndex.$cacheDeviceIndex"]
                    );
                if ($MACresult
                    && ($MACresult->{
                            "$oid_cdpCacheDeviceId.$ifIndex.$cacheDeviceIndex"
                        }
                        =~ /^SEP([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})$/i
                    )
                    )
                {
                    push @phones, lc("$1:$2:$3:$4:$5:$6");
                }
            }
        }
    }
    return @phones;
}

sub isVoIPEnabled {
    my ($this) = @_;
    return ( $this->{_VoIPEnabled} == 1 );
}

=item copyConfig

Copy the configuration.

Source and destination types are defined under ConfigFileType from CISCO-CONFIG-COPY MIB.
Local values are available in L<pf::SNMP::constants>.

We could support other destination types if there was motivation to do so.

Notice that we are throwing exceptions in here so make sure to trap them!

Inspired by: http://www.notarus.net/networking/cisco_snmp_config.html#wrmem

=cut

sub copyConfig {
    my ( $this, $src_type, $dest_type, $uri ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # Validation
    die("Can't connect in SNMP Read to switch " . $this->{_ip}) if (!$this->connectRead());
    die("Can't connect in SNMP Write to switch " . $this->{_ip}) if (!$this->connectWrite());

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
        $result = $this->{_sessionRead}->get_request(-varbindlist => [ "$OID_ccCopyEntryRowStatus.$random" ] );
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

    $result = $this->{_sessionWrite}->set_request( -varbindlist => $varbindlist );
    if ( defined($result) ) {
        $logger->debug("ccCopyTable row $random successfully created");
        $nb = 0;
        do {
            $nb++;
            sleep(1);
            $logger->trace("SNMP get_request for ccCopyState: $OID_ccCopyState.$random");
            $result = $this->{_sessionRead}->get_request( -varbindlist => [ "$OID_ccCopyState.$random" ] );
        } while ( ( $nb <= 120 ) && defined($result) && ( $result->{"$OID_ccCopyState.$random"} == 2 ) );

        if ( $nb == 120 ) {
            die("Config copy operation seems not to complete on " . $this->{_ip});
        }

        $logger->debug("deleting ccCopyTable row $random");
        $logger->trace(
            "SNMP set_request for ccCopyEntryRowStatus: $OID_ccCopyEntryRowStatus.$random"
        );
        $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [ "$OID_ccCopyEntryRowStatus.$random", Net::SNMP::INTEGER, $SNMP::DESTROY ]
        );
    } else {
        die("Problem copying configuration on ".$this->{_ip}.": " . $this->{_sessionWrite}->error() );
    }
    return ( defined($result) );
}

=item saveConfig

Save the running config into startup config.
Exact equivalent of doing a 'write mem' on the CLI.

Notice that we are throwing exceptions in here so make sure to trap them!

=cut

sub saveConfig {
    my ($this) = @_;
    $this->copyConfig($CISCO::RUNNING_CONFIG, $CISCO::STARTUP_CONFIG);
}

=item _radiusBounceMac

Using RADIUS Change of Authorization (CoA) defined in RFC3576 to bounce the port where a given MAC is present.

Uses L<pf::util::dhcp> for the low-level RADIUS stuff.

At proof of concept stage. For now using SNMP is still preferred way to bounce a port.

=cut

sub _radiusBounceMac {
    my ( $self, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

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
    try {
        my $connection_info = {
            nas_ip => $self->{'_controllerIp'} || $self->{'_ip'},
            secret => $self->{'_radiusSecret'},
            LocalAddr => $management_network->tag('vip'),
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
