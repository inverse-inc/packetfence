package pf::Switch::Ruckus::Unleashed;

=head1 NAME

pf::Switch::Ruckus::Unleashed

=head1 SYNOPSIS

Implements methods to manage Ruckus Unleashed AP

=head1 BUGS AND LIMITATIONS

=cut

use strict;
use warnings;

use base ('pf::Switch::Ruckus::SmartZone');

use pf::constants;
use pf::util;
use pf::util::wpa;
use pf::node;
use pf::config qw (
    $WEBAUTH_WIRELESS
);
use pf::log;
use pf::util::radius qw(perform_disconnect);
use Try::Tiny;

sub description { 'Ruckus Unleashed' }
use pf::SwitchSupports qw(
    WirelessMacAuth
);

=over

=item supportsWebFormRegistration

Will be activated only if HTTP is selected as a deauth method

=cut

sub supportsWebFormRegistration {
    my ($self) = @_;
    return $TRUE;
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::RADIUS;
    my %tech = (
        $SNMP::RADIUS => 'deauthenticateMacRadius',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
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
    return $self->radiusDisconnect($mac);
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
            "Unable to perform RADIUS Disconnect-Request on $self->{'_ip'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating $mac");

    # Where should we send the RADIUS Disconnect-Request?
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
        my $connection_info = $self->radius_deauth_connection_info($send_disconnect_to);

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
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
        switch_id               => $req->param('sip'),
        switch_mac              => clean_mac($req->param('mac')),
        synchronize_locationlog => $TRUE,
        connection_type         => $WEBAUTH_WIRELESS,
    );

    return \%params;
}

sub getAcceptForm {
    my ( $self, $mac, $destination_url, $portalSession ) = @_;
    my $logger = $self->logger;
    $logger->debug("Creating web release form");

    my $node = node_view($mac);
    my $last_ssid = $node->{last_ssid};
    $mac =~ s/:/-/g;
    my $html_form = qq[
        <form name="weblogin_form" data-autosubmit="1000" method="POST" action="https://unleashed.ruckuswireless.com:9998/login">
            <input type="hidden" name="username" value="$mac">
            <input type="hidden" name="password" value="$mac">
        </form>
        <script src="/content/autosubmit.js" type="text/javascript"></script>
    ];

    $logger->debug("Generated the following html form : ".$html_form);
    return $html_form;
}

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.
Overrides the default implementation to add the dynamic PSK

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    $args->{'unfiltered'} = $TRUE;
    $args->{'compute_dpsk'} = $FALSE;
    $self->compute_action(\$args);
    my @super_reply = @{$self->SUPER::returnRadiusAccessAccept($args)};
    my $status = shift @super_reply;
    my %radius_reply = @super_reply;
    my $radius_reply_ref = \%radius_reply;
    return [$status, %$radius_reply_ref] if($status == $RADIUS::RLM_MODULE_USERLOCK);

    if ($args->{profile}->dpskEnabled()) {
        if (defined($args->{owner}->{psk})) {
            $radius_reply_ref->{"MS-MPPE-Recv-Key"} = $self->generate_dpsk_attribute_value($args->{ssid}, $args->{owner}->{psk});
        } else {
            $radius_reply_ref->{"MS-MPPE-Recv-Key"} = $self->generate_dpsk_attribute_value($args->{ssid}, $args->{profile}->{_default_psk_key});
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
    return "0x".$hash;
}

sub find_user_by_psk {
    my ($self, $radius_request, $args) = @_;
    my $pid;
    if($radius_request->{"Ruckus-DPSK-Cipher"} != 4) {
        get_logger->error("Ruckus-DPSK-Cipher isn't for WPA2 that uses AES and HMAC-SHA1. This isn't supported by this module.");
        return $pid;
    }
    my $cache_key =  "Ruckus::Unleashed::check_if_radius_request_psk_matches::PMK::";
    my $ssid = $radius_request->{'Ruckus-SSID'};
    my $bssid = pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"Ruckus-BSSID"}));
    my $username = pack("H*", $radius_request->{'User-Name'});
    my $anonce = pack('H*', pf::util::wpa::strip_hex_prefix($radius_request->{'Ruckus-DPSK-Anonce'}));
    my $snonce = pf::util::wpa::snonce_from_eapol_key_frame(pack("H*",pf::util::wpa::strip_hex_prefix($radius_request->{"Ruckus-DPSK-EAPOL-Key-Frame"})));
    my $eapol_key_frame = pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"Ruckus-DPSK-EAPOL-Key-Frame"}));

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
