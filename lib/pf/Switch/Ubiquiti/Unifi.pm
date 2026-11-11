package pf::Switch::Ubiquiti::Unifi;

=head1 NAME

pf::Switch::Ubiquiti::Unifi

=head1 SYNOPSIS

The pf::Switch::Ubiquiti::Unifi module implements an object oriented interface to
manage Unifi  controllers

=head1 STATUS

Developed and tested on Unifi controller version 5.4.14 with a UniFi AP-AC-Pro running 3.4.14.3413

=head1 BUGS AND LIMITATIONS

=cut

use strict;
use warnings;

use base ('pf::Switch');

use DateTime;
use DateTime::Format::MySQL;
use POSIX ();
use pf::security_event qw(security_event_count_reevaluate_access);
use pf::constants::node qw($STATUS_UNREGISTERED);
use pf::file_paths qw($var_dir);
use pf::constants;
use pf::util;
use pf::node;
use pf::config qw(
    %connection_type_to_str
    $MAC
    $SSID
    $WEBAUTH_WIRELESS
);
use pf::locationlog;
use Try::Tiny;
use JSON::MaybeXS;
use MIME::Base64 ();
use IO::Socket::SSL ();
use pf::config::cluster;

sub description { 'Unifi Controller' }

=head1 SUBROUTINES

=cut

# CAPABILITIES
# access technology supported
use pf::SwitchSupports qw(
    ExternalPortal
    WirelessDot1x
    WirelessMacAuth
    Flow
);


our $DEFAULT_HTTP_PORT = 80;
our $DEFAULT_HTTPS_PORT = 443;
# UniFi OS Server (the software controller) listens on 11443 by default
our $UOS_SERVER_PORT = 11443;
# Timeout of the 11443 probe, so a controller without UniFi OS Server doesn't
# wait the full request timeout there before trying its old port
our $UOS_SERVER_PROBE_TIMEOUT = 3;
our $ALT_DEFAULT_PORT = 8443;

# Where each controller was found, so the port probe runs once per process and
# not on every command: "transport://ip" => { url => ..., unifi_os => 0|1 }
our %DETECTED_CONTROLLERS;

# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=head2 getVersion

Obtain image version information from switch

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
    if ( $sysDescr =~ m/V(\d{1}\.\d{2}\.\d{2})/ ) {
        return $1;
    } elsif ( $sysDescr =~ m/Version (\d+\.\d+\([^)]+\)[^,\s]*)(,|\s)+/ ) {
        return $1;
    } else {
        return $sysDescr;
    }
}

=head2 synchronize_locationlog

Override the Switch method so that the controller IP is inserted as the switch_ip in the locationlog

=cut

sub synchronize_locationlog {
    my ( $self, $ifIndex, $vlan, $mac, $voip_status, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role, $ifDesc) = @_;
    # Set the switch IP to the controller IP so that the locationlog entry has the proper switch_ip entry
    $self->{_ip} = $self->returnSwitchIP($self->{_switchMac}) if ($connection_type == $WEBAUTH_WIRELESS);
    $self->SUPER::synchronize_locationlog($ifIndex, $vlan, $mac, $voip_status, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role, $ifDesc);
}

=head2 returnSwitchIP

return the SwitchIP

=cut

sub returnSwitchIP {
    my ($self, $mac) = @_;
    if (my $ip = $self->getAccessPointMACIP($mac)) {
        return $ip;
    }
    if (ref($self)) {
        if (exists($self->{_controllerIp}) && $self->{_controllerIp} ne '') {
            return $self->{_controllerIp};
        }
    }
    return undef;
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

    my $client_ip = defined($r->headers_in->{'X-Forwarded-For'}) ? $r->headers_in->{'X-Forwarded-For'} : $r->connection->remote_ip;
    my @proxied_ip = split(',', $client_ip);
    $client_ip = $proxied_ip[0];

    %params = (
        switch_id               => $req->param('ap'),
        switch_mac              => $req->param('ap'),
        switch_ip               => $self->returnSwitchIP($req->param('ap')),
        client_mac              => clean_mac($req->param('id')),
        client_ip               => $client_ip,
        ssid                    => $req->param('ssid'),
        redirect_url            => $req->param('url'),
        status_code             => '200',
        synchronize_locationlog => $TRUE,
        connection_type         => $WEBAUTH_WIRELESS,
    );

    return \%params;
}

=head2 deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::HTTP;
    my %tech = (
        $SNMP::HTTP  => '_deauthenticateMacWithHTTP',
        $SNMP::RADIUS => 'deauthenticateMacRadius',
    );

    if ($connection_type == $WEBAUTH_WIRELESS) {
        $method = $SNMP::HTTP;
    }
    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=head2 _connect

Return the connection to the controller

=cut

sub _connect {
    my ($self) = @_;
    my $logger = $self->logger;

    my $controllerIp = $self->{_controllerIp};
    my $transport = lc($self->{_wsTransport});
    my $username = $self->{_wsUser};
    my $password = $self->{_wsPwd};

    my $ua = LWP::UserAgent->new();
    $ua->cookie_jar({ file => "$var_dir/run/.ubiquiti.cookies.txt", autosave => 1, ignore_discard => 1});
    # Controllers usually have a self-signed certificate, so it is only checked
    # when wsVerifyCertificate is enabled: then it must be issued by a trusted CA
    # for the controller address. Recent IO::Socket::SSL no longer infers
    # SSL_verify_mode from verify_hostname, so both are given.
    if (isenabled($self->{_wsVerifyCertificate})) {
        $ua->ssl_opts(verify_hostname => 1, SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_PEER());
    } else {
        $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE());
    }
    $ua->timeout(10);
    $ua->default_header('Content-Type' => "application/json");

    my $controllerPort = $self->{_controllerPort};
    my $base_url = "$transport://$controllerIp";
    my $login_path = "/api/login";
    my $api_prefix = "";
    my $unifi_os = $FALSE;
    my $url;
    my $response;

    # UniFi OS controllers (UDM, Cloud Key Gen2, UniFi OS Server, ...) answer
    # /proxy/network/status on 443, or 11443 for UniFi OS Server. Probe the
    # candidates in order unless a controller port is configured. A 401 is a
    # healthy controller asking for a login, so it counts as found.
    # A controller already found by this process is tried first, the full probe
    # only runs again when it stops answering there.
    my $detected_key = $controllerPort ? undef : $base_url;
    my $detected = defined $detected_key ? $DETECTED_CONTROLLERS{$detected_key} : undef;
    if ($detected && !$detected->{unifi_os}) {
        $logger->debug("Unifi controller previously found on $detected->{url} (not UniFi OS)");
    } elsif ($detected) {
        $url = $detected->{url};
        $response = $ua->get($url."/proxy/network/status");
        if ($response->code == 401 || $response->is_success) {
            $unifi_os = $TRUE;
        } else {
            $logger->info("Unifi controller no longer answers on $url (" . $response->status_line . "), probing it again");
            delete $DETECTED_CONTROLLERS{$detected_key};
            $detected = undef;
        }
    }

    my @uos_ports = $detected ? ()
                  : $controllerPort ? ($controllerPort)
                  : ($transport eq 'http' ? ($DEFAULT_HTTP_PORT) : ($DEFAULT_HTTPS_PORT, $UOS_SERVER_PORT));
    foreach my $port (@uos_ports) {
        $url = "${base_url}:${port}";
        if (!$controllerPort && $port == $UOS_SERVER_PORT) {
            my $timeout = $ua->timeout($UOS_SERVER_PROBE_TIMEOUT);
            $response = $ua->get($url."/proxy/network/status");
            $ua->timeout($timeout);
        } else {
            $response = $ua->get($url."/proxy/network/status");
        }
        if ($response->code == 401 || $response->is_success) {
            # UniFi OS redirects http to https: keep talking to where the probe
            # ended up, as long as it is the same host over https, since the
            # login with the controller password is posted there
            my $final = $response->request->uri;
            if ($final->scheme ne $transport || $final->port != $port || lc($final->host) ne lc($controllerIp)) {
                if (lc($final->host) ne lc($controllerIp) || ($final->scheme ne $transport && $final->scheme ne 'https')) {
                    $logger->warn("Unifi controller $url redirected to " . $final->scheme . "://" . $final->host_port . ", which is not the same host over https: ignoring it");
                    next;
                }
                $url = $final->scheme . "://" . $final->host_port;
                $logger->info("Unifi controller redirected $base_url:$port to $url, using it");
            }
            $unifi_os = $TRUE;
            $DETECTED_CONTROLLERS{$detected_key} = { url => $url, unifi_os => $TRUE } if defined $detected_key;
            last;
        }
        $self->_warn_certificate_failure($response, $url);
        $logger->debug("No UniFi OS controller on $url (" . $response->status_line . ")");
    }

    my $cookie_invalid = $FALSE;
    if ($unifi_os) {
        $login_path = "/api/auth/login";
        $api_prefix = "/proxy/network";
        $cookie_invalid = ($response->code == 401) ? $TRUE : $FALSE;
        # An authenticated session gets its token with the status response; a
        # 401 carries nothing and the login below will provide it. A session
        # without any token cannot send commands, so log in again to get one.
        if (!$cookie_invalid && !$self->_set_unifi_os_csrf_token($ua, $response, $TRUE)) {
            $logger->info("No CSRF token for the current Unifi controller session, logging in again");
            $cookie_invalid = $TRUE;
        }
    } else {
        # Old controller on port 8443 unless a controller port is configured
        $url = "${base_url}:" . ($controllerPort || $ALT_DEFAULT_PORT);
        # Check if cookie is still valid for old controller
        $response = $ua->get($url."/api/self");
        $self->_warn_certificate_failure($response, $url);
        $cookie_invalid = ($response->code == 401) ? $TRUE : $FALSE;
        if (defined $detected_key) {
            if ($cookie_invalid || $response->is_success) {
                $DETECTED_CONTROLLERS{$detected_key} = { url => $url, unifi_os => $FALSE };
            } else {
                # Nothing answered: probe everything again next time
                delete $DETECTED_CONTROLLERS{$detected_key};
            }
        }
    }
    if ($cookie_invalid) {
        # Clear old cookies before re-authenticating to avoid sending invalid session
        $ua->cookie_jar->clear();
        $response = $ua->post($url.$login_path, Content => encode_json({ username => $username, password => $password, remember => "true" }));

        unless($response->is_success) {
            my $hint = ($unifi_os && $response->code == 403) ? " (a 403 on $login_path means the credentials are refused: use a local controller admin account)" : "";
            $logger->error("Can't login on the Unifi controller ($url$login_path): ".$response->status_line.$hint);
            die;
        }
        $self->_set_unifi_os_csrf_token($ua, $response) if $unifi_os;
    }
    return ($ua, $url.$api_prefix);
}

=head2 _warn_certificate_failure

Log why the controller cannot be reached when its certificate is refused, which
only happens with wsVerifyCertificate enabled.

=cut

sub _warn_certificate_failure {
    my ($self, $response, $url) = @_;
    return unless $response->code == 500 && $response->status_line =~ /certificate verify failed/i;
    $self->logger->warn("The certificate of the Unifi controller on $url is not valid for this address or not issued by a trusted authority (" . $response->status_line . "). Disable 'Verify Certificate' (wsVerifyCertificate) for a controller with a self-signed certificate");
}

=head2 _set_unifi_os_csrf_token

UniFi OS refuses state-changing requests (POST/PUT/DELETE) that do not carry the
X-CSRF-Token header matching the session, answering 403 without any body. The
token comes with the login response (x-csrf-token / x-updated-csrf-token
header), is also present on the responses of an authenticated session, and is
embedded in the TOKEN session cookie (the csrfToken claim of its JWT). Take it
from wherever it is, send it on every request, and follow the controller when
it rotates it.

Return true when a token was found. With $quiet, a missing token is left to the
caller to handle instead of being warned about.

=cut

sub _set_unifi_os_csrf_token {
    my ($self, $ua, $response, $quiet) = @_;
    my $logger = $self->logger;

    my $token = $response->header('x-updated-csrf-token') || $response->header('x-csrf-token');
    if (!$token) {
        # Fall back to the csrfToken claim of the TOKEN cookie (a JWT). The jar
        # file is shared by every Unifi controller, so only take the cookie the
        # jar would send to this one.
        my $probe = HTTP::Request->new(GET => $response->request->uri);
        $ua->cookie_jar->add_cookie_header($probe);
        my ($val) = ($probe->header('Cookie') // '') =~ /(?:^|;\s*)TOKEN=([^;\s]+)/;
        my ($payload) = defined $val ? (split /\./, $val)[1] : ();
        if (defined $payload) {
            $payload =~ tr{-_}{+/};
            $payload .= '=' x ((4 - length($payload) % 4) % 4);
            my $claims = eval { decode_json(MIME::Base64::decode_base64($payload)) };
            $token = $claims->{csrfToken} if ref($claims) eq 'HASH' && $claims->{csrfToken};
        }
    }
    if (!$token) {
        $logger->warn("No CSRF token found in the Unifi controller response nor in its session cookie: POST commands will likely be refused") unless $quiet;
        return $FALSE;
    }
    $ua->default_header('X-CSRF-Token' => $token);
    $logger->debug("Using the Unifi controller CSRF token for this session");

    # The controller may hand out a rotated token on any response. Replace only
    # this handler: the cookie jar has its own response_done handler.
    $ua->set_my_handler(response_done => sub {
        my ($res, $agent) = @_;
        my $updated = $res->header('x-updated-csrf-token') || $res->header('x-csrf-token');
        $agent->default_header('X-CSRF-Token' => $updated) if $updated;
        return;
    }, owner => __PACKAGE__ . '::csrf_token');
    return $TRUE;
}


=head2 guestAuthorizationMinutes

Minutes of guest authorization to request from the controller for a node
with the given unregistration date (MySQL datetime, server local time).

Without "minutes" the controller applies its own guest default (4 or 8 hours
depending on the setup), which cut off registered nodes that have no
unregistration date (#9203). Such nodes get
$GUEST_AUTHORIZATION_MINUTES_NO_EXPIRY; a date in the past gets 1 minute
(delta_ms is an absolute difference, so an expired date used to grant as
much access as it was late).

Returns undef when the date can't be parsed: the controller default then
applies.

=cut

our $GUEST_AUTHORIZATION_MINUTES_NO_EXPIRY = 525600; # one year

sub guestAuthorizationMinutes {
    my ($self, $unregdate, $now_epoch) = @_;
    $now_epoch //= time;
    if (!defined($unregdate) || $unregdate eq '' || $unregdate eq $ZERO_DATE) {
        return $GUEST_AUTHORIZATION_MINUTES_NO_EXPIRY;
    }
    # mktime rather than DateTime->set_time_zone('local'), which dies on a
    # time skipped by a DST change
    my $end = eval {
        my $dt = DateTime::Format::MySQL->parse_datetime($unregdate);
        POSIX::mktime($dt->second, $dt->minute, $dt->hour, $dt->day, $dt->month - 1, $dt->year - 1900, 0, 0, -1);
    };
    if (!defined($end)) {
        $self->logger->warn("Unable to parse the unregistration date '$unregdate', not sending a guest authorization duration: the controller default applies");
        return undef;
    }
    my $seconds_left = $end - $now_epoch;
    return 1 if $seconds_left <= 0;
    # round up: a partial minute left still needs access
    return int(($seconds_left + 59) / 60);
}

=head2 _deauthenticateMacWithHTTP

Enable or disable the access of a user (portal vs no portal) using an HTTP webservices call

=cut

sub _deauthenticateMacWithHTTP {
    my ( $self, $mac ) = @_;
    my $logger = $self->logger;

    my $node_info = node_view($mac);

    my %site_opts;
    my $found = $FALSE;

    my $args = {
        mac => $mac,
    };
    my $command;
    unless ($node_info->{status} eq $STATUS_UNREGISTERED || security_event_count_reevaluate_access($mac))  {
        $command = "authorize-guest";

        my $minutes = $self->guestAuthorizationMinutes($node_info->{unregdate});
        $args->{minutes} = $minutes if defined($minutes);
    } else {
        $command = "unauthorize-guest";
    }

    $command = "kick-sta" if ($node_info->{last_connection_type} ne $connection_type_to_str{$WEBAUTH_WIRELESS});
    
    $args->{cmd} = $command;

    my ($ua, $base_url)  = $self->_connect();

    my $response = $ua->get("$base_url/api/self/sites");

    if ($response->code == 404) {
        $response = $ua->get("$base_url/proxy/network/api/self/sites");
    }

    unless($response->is_success) {
        $logger->error("Can't have the site list from the Unifi controller: ".$response->status_line);
        return;
    }

    $logger->info("Switching status on the Unifi controller using command $command");

    my $sites = decode_json($response->decoded_content());

    foreach my $entry (@{$sites->{'data'}}) {
        $response = $ua->get("$base_url/api/s/$entry->{'name'}/stat/sta/$mac");
        if ($response->is_success) {
            $found = $TRUE;
            $site_opts{'name'} = $entry->{'name'};
            $site_opts{'desc'} = $entry->{'desc'};
            $logger->info("Found site: $site_opts{'desc'}");
            last;
        }
        $logger->debug("$mac not found on site $entry->{'desc'}: ".$response->status_line);
    }
    $logger->info("$mac not found on any site of the Unifi controller, sending $command to every site") unless $found;

    # There are two flows of deauth that will be attempted

    # First...
    # The first one is doing the deauth on the site itself without adding the ap_mac in it which will grant access on the AP the user is currently connected on
    # This only happens if we found where the client is connected
    # This supports access points defined via IP or CIDR in the PF configuration
    if ($found) {
        $response = $ua->post("$base_url/api/s/$site_opts{'name'}/cmd/stamgr", Content => encode_json($args));
        if ($response->is_success) {
            $logger->info("Deauth on site: $site_opts{'desc'}");
        } else {
            $logger->error("Command $command refused by the Unifi controller for $mac on site $site_opts{'desc'}: ".$response->status_line);
        }
    } else {
        foreach my $entry (@{$sites->{'data'}}) {
            $response = $ua->post("$base_url/api/s/$entry->{'name'}/cmd/stamgr", Content => encode_json($args));
            if ($response->is_success) {
                $logger->trace("Deauth on site: $entry->{'desc'}");
            } else {
                $logger->warn("Command $command refused by the Unifi controller for $mac on site $entry->{'desc'}: ".$response->status_line);
            }
        }
    }

    # Second...
    # We go through all the entries in switches.conf and find the ones that are MAC address based and part of the group of the current entry
    # For each of these, we send the command including the AP MAC which allows to grant access to the device on all APs of that site (to enable web-auth roaming)
    # If we don't know which site the endpoint is connected on, we send the messages to all the sites
    # This only supports entries defined by their MAC address in switches.conf
    tie my %SwitchConfig, 'pfconfig::cached_hash', "config::Switch($host_id)";
    my $count = 0;
    foreach my $switch_id (keys(%SwitchConfig)) {
        my $switch = $SwitchConfig{$switch_id};
        # If the other switch is a MAC based entry and an Ubiquiti AP and is part of the same AP group, then we'll send the deauth
        if(valid_mac($switch_id) && $switch->{type} eq $self->{_type} && $switch->{group} eq $self->{_group}) {
            $count++;
            $args->{ap_mac} = $switch_id;
            if ($found) {
                $response = $ua->post("$base_url/api/s/$site_opts{'name'}/cmd/stamgr", Content => encode_json($args));
                if ($response->is_success) {
                    $logger->trace("Deauth on site: $site_opts{'desc'} for $switch_id");
                } else {
                    $logger->warn("Command $command refused by the Unifi controller for $mac on site $site_opts{'desc'} via $switch_id: ".$response->status_line);
                }
            } else {
                foreach my $entry (@{$sites->{'data'}}) {
                    $response = $ua->post("$base_url/api/s/$entry->{'name'}/cmd/stamgr", Content => encode_json($args));
                    if ($response->is_success) {
                        $logger->trace("Deauth on site: $entry->{'desc'} for $switch_id");
                    } else {
                        $logger->warn("Command $command refused by the Unifi controller for $mac on site $entry->{'desc'} via $switch_id: ".$response->status_line);
                    }
                }
            }
        }
    }
    if($count > 0) {
        $logger->info("Deauth on $count access points");
    }

}

=item getAccessPointMACIP

get IP associated to a AP MAC

=cut


sub getAccessPointMACIP {
    my ($self, $mac) = @_;
    my $logger = $self->logger;

    my $cache = $self->cache_distributed;

    my $result = $cache->get("Ubiquiti-" .$mac);

    return $result if defined($result);

    return $FALSE;
}

=item populateAccessPointMACIP

Fetch all the AP on the controller and cache it

=cut


sub populateAccessPointMACIP {
    my ($self) = @_;
    my $logger = $self->logger;

    my $cache = $self->cache_distributed;

    my $controllerIp = $self->{_controllerIp};
    my $transport = lc($self->{_wsTransport});
    my $username = $self->{_wsUser};
    my $password = $self->{_wsPwd};

    my ($ua, $base_url)  = $self->_connect();
    my $url = "$base_url/api/self/sites";

    my $response = $ua->get($url);

    if ($response->code == 404) {
        $url = "$base_url/proxy/network/api/self/sites";
        $response = $ua->get($url);
    }

    unless($response->is_success) {
        $logger->error("Can't have the site list from the Unifi controller ($url): ".$response->status_line);
        return;
    }

    local $@;
    my $content = $response->decoded_content();
    my $json_data = eval { decode_json($content)};
    if ($@) {
        $logger->error("Error parsing response from $url: $content");
        return
    }

    foreach my $entry (@{$json_data->{'data'}}) {
        $response = $ua->get("$base_url/api/s/$entry->{'name'}/stat/device/");
        unless($response->is_success) {
            $logger->error("Can't have the site list from the Unifi controller: ".$response->status_line);
            return;
        }
        my $json_data_ap = decode_json($response->decoded_content());
        my %exists;
        foreach my $AP (@{$json_data_ap->{'data'}}) {
            $cache->set("Ubiquiti-" . $AP->{'mac'} , $AP->{'ip'} );
            $exists{$AP->{'mac'}} = $TRUE;
            foreach my $vap (@{$AP->{'vap_table'}}) {
                $cache->set("Ubiquiti-" . $vap->{'bssid'},  $AP->{'ip'} ) unless $exists{$vap->{'bssid'}};
                $exists{$vap->{'bssid'}} = $TRUE;
            }
        }
    }
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

    if (!$self->hasRadiusSecret()) {
        $logger->warn(
            "Unable to perform RADIUS Disconnect-Request on $self->{'_ip'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating $mac");

    # Where should we send the RADIUS Disconnect-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};

    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $locationlog = locationlog_view_open_mac($mac);
        # The locationlog can already be closed (e.g. the node was deleted), use the last known AP
        if (!$locationlog || !$locationlog->{'switch_mac'}) {
            my $last = locationlog_last_entry_mac(clean_mac($mac));
            $locationlog = $last if ($last && $last->{'switch_mac'});
        }
        my $connection_info = $self->radius_deauth_connection_info($send_disconnect_to);

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        my $original_mac = $mac;
        $mac = uc($mac);
        $mac =~ s/:/-/g;
        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
        };
        my $nasID = $locationlog ? $locationlog->{'switch_mac'} : undef;
        if (defined($nasID) && $nasID ne '') {
            $nasID =~ s/://g;
            $attributes_ref->{'NAS-Identifier'} = $nasID;
        } else {
            # An empty NAS-Identifier makes the AP drop the request ("parse DA message failed")
            $logger->warn("No AP MAC address found in the locationlog of $original_mac, sending the Disconnect-Request without NAS-Identifier");
        }

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        $response = $self->handleRadiusDisconnect($connection_info, $attributes_ref);
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


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
