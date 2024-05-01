package pf::Switch::Cisco::Cisco_IOS_15_0;

=head1 NAME

pf::Switch::Cisco::Cisco_IOS_15_0 - Object oriented module to access and configure Cisco Catalyst 2960 switches

=head1 STATUS

=head1 SUPPORTS

=head2 802.1X with or without VoIP

=head2 Port-Security with or without VoIP

=head2 Link Up / Link Down

=head2 Stacked configuration

=head2 Firmware version

Recommended firmware is 12.2(58)SE1

The absolute minimum required firmware version is 12.2(25)SEE2.

Port-security + VoIP mode works with firmware 12.2(44)SE or greater unless mentioned below.
Earlier IOS were not explicitly tested.

The RADIUS part of this module also works with IOS XE switches.
It has been tested on IOS XE version 03.07.02E

This module extends pf::Switch::Cisco::Cisco_IOS_12_x.

=head1 PRODUCT LINES

=head2 2960, 2960S, 2960G

With no limitations that we are aware of.

=head2 2960 LanLite

The LanLite series doesn't support the fallback VLAN on RADIUS AAA based
approaches (MAC-Auth, 802.1X). This can affect fail-open scenarios.

=head1 BUGS AND LIMITATIONS

=head2 Port-Security

=head2 Status with IOS 15.x

At the moment we faced regressions with the Cisco IOS 15.x series. Not a lot
of investigation was performed but at this point consider this series as
broken with a Port-Security based configuration. At this moment, we recommend
users who cannot use another IOS to configure their switch to do MAC
Authentication instead (called MAC Authentication Bypass or MAB in Cisco's
terms) or get in touch with us so we can investigate further.

=head2 Problematic firmwares

12.2(50)SE, 12.2(55)SE were reported as malfunctioning for Port-Security operation.
Avoid these IOS.

12.2(44)SE6 is not sending security violation traps in a specific situation:
if a given MAC is authorized on a port/VLAN, no trap is sent if the device changes port
if the target port has the same VLAN as where the MAC was first authorized.
Without a security violation trap PacketFence can't authorize the port leaving the MAC unauthorized.
Avoid this IOS.

=head2 Delays sending security violation traps

Several IOS are affected by a bug that causes the security violation traps to take a long time before being sent.

In our testing, only the first traps were slow to come, the following were fast enough for a proper operation.
So although in testing they can feel like they are broken, once installed and active in the field these IOS are Ok.
Get in touch with us if you can reproduce a problematic behavior reliably and we will revisit our suggestion.

Known affected IOS: 12.2(44)SE2, 12.2(44)SE6, 12.2(52)SE, 12.2(53)SE1, 12.2(55)SE3

Known fixed IOS: 12.2(58)SE1

=head2 Port-Security with Voice over IP (VoIP)

=head2 Security table corruption issues with firmwares 12.2(46)SE or greater and PacketFence before 2.2.1

Several firmware releases have an SNMP security table corruption bug that happens only when VoIP devices are involved.

Although a Cisco problem we developed a workaround in PacketFence 2.2.1 that requires switch configuration changes.
Read the UPGRADE guide under 'Upgrading to a version prior to 2.2.1' for more information.

Firmware versions 12.2(44)SE6 or below should not upgrade their configuration.

Affected firmwares includes at least 12.2(46)SE, 12.2(52)SE, 12.2(53)SE1, 12.2(55)SE1, 12.2(55)SE3 and 12.2(58)SE1.

=head2 12.2(25r) disappearing config

For some reason when securing a MAC address the switch loses an important portion of its config.
This is a Cisco bug, nothing much we can do. Don't use this IOS for VoIP.
See issue #1020 for details.

=head2 SNMPv3

12.2(52) doesn't work in SNMPv3

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=head1 SNMP

This switch can parse SNMP traps and change a VLAN on a switch port using SNMP.

=cut

use strict;
use warnings;
use pf::log;
use Net::SNMP;
use Try::Tiny;

use base ('pf::Switch::Cisco::Cisco_IOS_12_x');
use pf::constants;
use pf::config qw(
    $WIRED_802_1X
    $WIRED_MAC_AUTH
    $WEBAUTH_WIRED
    %ConfigRoles
);
use pf::Switch::constants;
use pf::util;
use pf::util::radius qw(perform_coa);
use pf::web::util;
use pf::radius::constants;
use pf::locationlog qw(locationlog_get_session);

sub description { 'Cisco IOS v15.0' }

# CAPABILITIES
# access technology supported
# VoIP technology supported
# override Cisco_IOS_12_x's FALSE
use pf::SwitchSupports qw(
    WiredMacAuth
    WiredDot1x
    RadiusVoip
    RadiusDynamicVlanAssignment
    AccessListBasedEnforcement
    -DownloadableListBasedEnforcement
    RoleBasedEnforcement
    ExternalPortal
);

=head1 SUBROUTINES

TODO: This list is incomplete

=cut

sub getMinOSVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    return '12.2(25)SEE2';
}

sub getAllSecureMacAddresses {
    my ($self) = @_;
    my $logger = $self->logger;
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';

    my $secureMacAddrHashRef = {};
    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for cpsIfVlanSecureMacAddrRowStatus: $oid_cpsIfVlanSecureMacAddrRowStatus"
    );
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsIfVlanSecureMacAddrRowStatus" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$oid_cpsIfVlanSecureMacAddrRowStatus\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x",
                $2, $3, $4, $5, $6, $7 );
            my $oldVlan = $8;
            my $ifIndex = $1;
            push @{ $secureMacAddrHashRef->{$oldMac}->{$ifIndex} }, $oldVlan;
        }
    }

    return $secureMacAddrHashRef;
}

sub isDynamicPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $oid_cpsIfVlanSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.3.1.3';

    if ( !$self->connectRead() ) {
        return 0;
    }
    if ( !$self->isPortSecurityEnabled($ifIndex) ) {
        $logger->debug("port security is not enabled");
        return 0;
    }

    $logger->trace(
        "SNMP get_table for cpsIfVlanSecureMacAddrType: $oid_cpsIfVlanSecureMacAddrType"
    );
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsIfVlanSecureMacAddrType.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if (   ( $result->{$oid_including_mac} == 1 )
            || ( $result->{$oid_including_mac} == 3 ) )
        {
            return 0;
        }
    }

    return 1;
}

sub isStaticPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $oid_cpsIfVlanSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.3.1.3';

    if ( !$self->connectRead() ) {
        return 0;
    }
    if ( !$self->isPortSecurityEnabled($ifIndex) ) {
        $logger->info("port security is not enabled");
        return 0;
    }

    $logger->trace(
        "SNMP get_table for cpsIfVlanSecureMacAddrType: $oid_cpsIfVlanSecureMacAddrType"
    );
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsIfVlanSecureMacAddrType.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if (   ( $result->{$oid_including_mac} == 1 )
            || ( $result->{$oid_including_mac} == 3 ) )
        {
            return 1;
        }
    }

    return 0;
}

sub getSecureMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';

    my $secureMacAddrHashRef = {};
    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for cpsIfVlanSecureMacAddrRowStatus: $oid_cpsIfVlanSecureMacAddrRowStatus"
    );
    my $result = $self->{_sessionRead}->get_table(
        -baseoid => "$oid_cpsIfVlanSecureMacAddrRowStatus.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$oid_cpsIfVlanSecureMacAddrRowStatus\.$ifIndex\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x",
                $1, $2, $3, $4, $5, $6 );
            my $oldVlan = $7;
            push @{ $secureMacAddrHashRef->{$oldMac} }, int($oldVlan);
        }
    }

    return $secureMacAddrHashRef;
}

sub authorizeMAC {
    my ( $self, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = $self->logger;
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';

    if ( !$self->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't add an entry to the SecureMacAddrTable"
        );
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    # We will assemble the SNMP set request in this array and do it all in one pass
    my @oid_value;
    if ($deauthMac) {
        $logger->trace("Adding a cpsIfVlanSecureMacAddrRowStatus DESTROY to the set request");
        my $oid = "$oid_cpsIfVlanSecureMacAddrRowStatus.$ifIndex." . mac2oid($deauthMac) . ".$deauthVlan";
        push @oid_value, ($oid, Net::SNMP::INTEGER, $SNMP::DESTROY);
    }
    if ($authMac) {
        $logger->trace("Adding a cpsIfVlanSecureMacAddrRowStatus CREATE_AND_GO to the set request");
        # Warning: placing in deauthVlan instead of authVlan because authorization happens before VLAN change
        my $oid = "$oid_cpsIfVlanSecureMacAddrRowStatus.$ifIndex." . mac2oid($authMac) . ".$deauthVlan";
        push @oid_value, ($oid, Net::SNMP::INTEGER, $SNMP::CREATE_AND_GO);
    }
    if (@oid_value) {
        $logger->trace("SNMP set_request for cpsIfVlanSecureMacAddrRowStatus");
        my $result = $self->{_sessionWrite}->set_request(-varbindlist => \@oid_value);
        if (!defined($result)) {
            $logger->warn(
                "SNMP error tyring to remove or add secure rows to ifIndex $ifIndex in port-security table. "
                . "This could be normal. Error message: ".$self->{_sessionWrite}->error()
            );
            return 0;
        }
    }
    return 1;
}

=head2 dot1xPortReauthenticate

Points to pf::Switch implementation bypassing Cisco_IOS_12_x's overridden behavior.

=cut

sub dot1xPortReauthenticate {
    my ($self, $ifIndex, $mac) = @_;

    return $self->_dot1xPortReauthenticate($ifIndex);
}

=head2 NasPortToIfIndex

Translate RADIUS NAS-Port into switch's ifIndex.

=cut

sub NasPortToIfIndex {
    my ($self, $NAS_port) = @_;
    my $logger = $self->logger;

    # ex: 50023 is ifIndex 10023
    if ($NAS_port =~ s/^5/1/) {
        return $NAS_port;
    } else {
        $logger->warn("Unknown NAS-Port format. ifIndex translation could have failed. "
            ."VLAN re-assignment and switch/port accounting will be affected.");
    }
    return $NAS_port;
}

=head2 getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut

sub getVoipVsa {
    my ($self) = @_;
    my $logger = $self->logger;

    return ('Cisco-AVPair' => "device-traffic-class=voice");
}

=head2 deauthenticateMacRadius

Method to deauth a wired node with CoA.

=cut

sub deauthenticateMacRadius {
    my ($self, $ifIndex,$mac) = @_;
    my $logger = $self->logger;


    # perform CoA
    $self->radiusDisconnect($mac ,{ 'Acct-Terminate-Cause' => 'Admin-Reset'});
}

=head2 radiusDisconnect

Send a CoA to disconnect a mac

=cut

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = $self->logger;

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS CoA-Request on (".$self->{'_id'}."): RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating");

    my $send_disconnect_to = $self->{'_ip'};
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = $self->radius_deauth_connection_info($send_disconnect_to);

        $logger->debug("network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned");

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;
        # Standard Attributes

        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };
        $response = perform_coa($connection_info, $attributes_ref, [{ 'vendor' => 'Cisco', 'attribute' => 'Cisco-AVPair', 'value' => 'subscriber:command=reauthenticate' },{ 'vendor' => 'Cisco', 'attribute' => 'Cisco-AVPair', 'value' => 'subscriber:reauthenticate-type=last' }]);
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request on (".$self->{'_id'}.") : $_");
        $logger->error("Wrong RADIUS secret or unreachable network device (".$self->{'_id'}.") ...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ( ($response->{'Code'} eq 'Disconnect-ACK') || ($response->{'Code'} eq 'CoA-ACK') );

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request on (".$self->{'_id'}.")."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=head2 wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::SNMP => 'dot1xPortReauthenticate',
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    if ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::SNMP => 'handleReAssignVlanTrapForWiredMacAuth',
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
}

=head2 returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role be returned into.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Filter-Id';
}

=head2 returnRoleAttributes

Return the specific role attribute of the switch.

=cut

sub returnRoleAttributes {
    my ($self, $role) = @_;
    return ($self->returnRoleAttribute() => $role.".in");
}

=item returnPushAclsRoleAttributes


Return the specifics in and out attribute of the switch

=cut

sub returnPushAclsRoleAttributes {
    my ($self, $role) = @_;
    my %reply = (
        $self->returnRoleAttribute() => $role.".in",
        # Doesn't work for now
        #$self->returnRoleAttribute() => $role."out.out",
    );
    return %reply;
}


sub disableMABByIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = get_logger();

    if ( !$self->isProductionMode() ) {
        $logger->warn("Should set cafPortAuthorizeControl on $ifIndex to 3:forceAuthorized but the s");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $OID_cafPortAuthorizeControl = '1.3.6.1.4.1.9.9.656.1.2.1.1.5';

    $logger->trace("SNMP set_request for cafPortAuthorizeControl: $OID_cafPortAuthorizeControl");
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_cafPortAuthorizeControl.$ifIndex", Net::SNMP::INTEGER, 3 ] );
    return ( defined($result) );
}

sub enableMABByIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = get_logger();

    if ( !$self->isProductionMode() ) {
        $logger->warn("Should set cafPortAuthorizeControl on $ifIndex to 2:auto but the switch is no");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $OID_cafPortAuthorizeControl = '1.3.6.1.4.1.9.9.656.1.2.1.1.5';

    $logger->trace("SNMP set_request for cafPortAuthorizeControl: $OID_cafPortAuthorizeControl");
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_cafPortAuthorizeControl.$ifIndex", Net::SNMP::INTEGER, 2 ] );
    return ( defined($result) );
}


=head2 parseExternalPortalRequest

Parse external portal request using URI and it's parameters then return an hash reference with the appropriate parameters

See L<pf::web::externalportal::handle>

=cut

sub parseExternalPortalRequest {
    my ( $self, $r, $req ) = @_;
    my $logger = $self->logger;

    # Using a hash to contain external portal parameters
    my %params = ();

    # Cisco Catalyst 2960 uses external portal session ID handling process
    my $uri = $r->uri;
    return unless ($uri =~ /.*sid(\w+[^\/\&])/);
    my $session_id = $1;

    my $locationlog = pf::locationlog::locationlog_get_session($session_id);
    my $switch_id = $locationlog->{switch};
    my $client_mac = $locationlog->{mac};
    my $client_ip = defined($r->headers_in->{'X-Forwarded-For'}) ? $r->headers_in->{'X-Forwarded-For'} : $r->connection->remote_ip;
    my @proxied_ip = split(',', $client_ip);
    $client_ip = $proxied_ip[0];

    my $redirect_url;
    if ( defined($req->param('redirect')) ) {
        $redirect_url = $req->param('redirect');
    }
    elsif ( defined($r->headers_in->{'Referer'}) ) {
        $redirect_url = $r->headers_in->{'Referer'};
    }

    %params = (
        session_id              => $session_id,
        switch_id               => $switch_id,
        client_mac              => $client_mac,
        client_ip               => $client_ip,
        redirect_url            => $redirect_url,
        synchronize_locationlog => $FALSE,
        connection_type         => $WEBAUTH_WIRED,
);

    return \%params;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
