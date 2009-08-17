package pf::SNMP::Extreme;

=head1 NAME

pf::SNMP::Extreme - Object oriented module to parse SNMP traps and manage Extreme Networks' switches

=head1 STATUS

Currently only supports linkUp / linkDown mode

Developed and tested on Summit X250e-48p running on image version 12.0.0.4

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP');
use Log::Log4perl;
use Net::SNMP;

use constant {
    DELETE_VLAN => 3,
    ADD_UNTAGGED_VLAN => 2,
    CREATE_AND_GO => 4
};

=head1 SUBROUTINES

=over

=item getVersion - obtain image version information from switch

=cut

sub getVersion {
    my ($this) = @_;
    # current image description
    my $oid_extremeImageDescription = '1.3.6.1.4.1.1916.1.1.1.34.1.10.3'; # from EXTREME-SYSTEM-MIB
    my $logger = Log::Log4perl::get_logger(ref($this));
    if (!$this->connectRead()) {
        return '';
    }
    $logger->trace("SNMP get_request for extremeImageDescription: $oid_extremeImageDescription");
    my $result = $this->{_sessionRead}->get_request(-varbindlist => [$oid_extremeImageDescription]);

    my $extremeImageDescription = ( $result->{$oid_extremeImageDescription} || '' );
    if ($extremeImageDescription =~ m/version (\d+\.\d+\.\d+\.\d+)/) {
       return $1; 
    }
    return $extremeImageDescription;
}

=item getVlan - return vlan number (dot1Q tag) of a given ifIndex

=cut
sub getVlan {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    # a binary map of all the ports 0 = not in vlan, 1 = in vlan
    my $oid_extremeVlanOpaqueUntaggedPorts = '1.3.6.1.4.1.1916.1.2.6.1.1.2'; #from EXTREME-VLAN-MIB

    if (!$this->connectRead()) {
        return 0;
    }

    my $stackIndex, my $dot1dPort;
    if ($this->_getIfNameFromIfIndex($ifIndex) =~ /(\d+):(\d+)/) {
        $stackIndex = $1;
        $dot1dPort = $2; 
    } else {
        $logger->warn("Unable to get port information from this ifIndex: $ifIndex");
        return 0;
    }

    $logger->trace("SNMP get_table for extremeVlanOpaqueUntaggedPorts: $oid_extremeVlanOpaqueUntaggedPorts");
    # obtain raw information
    $this->{_sessionRead}->translate(0);
    my $result = $this->{_sessionRead}->get_table(-baseoid => "$oid_extremeVlanOpaqueUntaggedPorts");
    $this->{_sessionRead}->translate(1);

    foreach my $vlanIfIndexStack (keys %{$result}) {
        if ($vlanIfIndexStack =~ /^$oid_extremeVlanOpaqueUntaggedPorts\.(\d+)\.$stackIndex$/) {
            my $vlanIfIndex = $1;
            
            # get bit value at dot1d port
            my $portInThisVlan = $this->getBitAtPosition($result->{$vlanIfIndexStack}, $dot1dPort-1);
            if ($portInThisVlan) {
                my $vlan = $this->_getVlanTagFromVlanIfIndex($vlanIfIndex);
                $logger->trace("Port: $dot1dPort (ifIndex: $ifIndex) is in vlan $vlan (ifIndex: $vlanIfIndex)");
                return $vlan;
            }

        } else {
            $logger->warn("can't recognize output of extremeVlanOpaqueUntaggedPorts");
        }
    }
}

sub getVlans {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    # vlanIfIndex to vlan number (vlan tag)
    my $oid_extremeVlanIfVlanId = "1.3.6.1.4.1.1916.1.2.1.2.1.10"; #from EXTREME-VLAN-MIB
    # vlanIfIndex to vlan name
    my $oid_ifName = "1.3.6.1.2.1.31.1.1.1.1"; #from IF-MIB

    # hash were we store the values
    my $vlans  = {};

    if ( !$this->connectRead() ) {
        return $vlans;
    }

    # store all the vlan IfIndex => vlan tag to use later
    $logger->trace("SNMP get_table for extremeVlanIfVlanId: $oid_extremeVlanIfVlanId");
    my $vlanTagsByVlanIfIndex = $this->{_sessionRead}->get_table(-baseoid => "$oid_extremeVlanIfVlanId");

    $logger->trace("SNMP get_table for ifName: $oid_ifName");
    my $vlanNamesByVlanIfIndex = $this->{_sessionRead}->get_table(-baseoid => "$oid_ifName");

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
    my ($this, $vlan) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    # vlanIfIndex to vlan number (vlan tag)
    my $oid_extremeVlanIfVlanId = "1.3.6.1.4.1.1916.1.2.1.2.1.10"; #from EXTREME-VLAN-MIB
    
    if (!$this->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_table for extremeVlanIfVlanId: $oid_extremeVlanIfVlanId");
    my $result = $this->{_sessionRead}->get_table(-baseoid => "$oid_extremeVlanIfVlanId"); 

    # loop on all vlans
    foreach my $vlanIfIndex (keys %{$result}) {
        if ($result->{$vlanIfIndex} == $vlan) {
            return 1;
        }
    }
    $logger->warn("could not find vlan $vlan on this switch");
    return 0;
}

=item getMacBridgePortHash - returns an hash of MACs and ifIndex

key: mac address / value: ifIndex of port where mac address is

=cut

sub getMacBridgePortHash {
    my $this   = shift;
    my $vlan   = shift || '';
    my $logger = Log::Log4perl::get_logger(ref($this));
    my %macBridgePortHash  = ();

    if ( !$this->connectRead() ) {
        return %macBridgePortHash;
    }

    # mac address in OID associated to port
    my $oid_dot1dTpFdbPort       = '1.3.6.1.2.1.17.4.3.1.2';    #from BRIDGE-MIB
    # port associated to ifIndex
    my $oid_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #from BRIDGE-MIB

    $logger->trace("SNMP get_table for dot1dTpFdbPort: $oid_dot1dTpFdbPort");
    my $resultMacPort = $this->{_sessionRead}->get_table(-baseoid => "$oid_dot1dTpFdbPort");

    $logger->trace("SNMP get_table for dot1dBasePortIfIndex: $oid_dot1dBasePortIfIndex");
    my $resultPortIfIndex = $this->{_sessionRead}->get_table(-baseoid => "$oid_dot1dBasePortIfIndex");

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
    my ($this, $vlanIfIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    # vlanIfIndex to vlan number (vlan tag)
    my $oid_extremeVlanIfVlanId = "1.3.6.1.4.1.1916.1.2.1.2.1.10.".$vlanIfIndex; #from EXTREME-VLAN-MIB

    if (!$this->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_request for extremeVlanIfVlanId: $oid_extremeVlanIfVlanId");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => ["$oid_extremeVlanIfVlanId"] );
    if ((exists($result->{"$oid_extremeVlanIfVlanId"})) && ($result->{"$oid_extremeVlanIfVlanId"} ne 'noSuchInstance')) {
        return $result->{"$oid_extremeVlanIfVlanId"}; #return tag number (Integer)
    } else {
        return 0;                        #no tag returned
    }
}

=item _getVlanIfIndexFromVlanTag - returns the vlan ifIndex from a vlan's number (real dot1Q tag number)

These switches uses a vlan ifIndex everywhere instead of using directly the vlan (tag) 
number like most of the other makers do.

=cut 
sub _getVlanIfIndexFromVlanTag {
    my ($this, $vlan) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    # vlanIfIndex to vlan number (vlan tag)
    my $oid_extremeVlanIfVlanId = "1.3.6.1.4.1.1916.1.2.1.2.1.10"; #from EXTREME-VLAN-MIB
    
    if (!$this->connectRead()) {
        return 0;
    }    

    $logger->trace("SNMP get_table for extremeVlanIfVlanId: $oid_extremeVlanIfVlanId");
    my $result = $this->{_sessionRead}->get_table(-baseoid => "$oid_extremeVlanIfVlanId");

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

=item _getDot1dPortFromIfIndex - retrieve dot1d port from ifIndex

=cut
sub _getDot1dPortFromIfIndex {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    my $ifName = $this->_getIfNameFromIfIndex($ifIndex);
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
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    # get interface name which is stack:port on extreme switches
    my $oid_ifName = "1.3.6.1.2.1.31.1.1.1.1.".$ifIndex; # from IF-MIB

    if (!$this->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_request for ifName: $oid_ifName");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => ["$oid_ifName"] );
    if ((exists($result->{"$oid_ifName"})) && ($result->{"$oid_ifName"} ne 'noSuchInstance')) {
        return $result->{"$oid_ifName"}; #return port number (Integer)
    } else {
        return 0;                        #no port return
    }
}

=item parseTrap - interpret traps and populate a trap hash 

=cut 
sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    
    # linkUp / linkDown trap
    if ($trapString =~ /BEGIN TYPE 0 END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS .+\|\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1 = INTEGER: (\d+)\|/) {
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
    } else {
        $logger->info("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

=item _setVlan - swap the vlans on a port (ifIndex)

=cut
sub _setVlan {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $result;

    if ( !$this->connectRead() ) {
        return 0;
    }

    # vlan control OIDs (from EXTREME-VLAN-MIB)
    my $oid_extremeVlanOpaqueControlPorts = "1.3.6.1.4.1.1916.1.2.6.2.1.1";
    my $oid_extremeVlanOpaqueControlOperation = "1.3.6.1.4.1.1916.1.2.6.2.1.2";
    my $oid_extremeVlanOpaqueControlStatus = "1.3.6.1.4.1.1916.1.2.6.2.1.3";

    # get dot1d port and stack index
    $this->_getIfNameFromIfIndex($ifIndex) =~ /(\d+):(\d+)/;
    my $stackIndex = $1;
    my $dot1dPort = $2;

    if ( !defined($dot1dPort) ) {
        $logger->warn("cannot identify dot1d port, I give up");
        return 0;
    }

    # Convert vlan into VlanIfIndex needed for the snmp set
    my $oldVlanIfIndex = $this->_getVlanIfIndexFromVlanTag($oldVlan);
    my $newVlanIfIndex = $this->_getVlanIfIndexFromVlanTag($newVlan);

    # create a portlist that will map to affected port only
    my $portList = $this->createPortListWithOneItem($dot1dPort);

    $logger->trace("locking - trying to lock \$switch_locker{".$this->{_ip}."} in _setVlan");
    {
        lock %{ $switch_locker_ref->{ $this->{_ip} } };
        $logger->trace("locking - \$switch_locker{".$this->{_ip}."} locked in _setVlan");

        # set all values
        if ( !$this->connectWrite() ) {
            return 0;
        }

        $logger->trace("SNMP set_request to remove port $dot1dPort from old vlan: $oldVlan (ifIndex: $oldVlanIfIndex)");
        my $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
                "$oid_extremeVlanOpaqueControlPorts.$oldVlanIfIndex.$stackIndex",
                Net::SNMP::OCTET_STRING,
                $portList,
                "$oid_extremeVlanOpaqueControlOperation.$oldVlanIfIndex.$stackIndex",
                Net::SNMP::INTEGER,
                DELETE_VLAN,
                "$oid_extremeVlanOpaqueControlStatus.$oldVlanIfIndex.$stackIndex",
                Net::SNMP::INTEGER,
                CREATE_AND_GO
            ]
        );
        if ( !defined($result) ) {
            $logger->error("error removing port from old vlan: ".$this->{_sessionWrite}->error);
        }

        $logger->trace("SNMP set_request to add port $dot1dPort to new vlan: $newVlan (ifIndex: $newVlanIfIndex)");

        $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
                "$oid_extremeVlanOpaqueControlPorts.$newVlanIfIndex.$stackIndex",
                Net::SNMP::OCTET_STRING,
                $portList,
                "$oid_extremeVlanOpaqueControlOperation.$newVlanIfIndex.$stackIndex",
                Net::SNMP::INTEGER,
                ADD_UNTAGGED_VLAN,
                "$oid_extremeVlanOpaqueControlStatus.$newVlanIfIndex.$stackIndex",
                Net::SNMP::INTEGER,
                CREATE_AND_GO

            ]
        );
        if ( !defined($result) ) {
            $logger->error("error adding port to new vlan: ".$this->{_sessionWrite}->error);
        }
    }
    $logger->trace("locking - \$switch_locker{".$this->{_ip}."} unlocked in _setVlan");
    return ( defined($result) );
}

=back

=head1 BUGS AND LIMITATIONS
    
Stacked switches should work but they were never tested.

SNMPv3 support was not tested.

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009 Inverse inc.

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
