package pf::Switch::Avaya;

=head1 NAME

pf::Switch::Avaya - Object oriented module to access SNMP enabled Avaya switches

=head1 SYNOPSIS

The pf::SNMP::Avaya module implements an object oriented interface
to access SNMP enabled Avaya switches.

=head1 BUGS AND LIMITATIONS

=head2 BayStack stacking issues

Sometimes switches that were previously in a stacked setup will report
security violations as if they were still stacked.
You will notice security authorization made on wrong ifIndexes.
A factory reset / reconfiguration will resolve the situation.
We experienced the issue with a BayStack 470 running 3.7.5.13 but we believe it affects other BayStacks and firmwares.

=head2 Hard to predict OIDs seen on some variants

We faced issues where some switches (ie ERS2500) insisted on having a board index of 1 when adding a MAC to the security table although for most other operations the board index was 0.
Our attempted fix is to always consider the board index to start with 1 on the operations touching secuirty status (isPortSecurity and authorizeMAC).
Be aware of that if you start to see MAC authorization failures and report the problem to us, we might have to do a per firmware or per device implementation instead.

=cut

use strict;
use warnings;

use Net::SNMP;
use Try::Tiny;

use base ('pf::Switch::Nortel');

use pf::constants;
use pf::config qw(
    $WIRED_MAC_AUTH
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);
use pf::Switch::constants;
use pf::util;
use pf::accounting qw(node_accounting_current_sessionid);
use pf::node qw(node_attributes);
use pf::util::radius qw(perform_disconnect);
use pf::log;

sub description { 'Avaya Switch Module' }

=head1 CAPABILITIES

TODO: This list is incomplete

=cut

=head1 METHODS

TODO: This list is incomplete

=cut

sub supportsWiredMacAuth { return $SNMP::TRUE; }
sub supportsWiredDot1x { return $SNMP::TRUE }
sub supportsRadiusVoip { return $SNMP::TRUE }

=head2 identifyConnectionType

Used to override L<pf::Connection::identifyType> behavior if needed on a per switch module basis.

=cut

sub _identifyConnectionType {
    my ($self, $nas_port_type, $eap_type, $mac, $user_name) = @_;
    my $logger = $self->logger();

    unless( defined($nas_port_type) ){
        $logger->info("Request type is not set. On Nortel this means it's MAC AUTH");
        return $WIRED_MAC_AUTH;
    }

    # if we're not overiding, we call the parent method
    return $self->SUPER::_identifyConnectionType($nas_port_type, $eap_type, $mac, $user_name);

}

=head2 parseRequest

Takes FreeRADIUS' RAD_REQUEST hash and process it to return
NAS Port type (Ethernet, Wireless, etc.)
Network Device IP
EAP
MAC
NAS-Port (port)
User-Name

=cut


sub parseRequest {
    my ($self, $radius_request) = @_;
    my $client_mac = clean_mac($radius_request->{'Calling-Station-Id'}) || clean_mac($radius_request->{'User-Name'});
    my $user_name       = $self->parseRequestUsername($radius_request);
    my $nas_port_type = $radius_request->{'NAS-Port-Type'};
    my $port = $radius_request->{'NAS-Port'};
    my $eap_type = 0;
    if (exists($radius_request->{'EAP-Type'})) {
        $eap_type = $radius_request->{'EAP-Type'};
    }
    my $nas_port_id;
    if (defined($radius_request->{'NAS-Port-Id'})) {
        $nas_port_id = $radius_request->{'NAS-Port-Id'};
    }
    return ($nas_port_type, $eap_type, $client_mac, $port, $user_name, $nas_port_id, undef, $nas_port_id);
}


=head2 getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut

sub getVoipVsa {
    return ();
}

=head2 parseTrap

Unimplemented base method meant to be overriden in switches that support SNMP trap based methods.

=cut

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
        $trapHashRef->{'trapIfIndex'} = $self->getIfIndex($1,$2);
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

=head2 getIfIndex

return the ifindex based on the slot number and the port number

=cut

sub getIfIndex {
    my ($self, $ifDesc_param,$param2) = @_;

    if ( !$self->connectRead() ) {
        return 0;
    }

    my $OID_ifDesc = '1.3.6.1.2.1.31.1.1.1.1';
    my $result = $self->{_sessionRead}->get_table( -baseoid => $OID_ifDesc );
    foreach my $key ( keys %{$result} ) {
        my $ifDesc = $result->{$key};
        if ( $ifDesc =~ /\(Slot:\s$ifDesc_param\sPort:\s$param2\)/i ) {
            $key =~ /^$OID_ifDesc\.(\d+)$/;
            return $1;
        }
    }
}

=head2 getBoardPortFromIfIndex

return the slot and the port number based on the ifindex

=cut

sub getBoardPortFromIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_ifDesc = '1.3.6.1.2.1.31.1.1.1.1';
    my $result = $self->{_sessionRead}->get_request( -varbindlist => ["$OID_ifDesc.$ifIndex"] );
    if ($result->{"$OID_ifDesc.$ifIndex"} =~ /Slot:\s(\d+)\sPort:\s(\d+)/) {
        return ($1,$2);
    }
}

=head2 getBoardPortFromIfIndexForSecurityStatus

We noticed that the security status related OIDs always report their first boardIndex to 1 even though elsewhere
it's all referenced as 0.
I'm unsure if this is a bug or a feature so we created this hook that will always assume 1 as first board index.
To be used by method which read or write to security status related MIBs.

=cut

sub getBoardPortFromIfIndexForSecurityStatus {
    my ( $self, $ifIndex ) = @_;

    my ($board, $port) = $self->getBoardPortFromIfIndex($ifIndex);

    return ( $board, $port );
}

=head2 getAllSecureMacAddresses - return all MAC addresses in security table and their VLAN

Returns an hashref with MAC => ifIndex => Array(VLANs)

=cut

sub getAllSecureMacAddresses {
    my ($self) = @_;
    my $logger = $self->logger;
    my $OID_s5SbsAuthCfgAccessCtrlType = '1.3.6.1.4.1.45.1.6.5.3.10.1.2.0';

    my $secureMacAddrHashRef = {};
    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    my $result = $self->{_sessionRead}->get_table( -baseoid => "$OID_s5SbsAuthCfgAccessCtrlType" );
    while ( my ( $oid_including_mac, $ctrlType ) = each( %{$result} ) ) {
        if (( $oid_including_mac =~
            /^$OID_s5SbsAuthCfgAccessCtrlType
                \.([0-9]+)\.([0-9]+)                                 # boardIndex, portIndex
                \.([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)   # MAC address
            $/x) && ( $ctrlType == 1 )) {

                my $boardIndx = $1;
                my $portIndx  = $2;
                my $ifIndex = $self->getIfIndex( $boardIndx, $portIndx );
                my $oldMac = oid2mac($3);
                push @{ $secureMacAddrHashRef->{$oldMac}->{$ifIndex} }, $self->getVlan($ifIndex);
        }
    }

    return $secureMacAddrHashRef;
}

=head2 getSecureMacAddresses - return all MAC addresses in security table and their VLAN for a given ifIndex

Returns an hashref with MAC => Array(VLANs)

=cut

sub getSecureMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $OID_s5SbsAuthCfgAccessCtrlType = '1.3.6.1.4.1.45.1.6.5.3.10.1.2';
    my $secureMacAddrHashRef = {};

    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    my $oldVlan = $self->getVlan($ifIndex);

    $logger->trace(
        "SNMP get_table for s5SbsAuthCfgAccessCtrlType: $OID_s5SbsAuthCfgAccessCtrlType"
    );

    my $result = $self->{_sessionRead}->get_table( -baseoid => "$OID_s5SbsAuthCfgAccessCtrlType" );
    while ( my ( $oid_including_mac, $ctrlType ) = each( %{$result} ) ) {
        if ($ctrlType eq $ifIndex) {
            if ( $oid_including_mac =~
                /^$OID_s5SbsAuthCfgAccessCtrlType
                    \.([0-9]+)\.([0-9]+)                             # boardIndex, portIndex
                    \.([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)  # MAC address
                $/x ) {

                my $oldMac = oid2mac($3);
                push @{ $secureMacAddrHashRef->{$oldMac} }, $oldVlan;
            }
        }
    }

    return $secureMacAddrHashRef;
}


=head2 authorizeMAC - authorize a MAC address and de-authorize the previous one if required

=cut

sub _authorizeMAC {
    my ( $self, $ifIndex, $mac, $authorize ) = @_;
    my $OID_s5SbsAuthCfgAccessCtrlType = '1.3.6.1.4.1.45.1.6.5.3.10.1.4';
    my $OID_s5SbsAuthCfgStatus         = '1.3.6.1.4.1.45.1.6.5.3.10.1.5';
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
    my @boardIndx;

    # Because the boardIndx for a standalone switch can be 0 or 1 (random)
    if ($boardIndx eq '1') {
        @boardIndx = qw(0 1);
    } else {
        push (@boardIndx, $boardIndx);
    }

    my $cfgStatus = ($authorize) ? 2 : 3;
    my $mac_oid = mac2oid($mac);

    my $result;
    my $return;
    if ($authorize) {
        $logger->trace( "SNMP set_request for s5SbsAuthCfgAccessCtrlType: $OID_s5SbsAuthCfgAccessCtrlType" );
        foreach $boardIndx (@boardIndx) {
            $result = $self->{_sessionWrite}->set_request(
                -varbindlist => [
                    "$OID_s5SbsAuthCfgAccessCtrlType.$boardIndx.$portIndx.$mac_oid", Net::SNMP::INTEGER, $TRUE,
                    "$OID_s5SbsAuthCfgStatus.$boardIndx.$portIndx.$mac_oid", Net::SNMP::INTEGER, $cfgStatus
                ]
            );
            if ($result) {
                $return = 1;
            }
        }
    } else {
        foreach $boardIndx (@boardIndx) {
            $logger->warn("Remove mac ".$OID_s5SbsAuthCfgStatus.$boardIndx.$portIndx.$mac_oid);
            $logger->trace( "SNMP set_request for s5SbsAuthCfgStatus: $OID_s5SbsAuthCfgStatus" );
            $result = $self->{_sessionWrite}->set_request(
                -varbindlist => [
                    "$OID_s5SbsAuthCfgStatus.$boardIndx.$portIndx.$mac_oid", Net::SNMP::INTEGER, $cfgStatus
                ]
            );
            if ($result) {
                $return = 1;
            }
        }
    }

    return $TRUE if (defined($return));

    $logger->warn("MAC authorize / deauthorize failed with " . $self->{_sessionWrite}->error());
    return;
}

=head2 getPhonesLLDPAtIfIndex

Return list of MACs found through LLDP on a given ifIndex.

If this proves to be generic enough, it could be promoted to L<pf::Switch>.
In that case, create a generic ifIndexToLldpLocalPort also.

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
    my $oid_lldpRemPortId  = '1.0.8802.1.1.2.1.4.1.1.7';
    my $oid_lldpRemSysDesc = '1.0.8802.1.1.2.1.4.1.1.10';

    if ( !$self->connectRead() ) {
        return @phones;
    }
    $logger->trace(
        "SNMP get_next_request for lldpRemSysDesc: $oid_lldpRemSysDesc");
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => $oid_lldpRemSysDesc );
    foreach my $oid ( keys %{$result} ) {
        if ( $oid =~ /^$oid_lldpRemSysDesc\.([0-9]+)\.([0-9]+)\.([0-9]+)$/ ) {
            if ( $ifIndex eq $2 ) {
                my $cache_lldpRemTimeMark     = $1;
                my $cache_lldpRemLocalPortNum = $2;
                my $cache_lldpRemIndex        = $3;
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
                            =~ /([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})$/i
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




=head2 deauthenticateMac

Actual implementation.

Allows callers to refer to this implementation even though someone along the way override the above call.

=cut

sub deauthenticateMac {
    my ($self, $IfIndex, $mac) = @_;
    my $logger = $self->logger;


    my $oid_bseePortConfigMultiHostClearNeap = "1.3.6.1.4.1.45.5.3.3.1.19";
    if (!$self->connectWrite()) {
        return 0;
    }
    $mac =~ s/://g;
    $mac =~ s/([a-fA-F0-9]{2})/chr(hex $1)/eg;
    #my $mic = mac2oid($mac);
    $logger->trace("SNMP set_request force port to reauthenticateon mac: $mac");
    my $result = $self->{_sessionWrite}->set_request(-varbindlist => [
        "$oid_bseePortConfigMultiHostClearNeap.$IfIndex", Net::SNMP::OCTET_STRING, $mac
    ]);

    if (!defined($result)) {
        $logger->error("got an SNMP error trying to force mac auth re authenticate: ".$self->{_sessionWrite}->error);
    }

    return (defined($result));
}

=head2 wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::SNMP;
        my %tech = (
            $SNMP::SNMP => 'deauthenticateMac',
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    if ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::SNMP;
        my %tech = (
            $SNMP::SNMP => 'deauthenticateMac',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
}

=head2 deauthenticateMacRadius

Method to deauth a wired node with CoA.

=cut

sub deauthenticateMacRadius {
    my ($self, $ifIndex,$mac) = @_;
    my $logger = $self->logger;


    # perform CoA
    $self->radiusDisconnect($mac);
}

=head2 radiusDisconnect

Sends a RADIUS Disconnect-Request to the NAS with the MAC as the Calling-Station-Id to disconnect.

Optionally you can provide other attributes as an hashref.

Uses L<pf::util::radius> for the low-level RADIUS stuff.

=cut

# TODO consider whether we should handle retries or not?

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = $self->logger;

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS CoA-Request on $self->{'_ip'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating $mac");

    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip($send_disconnect_to),
        };

        $logger->debug("network device supports roles. Evaluating role to be returned");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $self);

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;
        my $time = time;

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
            'Event-Timestamp' => $time,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        if ( $self->shouldUseCoA({role => $role}) ) {

            $attributes_ref = {
                %$attributes_ref,
                'Filter-Id' => $role,
            };
            $logger->info("Returning ACCEPT with Role: $role");
            $response = perform_coa($connection_info, $attributes_ref);

        }
        else {
            $response = perform_disconnect($connection_info, $attributes_ref);
        }
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request: $_");
        $logger->error("Wrong RADIUS secret or unreachable network device...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ( ($response->{'Code'} eq 'Disconnect-ACK') || ($response->{'Code'} eq 'CoA-ACK') );

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

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
