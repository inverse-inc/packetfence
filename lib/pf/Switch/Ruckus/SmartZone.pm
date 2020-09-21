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
    %connection_type_to_str
);
use pf::util::radius qw(perform_disconnect);
use pf::log;
use pf::util::wpa;
use Crypt::PBKDF2;

sub description { 'Ruckus SmartZone Wireless Controllers' }
use pf::SwitchSupports qw(
    WirelessMacAuth
    -WebFormRegistration
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
    my %tech = (
        $SNMP::RADIUS => 'deauth',
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
    my $node_info = node_view($mac);
    if ($node_info->{last_connection_type} eq $connection_type_to_str{$WEBAUTH_WIRELESS}) {
        $self->deauthenticateMacWebservices($mac);
    }
    else {
        $self->deauthenticateMacDefault($mac);
    }
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
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip($send_disconnect_to),
        };

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
    if($node_info->{status} eq "unreg" || security_event_count_reevaluate_access($mac)) {
        $payload = encode_json({
         "Vendor"=> "ruckus",
         "RequestPassword"=> $webservicesPassword,
         "APIVersion"=> "1.0",
         "RequestCategory"=> "UserOnlineControl",
         "RequestType"=> "Logout",
         "UE-IP"=> $ip,
         "UE-MAC"=> $ucmac
        });
    }
    else {
        $payload = encode_json({
         "Vendor"=> "ruckus",
         "RequestPassword"=> $webservicesPassword,
         "APIVersion"=> "1.0",
         "RequestCategory"=> "UserOnlineControl",
         "RequestType"=> "Login",
         "UE-IP"=> $ip,
         "UE-MAC"=> $ucmac,
         "UE-Proxy"=> "0",
         "UE-Username"=> $ucmac,
         "UE-Password"=> $ucmac
        });
    }
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->ssl_opts(verify_hostname => 0);
    my $res = $ua->post("https://$controllerIp:9443/portalintf", Content => $payload, "Content-Type" => "application/json");
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
            psk => { '!=', '', '!=', undef },
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

    return pf::util::wpa::match_mic(
      pf::util::wpa::calculate_ptk(
        pf::util::wpa::calculate_pmk($radius_request->{"Ruckus-Wlan-Name"}, $psk),
        pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"Ruckus-BSSID"})),
        pack("H*", $radius_request->{"User-Name"}),
        pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"Ruckus-DPSK-Anonce"})),
        pf::util::wpa::snonce_from_eapol_key_frame(pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"Ruckus-DPSK-EAPOL-Key-Frame"}))),
      ),      
      pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"Ruckus-DPSK-EAPOL-Key-Frame"})),
    );
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
