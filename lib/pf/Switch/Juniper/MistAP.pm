package pf::Switch::Juniper::MistAP;

=head1 NAME

pf::Switch::Juniper::MistAP - Object oriented module to manage Juniper Mist AP

=over

=item Supports

=over

=item Deauthentication with RADIUS Disconnect (RFC3576)


=head1 BUGS AND LIMITATIONS

=over

=item Version specific issues

=over

=cut

use strict;
use warnings;

use Try::Tiny;

use base ('pf::Switch');

use pf::constants;
use pf::config qw(
    $MAC
    $SSID
    $WEBAUTH_WIRELESS
);
use pf::web::util;
use pf::util;
use pf::node;
use pf::util::radius qw(perform_disconnect);
use pf::radius::constants;
use pf::locationlog qw(locationlog_get_session);
use pf::util::wpa;
use pf::log;

sub description { 'Juniper Mist Access Point' }

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
use pf::SwitchSupports qw(
    WirelessDot1x
    WirelessMacAuth
    RoleBasedEnforcement
    WiredMacAuth
    WiredDot1x
    ExternalPortal
    -SaveConfig
    -Cdp
    -Lldp
);
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=item getVersion - obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    $logger->info("we don't know how to determine the version through SNMP ! but it has been tested on 0.14.29676");
    return 'i0.14.29676';
}

=item deauthenticateMacDefault

De-authenticate a MAC address from wireless network (including 802.1x).

New implementation using RADIUS Disconnect-Request.

=cut

sub deauthenticateMacDefault {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    # TODO push Login-User => 1 (RFC2865) in pf::radius::constants if someone ever reads this
    # (not done because it doesn't exist in current branch)
    return $self->radiusDisconnect( $mac, { 'Service-Type' => 'Login-User'} );
}

=item returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Airespace-ACL-Name';
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::RADIUS;
    my %tech = (
        $SNMP::RADIUS => 'deauthenticateMacDefault',
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
    $radius_reply_ref->{'Service-Type'} = 'Administrative-User';
    $radius_reply_ref->{'Reply-Message'} = "Switch enable access granted by PacketFence";
    $radius_reply_ref->{'Reply-Message'} = $args->{'message'}." . ".$radius_reply_ref->{'Reply-Message'} if exists $args->{'message'};
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
    $radius_reply_ref->{'Service-Type'} = 'NAS-Prompt-User';
    $radius_reply_ref->{'Reply-Message'} = "Switch read access granted by PacketFence";
    $radius_reply_ref->{'Reply-Message'} = $args->{'message'}." . ".$radius_reply_ref->{'Reply-Message'} if exists $args->{'message'};
    $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with read access");
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeRead', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Overrides the default implementation to add the dynamic acls

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    $args->{'unfiltered'} = $TRUE;
    my @super_reply = @{$self->SUPER::returnRadiusAccessAccept($args)};
    my $status = shift @super_reply;
    my %radius_reply = @super_reply;
    my $radius_reply_ref = \%radius_reply;
    return [$status, %$radius_reply_ref] if($status == $RADIUS::RLM_MODULE_USERLOCK);

    my @av_pairs = defined($radius_reply_ref->{'Cisco-AVPair'}) ? @{$radius_reply_ref->{'Cisco-AVPair'}} : ();

    my $role = $self->getRoleByName($args->{'user_role'});
    if ( isenabled($self->{_UrlMap}) && $self->externalPortalEnforcement ) {
        if ( defined($args->{'user_role'}) && $args->{'user_role'} ne "" && defined($self->getUrlByName($args->{'user_role'}) ) ) {
            $args->{'session_id'} = "sid".$self->setSession($args);
            my $redirect_url = $self->getUrlByName($args->{'user_role'});
            $redirect_url .= '/' unless $redirect_url =~ m(\/$);
            $redirect_url .= $args->{'session_id'};
            # Cisco and Meraki started adding "&redirect_url=http://example.com" unconditionnaly to the redirect URL.
            # This means that since we don't have any query parameters that generated paths like "/Cisco::WLC/sid123456&redirect_url=http://example.com" which extracts the SID as sid123456&redirect_url=http://example.com
            # We add empty query parameters to our path as a workaround
            $redirect_url .= "?";
            #override role if a role in role map is define
            if (isenabled($self->{_RoleMap}) && $self->supportsRoleBasedEnforcement()) {
                my $role_map = $self->getRoleByName($args->{'user_role'});
                $role = $role_map if (defined($role_map));
                # remove the role if any as we push the redirection ACL along with it's role
                delete $radius_reply_ref->{$self->returnRoleAttribute()};
            }
            $logger->info("Adding web authentication redirection to reply using role: '$role' and URL: '$redirect_url'");
            push @av_pairs, "url-redirect-acl=$role";
            push @av_pairs, "url-redirect=".$redirect_url;
        }
    }
    $self->addDPSK($args, $radius_reply_ref, \@av_pairs);
    $radius_reply_ref->{'Cisco-AVPair'} = \@av_pairs;

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

sub addDPSK {
    my ($self, $args, $radius_reply_ref, $av_pairs) = @_;
    if ($args->{profile}->dpskEnabled()) {
        if (defined($args->{owner}->{psk})) {
            push @$av_pairs, "psk=$args->{owner}->{psk}";
        } else {
            push @$av_pairs, "psk=$args->{profile}->{_default_psk_key}";
        }
        push @$av_pairs, "psk-mode=ascii";
    }
}

=head2 radiusDisconnect

Send a RADIUS disconnect to the controller/AP

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

    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }
    # On which port we have to send the CoA-Request ?
    my $nas_port = $self->{'_disconnectPort'} || '3799';
    my $coa_port = $self->{'_coaPort'} || '1700';
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = $self->radius_deauth_connection_info($send_disconnect_to);
        $connection_info->{nas_port} = $coa_port;

        $logger->debug("network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $self);

        my $node_info = node_view($mac);
        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;
        # Standard Attributes

        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
            'NAS-Port' => $node_info->{'last_port'},
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        # Roles are configured and the user should have one.
        # We send a regular disconnect if there is an open trapping security_event
        # to ensure the VLAN is actually changed to the isolation VLAN.
        if ( $self->shouldUseCoA({role => $role}) ) {
            $logger->info("Returning ACCEPT with Role: $role");
            my $vsa = [
                {
                vendor => "Cisco",
                attribute => "Cisco-AVPair",
                value => "audit-session-id=$node_info->{'sessionid'}",
                },
                {
                vendor => "Cisco",
                attribute => "Cisco-AVPair",
                value => "subscriber:command=reauthenticate",
                },
                {
                vendor => "Cisco",
                attribute => "Cisco-AVPair",
                value => "subscriber:reauthenticate-type=last",
                }
            ];
            $response = perform_coa($connection_info, $attributes_ref, $vsa);

        }
        else {
            my $connection_info = $self->radius_deauth_connection_info($send_disconnect_to);
            $connection_info->{nas_port} = $nas_port;
            $response = perform_disconnect($connection_info, $attributes_ref);
        }
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request on (".$self->{'_id'}."): $_");
        $logger->error("Wrong RADIUS secret or unreachable network device (".$self->{'_id'}.")... On some Cisco Wireless Controllers you might have to set disconnectPort=1700 as some versions ignore the CoA requests on port 3799") if ($_ =~ /^Timeout/);
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

=item parseRequest

Redefinition of pf::Switch::parseRequest due to specific attribute being used for webauth

=cut

sub parseRequest {
    my ( $self, $radius_request ) = @_;
    my $client_mac      = ref($radius_request->{'Calling-Station-Id'}) eq 'ARRAY'
                           ? clean_mac($radius_request->{'Calling-Station-Id'}[0])
                           : clean_mac($radius_request->{'Calling-Station-Id'});
    my $user_name       = $self->parseRequestUsername($radius_request);
    my $nas_port_type   = $radius_request->{'NAS-Port-Type'};
    my $port            = $radius_request->{'NAS-Port'};
    my $eap_type        = ( exists($radius_request->{'EAP-Type'}) ? $radius_request->{'EAP-Type'} : 0 );
    my $nas_port_id     = ( defined($radius_request->{'NAS-Port-Id'}) ? $radius_request->{'NAS-Port-Id'} : undef );
    my $session_id = $self->getCiscoAvPairAttribute($radius_request, 'audit-session-id');

    return ($nas_port_type, $eap_type, $client_mac, $port, $user_name, $nas_port_id, $session_id, $nas_port_id);
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

    # Cisco WLC uses external portal session ID handling process
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
    elsif ( defined($req->param('redirect_url')) ) {
        $redirect_url = $req->param('redirect_url');
    }
    elsif ( defined($r->headers_in->{'Referer'}) ) {
        $redirect_url = $r->headers_in->{'Referer'};
    }

    if($redirect_url !~ /^http/) {
        $redirect_url = "http://".$redirect_url;
    }

    %params = (
        session_id              => $session_id,
        switch_id               => $switch_id,
        client_mac              => $client_mac,
        client_ip               => $client_ip,
        redirect_url            => $redirect_url,
        synchronize_locationlog => $FALSE,
        connection_type         => $WEBAUTH_WIRELESS,
    );

    return \%params;
}


sub find_user_by_psk {
    my ($self, $radius_request, $args) = @_;
    my $cache_key = "MistAP::check_if_radius_request_psk_matches::PMK::";
    my $ssid = $radius_request->{'Eleven-EAPOL-SSID'};
    my $bssid = pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"Eleven-EAPOL-APMAC"}));
    my $username = pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{'Eleven-EAPOL-STMAC'}));
    my $anonce = pack('H*', pf::util::wpa::strip_hex_prefix($radius_request->{'Eleven-EAPOL-Anonce'}));
    my $snonce = pf::util::wpa::snonce_from_eapol_key_frame(pack("H*",pf::util::wpa::strip_hex_prefix($radius_request->{"Eleven-EAPOL-Frame-2"})));
    my $eapol_key_frame = pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"Eleven-EAPOL-Frame-2"}));

    return $self->iterate_user_by_psk($args, $radius_request, $ssid, $bssid, $username, $anonce, $snonce, $eapol_key_frame, $cache_key);
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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
