package pf::Switch::Extreme;

=head1 NAME

pf::Switch::Extreme - Object oriented module to parse SNMP traps and manage Extreme Networks' switches

=head1 STATUS

=head1 SUPPORTS

=over

=item linkUp / linkDown mode (Extreme XOS 12.2 and up)

=item port-security (called MAC Address Lockdown)

Requires XOS 12.7.

Developed and tested on Summit X250e-48p running on image version 12.4.2.17 (never released).

=item MAC-Authentication / 802.1X

This was tested on XOS 12.4.2.17 and probably worked on earlier versions.

=back

=head1 BUGS AND LIMITATIONS

=over

=item Stacked Switches

Stacked switches are unimplemented but all the mechanism is there.
If you have access to the hardware please let us know and we will implement support for it.

Chassis support is unimplemented too.

=item SNMPv3

SNMPv3 support was not tested.

=item Port-security mode (MAC Address Lockdown)

Known to work with ExtremeXOS image version 12.7 and later

Relies on XML calls which require web interface to be enabled

=item HTTPS Web Services

HTTPS support relies on external modules for Extreme OS below 11.2.
Even if your Extreme OS version is greater than 11.2 verify the module's presence with 'show ssl' before enabling https.

SSL Web Services (HTTPS) was not tested.

=back

=cut

use strict;
use warnings;

use base ('pf::Switch');
use Net::SNMP;
use SOAP::Lite;
use Try::Tiny;

use pf::constants;
use pf::constants::role qw($VOICE_ROLE);
use pf::config qw(
    $MAC
    $PORT
);
use pf::file_paths qw($lib_dir);
# importing switch constants
use pf::Switch::constants;
use pf::util;

# CAPABILITIES
# access technology supported
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }

=head1 SUBROUTINES

=over

=item getVersion - obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    # current image description
    my $oid_extremeImageDescription = '1.3.6.1.4.1.1916.1.1.1.34.1.10.3'; # from EXTREME-SYSTEM-MIB
    my $logger = $self->logger;
    if (!$self->connectRead()) {
        return '';
    }
    $logger->trace("SNMP get_request for extremeImageDescription: $oid_extremeImageDescription");
    my $result = $self->{_sessionRead}->get_request(-varbindlist => [$oid_extremeImageDescription]);

    my $extremeImageDescription = ( $result->{$oid_extremeImageDescription} || '' );
    if ($extremeImageDescription =~ m/version (\d+\.\d+\.\d+\.\d+)/) {
       return $1;
    }
    return $extremeImageDescription;
}

=item getVlan - return vlan number (dot1Q tag) of a given ifIndex

=cut

sub getVlan {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    # a binary map of all the ports 0 = not in vlan, 1 = in vlan
    my $oid_extremeVlanOpaqueUntaggedPorts = '1.3.6.1.4.1.1916.1.2.6.1.1.2'; #from EXTREME-VLAN-MIB

    if (!$self->connectRead()) {
        return 0;
    }

    my ($stackIndex, $dot1dPort);
    if ($self->_getIfNameFromIfIndex($ifIndex) =~ /(\d+):(\d+)/) {
        $stackIndex = $1;
        $dot1dPort = $2;
    } else {
        $logger->warn("Unable to get port information from this ifIndex: $ifIndex");
        return 0;
    }

    $logger->trace("SNMP get_table for extremeVlanOpaqueUntaggedPorts: $oid_extremeVlanOpaqueUntaggedPorts");
    # obtain raw information
    $self->{_sessionRead}->translate(0);
    my $result = $self->{_sessionRead}->get_table(-baseoid => "$oid_extremeVlanOpaqueUntaggedPorts", -maxrepetitions  => 1);
    $self->{_sessionRead}->translate(1);

    foreach my $vlanIfIndexStack (keys %{$result}) {
        if ($vlanIfIndexStack =~ /^$oid_extremeVlanOpaqueUntaggedPorts\.(\d+)\.$stackIndex$/) {
            my $vlanIfIndex = $1;

            # get bit value at dot1d port
            my $portInThisVlan = $self->getBitAtPosition(
                $result->{$vlanIfIndexStack},
                $self->_translateStackDot1dToPortListPosition($stackIndex, $dot1dPort) - 1
            );
            if ($portInThisVlan) {
                my $vlan = $self->_getVlanTagFromVlanIfIndex($vlanIfIndex);
                $logger->trace("Port: $dot1dPort (ifIndex: $ifIndex) is in vlan $vlan (ifIndex: $vlanIfIndex)");
                return $vlan;
            }

        } else {
            $logger->warn("can't recognize output of extremeVlanOpaqueUntaggedPorts");
        }
    }
}

sub getVlans {
    my ($self) = @_;
    my $logger = $self->logger;
    # vlanIfIndex to vlan number (vlan tag)
    my $oid_extremeVlanIfVlanId = "1.3.6.1.4.1.1916.1.2.1.2.1.10"; #from EXTREME-VLAN-MIB
    # vlanIfIndex to vlan name
    my $oid_ifName = "1.3.6.1.2.1.31.1.1.1.1"; #from IF-MIB

    # hash were we store the values
    my $vlans  = {};

    if ( !$self->connectRead() ) {
        return $vlans;
    }

    # store all the vlan IfIndex => vlan tag to use later
    $logger->trace("SNMP get_table for extremeVlanIfVlanId: $oid_extremeVlanIfVlanId");
    my $vlanTagsByVlanIfIndex = $self->{_sessionRead}->get_table(-baseoid => "$oid_extremeVlanIfVlanId", -maxrepetitions  => 1);

    $logger->trace("SNMP get_table for ifName: $oid_ifName");
    my $vlanNamesByVlanIfIndex = $self->{_sessionRead}->get_table(-baseoid => "$oid_ifName", -maxrepetitions  => 1);

    # loop on all vlans joining the two hashes on vlan IfIndex to provide tags => names
    foreach my $key (keys %{$vlanTagsByVlanIfIndex}) {

        # match on vlan ifName
        $key =~ /^$oid_extremeVlanIfVlanId\.(\d+)$/;
        my $vlanIfIndex = $1;

        # this ugly thing means: vlans->{tag} = name
        $vlans->{$vlanTagsByVlanIfIndex->{$key}} = $vlanNamesByVlanIfIndex->{$oid_ifName.".".$vlanIfIndex};
    }

    if (! keys %{$vlans}) {
        $logger->warn("returned 0 vlan. This could be a problem");
    }
    return $vlans;
}

=item isDefinedVlan - returns true or false based on if requested vlan exists or not

=cut

sub isDefinedVlan {
    my ($self, $vlan) = @_;
    my $logger = $self->logger;
    # vlanIfIndex to vlan number (vlan tag)
    my $oid_extremeVlanIfVlanId = "1.3.6.1.4.1.1916.1.2.1.2.1.10"; #from EXTREME-VLAN-MIB

    if (!$self->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_table for extremeVlanIfVlanId: $oid_extremeVlanIfVlanId");
    my $result = $self->{_sessionRead}->get_table(-baseoid => "$oid_extremeVlanIfVlanId", -maxrepetitions  => 1);

    # loop on all vlans
    foreach my $vlanIfIndex (keys %{$result}) {
        if ($result->{$vlanIfIndex} == $vlan) {
            return 1;
        }
    }
    $logger->warn("could not find vlan $vlan on this switch");
    return 0;
}

=item _getMacAtIfIndex - obtain list of MACs at switch ifIndex

This supersedes the _getMacAtIfIndexPreXOS.
It uses the new MIB available in Extreme XOS 12.2+: extremeFdbMacExosFdbTable.

=cut

sub _getMacAtIfIndex {
    my ( $self, $ifIndex, $vlan ) = @_;
    my $logger = $self->logger;
    my @macArray;

    if ( !$self->connectRead() ) {
        return @macArray;
    }

    # if a vlan is set, we will filter on that VLAN but we need it in ifIndex format first
    if (defined($vlan)) {
        $vlan = $self->_getVlanIfIndexFromVlanTag($vlan);
    }

    my $oid_extremeFdbMacExosFdbPortIfIndex = "1.3.6.1.4.1.1916.1.16.4.1.3"; #from EXTREME-FDB-MIB

    $logger->trace("SNMP get_table for extremeFdbMacExosFdbPortIfIndex: $oid_extremeFdbMacExosFdbPortIfIndex");
    my $resultPortIfIndex = $self->{_sessionRead}->get_table(-baseoid => "$oid_extremeFdbMacExosFdbPortIfIndex", -maxrepetitions  => 1);

    # result is of format: extremeFdbMacExosFdbPortIfIndex.<mac>.<vlanIfIndex> = <ifIndex>
    foreach my $oidWithIndex (keys %{$resultPortIfIndex}) {

        # if this is an ifIndex we are interested in
        if ($resultPortIfIndex->{$oidWithIndex} == $ifIndex) {

            if ($oidWithIndex =~
                /^$oid_extremeFdbMacExosFdbPortIfIndex\.                         # query oid
                (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\.         # mac in OID format
                (\d+)                                                            # vlanIfIndex
                $/x) {

                my $oid_mac = $1;
                my $vlanIfIndex = $2;

                # if vlan is set and is not our current ifIndex then we are not interested in this entry
                next if (defined($vlan) && $vlan != $vlanIfIndex);
                push @macArray, oid2mac($oid_mac);

            } else {
                $logger->debug("problem parsing the extremeFdbMacExosFdbPortIfIndex oid...");
            }
        }
    }
    if (!@macArray) {
        $logger->warn("couldn't get MAC at ifIndex $ifIndex");
    }
    return @macArray;
}

=item _getMacAtIfIndexPreXOS - obtain list of MACs at switch ifIndex

Starting with version 12.2 the extremeFdbMacFdbTable MIB is no longer supported on Extreme XOS.
This method calls the old version (extremeFdbMacFdbTable).
A auto-detection layer and code re-routing could be written if there is some incentive to do it.

=cut

sub _getMacAtIfIndexPreXOS {
    my ( $self, $ifIndex, $vlan ) = @_;
    my $logger = $self->logger;
    my @macArray;

    if ( !$self->connectRead() ) {
        return @macArray;
    }

    if ( !defined($vlan) ) {
        $vlan = $self->getVlan($ifIndex);
    }

    my $oid_extremeFdbMacFdbPortIfIndex = "1.3.6.1.4.1.1916.1.16.1.1.4"; #from EXTREME-FDB-MIB
    my $oid_extremeFdbMacFdbMacAddress = "1.3.6.1.4.1.1916.1.16.1.1.3"; #from EXTREME-FDB-MIB

    $logger->trace("SNMP get_table for extremeFdbMacFdbPortIfIndex: $oid_extremeFdbMacFdbPortIfIndex");
    my $resultPortIfIndex = $self->{_sessionRead}->get_table(-baseoid => "$oid_extremeFdbMacFdbPortIfIndex", -maxrepetitions  => 1);

    $logger->trace("SNMP get_table for extremeFdbMacFdbMacAddress: $oid_extremeFdbMacFdbMacAddress");
    my $resultMacAddr = $self->{_sessionRead}->get_table(-baseoid => "$oid_extremeFdbMacFdbMacAddress", -maxrepetitions  => 1);

    foreach my $oidWithIndex (keys %{$resultPortIfIndex}) {
        if ($resultPortIfIndex->{$oidWithIndex} == $ifIndex) {
            if ($oidWithIndex =~ /^$oid_extremeFdbMacFdbPortIfIndex\.(\d+)\.(\d+)$/) {
                my $vlanIfIndex = $1;
                my $index = $2;
                if ( $resultMacAddr->{"$oid_extremeFdbMacFdbMacAddress.$vlanIfIndex.$index"}
                    =~ /0x([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})/i) {
                    push @macArray, lc("$1:$2:$3:$4:$5:$6");
                } else {
                    $logger->debug("couldn't find mac-entry index");
                }
            } else {
                $logger->debug("couldn't find mac-entry index");
            }
        }
    }
    if (!@macArray) {
        $logger->warn("couldn't get MAC at ifIndex $ifIndex");
    }
    return @macArray;
}

=item getMacBridgePortHash - returns an hash of MACs and ifIndex

key: mac address / value: ifIndex of port where mac address is

=cut

sub getMacBridgePortHash {
    my $self   = shift;
    my $vlan   = shift || '';
    my $logger = $self->logger;
    my %macBridgePortHash  = ();

    if ( !$self->connectRead() ) {
        return %macBridgePortHash;
    }

    # mac address in OID associated to port
    my $oid_dot1dTpFdbPort       = '1.3.6.1.2.1.17.4.3.1.2';    #from BRIDGE-MIB
    # port associated to ifIndex
    my $oid_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #from BRIDGE-MIB

    $logger->trace("SNMP get_table for dot1dTpFdbPort: $oid_dot1dTpFdbPort");
    my $resultMacPort = $self->{_sessionRead}->get_table(-baseoid => "$oid_dot1dTpFdbPort", -maxrepetitions  => 1);

    $logger->trace("SNMP get_table for dot1dBasePortIfIndex: $oid_dot1dBasePortIfIndex");
    my $resultPortIfIndex = $self->{_sessionRead}->get_table(-baseoid => "$oid_dot1dBasePortIfIndex", -maxrepetitions  => 1);

    # merging mac to port and port to ifIndex to get a mac to ifIndex hash
    foreach my $oidMac (keys %{$resultMacPort}) {
        $oidMac =~ /^$oid_dot1dTpFdbPort\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
        my $mac = sprintf( "%02X:%02X:%02X:%02X:%02X:%02X", $1, $2, $3, $4, $5, $6);
        my $port = $resultMacPort->{$oidMac};

        # mac to ifIndex
        $macBridgePortHash{$mac} = $resultPortIfIndex->{$oid_dot1dBasePortIfIndex.".".$port};
    }
    if (! keys %macBridgePortHash) {
        $logger->warn("couldn't get MAC address list");
    }
    return %macBridgePortHash;
}

=item _getVlanTagFromVlanIfIndex - returns the vlan number (real dot1Q tag number) from a vlan's ifIndex

These switches uses a vlan ifIndex everywhere instead of using directly the vlan (tag) number like most of the other makers do.

=cut

sub _getVlanTagFromVlanIfIndex {
    my ($self, $vlanIfIndex) = @_;
    my $logger = $self->logger;
    # vlanIfIndex to vlan number (vlan tag)
    my $oid_extremeVlanIfVlanId = "1.3.6.1.4.1.1916.1.2.1.2.1.10.".$vlanIfIndex; #from EXTREME-VLAN-MIB

    if (!$self->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_request for extremeVlanIfVlanId: $oid_extremeVlanIfVlanId");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => ["$oid_extremeVlanIfVlanId"] );
    if ((exists($result->{"$oid_extremeVlanIfVlanId"}))
        && ($result->{"$oid_extremeVlanIfVlanId"} ne 'noSuchInstance')) {

        #return tag number (Integer)
        return $result->{"$oid_extremeVlanIfVlanId"};

    } else {

        #no tag returned
        return 0;
    }
}

=item _getVlanTagLookupTable - returns the whole table for VLAN ifIndex to VLAN dot1q tags lookups

Useful to avoid multiple lookups in a tight loop.

=cut

sub _getVlanTagLookupTable {
    my ($self) = @_;
    my $logger = $self->logger;

    # vlanIfIndex to vlan number (vlan tag)
    my $oid_extremeVlanIfVlanId = "1.3.6.1.4.1.1916.1.2.1.2.1.10"; #from EXTREME-VLAN-MIB

    if (!$self->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_table for extremeVlanIfVlanId: $oid_extremeVlanIfVlanId");
    my $result = $self->{_sessionRead}->get_table(-baseoid => "$oid_extremeVlanIfVlanId", -maxrepetitions  => 1);

    if (defined($result) && ($result ne 'noSuchInstance')) {
        # here I'm stripping OIDs from the hash's keys
        # changing <oid...>.<vlanIfIndex> => <vlanTag> into <vlanIfIndex> => <vlanTag>
        foreach my $key (keys %{$result}) {
            $key =~ /^$oid_extremeVlanIfVlanId\.(\d+)$/;
            $result->{$1} = delete $result->{$key}; # delete returns the deleted value as a nice side-effect
        }
        return $result;
    } else {
        $logger->warn("Unable to fetch VLAN ifIndex to VLAN tag information. You are likely to experience issues");
        return;
    }
}

=item _getVlanIfIndexFromVlanTag - returns the vlan ifIndex from a vlan's number (real dot1Q tag number)

These switches uses a vlan ifIndex everywhere instead of using directly the vlan (tag)
number like most of the other makers do.

=cut

sub _getVlanIfIndexFromVlanTag {
    my ($self, $vlan) = @_;
    my $logger = $self->logger;
    # vlanIfIndex to vlan number (vlan tag)
    my $oid_extremeVlanIfVlanId = "1.3.6.1.4.1.1916.1.2.1.2.1.10"; #from EXTREME-VLAN-MIB

    if (!$self->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_table for extremeVlanIfVlanId: $oid_extremeVlanIfVlanId");
    my $result = $self->{_sessionRead}->get_table(-baseoid => "$oid_extremeVlanIfVlanId", -maxrepetitions  => 1);

    # loop on all vlans
    foreach my $oidWithVlanIfIndex (keys %{$result}) {
        if ($result->{$oidWithVlanIfIndex} == $vlan) {
            $oidWithVlanIfIndex =~ /^$oid_extremeVlanIfVlanId\.(\d+)$/;
            return $1;
        }
    }
    $logger->warn("Could not get vlan's ifIndex..");
    return 0;
}

=item _getVlanIfDescrFromVlanTag - returns the vlan ifDescr from a vlan's number (real dot1Q tag number)

These switches uses VLAN ifDescr for Fdb operations over Web Services. Helper method to translate it.

=cut

sub _getVlanIfDescrFromVlanTag {
    my ($self, $vlan) = @_;
    my $logger = $self->logger;

    # vlanIfIndex to vlanIfDescr
    my $oid_extremeVlanIfDescr = "1.3.6.1.4.1.1916.1.2.1.2.1.2"; #from EXTREME-VLAN-MIB

    # fetch vlanIfIndex based on vlan tag
    my $vlanIfIndex = $self->_getVlanIfIndexFromVlanTag($vlan);

    if (!$self->connectRead()) {
        return 0;
    }

    my $oid_vlanIfDescrFromIfIndex = $oid_extremeVlanIfDescr . "." . $vlanIfIndex;
    $logger->trace("SNMP get_request for extremeVlanIfDescr: $oid_vlanIfDescrFromIfIndex");
    my $result = $self->{_sessionRead}->get_request(-varbindlist => ["$oid_vlanIfDescrFromIfIndex"] );

    if (!defined($result->{$oid_vlanIfDescrFromIfIndex})
        || ($result->{$oid_vlanIfDescrFromIfIndex} eq 'noSuchInstance')) {
        $logger->warn("Unable to retrieve VLAN IfDescr for VLAN $vlan");
        return;
    }

    return $result->{$oid_vlanIfDescrFromIfIndex};
}

=item _getVlanTagFromVlanIfDescr - returns the vlan's number (real dot1Q tag number) from a VLAN name (ifDescr)

=cut

sub _getVlanTagFromVlanIfDescr {
    my ($self, $vlanIfDescr) = @_;
    my $logger = $self->logger;

    # vlanIfIndex to vlanIfDescr
    my $oid_extremeVlanIfDescr = "1.3.6.1.4.1.1916.1.2.1.2.1.2"; #from EXTREME-VLAN-MIB

    if (!$self->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_table for extremeVlanIfDescr: $oid_extremeVlanIfDescr");
    my $result = $self->{_sessionRead}->get_table(-baseoid => "$oid_extremeVlanIfDescr", -maxrepetitions  => 1);

    if (!defined($result)) {
        $logger->warn("Unable to retrieve VLAN tag for VLAN $vlanIfDescr");
        return;
    }

    foreach my $oidVlanIfIndexToIfDescr (keys %{$result}) {
        if ($result->{$oidVlanIfIndexToIfDescr} =~ /^
            (:?"|)           # begin string + optional "
            $vlanIfDescr     # vlan name string
            (:?"|)$          # optional " + end string
            /x) {
            # grab vlanIfIndex from last digit of oid
            my ($vlanIfIndex) = $oidVlanIfIndexToIfDescr =~ /^$oid_extremeVlanIfDescr\.(\d+)$/;
            # there can only be one matching VLAN string so I return here even if we are in a loop
            return $self->_getVlanTagFromVlanIfIndex($vlanIfIndex);
        }
    }
    $logger->warn("VLAN $vlanIfDescr not found!");
    return;
}

=item _getDot1dPortFromIfIndex - retrieve dot1d port from ifIndex

=cut

sub _getDot1dPortFromIfIndex {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;

    my $ifName = $self->_getIfNameFromIfIndex($ifIndex);
    if ($ifName =~ /(\d+):(\d+)/) {
        return $2;
    } else {
        return 0;
    }
}

=item _getIfNameFromIfIndex - returns the ifName based on ifIndex

ifName format is: <switch stack id>:<dot1d port number> (ex: 1:12)

=cut

sub _getIfNameFromIfIndex {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;
    # get interface name which is stack:port on extreme switches
    my $oid_ifName = "1.3.6.1.2.1.31.1.1.1.1.".$ifIndex; # from IF-MIB

    if (!$self->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_request for ifName: $oid_ifName");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => ["$oid_ifName"] );
    if ((exists($result->{"$oid_ifName"})) && ($result->{"$oid_ifName"} ne 'noSuchInstance')) {
        return $result->{"$oid_ifName"}; #return port number (Integer)
    } else {
        return 0;                        #no port return
    }
}

=item _getIfIndexLookupTable - returns an hashref of ifName to ifIndex

ifName format is: <switch stack id>:<dot1d port number> (ex: 1:12)

=cut

sub _getIfIndexLookupTable {
    my ($self) = @_;
    my $logger = $self->logger;
    # get interface name which is stack:port on extreme switches
    my $oid_ifName = "1.3.6.1.2.1.31.1.1.1.1"; # from IF-MIB

    if (!$self->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_table for ifName: $oid_ifName");
    my $result = $self->{_sessionRead}->get_table(-baseoid => "$oid_ifName", -maxrepetitions  => 1);
    if (defined($result) && ($result ne 'noSuchInstance')) {
        # here I'm stripping OIDs from the hash's keys
        # changing <oid...>.<IfIndex> => <IfName> into <IfIndex> => <IfName>
        foreach my $key (keys %{$result}) {
            $key =~ /^$oid_ifName\.(\d+)$/;
            # this will populate the hash with: ifName => ifIndex
            $result->{$result->{$key}} = $1;
            # delete what we just processed
            delete $result->{$key};
        }
        return $result;
    } else {
        $logger->warn("Unable to fetch ifIndex to ifName information. You are likely to experience issues");
        return;
    }
}

=item parseTrap - interpret traps and populate a trap hash

=cut

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;

    # linkUp / linkDown trap
    if ($trapString =~ /BEGIN TYPE 0 END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS .+\|\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1 = INTEGER: (\d+)\|/) {
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;

    # EXTREME-V2TRAP-MIB::extremeMacDetectedOnLockedPort
    } elsif ($trapString =~/BEGIN VARIABLEBINDINGS .+\.1\.3\.6\.1\.4\.1\.1916\.4\.3\.0\.3.+\|\.1\.3\.6\.1\.4\.1\.1916\.4\.3\.5\.[0-9]+ = INTEGER: ([0-9]+)\|\.1\.3\.6\.1\.4\.1\.1916\.4\.3\.3\.0 = STRING: "([0-9A-Z]{2}:[0-9A-Z]{2}:[0-9A-Z]{2}:[0-9A-Z]{2}:[0-9A-Z]{2}:[0-9A-Z]{2})"\|\.1\.3\.6\.1\.4\.1\.1916\.4\.3\.4\.0 = INTEGER: ([0-9]+) END VARIABLEBINDINGS/) {
        $trapHashRef->{'trapType'} = 'secureMacAddrViolation';
        $trapHashRef->{'trapVlan'} = $1;
        $trapHashRef->{'trapIfIndex'} = $3;
        $trapHashRef->{'trapMac'} = lc($2);

    } else {
        $logger->info("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

=item _setVlan - swap the vlans on a port (ifIndex)

=cut

sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;
    my $result;

    if ( !$self->connectRead() ) {
        return 0;
    }

    # vlan control OIDs (from EXTREME-VLAN-MIB)
    my $oid_extremeVlanOpaqueControlPorts = "1.3.6.1.4.1.1916.1.2.6.2.1.1";
    my $oid_extremeVlanOpaqueControlOperation = "1.3.6.1.4.1.1916.1.2.6.2.1.2";
    my $oid_extremeVlanOpaqueControlStatus = "1.3.6.1.4.1.1916.1.2.6.2.1.3";

    # get dot1d port and stack index
    $self->_getIfNameFromIfIndex($ifIndex) =~ /(\d+):(\d+)/;
    my $stackIndex = $1;
    my $dot1dPort = $2;

    if ( !defined($dot1dPort) ) {
        $logger->warn("cannot identify dot1d port, I give up");
        return 0;
    }

    # Convert vlan into VlanIfIndex needed for the snmp set
    my $oldVlanIfIndex = $self->_getVlanIfIndexFromVlanTag($oldVlan);
    my $newVlanIfIndex = $self->_getVlanIfIndexFromVlanTag($newVlan);

    # create a portlist that will map to affected port only
    my $portList = $self->createPortListWithOneItem($dot1dPort);

    {
        my $lock = $self->getExclusiveLock();

        # set all values
        if ( !$self->connectWrite() ) {
            return 0;
        }

        # if port-security is activated, we need to remove it from the port before we can do a VLAN change
        my $is_port_security_enabled = $self->isPortSecurityEnabled($ifIndex);
        my @secured_macs;
        if ($is_port_security_enabled) {

            $self->disablePortSecurityByIfIndex($ifIndex);
            @secured_macs = $self->_deauthorizeCurrentMac($ifIndex, $oldVlan);
        }

        $logger->trace("SNMP set_request to remove port $dot1dPort from old vlan: $oldVlan (ifIndex: $oldVlanIfIndex)");
        my $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$oid_extremeVlanOpaqueControlPorts.$oldVlanIfIndex.$stackIndex",
                Net::SNMP::OCTET_STRING,
                $portList,
                "$oid_extremeVlanOpaqueControlOperation.$oldVlanIfIndex.$stackIndex",
                Net::SNMP::INTEGER,
                $EXTREME::VLAN::DELETE,
                "$oid_extremeVlanOpaqueControlStatus.$oldVlanIfIndex.$stackIndex",
                Net::SNMP::INTEGER,
                $SNMP::CREATE_AND_GO
            ]
        );
        if ( !defined($result) ) {
            $logger->error("error removing port from old vlan: ".$self->{_sessionWrite}->error);
        }

        $logger->trace("SNMP set_request to add port $dot1dPort to new vlan: $newVlan (ifIndex: $newVlanIfIndex)");

        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$oid_extremeVlanOpaqueControlPorts.$newVlanIfIndex.$stackIndex",
                Net::SNMP::OCTET_STRING,
                $portList,
                "$oid_extremeVlanOpaqueControlOperation.$newVlanIfIndex.$stackIndex",
                Net::SNMP::INTEGER,
                $EXTREME::VLAN::ADD_UNTAGGED,
                "$oid_extremeVlanOpaqueControlStatus.$newVlanIfIndex.$stackIndex",
                Net::SNMP::INTEGER,
                $SNMP::CREATE_AND_GO

            ]
        );
        if ( !defined($result) ) {
            $logger->error("error adding port to new vlan: ".$self->{_sessionWrite}->error);
        }

        # if port-security is activated, we need to re-enable it
        if ($is_port_security_enabled) {
            # re-authorize MACs previously deauthorized
            foreach my $mac (@secured_macs) {
                $self->authorizeMAC($ifIndex, undef, $mac, undef, $newVlan);
            }
            $self->enablePortSecurityByIfIndex($ifIndex);
        }

    }
    $logger->trace("locking - \$switch_locker{".$self->{_ip}."} unlocked in _setVlan");
    return ( defined($result) );
}

=item getAllSecureMacAddresses - return all MAC addresses in security table and their VLAN

Returns an hashref with MAC => ifIndex => Array(VLANs)

=cut

sub getAllSecureMacAddresses {
    my ( $self ) = @_;

    # using the SNMP method it was faster than WS in my limited testing
    return $self->_getAllSecureMacAddressesWithSNMP();
}

=item _getAllSecureMacAddressesWithSNMP - return all MAC addresses in security table and their VLAN

This implementation relies on an SNMP interface that was introduced in 12.2.

Returns an hashref with MAC => ifIndex => Array(VLANs)

=cut

sub _getAllSecureMacAddressesWithSNMP {
    my ( $self ) = @_;
    my $logger = $self->logger;

    # from EXTREME-FDB-MIB
    my $oid_extremeFdbMacExosFdbPortIfIndex = '1.3.6.1.4.1.1916.1.16.4.1.3';
    my $oid_extremeFdbMacExosFdbStatus = '1.3.6.1.4.1.1916.1.16.4.1.4';

    my $secureMacAddrHashRef = {};
    if (!$self->connectRead()) {
        return $secureMacAddrHashRef;
    }

    # fetching information that will be useful to lookup VLANs
    my $vlanIfIndexToTags = $self->_getVlanTagLookupTable();

    $logger->trace("SNMP get_table for extremeFdbMacExosFdbPortIfIndex: $oid_extremeFdbMacExosFdbPortIfIndex");
    my $FdbPortIfIndex = $self->{_sessionRead}->get_table(-baseoid => "$oid_extremeFdbMacExosFdbPortIfIndex", -maxrepetitions  => 1);

    # We read the extremeFdbMacFdbStatus in order to know if there is any MAC static on the port in the vlan
    $logger->trace("SNMP get_table for extremeFdbMacExosFdbStatus: $oid_extremeFdbMacExosFdbStatus");
    my $FdbStatus = $self->{_sessionRead}->get_table(-baseoid => "$oid_extremeFdbMacExosFdbStatus", -maxrepetitions  => 1);
    foreach my $fdb_entry (keys %{$FdbStatus}) {

        # Extreme identify static entries in the fdb as management (thus the == $SNMP::MGMT)
        if (($FdbStatus->{"$fdb_entry"} eq $SNMP::MGMT) &&
            ($fdb_entry =~
                /^$oid_extremeFdbMacExosFdbStatus\.                              # query oid
                (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\.         # mac in OID format
                (\d+)                                                            # vlanIfIndex
                $/x)
            ) {

            my $oid_mac = $1;
            my $mac = oid2mac($oid_mac);
            my $vlanIfIndex = $2;

            if (exists($FdbPortIfIndex->{"$oid_extremeFdbMacExosFdbPortIfIndex.$oid_mac.$vlanIfIndex"})) {
                my $ifIndex = $FdbPortIfIndex->{"$oid_extremeFdbMacExosFdbPortIfIndex.$oid_mac.$vlanIfIndex"};

                push @{ $secureMacAddrHashRef->{$mac}->{$ifIndex} }, $vlanIfIndexToTags->{$vlanIfIndex};
            }
        }
    }
    return $secureMacAddrHashRef;
}

=item _getAllSecureMacAddressesWithWS - return all MAC addresses in security table and their VLAN

This implementation relies on the Web Services interface.

Returns an hashref with MAC => ifIndex => Array(VLANs)

=cut

# TODO Performance improvement possible: I am fetching and grinding the whole tree client side..
# It was not optimized because I didn't figure out how to do filtered requests on the Fdb Table
# and we should have the SNMP interface back (hopefully)
sub _getAllSecureMacAddressesWithWS {
    my ($self) = @_;
    my $logger = $self->logger;

    my $secureMacAddrHashRef = {};

    my $ws_client = $self->_getSOAPHandle();

    my $som;
    try {
        # fetch the Fdb table
        $som = $ws_client->call(SOAP::Data->name($EXTREME::WS_GET_ALL_FDB));
    } catch {
        $logger->error("Problem trying to fetch All secure MAC addresses. Error: $@");
        return;
    };

    # handle errors
    if ($som->fault) {
        $logger->warn("error fetching secured MAC table. Error:"
            . $som->faultstring . " (Error code: ".$som->faultcode.")");
        return;
    } else {
        my @fdbTable = $som->valueof($EXTREME::WS_NODE_ALL_FDB_RESPONSE);

        # we will use this lookup cache to avoid translating over and over the same VLANs and ifIndexes
        my $vlanTagLookupCache = {};
        my $ifIndexLookupTable = $self->_getIfIndexLookupTable();
        foreach my $fdbEntry (@fdbTable) {
            # skip non-permanent entries
            next if ($fdbEntry->{$EXTREME::WS_DATATYPE_PERMANENT} eq $EXTREME::WS_DATATYPE_FALSE);

            # simplifying variables
            my $mac = $fdbEntry->{$EXTREME::WS_DATATYPE_MAC};
            my $vlanName = $fdbEntry->{$EXTREME::WS_DATATYPE_VLAN};
            my $port = $fdbEntry->{$EXTREME::WS_DATATYPE_PORT};

            # translate VLAN name into vlan dot1q id and store in cache if not already there
            if (!exists($vlanTagLookupCache->{$vlanName})) {
                $vlanTagLookupCache->{$vlanName} = $self->_getVlanTagFromVlanIfDescr($vlanName);
            }

            # from port to ifIndex
            # TODO: no stack support right now
            my $ifIndex = $ifIndexLookupTable->{'1:'.$port};

            # add MAC to secure address table with translated VLAN name into vlan dot1q id
            push @{ $secureMacAddrHashRef->{$mac}->{$ifIndex} }, $vlanTagLookupCache->{$vlanName};
        }
    }
    return $secureMacAddrHashRef;
}

=item getSecureMacAddresses - return all MAC addresses in security table and their VLAN for a given ifIndex

Returns an hashref with MAC => Array(VLANs)

=cut

sub getSecureMacAddresses {
    my ( $self, $ifIndex ) = @_;

    # using the SNMP method but the WS proved to be faster in some cases...
    return $self->_getSecureMacAddressesWithSNMP($ifIndex);
}


=item _getSecureMacAddressesWithWS - return all MAC addresses in security table and their VLAN for a given ifIndex

This implementation relies on the Web Services interface.

Returns an hashref with MAC => Array(VLANs)

=cut

# TODO Performance improvement possible: I am fetching and grinding the whole tree client side..
# It was not optimized because I didn't figure out how to do filtered requests on the Fdb Table
# and we should have the SNMP interface back (hopefully)
sub _getSecureMacAddressesWithWS {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    my $secureMacAddrHashRef = {};

    my $ws_client = $self->_getSOAPHandle();

    # TODO: stack port translation (XML expects 17 and not 1:17 but what is it when stacked?)
    my $port = $self->_getDot1dPortFromIfIndex($ifIndex);

    my $som;
    try {
        # fetch the Fdb table
        $som = $ws_client->call(SOAP::Data->name($EXTREME::WS_GET_ALL_FDB));
    } catch {
        $logger->error("Problem trying to fetch secure MAC addresses on ifIndex $ifIndex. Error: $@");
        return;
    };

    # handle errors
    if ($som->fault) {
        $logger->warn("error fetching secured MACs on ifIndex $ifIndex error:"
            . $som->faultstring . " (Error code: ".$som->faultcode.")");
        return;
    } else {
        my @fdbTable = $som->valueof($EXTREME::WS_NODE_ALL_FDB_RESPONSE);

        # we will use this lookup cache to avoid translating over and over the same VLANs
        my $vlanTagLookupCache = {};
        foreach my $fdbEntry (@fdbTable) {
            # skip non-permanent entries and the ones on the wrong ifIndex
            next if ($fdbEntry->{$EXTREME::WS_DATATYPE_PERMANENT} eq $EXTREME::WS_DATATYPE_FALSE);
            next if ($fdbEntry->{$EXTREME::WS_DATATYPE_PORT} != $port);

            # simplifying variables
            my $mac = $fdbEntry->{$EXTREME::WS_DATATYPE_MAC};
            my $vlanName = $fdbEntry->{$EXTREME::WS_DATATYPE_VLAN};

            # translate VLAN name into vlan dot1q id and store in cache if not already there
            if (!exists($vlanTagLookupCache->{$vlanName})) {
                $vlanTagLookupCache->{$vlanName} = $self->_getVlanTagFromVlanIfDescr($vlanName);
            }

            # add MAC to secure address table with translated VLAN name into vlan dot1q id
            push @{ $secureMacAddrHashRef->{$mac} }, $vlanTagLookupCache->{$vlanName};
        }
    }
    return $secureMacAddrHashRef;
}

=item _getSecureMacAddressesWithSNMP - return all MAC addresses in security table and their VLAN for a given ifIndex

This implementation relies on an SNMP interface that was introduced in 12.2

Returns an hashref with MAC => Array(VLANs)

=cut

sub _getSecureMacAddressesWithSNMP {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    # from EXTREME-FDB-MIB
    my $oid_extremeFdbMacExosFdbPortIfIndex = '1.3.6.1.4.1.1916.1.16.4.1.3';
    my $oid_extremeFdbMacExosFdbStatus = '1.3.6.1.4.1.1916.1.16.4.1.4';

    my $secureMacAddrHashRef = {};
    if (!$self->connectRead()) {
        return $secureMacAddrHashRef;
    }

    # fetching information that will be useful to lookup VLANs
    my $vlanIfIndexToTags = $self->_getVlanTagLookupTable();

    $logger->trace("SNMP get_table for extremeFdbMacExosFdbPortIfIndex: $oid_extremeFdbMacExosFdbPortIfIndex");
    my $FdbPortIfIndex = $self->{_sessionRead}->get_table(-baseoid => "$oid_extremeFdbMacExosFdbPortIfIndex", -maxrepetitions  => 1);

    # We read the extremeFdbMacFdbStatus in order to know if there is any MAC static on the port in the vlan
    $logger->trace("SNMP get_table for extremeFdbMacExosFdbStatus: $oid_extremeFdbMacExosFdbStatus");
    my $FdbStatus = $self->{_sessionRead}->get_table(-baseoid => "$oid_extremeFdbMacExosFdbStatus", -maxrepetitions  => 1);
    foreach my $fdb_entry (keys %{$FdbPortIfIndex}) {

        # We are only interested in ports of a specific ifIndex
        if (($FdbPortIfIndex->{"$fdb_entry"} == $ifIndex) &&
            ($fdb_entry =~
                /^$oid_extremeFdbMacExosFdbPortIfIndex\.                         # query oid
                (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\.         # mac in OID format
                (\d+)                                                            # vlanIfIndex
                $/x)
            ) {

            my $oid_mac = $1;
            my $mac = oid2mac($oid_mac);
            my $vlanIfIndex = $2;

            # Extreme identify static entries in the fdb as management (thus the == $SNMP::MGMT)
            if (exists($FdbStatus->{"$oid_extremeFdbMacExosFdbStatus.$oid_mac.$vlanIfIndex"}) &&
                $FdbStatus->{"$oid_extremeFdbMacExosFdbStatus.$oid_mac.$vlanIfIndex"} eq $SNMP::MGMT) {

                push @{ $secureMacAddrHashRef->{$mac} }, $vlanIfIndexToTags->{$vlanIfIndex};
            }
        }
    }
    return $secureMacAddrHashRef;
}

=item isPortSecurityEnabled - returns 1 or 0 whether maclock is activated or not

Requires ExtremeXOS 12.4.3

=cut

sub isPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    my $oid_extremePortVlanInfoMacLockDownEnabled = '1.3.6.1.4.1.1916.1.4.17.1.4'; # from EXTREME-PORT-MIB

    # get untagged vlanIfIndex on ifIndex
    # TODO efficiency could be improved here but I don't think it's worth it for now.
    my $vlan = $self->getVlan($ifIndex);
    my $vlanIfIndex = $self->_getVlanIfIndexFromVlanTag($vlan);

    if (!defined($vlanIfIndex)) {
        $logger->warn("Unable to retrieve untagged VLAN information, can't say if port security is enabled or not..");
        return 0;
    }

    if (!$self->connectRead()) {
        return 0;
    }

    # here we are looking for MAC Lockdown enabled on given ifIndex's untagged vlan
    # $oid_extremePortVlanInfoMacLockDownEnabled.<ifIndex>.<vlanIfIndex>
    my $oid_isPortSecurityEnabled = "$oid_extremePortVlanInfoMacLockDownEnabled.$ifIndex.$vlanIfIndex";

    $logger->trace("SNMP get_request for extremePortVlanInfoMacLockDownEnabled: $oid_isPortSecurityEnabled");
    my $result = $self->{_sessionRead}->get_request(-varbindlist => ["$oid_isPortSecurityEnabled"]);

    if (!defined($result)) {
        $logger->warn("Retrieving MAC Lockdown status failed. Error: ".$self->{_sessionRead}->error);
        return 0;
    } elsif (!defined($result->{$oid_isPortSecurityEnabled})) {
        $logger->warn("Retrieving MAC Lockdown status failed. Requested OID $oid_isPortSecurityEnabled not defined");
        return 0;
    } elsif ($result->{$oid_isPortSecurityEnabled} eq 'noSuchInstance') {
        $logger->warn(
            "Retrieving MAC Lockdown status failed. "
            . "Requested OID $oid_isPortSecurityEnabled returned 'noSuchInstance'"
        );
        return 0;
    }

    if ($result->{$oid_isPortSecurityEnabled} == 1) {
        return 1;
    }
    return 0;
}

=item _isPortSecurityEnabledOld - returns 1 or 0 whether maclock is activated or not

DEPRECATED for reference only. See isPortSecurityEnabled instead.

Here we rely on a special entry we add during the PacketFence setup to work-around a limitation in the
capabilities of the Extreme OS (can't know if maclock is activated or not)

=cut

sub _isPortSecurityEnabledOld {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    my $oid_extremeFdbPermFdbPortList = '1.3.6.1.4.1.1916.1.16.3.1.4'; # from EXTREME-FDB-MIB

    my ($stackIndex, $dot1dPort);
    if ($self->_getIfNameFromIfIndex($ifIndex) =~ /(\d+):(\d+)/) {
        $stackIndex = $1;
        $dot1dPort = $2;
    } else {
        $logger->warn("Unable to get port information from this ifIndex: $ifIndex");
        return 0;
    }

    # here we are looking for something very specific as explained in this sub's comment
    # oid_extremeFdbPermFdbPortList + stackIndex + special MAC in oid format + special VLAN
    my $specialVlan = $self->_getVlanTagFromVlanIfDescr($EXTREME::PORT_SECURITY_DETECT_VLAN);
    my $oid_isPortSecurityEnabled = $oid_extremeFdbPermFdbPortList . "."
        . $stackIndex . "." . mac2oid($self->generateFakeMac('', $ifIndex)) . "." . $specialVlan;

    if (!$self->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_request to find lock-learning state: $oid_isPortSecurityEnabled");
    # obtain raw information
    $self->{_sessionRead}->translate(0);
    my $result = $self->{_sessionRead}->get_request(-varbindlist => ["$oid_isPortSecurityEnabled"]);
    $self->{_sessionRead}->translate(1);

    # no result, no port-security
    if (!defined($result->{$oid_isPortSecurityEnabled})
        || ($result->{$oid_isPortSecurityEnabled} eq 'noSuchInstance')) {
        return 0;
    }

    # finding port bit on extremeFdbPermFdbPortList
    my $ifIndexHasLockedLearning = $self->getBitAtPosition(
        $result->{$oid_isPortSecurityEnabled},
        $self->_translateStackDot1dToPortListPosition($stackIndex, $dot1dPort) - 1
    );

    return $ifIndexHasLockedLearning;
}


=item authorizeMAC - authorize a MAC address and de-authorize the previous one if required

=cut

sub authorizeMAC {
    my ( $self, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't add an entry to the SecureMacAddrTable");
        return 1;
    }

    # TODO: if it's a fake MAC we don't act on it (see #1070 for context)
    if ($deauthMac && !$self->isFakeMac($deauthMac)) {
        $self->_deauthorizeMAC($ifIndex, $deauthMac, $deauthVlan);
    }

    # TODO: if it's a fake MAC we don't act on it (see #1070 for context)
    if ($authMac  && !$self->isFakeMac($authMac)) {
        return $self->_authorizeMAC($ifIndex, $authMac, $authVlan);
    }

    return 1;
}

=item _authorizeMAC - authorize a MAC address on a given ifIndex and VLAN

=cut

sub _authorizeMAC {
    my ($self, $ifIndex, $mac, $vlan) = @_;
    my $logger = $self->logger;

    my $ws_client = $self->_getSOAPHandle();

    # the Web Services call expects the VLAN in ifDescr format so a translation is in order
    my $vlan_name = $self->_getVlanIfDescrFromVlanTag($vlan);
    if (!defined($vlan_name)) {
        $logger->error("can't perform MAC authorization without a VLAN name");
        return 0;
    }

    # TODO: stack port translation (XML expects 17 and not 1:17 but what is it when stacked?)
    my $port = $self->_getDot1dPortFromIfIndex($ifIndex);

    my $response;
    try {
        $response = $ws_client->call(
            SOAP::Data->name($EXTREME::WS_CREATE_FDB) => (
                SOAP::Data->name($EXTREME::WS_DATATYPE_MAC => $mac),
                SOAP::Data->name($EXTREME::WS_DATATYPE_VLAN => $vlan_name),
                SOAP::Data->name($EXTREME::WS_DATATYPE_PORT => $port),
            )
        );
    } catch {
        $logger->error("Problem trying to authorize a secure MAC addresses on ifIndex $ifIndex. Error: $@");
        return 0;
    };

    if ($response->fault) {
        $logger->error("error authorizing MAC: " . $response->faultstring
            . " (Error code: " . $response->faultcode . ")");
        return 0;
    }
    return 1;
}

=item _deauthorizeMAC - authorize a MAC address on a given ifIndex and VLAN

On Extreme removing an entry from the secure table is based on MAC and VLAN only. IfIndex is not required.
For compatibility we won't change subroutine signature, we will just throw out the param.

=cut

sub _deauthorizeMAC {
    my ($self, $ifIndex, $mac, $vlan) = @_;
    my $logger = $self->logger;

    my $ws_client = $self->_getSOAPHandle();

    # the Web Services call expects the VLAN in ifDescr format so a translation is in order
    my $vlan_name = $self->_getVlanIfDescrFromVlanTag($vlan);
    if (!defined($vlan_name)) {
        $logger->error("can't perform MAC deauthorization without a VLAN name");
        return 0;
    }

    my $response;
    try {
        $response = $ws_client->call(
            SOAP::Data->name($EXTREME::WS_DELETE_FDB) => (
                SOAP::Data->name($EXTREME::WS_DATATYPE_MAC => $mac),
                SOAP::Data->name($EXTREME::WS_DATATYPE_VLAN => $vlan_name),
            )
        );
    } catch {
        $logger->error("Problem trying to deauthorize a secure MAC addresses on ifIndex $ifIndex. Error: $@");
        return 0;
    };

    if ($response->fault) {
        $logger->warn("error deauthorizing MAC: " . $response->faultstring
            . " (Error code: " . $response->faultcode . ")");
        return 0;
    }
    return 1;
}

=item _deauthorizeCurrentMac - deauthorize MACs on a given ifIndex / VLAN

Utility method that will find MAC address(es) on the given ifIndex / VLAN and will deauthorize them.

Returns deauthorized MAC(s)

=cut

sub _deauthorizeCurrentMac {
    my ($self, $ifIndex, $deauth_vlan) = @_;

    my $secureTableHashRef = $self->getSecureMacAddresses($ifIndex);

    # hash is valid and has one MAC
    my $valid = (ref($secureTableHashRef) eq 'HASH');
    my $mac_count = scalar(keys %{$secureTableHashRef});
    if ($valid && $mac_count == 1) {

        # normal case
        # grab MAC
        my $mac = (keys %{$secureTableHashRef})[0];
        # using authorizeMAC with deauth only parameters
        $self->authorizeMAC($ifIndex, $mac, undef, $deauth_vlan, undef);
        return $mac;

    } elsif ($valid && $mac_count > 1) {

        # VoIP case
        # check every MAC and stored the ones deauthorized
        my @deauth_mac;
        foreach my $mac (keys %{$secureTableHashRef}) {

            # for every MAC check every VLAN
            foreach my $vlan (@{$secureTableHashRef->{$mac}}) {
                # is VLAN equals to deauth_vlan
                if ($vlan == $deauth_vlan) {
                    # then we need to remove that MAC from that VLAN
                    # using authorizeMAC with deauth only parameters
                    $self->authorizeMAC($ifIndex, $mac, undef, $vlan, undef);
                    push (@deauth_mac, $mac);
                }
            }
        }
        return @deauth_mac;
    }
    return;
}


=item _translateStackDot1dToPortListPosition

Translates the slot # and dot1d port number into a integer position for use in port list.
A port list is when all the ports are represented in a binary notation one after the other with ones and zeros.

See extremeFdbPermFdbPortList in EXTREME-FDB-MIB for details.

=cut

sub _translateStackDot1dToPortListPosition {
    my ($self, $slotNumber, $dot1dPort) = @_;

    return ((($slotNumber-1) * $self->_getPortsPerSlot()) + $dot1dPort);
}

=item _getPortsPerSlot - Number of ports in a slots for this Chassis (Switch)

=cut

sub _getPortsPerSlot {
    my ($self) = @_;
    my $logger = $self->logger;

    $logger->debug("unimplemented");
    # TODO: unimplemented but would be relatively easy to do so since all required hooks are there
    # I have not implemented it because I wonder how I would cache that value and I would need to test it
    # and make sure it follows the class hierarchy
    #EXTREME-SYSTEM-MIB::extremeChassisPortsPerSlot
    return 256;
}

=item _getSOAPHandle - get a handle to call Extreme's Web Services on the current switch

=cut

#TODO test self-signed certs from the server (disabled by default)
sub _getSOAPHandle {
    my ($self) = @_;
    my $logger = $self->logger;

    my $proxy_url =
        $self->{_wsTransport} . "://" # transport (http, https)
        . $self->{_wsUser} . ":" . $self->{_wsPwd} . "@" . $self->{_ip} # auth (user:pass@host)
        . "/" . $EXTREME::WS_PROXY_URI_PATH # path
    ;

    my $connection;
    try {
        $connection = SOAP::Lite
            -> proxy($proxy_url, timeout => $EXTREME::WS_TIMEOUT)
            -> ns($EXTREME::WS_NAMESPACE_FDB, $EXTREME::WS_PREFIX_XOS)
            -> autotype(0)
        ;
    } catch {
        $logger->error("Problem connecting to Web Services provider on switch. Error: $@");
        return;
    };

    return $connection;
}

=item enablePortSecurityByIfIndex - enable lock-learning on a given ifIndex

On this switch, the lock-learning is a per-vlan attribute so it performs it on the current untagged VLAN of the ifIndex

=cut

sub enablePortSecurityByIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    my $result = $self->_setPortSecurityByIfIndex($ifIndex, $TRUE);
    if (!defined($result)) {
        $logger->error("problem trying to enable port-security (lock-learning)");
        return;
    }
    return 1;
}

=item disablePortSecurityByIfIndex - disable lock-learning on a given ifIndex (by configuring unlock-learning)

On this switch, the lock-learning is a per-vlan attribute so it performs it on the current untagged VLAN of the ifIndex

=cut

sub disablePortSecurityByIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    my $result = $self->_setPortSecurityByIfIndex($ifIndex, $FALSE);
    if (!defined($result)) {
        $logger->error("problem trying to disable port-security (lock-learning)");
        return;
    }
    return 1;
}

=item _setPortSecurityByIfIndex - change lock-learning configuration on a given ifIndex

Requires ExtremeXOS 12.4.3

On this switch, the lock-learning is a per-vlan attribute so it performs it on the current untagged VLAN of the ifIndex

=cut

sub _setPortSecurityByIfIndex {
    my ( $self, $ifIndex, $enable ) = @_;
    my $logger = $self->logger;

    my $oid_extremePortVlanInfoMacLockDownEnabled = '1.3.6.1.4.1.1916.1.4.17.1.4'; # from EXTREME-PORT-MIB

    # get untagged vlanIfIndex on ifIndex
    # TODO efficiency could be improved here but I don't think it's worth it for now.
    my $vlan = $self->getVlan($ifIndex);
    my $vlanIfIndex = $self->_getVlanIfIndexFromVlanTag($vlan);

    if (!defined($vlanIfIndex)) {
        $logger->warn("Unable to retrieve untagged VLAN information, can't change port security settings..");
        return;
    }

    if (!$self->connectWrite()) {
        return;
    }

    # here we are setting MAC Lockdown on a given ifIndex's untagged vlan
    # $oid_extremePortVlanInfoMacLockDownEnabled.<ifIndex>.<vlanIfIndex>
    my $oid_setPortSecurityByIfIndex = "$oid_extremePortVlanInfoMacLockDownEnabled.$ifIndex.$vlanIfIndex";

    $logger->trace("SNMP set_request to change MAC Lockdown value for ifIndex $ifIndex VLAN $vlanIfIndex to $enable: "
        . "$oid_setPortSecurityByIfIndex");
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [ $oid_setPortSecurityByIfIndex, Net::SNMP::INTEGER, $enable ]
    );
    if (!defined($result)) {
       $logger->error("Unable to change MAC Lockdown value for ifIndex $ifIndex: ".$self->{_sessionWrite}->error);
       return;
    }
    return 1;
}

=item _setPortSecurityByIfIndexCLI - change lock-learning configuration on a given ifIndex

DEPRECATED by SNMP version. See _setPortSecurityByIfIndex.

On this switch, the lock-learning is a per-vlan attribute so it performs it on the current untagged VLAN of the ifIndex

Warning: this method should _never_ be called in a thread.
Net::Appliance::Session is not thread safe: L<http://www.cpanforum.com/threads/6909/>
Experienced mostly when using SSH.

Warning: this code doesn't support elevating to privileged mode. See #900 and #1370.

=cut

sub _setPortSecurityByIfIndexCLI {
    my ( $self, $ifIndex, $enable ) = @_;
    my $logger = $self->logger;

    my $session;
    eval {
        require Net::Appliance::Session;
        $session = Net::Appliance::Session->new(
            Host => $self->{_ip},
            Timeout => 5,
            Transport => $self->{_cliTransport},
            Platform => 'ExtremeXOS',
            Source   => $lib_dir.'/pf/Switch/Extreme/nas-pb.yml',
        );
        $session->do_paging(0);
        $session->connect(
            Name     => $self->{_cliUser},
            Password => $self->{_cliPwd}
        );
    };

    if ($@) {
        $logger->warn("Unable to connect to ".$self->{'_ip'}." using ".$self->{_cliTransport}.". Failed with $@");
        return;
    }

    # TODO: stack port translation (XML expects 17 and not 1:17 but what is it when stacked?)
    my $port = $self->_getDot1dPortFromIfIndex($ifIndex);
    my $vlan = $self->_getVlanIfDescrFromVlanTag($self->getVlan($ifIndex));
    my $action = $enable ? "lock-learning" : "unlock-learning"; # if enable true, action = lock otherwise unlock

    my $command = "configure port $port vlan $vlan $action";

    $logger->trace("sending CLI command '$command'");
    my @output;
    eval { @output = $session->cmd(String => $command, Timeout => '10');};
    if ($@) {
        $logger->warn("Error with command $command on ".$self->{'_ip'}.". Failed with $@");
        $session->close();
        return;
    }

    if (grep(/error/i, @output)) {
        $logger->warn("Error with command $command on ".$self->{'_ip'}.". Failed with ".join(@output));
        $session->close();
        return;
    }

    $session->close();
    return 1;
}

=item isVoIPEnabled - is Voice over IP enabled on that switch?

=cut

sub isVoIPEnabled {
    my ($self) = @_;
    return ( $self->{_VoIPEnabled} == 1 );
}

=item getVoiceVlan - in what VLAN should a VoIP device be

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

=item returnAuthorizeRead

Return radius attributes to allow read access

=cut

sub returnAuthorizeRead {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    my $radius_reply_ref;
    my $status;
    $radius_reply_ref->{'Service-Type'} = '0';
    $radius_reply_ref->{'Reply-Message'} = "Switch read access granted by PacketFence";
    $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with read access");
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeRead', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=item returnAuthorizeWrite

Return radius attributes to allow write access

=cut

sub returnAuthorizeWrite {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    my $radius_reply_ref;
    my $status;
    $radius_reply_ref->{'Service-Type'} = '6';
    $radius_reply_ref->{'Reply-Message'} = "Switch enable access granted by PacketFence";
    $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with write access");
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeWrite', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
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
