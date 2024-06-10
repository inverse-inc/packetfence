package pf::task::fleetdm;

=head1 NAME

pf::task::fleetdm - Task for handling fleetdm events

=cut

=head1 DESCRIPTION

pf::task::fleetdm

=cut

use strict;
use warnings;
use pf::config qw(%Config);
use base 'pf::task';
use JSON;
use HTTP::Tiny;
use pf::CHI;
use pf::security_event;
use pf::log;

our $cache = pf::CHI->new(namespace => 'fleetdm');
our $fleetdm_host = "";
our $fleetdm_email = "";
our $fleetdm_password = "";
our $fleetdm_token = "";

my $logger = get_logger;
my $msg = "";

unless (exists($Config{fleetdm})) {
    $msg = "Unable to locate fleetdm config in pfconfig, section 'fleetdm' does not exist.";
    $logger->error($msg);
    return 1;
}

unless (exists($Config{fleetdm}->{host}) &&
    exists($Config{fleetdm}->{email}) &&
    exists($Config{fleetdm}->{password}) &&
    exists($Config{fleetdm}->{token})
) {
    $msg = "Invalid fleetdm config: 'host', 'email', 'password', 'token' should be defined in pf.conf. Did you manually changed the config file ?";
    $logger->error($msg);
    return 1;
}

$fleetdm_host = $Config{fleetdm}->{host};
$fleetdm_email = $Config{fleetdm}->{email};
$fleetdm_password = $Config{fleetdm}->{password};
$fleetdm_token = $Config{fleetdm}->{token};

if ($fleetdm_host eq "") {
    $msg = "Unable to find a valid 'host' value in FleetDM config.";
    $logger->error($msg);
    return 1;
}

if ($fleetdm_token eq "" &&
    ($fleetdm_email eq "" || $fleetdm_password eq "")
) {
    $msg = "Unable to obtain credentials for FleetDM. Either 'token' or 'email+password' is required.";
    $logger->error($msg);
    return 1;
}

sub doTask {
    my ($self, $args) = @_;

    unless (exists($args->{type}) && exists($args->{payload})) {
        $msg = "Unable to extract event 'type' or 'payload' from task.";
        $logger->error($msg);
        return 1;
    }

    if ($args->{type} eq "policy-violation") {
        handlePolicy($args->{payload});
    }

    if ($args->{type} eq "CVE") {
        handleCVE($args->{payload});
    }

    $msg = "Unknown event type: $args->{type}";
    $logger->error($msg);
    return 1;
}

sub handlePolicy {
    my ($payload) = @_;
    my $data = decode_json($payload);

    unless (exists($data->{timestamp}) && exists($data->{policy}) && exists($data->{hosts})) {
        $msg = "Invalid FleetDM event entry. Missing 'timestamp' or 'policy' or 'hosts'";
        $logger->error($msg);
        return 1;
    }

    unless (exists($data->{policy}->{id}) && exists($data->{policy}->{name}) && exists($data->{policy}->{query})) {
        $msg = "Invalid FleetDM policy violation event struct. Missing policy 'id' or 'name' or 'query'";
        $logger->error($msg);
        return 1;
    }

    my $policy_name = $data->{policy}->{name};

    my @hosts = @{$data->{hosts}};
    foreach my $host (@hosts) {
        unless (exists($host->{id}) && exists($host->{hostname})) {
            $msg = "Invalid host entry: missing either 'id' or 'hostname', please check fleetDM response. skipped.";
            $logger->error($msg);
            next;
        }

        my $host_id = $host->{id};
        my $primary_mac = cachedGetHostMac($host_id);

        if (defined($primary_mac) && $primary_mac ne "") {
            triggerPolicy($primary_mac, "FleetDM Policy Violation", $policy_name, $payload)
        }
    }
}

sub handleCVE {
    my ($payload) = @_;
    my $data = decode_json($payload);

    unless (exists($data->{timestamp}) && exists($data->{vulnerability})) {
        $msg = "Invalid FleetDM CVE event entry. Missing 'timestamp' or 'vulnerability'";
        $logger->error($msg);
        return 1;
    }

    unless (exists($data->{vulnerability}->{cve}) && exists($data->{vulnerability}->{hosts_affected})) {
        $msg = "Invalid FleetDM vulnerability CVE event struct. Missing 'cve' or 'hosts_affected'";
        $logger->error($msg);
        return 1;
    }

    my $cve = $data->{vulnerability}->{cve};

    my @hosts = @{$data->{vulnerability}->{hosts_affected}};
    foreach my $host (@hosts) {
        unless (exists($host->{id}) && exists($host->{display_name})) {
            $msg = "Invalid host entry: missing either 'id' or 'display_name', please check fleetDM response. skipped.";
            $logger->error($msg);
            next;
        }

        my $host_id = $host->{id};
        my $primary_mac = cachedGetHostMac($host_id);

        if (defined($primary_mac) && $primary_mac ne "") {
            triggerPolicy($primary_mac, "FleetDM CVE", $cve, $payload)
        }
    }
}

sub triggerPolicy() {
    my ($mac, $type, $tid, $json) = @_;
    security_event_trigger({
        mac     => $mac,
        type    => $type,
        tid     => $tid,
        'notes' => $json
    });
}

sub login {
    my $http = HTTP::Tiny->new;

    my $url = $fleetdm_host . "/api/v1/fleet/login";

    my $post_data = {
        email    => $fleetdm_email,
        password => $fleetdm_password,
    };
    my $json_post_data = encode_json($post_data);

    my $response = $http->post($url, {
        content => $json_post_data,
        headers => { 'Content-Type' => 'application/json' }
    });

    my $ret = "";
    if (!$response->{success}) {
        $msg = "unable to perform FleetDM API: " . $response->{reason};
        $logger->error($msg);
        return "";
    }

    if ($response->{status} != 200) {
        $msg = "error $response->{status} occured while login: $response->{reason}";
        $logger->error($msg);
        return "";
    }

    my $data = decode_json($response->{content});
    unless (defined($data->{token} && $data->{token} ne "")) {
        $msg = "invalid login FleetDM login response. 'token' not found.";
        $logger->error($msg);
        return "";
    }
    $ret = $data->{token};
    return $ret;
}

sub refreshToken {
    if ($Config{fleetdm}->{token} ne "") {
        $fleetdm_token = $Config{fleetdm}->{token};
        return;
    }

    my $token = $cache->get("fleetdm_api_token");
    if (defined($token) && $token ne "") {
        $fleetdm_token = $token;
        return;
    }

    $token = login();
    if (defined($token) && $token ne "") {
        $fleetdm_token = $token;
        $cache->set("fleetdm_api_token", $token, "5m");
        return;
    }
}

sub cachedGetHostMac {
    my ($host_id) = @_;
    my $cache_key = "fleetdm_host_id:" . $host_id;
    my $mac_address = $cache->get($cache_key);

    if (defined($mac_address) && $mac_address ne "") {
        return $mac_address;
    }

    $mac_address = getHostMac($host_id);
    if (defined($mac_address) && $mac_address ne "") {
        $cache->set($cache_key, $mac_address, "7d");
        return ($mac_address)
    }
    return ""
}

sub getHostMac {
    my ($host_id) = @_;

    refreshToken();
    unless (defined($fleetdm_token) && $fleetdm_token ne "") {
        return ""
    }

    my $url = $fleetdm_host . "/api/v1/fleet/hosts/" . $host_id;
    my $http = HTTP::Tiny->new;
    my $response = $http->get($url, {
        headers => { 'Authorization' => "Bearer " . $fleetdm_token }
    });

    my $ret = "";

    if (!$response->{success}) {
        $msg = "unable to perform API call '$url': $response->{reason}";
        $logger->error($msg);
        return "";
    }

    if ($response->{status} != 200) {
        $msg = "http error $response->{status} occured while performing API call '$url': $response->{reason}";
        $logger->error($msg);
        return "";
    }

    unless (exists($response->{content}) && $response->{content} ne "") {
        $msg = "invalid FleetDM host API call response, missing response body.";
        $logger->error($msg);
        return "";
    }

    my $data = decode_json($response->{content});

    unless (exists($data->{host}) && exists($data->{host}->{primary_mac})) {
        $msg = "unable to extract primary mac from host API response.";
        $logger->error($msg);
        return "";
    }
    return $data->{host}->{primary_mac};
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

