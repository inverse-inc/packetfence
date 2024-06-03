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



=head2 doTask


=cut

our $fleetdm_host = "";
our $fleetdm_email = "";
our $fleetdm_password = "";
our $fleetdm_token = "";

# our $CHI_CACHE = CHI->new(driver => 'RawMemory', datastore => {});
our $cache = pf::CHI->new(namespace => 'fleetdm_api', driver => 'File');

sub doTask {
    my ($self, $args) = @_;
    print("---- in processing fleetdm \n");

    unless (exists($Config{fleetdm})) {
        print("unable to locate fleetdm config, task skipped")
    }
    $fleetdm_host = $Config{fleetdm}->{host};
    $fleetdm_email = $Config{fleetdm}->{email};
    $fleetdm_password = $Config{fleetdm}->{password};
    $fleetdm_token = $Config{fleetdm}->{token};

    if ($fleetdm_token eq "") {
        $fleetdm_token = login($fleetdm_host, $fleetdm_email, $fleetdm_password);
    }

    my $type = $args->{type};
    my $payload = $args->{payload};

    my $data = decode_json($payload);

    my $timestamp = $data->{timestamp};
    my $policy = $data->{policy};
    my $policy_id = $data->{policy}->{id};
    my $policy_name = $data->{policy}->{name};
    my $policy_query = $data->{policy}->{query};

    # todo clean up
    print("---- timestamp: ", $timestamp, "\n");
    print("---- policy_id: ", $policy_id, "\n");
    print("---- policy_name: ", $policy_name, "\n");

    my @hosts = @{$data->{hosts}};
    foreach my $host (@hosts) {
        my $host_id = $host->{id};
        my $hostname = $host->{hostname};

        print("  ---- host_id: ", $host_id, "\n");
        print("  ---- hostname: ", $hostname, "\n");

        my $primary_mac = cachedGetHostInfo($host_id);
        print("  ---- mac is: ", $primary_mac);

        if (defined($primary_mac) && $primary_mac ne "") {
            triggerPolicy($primary_mac, "Custom", $policy_name)
        }
    }
}

sub triggerPolicy() {
    my ($mac, $type, $tid) = @_;
    security_event_trigger({ mac => $mac, tid => $tid, type => $type });
}

sub login {
    my ($host, $email, $password) = @_;
    my $http = HTTP::Tiny->new;

    my $url = $host . "/api/v1/fleet/login";

    my $post_data = {
        email    => $email,
        password => $password,
    };
    my $json_post_data = encode_json($post_data);

    my $response = $http->post($url, {
        content => $json_post_data,
        headers => { 'Content-Type' => 'application/json' }
    });

    my $ret = "";
    if ($response->{success} && $response->{status} == 200) {
        my $data = decode_json($response->{content});
        $ret = $data->{token};
    }
    else {
        print("error :", $response->{status}, " ", $response->{reason});
    }
    return $ret;
}

sub getHostInfo {
    my ($host_id) = @_;

    my $url = $fleetdm_host . "/api/v1/fleet/hosts/" . $host_id;

    my $http = HTTP::Tiny->new;
    my $response = $http->get($url, {
        headers => { 'Authorization' => "Bearer " . $fleetdm_token }
    });

    my $ret = "";
    if ($response->{success} && $response->{status} == 200) {
        my $data = decode_json($response->{content});
        $ret = $data->{host}->{primary_mac}
    }
    else {
        print("error :", $response->{status}, " ", $response->{reason});
    }
    return $ret;
}

sub cachedGetHostInfo {
    # todo remove debug info after demo
    my ($host_id) = @_;
    my $cache_key = "fleetdm_host_id:" . $host_id;
    my $mac_address = $cache->get($cache_key);

    if (defined($mac_address) && $mac_address ne "") {
        print("    ---- cache hit: ", "$mac_address\n");
        return $mac_address;
    }

    print("    ---- cache miss: trying to invoke fleetDM API\n");
    $mac_address = getHostInfo($host_id);
    if (defined($mac_address) && $mac_address ne "") {
        print("        ---- got host info from API, mac address is: $mac_address\n");
        $cache->set($cache_key, $mac_address, '10m');
        return ($mac_address)
    }
    return ""
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

