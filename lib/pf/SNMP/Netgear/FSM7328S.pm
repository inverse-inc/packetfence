package pf::SNMP::Netgear::FSM7328S;

=head1 NAME

pf::SNMP::Netgear::FSM7328S - Object oriented module to access and configure enabled Netgear FSM7328S switches.

=head1 STATUS

=over

=item Port-security

- Developped and tested on a FSM7328S using firmware (Software version) 7.3.1.7 

- VoIP configuration not tested

=item Link up/down

- Can't work in this mode since up/down traps are parts of the port-security process

=back

=head1 BUGS AND LIMITATIONS

=over

=item forceDeauthOnLinkDown

The MAC address needs to be unauthorized from the port otherwise this MAC will stay authorized on the VLAN and no
more traps will show up.

=back 
=cut

use strict;
use warnings;

use POSIX;
use Log::Log4perl;
use Net::SNMP;

use pf::SNMP::constants;
use pf::config;
use pf::util;

use base ('pf::SNMP::Netgear');

sub description {'Netgear FSM7328S'}

=head1 METHODS

=over

=item authorizeMAC

Add a new MAC to the list of secure MACs for the ifIndex and remove the existing MAC from the list of secured ones.
Returns 1 on success 0 on failure.

=cut

sub authorizeMAC {
    my ( $this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_agentPortSecurityMACAddressRemove
        = '1.3.6.1.4.1.4526.10.20.1.2.1.9';    # NETGEAR-PORTSECURITY-PRIVATE-MIB
    my $OID_agentPortSecurityMACAddressAdd
        = '1.3.6.1.4.1.4526.10.20.1.2.1.8';    # NETGEAR-PORTSECURITY-PRIVATE-MIB

    if ( !$this->isProductionMode() ) {
        $logger->info( "The switch isn't in production mode (Do nothing): "
                . "Should deauthorize MAC $deauthMac on ifIndex $ifIndex "
                . "and authorize MAC $authMac on ifIndex $ifIndex" );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        $logger->warn( "Cannot connect to switch " . $this->{'_ip'} );
        return 0;
    }

    # Deauthorize MAC address from old location
    if ($deauthMac) {

        $logger->trace( "SNMP set_request for agentPortSecurityMACAddressRemove: "
                . "( $OID_agentPortSecurityMACAddressRemove.$ifIndex)" );
        my $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_agentPortSecurityMACAddressRemove.$ifIndex", Net::SNMP::OCTET_STRING,
                "$deauthVlan $deauthMac"
            ]
        );
        if ( !defined($result) ) {
            $logger->error( "Error deauthorizing $deauthVlan $deauthMac on ifIndex $ifIndex: "
                    . $this->{_sessionWrite}->error );
                return 0;
        }
        else {
            $logger->info("Deauthorizing $deauthVlan $deauthMac on ifIndex $ifIndex");
        }
    }

    # Authorize MAC address at new location
    if ($authMac) {

        $logger->trace( "SNMP set_request for agent: " . "( $OID_agentPortSecurityMACAddressAdd.$ifIndex )" );
        my $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_agentPortSecurityMACAddressAdd.$ifIndex", Net::SNMP::OCTET_STRING,
                "$authVlan $authMac"
            ]
        );
        if ( !defined($result) ) {
            $logger->error( "Error authorizing $authVlan $authMac on ifIndex $ifIndex: "
                    . $this->{_sessionWrite}->error );
            return 0;
        }
        else {
            $logger->info("Authorizing $authVlan $authMac on ifIndex $ifIndex");
        }
    }

    return 1;
}

=item forceDeauthOnLinkDown

Force a MAC address deauthorization from the port sending the linkdown trap.
Always returns 1.

See bugs and limitations.

=cut

sub forceDeauthOnLinkDown {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # here we actively ignore uplinks because this is called from the parsing threads which don't
    # check for uplinks (yet).
    # This hack is to work-around "Netgear's not sending traps under certain circumstances" "feature"
    my @uplinks = $this->getUpLinks();

    if ( @uplinks && $uplinks[0] == -1 ) {
        $logger->warn("Can't determine uplinks for the switch -> do nothing");
    }
    else {
        if ( grep( { $_ == $ifIndex } @uplinks ) == 0 ) {
            my $trustedMacHash = $this->getSecureMacAddresses($ifIndex);
            my $deauthMac      = ( keys %{$trustedMacHash} )[0];
            my $authMac        = $this->generateFakeMac( $FALSE, $ifIndex );
            my $deauthVlan     = $trustedMacHash->{$deauthMac}->[0];
            my $authVlan       = $this->{'_macDetectionVlan'};
            $this->authorizeMAC( $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan );
        }
    }

    return 1;
}

=item getAllSecureMacAddresses
Fetch all secure MAC addresses from the agentPortSecurityTable.
Returns only those addresses for interfaces where PortSecurityMode is enabled.

Returns a hashref where the key is an authorized MAC and the value is an arrayref of vlan ids.
From a practical point of view, we expect to only ever have one element in the list.
This is to maintain backwards compatibility with existing implementations of this method.

=cut

sub getAllSecureMacAddresses {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_agentPortSecurityTable      = '1.3.6.1.4.1.4526.10.20.1.2';
    my $OID_agentPortSecurityMode       = '1.3.6.1.4.1.4526.10.20.1.2.1.1'; # NETGEAR-PORTSECURITY-PRIVATE-MIB
    my $OID_agentPortSecurityStaticMACs = '1.3.6.1.4.1.4526.10.20.1.2.1.6'; # NETGEAR-PORTSECURITY-PRIVATE-MIB
    my $secureMacAddrHashRef            = {};

    if ( !$this->connectRead() ) {
        $logger->warn( "Cannot connect to switch " . $this->{'_ip'} );
        return $secureMacAddrHashRef;
    }

    $this->{_sessionRead}->translate(0);
    $logger->trace( "SNMP get_table for agentPortSecurityTable: $OID_agentPortSecurityTable" );
    my $result = $this->{_sessionRead}->get_table( -baseoid => "$OID_agentPortSecurityTable" );
    $this->{_sessionRead}->translate(1);

    my $ifIndex = 1;

    # iterate over all ifIndexes
    while ( exists $result->{"$OID_agentPortSecurityMode.$ifIndex"} ) {

        # add the mac vlan pair to secureMacAddrHashRef only if PortSecurityMode is enabled
        if ( $result->{"$OID_agentPortSecurityMode.$ifIndex"} == 1 ) {
            my @vlan_mac = split( /,/, $result->{"$OID_agentPortSecurityStaticMACs.$ifIndex"} );
            for my $vm_pair (@vlan_mac) {
                my ( $vlan, $mac ) = split( ' ', $vm_pair );
                push @{ $secureMacAddrHashRef->{$mac} }, $vlan;
            }
        }
        $ifIndex++;
    }

    return $secureMacAddrHashRef;
}

=item getSecureMacAddresses

Fetch all secure MAC addresses from the agentPortSecurityStaticMACs for the ifIndex.

Returns a hashref where the key is an authorized MAC and the value is an arrayref of vlan ids.
From a practical point of view, we expect to only ever have one element in the list.
This is to maintain backwards compatibility with existing implementations of this method.

=cut

sub getSecureMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_agentPortSecurityStaticMACs = '1.3.6.1.4.1.4526.10.20.1.2.1.6'; # NETGEAR-PORTSECURITY-PRIVATE-MIB
    my $secureMacAddrHashRef            = {};

    if ( !$this->connectRead() ) {
        $logger->warn( "Cannot connect to switch " . $this->{'_ip'} );
        return $secureMacAddrHashRef;
    }

    $logger->trace( "SNMP get for agentPortSecurityStaticMACs: $OID_agentPortSecurityStaticMACs.$ifIndex" );
    my $result
        = $this->{_sessionRead}->get_request( -varbindlist => ["$OID_agentPortSecurityStaticMACs.$ifIndex"] );

    if ( !defined($result) ) {
        $logger->error( "Error getting OID_agentPortSecurityStaticMACs " . $this->{_sessionRead}->error );
    }
    else {
        # result will be a , separated list of 'vlan mac' pairs
        my @vlan_mac = split( /,/, $result->{"$OID_agentPortSecurityStaticMACs.$ifIndex"} );
        for my $vm_pair (@vlan_mac) {
            my ( $vlan, $mac ) = split( ' ', $vm_pair );
            push @{ $secureMacAddrHashRef->{$mac} }, $vlan;
        }
    }

    return $secureMacAddrHashRef;
}


=item isPortSecurityEnabled



=cut

sub isPortSecurityEnabled {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_agentGlobalPortSecurityMode = '1.3.6.1.4.1.4526.10.20.1.1.0';   # NETGEAR-PORTSECURITY-PRIVATE-MIB
    my %PortSecurityMode = ( 1 => "enabled", 2 => "disabled" );

    if ( !$this->connectRead() ) {
        $logger->warn( "Cannot connect to switch " . $this->{'_ip'} );
        return 0;
    }

    $logger->trace(
        "SNMP get_request for OID_agentGlobalPortSecurityMode: " . "( $OID_agentGlobalPortSecurityMode )" );
    my $result = $this->{_sessionRead}->get_request( -varbindlist => ["$OID_agentGlobalPortSecurityMode"] );
    if ( !defined($result) ) {
        $logger->error( "Error getting OID_agentGlobalPortSecurityMode " . $this->{_sessionRead}->error );
    }
    else {
        $logger->info( "Port Security mode on "
                . $this->{'_ip'} . "is "
                . $PortSecurityMode{ $result->{$OID_agentGlobalPortSecurityMode} } );
    }

    my $enabled;
    if ( $result->{"$OID_agentGlobalPortSecurityMode"} == 1 ) {
        $enabled = $TRUE;
    }
    else {
        $enabled = $FALSE;
    }
    return $enabled;
}

=item parseTrap

=cut

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $trapHashRef;

# link up/down traps
# Example:
# 2013-07-25|13:01:28|UDP: [10.100.6.31]:1024->[10.100.16.90]|0.0.0.0|BEGIN TYPE 0 END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.2.1.1.3.0 = Timeticks: (244400) 0:40:44.00|.1.3.6.1.6.3.1.1.4.1.0 = OID: .1.3.6.1.6.3.1.1.5.4|.1.3.6.1.2.1.2.2.1.1.1 = INTEGER: 1|.1.3.6.1.2.1.2.2.1.7.1 = INTEGER: up(1)|.1.3.6.1.2.1.2.2.1.8.1 = INTEGER: up(1) END VARIABLEBINDINGS
    if ($trapString =~ 
            /BEGIN\ TYPE\ \d+\ END\ TYPE\ BEGIN\ SUBTYPE\ 0\ END\ SUBTYPE\ 
             BEGIN\ VARIABLEBINDINGS\ .+ \.1\.3\.6\.1\.2\.1\.2\.2\.1\.7\.(\d+)\ 
             =\ INTEGER:\ (up|down)
            /x
        )
    {
        $trapHashRef->{'trapIfIndex'} = $1;
        $trapHashRef->{'trapType'}    = $2;

        if ( $trapHashRef->{'trapType'} eq "down" ) {
            $this->forceDeauthOnLinkDown( $trapHashRef->{'trapIfIndex'} );
        }
    }

# secure MAC address violation traps
# Example:
# 2013-07-25|13:16:03|UDP: [10.100.6.31]:1024->[10.100.16.90]|0.0.0.0|BEGIN TYPE 0 END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS .1.3.6.1.2.1.1.3.0 = Timeticks: (331900) 0:55:19.00|.1.3.6.1.6.3.1.1.4.1.0 = OID: .1.3.6.1.4.1.6132.1.1.20.2.1|.1.3.6.1.2.1.2.2.1.1 = INTEGER: 1|.1.3.6.1.4.1.4526.10.20.1.2.1.7 = STRING: "100 b8:88:e3:dd:f9:45" END VARIABLEBINDINGS
    elsif (
        $trapString =~ 
            /BEGIN\ VARIABLEBINDINGS\ .+1\.3\.6\.1\.2\.1\.2\.2\.1\.1\ = \ INTEGER:\ (\d+)
             .+ .1.3.6.1.4.1.4526.10.20.1.2.1.7\ =\ STRING:\ "(\d+)\ ([^"]+)" 
            /x
        )
    {
        $trapHashRef->{'trapType'}    = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1;
        $trapHashRef->{'trapVlan'}    = $2;
        $trapHashRef->{'trapMac'}     = $3;
    }

    # unhandled traps
    else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }

    return $trapHashRef;
}

=item _setVlan

=cut

sub _setVlan {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_configPortDefaultVlanId = '1.3.6.1.2.1.17.7.1.4.5.1.1';    # Q-BRIDGE-MIB

    my $result;

    if ( !$this->isProductionMode() ) {
        $logger->info( "The switch isn't in production mode (Do nothing): "
                . "Should set ifIndex $ifIndex to VLAN $newVlan" );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        $logger->warn( "Cannot connect to switch " . $this->{'_ip'} );
        return 0;
    }

    $this->forceDeauthOnLinkDown($ifIndex);

    # Change port PVID
    $logger->trace( "SNMP set_request for OID_configPortDefaultVlanId: "
            . "( $OID_configPortDefaultVlanId.$ifIndex i $newVlan )" );

    $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_configPortDefaultVlanId.$ifIndex", Net::SNMP::UNSIGNED32, $newVlan ] );

    if ( !defined($result) ) {
        $logger->error( "Error setting PVID $newVlan on ifIndex $ifIndex: " . $this->{_sessionWrite}->error );
    }
    else {
        $logger->info("Setting PVID $newVlan on ifIndex $ifIndex");
    }

    return ( defined($result) );
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
