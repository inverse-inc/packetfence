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

use Log::Log4perl;
use Net::SNMP;

use base ('pf::Switch::Nortel');

use pf::constants;
use pf::config;
use pf::Switch::constants;
use pf::util;
use pf::accounting qw(node_accounting_current_sessionid);
use pf::node qw(node_attributes);
use pf::util::radius qw(perform_coa perform_disconnect);

sub description { 'Avaya Switch Module' }

=head1 CAPABILITIES

=head1 METHODS

TODO: This list is incomplete

=cut


sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( $trapString
        =~ /^BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = INTEGER: \d+\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.7\.\d+ = INTEGER: [^|]+\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.8\.\d+ = INTEGER: [^)]+\)/
        )
    {
        $trapHashRef->{'trapType'} = ( ( $1 == 2 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
    } elsif ( $trapString
        =~ /\|\.1\.3\.6\.1\.4\.1\.45\.1\.6\.5\.3\.12\.1\.3\.(\d+)\.(\d+) = $SNMP::MAC_ADDRESS_FORMAT/) {

        $trapHashRef->{'trapType'} = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $this->getIfIndex($1,$2);
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($3);
        $trapHashRef->{'trapVlan'} = $this->getVlan( $trapHashRef->{'trapIfIndex'} );

        if ($trapHashRef->{'trapIfIndex'} <= 0) {
            $logger->warn(
                "Trap ifIndex is invalid. Should this switch be factory-reset? "
                . "See Nortel's BayStack Stacking issues in module documentation for more information."
            );
        }

        $logger->debug(
            "ifIndex for " . $trapHashRef->{'trapMac'} . " on switch " . $this->{_ip}
            . " is " . $trapHashRef->{'trapIfIndex'}
        );

    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub getIfIndex {
    my ($this, $ifDesc_param,$param2) = @_;

    if ( !$this->connectRead() ) {
        return 0;
    }

    my $OID_ifDesc = '1.3.6.1.2.1.31.1.1.1.1';
    my $result = $this->{_sessionRead}->get_table( -baseoid => $OID_ifDesc );
    foreach my $key ( keys %{$result} ) {
        my $ifDesc = $result->{$key};
        if ( $ifDesc =~ /\(Slot:\s$ifDesc_param\sPort:\s$param2\)/i ) {
            $key =~ /^$OID_ifDesc\.(\d+)$/;
            return $1;
        }
    }
}

sub getBoardPortFromIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_ifDesc = '1.3.6.1.2.1.31.1.1.1.1';
    my $result = $this->{_sessionRead}->get_request( -varbindlist => ["$OID_ifDesc.$ifIndex"] );
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
    my ( $this, $ifIndex ) = @_;

    my ($board, $port) = $this->getBoardPortFromIfIndex($ifIndex);

    return ( $board, $port );
}

sub getAllSecureMacAddresses {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_s5SbsAuthCfgAccessCtrlType = '1.3.6.1.4.1.45.1.6.5.3.10.1.2.0';

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }

    my $result = $this->{_sessionRead}->get_table( -baseoid => "$OID_s5SbsAuthCfgAccessCtrlType" );
    while ( my ( $oid_including_mac, $ctrlType ) = each( %{$result} ) ) {
        if (( $oid_including_mac =~
            /^$OID_s5SbsAuthCfgAccessCtrlType
                \.([0-9]+)\.([0-9]+)                                 # boardIndex, portIndex
                \.([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)   # MAC address
            $/x) && ( $ctrlType == 1 )) {

                my $boardIndx = $1;
                my $portIndx  = $2;
                my $ifIndex = $this->getIfIndex( $boardIndx, $portIndx );
                my $oldMac = oid2mac($3);
                push @{ $secureMacAddrHashRef->{$oldMac}->{$ifIndex} }, $this->getVlan($ifIndex);
        }
    }

    return $secureMacAddrHashRef;
}

sub getSecureMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_s5SbsAuthCfgAccessCtrlType = '1.3.6.1.4.1.45.1.6.5.3.10.1.2';
    my $secureMacAddrHashRef = {};

    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    my $oldVlan = $this->getVlan($ifIndex);

    $logger->trace(
        "SNMP get_table for s5SbsAuthCfgAccessCtrlType: $OID_s5SbsAuthCfgAccessCtrlType"
    );

    my $result = $this->{_sessionRead}->get_table( -baseoid => "$OID_s5SbsAuthCfgAccessCtrlType" );
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


#called with $authorized set to true, creates a new line to authorize the MAC
#when $authorized is set to false, deletes an existing line
sub _authorizeMAC {
    my ( $this, $ifIndex, $mac, $authorize ) = @_;
    my $OID_s5SbsAuthCfgAccessCtrlType = '1.3.6.1.4.1.45.1.6.5.3.10.1.4';
    my $OID_s5SbsAuthCfgStatus         = '1.3.6.1.4.1.45.1.6.5.3.10.1.5';
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->info( "not in production mode ... we won't delete an entry from the SecureMacAddrTable" );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    # careful readers will notice that we don't use getBoardPortFromIfIndex here. 
    # That's because Nortel thought that it made sense to start BoardIndexes differently for different OIDs
    # on the same switch!!! 
    my ( $boardIndx, $portIndx ) = $this->getBoardPortFromIfIndexForSecurityStatus($ifIndex);
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
            $result = $this->{_sessionWrite}->set_request(
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
            $result = $this->{_sessionWrite}->set_request(
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

    $logger->warn("MAC authorize / deauthorize failed with " . $this->{_sessionWrite}->error());
    return;
}

sub getPhonesLLDPAtIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @phones;
    if ( !$this->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch "
                . $this->{_ip}
                . ". getPhonesLLDPAtIfIndex will return empty list." );
        return @phones;
    }
    my $oid_lldpRemPortId  = '1.0.8802.1.1.2.1.4.1.1.7';
    my $oid_lldpRemSysDesc = '1.0.8802.1.1.2.1.4.1.1.10';

    if ( !$this->connectRead() ) {
        return @phones;
    }
    $logger->trace(
        "SNMP get_next_request for lldpRemSysDesc: $oid_lldpRemSysDesc");
    my $result = $this->{_sessionRead}
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
                    my $MACresult = $this->{_sessionRead}->get_request(
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




=head2 parseRequest

Redefinition of pf::Switch::parseRequest due to client mac being parsed from User-Name rather than Calling-Station-Id

=cut

sub parseRequest {
    my ( $this, $radius_request ) = @_;
    my $client_mac      = clean_mac($radius_request->{'User-Name'});
    my $user_name       = $radius_request->{'TLS-Client-Cert-Common-Name'} || $radius_request->{'User-Name'};
    my $nas_port_type   = $radius_request->{'NAS-Port-Type'};
    my $port            = $radius_request->{'NAS-Port'};
    my $eap_type        = ( exists($radius_request->{'EAP-Type'}) ? $radius_request->{'EAP-Type'} : 0 );
    my $nas_port_id     = ( defined($radius_request->{'NAS-Port-Id'}) ? $radius_request->{'NAS-Port-Id'} : undef );

    return ($nas_port_type, $eap_type, $client_mac, $port, $user_name, $nas_port_id, undef);
}

=head2 deauthenticateMac

Actual implementation.

Allows callers to refer to this implementation even though someone along the way override the above call.

=cut

sub deauthenticateMac {
    my ($this, $IfIndex, $mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));


    my $oid_bseePortConfigMultiHostClearNeap = "1.3.6.1.4.1.45.5.3.3.1.19";
    if (!$this->connectWrite()) {
        return 0;
    }
    $mac =~ s/://g;
    $mac =~ s/([a-fA-F0-9]{2})/chr(hex $1)/eg;
    #my $mic = mac2oid($mac);
    $logger->trace("SNMP set_request force port to reauthenticateon mac: $mac");
    my $result = $this->{_sessionWrite}->set_request(-varbindlist => [
        "$oid_bseePortConfigMultiHostClearNeap.$IfIndex", Net::SNMP::OCTET_STRING, $mac
    ]);

    if (!defined($result)) {
        $logger->error("got an SNMP error trying to force mac auth re authenticate: ".$this->{_sessionWrite}->error);
    }

    return (defined($result));
}

=head2 wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques {
    my ($this, $method, $connection_type) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
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
    my ($this, $ifIndex,$mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));


    # perform CoA
    $this->radiusDisconnect($mac);
}

=head2 radiusDisconnect

Sends a RADIUS Disconnect-Request to the NAS with the MAC as the Calling-Station-Id to disconnect.

Optionally you can provide other attributes as an hashref.

Uses L<pf::util::radius> for the low-level RADIUS stuff.

=cut

# TODO consider whether we should handle retries or not?

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

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
            LocalAddr => $management_network->tag('vip'),
        };

        $logger->debug("network device supports roles. Evaluating role to be returned");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $self);

        my $acctsessionid = node_accounting_current_sessionid($mac);
        my $node_info = node_attributes($mac);
        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;

        # Standard Attributes
        my $attributes_ref = {
            #'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
            'Acct-Session-Id' => $acctsessionid,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        # Roles are configured and the user should have one
        if (defined($role) && (defined($node_info->{'status'}) ) ) {

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

    return $TRUE if ($response->{'Code'} eq 'CoA-ACK');

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

Copyright (C) 2005-2015 Inverse inc.

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
