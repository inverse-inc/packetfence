package pf::Switch::Xirrus;

=head1 NAME

pf::Switch::Xirrus

=head1 SYNOPSIS

Implement object oriented module to interact with Xirrus network equipment

=head1 STATUS

Developed and tested against XS4 model ArrayOS version 3.5-724.

According to Xirrus engineers, this modules should work on any XS and XN model.

=head2 External Portal Enforcement

Developed and tested on XR4430 running 6.4.1

=head1 BUGS AND LIMITATIONS

SNMPv3 support is untested.

=head2 External Portal Enforcement - Cannot use the access point behind a NAT gateway

Since the access point is not sending the IP address of the device in the URL parameters,
the access point and PacketFence cannot be separated by a NAT gateway.
This module uses the remote IP in the HTTP request to determine the IP of the client.

=cut

use strict;
use warnings;

use POSIX;
use Try::Tiny;

use pf::config qw(
    $MAC
    $SSID
    $WIRELESS_MAC_AUTH
    $WEBAUTH_WIRELESS
);
use pf::constants;
use pf::node;
use pf::Switch::constants;
use pf::util;
use pf::util::radius qw(perform_disconnect);
use pf::constants::role qw($REJECT_ROLE);

use base ('pf::Switch');


sub description { 'Xirrus WiFi Arrays' }

=head1 SUBROUTINES

TODO: this list is incomplete

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }
sub supportsExternalPortal { return $TRUE; }
sub supportsWebFormRegistration { return $TRUE; }
sub supportsRoleBasedEnforcement { return $TRUE; }

#
# %TRAP_NORMALIZERS
# A hash of Xirrus trap normalizers
# Use the following convention when adding a normalizer
# <nameOfTrapNotificationType>TrapNormalizer
#
our %TRAP_NORMALIZERS = (
   '.1.3.6.1.4.1.14823.2.3.1.11.1.2.1017' => 'wlsxNUserEntryDeAuthenticatedTrapNormalizer',
);

=item getVersion

obtain image version information from switch

=cut

sub getVersion {
    my ($self)       = @_;
    my $oid_sysDescr = '1.3.6.1.2.1.1.1.0';
    my $logger       = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysDescr: $oid_sysDescr");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_sysDescr] );
    my $sysDescr = ( $result->{$oid_sysDescr} || '' );

    # sysDescr sample output:
    #Xirrus XS4 WiFi Array
    #, ArrayOS Version 3.5-724

    if ( $sysDescr =~ m/Version (\d+\.\d+-\d+)/ ) {
        return $1;
    } else {
        $logger->warn("couldn't extract exact version information, returning SNMP System Description instead");
        return $sysDescr;
    }
}

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;

    # wlsxNUserEntryDeAuthenticated: 1.3.6.1.4.1.14823.2.3.1.11.1.2.1017

    if ( $trapString =~ /\.1\.3\.6\.1\.4\.1\.14823\.2\.3\.1\.11\.1\.2\.1017[|].+[|]\.1\.3\.6\.1\.4\.1\.14823\.2\.3\.1\.11\.1\.1\.52\.[0-9]+ = $SNMP::MAC_ADDRESS_FORMAT/ ) {
        $trapHashRef->{'trapType'} = 'dot11Deauthentication';
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($1);

    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

=item deauthenticateMacDefault

deauthenticate a MAC address from wireless network (including 802.1x)

=cut

sub deauthenticateMacDefault {
    my ($self, $mac) = @_;
    my $logger = $self->logger;
    my $OID_stationDeauthMacAddress = '1.3.6.1.4.1.21013.1.2.22.3.0'; # from XIRRUS-MIB

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't write to the stationDeauthMacAddress");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    $logger->trace("SNMP set_request for stationDeauthMacAddress: $OID_stationDeauthMacAddress");
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_stationDeauthMacAddress",
            Net::SNMP::OCTET_STRING,
            $mac
        ] );

    # TODO: validate result
    $logger->info("deauthenticate mac $mac from access point : " . $self->{_ip});
    return ( defined($result) );

}

=item deauthenticateMacDefault

De-authenticate a MAC address from wireless network (including 802.1x).

New implementation using RADIUS Disconnect-Request.

=cut

sub deauthenticateMacRadius {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    # TODO push Login-User => 1 (RFC2865) in pf::radius::constants if someone ever reads this
    # (not done because it doesn't exist in current branch)
    return $self->radiusDisconnect( $mac );
}

=item radiusDisconnect

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

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;

        # Standard Attributes
        my $attributes_ref = {
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        $response = perform_disconnect( $connection_info,
            {
                'Calling-Station-Id' => $mac,
            },
        );
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

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::SNMP;
    my %tech = (
        $SNMP::SNMP => 'deauthenticateMacDefault',
        $SNMP::RADIUS => 'deauthenticateMacRadius',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=item returnAuthorizeWrite

Return radius attributes to allow write access

=cut

sub returnAuthorizeWrite {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    my $radius_reply_ref;
    my $status;
    $radius_reply_ref->{'Xirrus-Admin-Role'} = 'read-write';
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
    $radius_reply_ref->{'Xirrus-Admin-Role'} = 'read-only';
    $radius_reply_ref->{'Reply-Message'} = "Switch read access granted by PacketFence";
    $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with read access");
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeRead', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Overriding the default implementation for the external captive portal

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    my $radius_reply_ref = {};
    my $status;

    # should this node be kicked out?
    my $kick = $self->handleRadiusDeny($args);
    return $kick if (defined($kick));

    my $node = $args->{'node_info'};

    if ( $self->externalPortalEnforcement ) {
        my $security_event = pf::security_event::security_event_view_top($args->{'mac'});
        # if user is unregistered or is in security_event then we reject him to show him the captive portal
        if ( $node->{status} eq $pf::node::STATUS_UNREGISTERED || defined($security_event) ){
            $logger->info("[$args->{'mac'}] is unregistered. Refusing access to force the eCWP");
            $args->{user_role} = $REJECT_ROLE;
            $self->handleRadiusDeny();
        }
        else{
            $logger->info("Returning ACCEPT");
            ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
            return [$status, %$radius_reply_ref];
        }
    }

    return $self->SUPER::returnRadiusAccessAccept($args);
}


=item parseExternalPortalRequest

Parse external portal request using URI and it's parameters then return an hash reference with the appropriate parameters

See L<pf::web::externalportal::handle>

=cut

sub parseExternalPortalRequest {
    my ( $self, $r, $req ) = @_;
    my $logger = $self->logger;

    # Using a hash to contain external portal parameters
    my %params = ();

    my $client_ip = defined($r->headers_in->{'X-Forwarded-For'}) ? $r->headers_in->{'X-Forwarded-For'} : $r->connection->remote_ip;

    %params = (
        switch_id               => $req->param('nasid'),
        client_mac              => clean_mac($req->param('mac')),
        client_ip               => $client_ip,
        ssid                    => $req->param('ssid'),
        redirect_url            => $req->param('userurl'),
        status_code             => '200',
        synchronize_locationlog => $TRUE,
        connection_type         => $WEBAUTH_WIRELESS,
    );

    return \%params;
}


sub getAcceptForm {
    my ( $self, $mac, $destination_url, $portalSession ) = @_;
    my $logger = $self->logger;
    $logger->debug("Creating web release form");

    my $uamip = $portalSession->param("ecwp-original-param-uamip");
    my $uamport = $portalSession->param("ecwp-original-param-uamport");
    my $userurl = $portalSession->param("ecwp-original-param-userurl");
    my $challenge = $portalSession->param("ecwp-original-param-challenge");
    my $newchal  = pack "H32", $challenge;

    my @ib = unpack("C*", "\0" . $mac . $newchal);
    my $encstr = join("", map {sprintf('\%3.3o', $_)} @ib);
    my ($passvar) = split(/ /, `printf '$encstr' | md5sum`);

    $mac =~ s/:/-/g;

    my $html_form = qq[
        <script>
        if (document.URL.match(/res=success/)){
            //http requests are too fast for the ap
            //we leave him time to understand what is happening
            setTimeout(function(){window.location = "$destination_url"}, 2000)
        }
        else{
            window.location = "http://$uamip:$uamport/logon?username=$mac&password=$passvar&userurl=$destination_url"
        }
        </script>
    ];

    $logger->debug("Generated the following html form : ".$html_form);
    return $html_form;
}

=item returnRoleAttribute

Xirrus uses the standard Filter-Id parameter.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Filter-Id';
}


=item wlsxNUserEntryDeAuthenticatedTrapNormalizer

trap normalizer for wlsxNUserEntryDeAuthenticated trap

=cut

sub wlsxNUserEntryDeAuthenticatedTrapNormalizer {
    my ($self, $trapInfo) = @_;
    my $logger = $self->logger;
    my ($pdu, $variables) = @$trapInfo;
    return {
        trapType => 'dot11Deauthentication',
        trapMac => $self->getMacFromTrapVariablesForOIDBase($variables, '.1.3.6.1.4.1.14823.2.3.1.11.1.1.52.'),
    };
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

