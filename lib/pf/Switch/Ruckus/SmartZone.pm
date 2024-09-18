package pf::Switch::Ruckus::SmartZone;

=head1 NAME

pf::Switch::Ruckus::SmartZone

=head1 SYNOPSIS

Implements methods to manage Ruckus SmartZone Wireless Controllers

=head1 BUGS AND LIMITATIONS

=head2 Unbound DPSK

- Is currently only supported for WPA2 which uses AES along with HMAC-SHA1
- Doesn't support 802.11r (Fast Transition). Make sure you disable this on your SmartZone.

=cut

use strict;
use warnings;

use base ('pf::Switch::Ruckus');

use Try::Tiny;
use pf::accounting qw(node_accounting_dynauth_attr);
use pf::constants;
use pf::util;
use LWP::UserAgent;
use pf::node;
use pf::security_event;
use pf::ip4log;
use JSON::MaybeXS qw(encode_json);
use pf::config qw (
    $WEBAUTH_WIRELESS
    $WIRELESS_MAC_AUTH
    %connection_type_to_str
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);
use pf::util::radius qw(perform_disconnect);
use pf::log;
use pf::util::wpa;
use Crypt::PBKDF2;
use Data::Dumper;

sub description { 'Ruckus SmartZone Wireless Controllers' }
use pf::SwitchSupports qw(
    WirelessMacAuth
    -WebFormRegistration
    WiredMacAuth
    WirelessDot1x
);

=over


=item parseExternalPortalRequest

Parse external portal request using URI and it's parameters then return an hash reference with the appropriate parameters

See L<pf::web::externalportal::handle>

=cut

sub parseExternalPortalRequest {
    my ( $self, $r, $req ) = @_;
    my $logger = $self->logger;

    # Using a hash to contain external portal parameters
    my %params = ();

    %params = (
        client_mac              => clean_mac($req->param('client_mac')),
        client_ip               => defined($req->param('uip')) ? $req->param('uip') : undef,
        ssid                    => $req->param('ssid'),
        redirect_url            => $req->param('url'),
        switch_id               => $req->param('nbiIP'),
        synchronize_locationlog => $TRUE,
        connection_type         => $WEBAUTH_WIRELESS,
    );

    return \%params;
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::RADIUS;
    # If an explicit supported deauth method is chosen, use it (HTTP/HTTPS). Needed for non-proxy RADIUS scenarios
    # where auth is via radius but COA/disconnect is via webservices.
    my %tech = (
        $SNMP::RADIUS => 'deauth',
        $SNMP::HTTP  => 'deauthenticateMacWebservices',
        $SNMP::HTTPS => 'deauthenticateMacWebservices'
    );
    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=head2 deauth

Deauthenticate a client using HTTP or RADIUS depending on the connection type

=cut

sub deauth {
    my ($self, $mac) = @_;
    my $logger = $self->logger;
    my $node_info = node_view($mac);
    if (isenabled($self->{_ExternalPortalEnforcement})) {
        if($node_info->{last_connection_type} eq $connection_type_to_str{$WEBAUTH_WIRELESS} || $node_info->{last_connection_type} eq $connection_type_to_str{$WIRELESS_MAC_AUTH}) {
            $self->deauthenticateMacWebservices($mac);
            return;
        }
    }
    $self->deauthenticateMacDefault($mac);
}

=head2 radiusDisconnect

Send a RADIUS disconnect to the controller/AP

=cut

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = $self->logger();

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS Disconnect-Request on $self->{'_id'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating");

    # Where should we send the RADIUS Disconnect-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    my $nas_ip_address = $self->{_switchIp};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }

    my $response;
    try {
        my $connection_info = $self->radius_deauth_connection_info($send_disconnect_to);

        if (defined($self->{'_disconnectPort'}) && $self->{'_disconnectPort'} ne '') {
            $connection_info->{'nas_port'} = $self->{'_disconnectPort'};
        }

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            # Use the IP address of the IP address at all times for the NAS-IP-Address even when sending to the controller
            'NAS-IP-Address' => $self->{_ip},
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        $response = perform_disconnect($connection_info, $attributes_ref);
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS Disconnect-Request: $_");
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

=head2 deauthenticateMacWebservices

Deauthenticate a MAC address using the Ruckus Northbound API

=cut

sub deauthenticateMacWebservices {
    my ($self, $mac) = @_;
    my $logger = $self->logger;
    my $controllerIp = $self->{_controllerIp} || $self->{_ip};
    my $webservicesPassword = $self->{_wsPwd};
    
    my $ucmac = uc $mac;
    my $ip = pf::ip4log::mac2ip($mac);
    my $node_info = node_view($mac);
    my $payload;

    my %baseCommand=(
        "Vendor"=> "ruckus",
        "RequestPassword"=> $webservicesPassword,
        "APIVersion"=> "1.0",
        "RequestCategory"=> "UserOnlineControl",
        "UE-MAC"=> $ucmac
    );
    # Add UE-IP if the ip of the device is known
    if ($ip) {
        $baseCommand{"UE-IP"} = $ip;
    }

    # If a webservice username is defined, add the key/value to the hash so that it appears on the json.
    # Otherwise, the "RequestUserName" field should not exist at all.
    # RequestUserName is used in "managed Service Provider" domains in SmartZone HighScale
    # See here: https://docs.commscope.com/bundle/sz-510-hotspot-wispr-guide-sz300vsz/page/GUID-160E59E5-5816-4618-B0D4-091FAA9AD49C.html#

    if (defined($self->{'_wsUser'}) && $self->{'_wsUser'} ne ''){
        $baseCommand{"RequestUserName"}=$self->{'_wsUser'};
    }

    if ( $node_info->{last_connection_type} eq $connection_type_to_str{$WIRELESS_MAC_AUTH} ){
        # For Ruckus smartzone, if using non-proxy RADIUS (MAC auth), the CoA/disconnect is via web services.
        # We need to invoke the "Disconnect" method every time we want the user to change status. For mac-auth, "Login" or "Logout" will not trigger a vlan change / reconnection
        # So basically, the user needs to configure the deauth method as http/https to force it to use "deauthenticateMacWebservices"
        # and once here, we check if the connection was WIRELESS_MAC_AUTH and trigger the logout webservice call
        # "Disconnect" also forces the ap to disociate the client which is what we want for unreg/role revaluation.
        $baseCommand{"RequestType"}="Disconnect";
    } elsif( $node_info->{status} eq "unreg" || security_event_count_reevaluate_access($mac) ){
        $baseCommand{"RequestType"}="Logout";
    } else {
        $baseCommand{"RequestType"}="Login";
        $baseCommand{"UE-Proxy"}="0";
        $baseCommand{"UE-Username"}=$ucmac;
        $baseCommand{"UE-Password"}=$ucmac;
    }
    $logger->debug(Dumper(\%baseCommand));
    $payload = encode_json(\%baseCommand);

    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->ssl_opts(verify_hostname => 0);
    my $transport = lc($self->{_wsTransport});
    
    # Ruckus smartzone supports webservices calls on port 9443 if using https or 9080 if http. Thus we chose accordingly
    # http allows for easier troubleshooting by doing a tcpdump and looking at the request / response on the wire.
    my $wsPort = "9443";
    if($transport eq "http") {
        $wsPort = "9080"
    }
    my $base_url = "$transport://$controllerIp:$wsPort"; 
    my $res = $ua->post("$base_url/portalintf", Content => $payload, "Content-Type" => "application/json");
    if($res->is_success) {
        $logger->info("Contacted Ruckus to perform deauthentication");
        $logger->debug("Got the following response: ".$res->decoded_content);
    }
    else {
        $logger->error("Failed to contact Ruckus for deauthentication: ".$res->status_line);
    }
}

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.
Overrides the default implementation to add the dynamic PSK

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

    if ($args->{profile}->dpskEnabled()) {
        if (defined($args->{owner}->{psk})) {
            $radius_reply_ref->{"Ruckus-DPSK"} = $self->generate_dpsk_attribute_value($args->{ssid}, $args->{owner}->{psk});
        } else {
            $radius_reply_ref->{"Ruckus-DPSK"} = $self->generate_dpsk_attribute_value($args->{ssid}, $args->{profile}->{_default_psk_key});
        }
    }
    
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=head2 generate_dpsk_attribute_value

Generates the RADIUS attribute value for Ruckus-DPSK given an SSID name and the passphrase

=cut

sub generate_dpsk_attribute_value {
    my ($self, $ssid, $dpsk) = @_;

    my $pbkdf2 = Crypt::PBKDF2->new(
        iterations => 4096,
        output_len => 32,
    );
     
    my $hash = $pbkdf2->PBKDF2_hex($ssid, $dpsk);
    return "0x00".$hash;
}


sub find_user_by_psk {
    my ($self, $radius_request) = @_;
    my ($status, $iter) = pf::dal::person->search(
        -where => {
            psk => {'!=' => [-and => '', undef]},
        },
    );

    my $matched = 0;
    my $pid;
    while(my $person = $iter->next) {
        get_logger->debug("User ".$person->{pid}." has a PSK. Checking if it matches the one in the packet");
        if($self->check_if_radius_request_psk_matches($radius_request, $person->{psk})) {
            get_logger->info("PSK matches the one of ".$person->{pid});
            $matched ++;
            $pid = $person->{pid};
        }
    }

    if($matched > 1) {
        get_logger->error("Multiple users use the same PSK. This cannot work with unbound DPSK. Ignoring it.");
        return undef;
    }
    else {
        return $pid;
    }
}

sub check_if_radius_request_psk_matches {
    my ($self, $radius_request, $psk) = @_;
    if($radius_request->{"Ruckus-DPSK-Cipher"} != 4) {
        get_logger->error("Ruckus-DPSK-Cipher isn't for WPA2 that uses AES and HMAC-SHA1. This isn't supported by this module.");
        return $FALSE;
    }

    my $pmk = $self->cache->compute(
        "Ruckus::SmartZone::check_if_radius_request_psk_matches::PMK::$radius_request->{'Ruckus-Wlan-Name'}+$psk", 
        {expires_in => '1 month', expires_variance => '.20'},
        sub { pf::util::wpa::calculate_pmk($radius_request->{"Ruckus-Wlan-Name"}, $psk) },
    );

    return pf::util::wpa::match_mic(
      pf::util::wpa::calculate_ptk(
        $pmk,
        pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"Ruckus-BSSID"})),
        pack("H*", $radius_request->{"User-Name"}),
        pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"Ruckus-DPSK-Anonce"})),
        pf::util::wpa::snonce_from_eapol_key_frame(pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"Ruckus-DPSK-EAPOL-Key-Frame"}))),
      ),      
      pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"Ruckus-DPSK-EAPOL-Key-Frame"})),
    );
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
            $SNMP::RADIUS => 'deauthenticateMacDefault',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    elsif ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacDefault',
        );
        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    else{
        $logger->error("This authentication mode is not supported");
    }

}

=item deauthenticateMacDefault

De-authenticate a MAC address from wire network (including 802.1x).

New implementation using RADIUS Disconnect-Request.

=cut

sub deauthenticateMacDefault {
    my ( $self, $ifindex, $mac, $is_dot1x ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    #Fetching the acct-session-id
    my $dynauth = node_accounting_dynauth_attr($mac);

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    return $self->radiusDisconnect(
        $mac, { 'User-Name' => $dynauth->{'username'} },
    );
}

=back

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
