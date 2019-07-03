package pf::provisioner::sentinelone;
=head1 NAME

pf::provisioner::sentinelone

=cut

=head1 DESCRIPTION

Allows to validate installation and compliance using the SentinelOne API

=cut

use strict;
use warnings;
use Moo;
extends 'pf::provisioner';

use JSON::MaybeXS qw(decode_json encode_json);
use pf::constants;
use pf::util qw(clean_mac);
use LWP::UserAgent;
use HTTP::Request::Common;
use pf::log;
use pf::constants::provisioning qw($SENTINEL_ONE_TOKEN_EXPIRY $NOT_COMPLIANT_FLAG);
use pf::node;
use pf::enforcement;
use List::MoreUtils qw(any);
use pf::error;

=head1 Atrributes

=head2 api_username

Username to connect to the API

=cut

has api_username => (is => 'rw');

=head2 api_password

Password to connect to the API

=cut

has api_password => (is => 'rw');

=head2 host

Host of the SentinelOne web API

=cut

has host => (is => 'rw', required => $TRUE);

=head2 port

Port to connect to the SentinelOne web API

=cut

has port => (is => 'rw', default =>  sub { $HTTPS_PORT } );

=head2 protocol

Protocol to connect to the SentinelOne web API

=cut

has protocol => (is => 'rw', default => sub { $HTTPS } );

=head2 win_agent_download_uri

URI to download the windows agent

=cut

has win_agent_download_uri => (is => 'rw');

=head2 mac_osx_agent_download_uri

URI to download the Mac OSX agent

=cut

has mac_osx_agent_download_uri => (is => 'rw');

=head2 api_version

The API version to use

=cut

has api_version => (is => 'lazy');

=head1 Methods

=head2 _token_cache_key

The cache key for the token

=cut
sub _token_cache_key {
    my ($self) = @_;
    return $self->id."-token";
}

=head2 supportsPolling

This provisioner supports polling at a regular interval

=cut

sub supportsPolling {$TRUE}

=head2 token

Get the authentication token from the cache or fetch it using the API

=cut

sub token {
    my ($self) = @_;
    my $logger = get_logger();
    return $self->cache->compute($self->_token_cache_key, sub { $self->fetch_token() }, { expires_in => $SENTINEL_ONE_TOKEN_EXPIRY });
}

=head2 fetch_token

Fetch the authentication token on the SentinelOne API

=cut

sub fetch_token {
    my ($self) = @_;
    my $logger = get_logger();

    my $ua = LWP::UserAgent->new();

    my $req = HTTP::Request::Common::POST($self->_build_uri("login"), Content => encode_json({username => $self->api_username, password => $self->api_password}), 'Content-Type' => 'application/json');

    my $res = $ua->request($req);

    print $res->decoded_content;

    if($res->is_success){
        my $info = $self->_extract_data_from_response(decode_json($res->decoded_content));
        my $token = $info->{token};
        $logger->debug("Got token : $token");
        return $token;
    }
    else {
        $logger->error("Failed to get token from SentinelOne API : ".$res->status_line);
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
}

=head2 fetch_agent_info

Fetch the agent information for a MAC address

=cut

sub fetch_agent_info {
    my ($self, $mac) = @_;
    my $logger = get_logger;
    my $uri = $self->_build_uri("agent_info") . "?query=$mac";
    my $req = HTTP::Request::Common::GET($uri);
    my $res = $self->execute_request($req);
    if($res == $pf::provisioner::COMMUNICATION_FAILED){
        return $res;
    }
    else {
        my $devices = $self->_extract_data_from_response(decode_json($res->decoded_content())); 
        if(scalar(@$devices) == 0){
            $logger->info("Cannot find $mac on Sentinel One server");
            return $FALSE;
        }
        elsif(scalar(@$devices) == 1){
            $logger->info("$mac was found on SentinelOne server");
            my $device = $devices->[0];
            return $device;
        }
        else {
            $logger->error("Device $mac returned multiple results in Sentinel One. This is not normal. Will return the first result found.");
            return $devices->[0];
        }
    }
}

=head2 execute_request

Execute a request, retrying it one if the request is unauthenticated (in case the cached token was invalidated)

=cut

sub execute_request {
    my ($self, $req) = @_;
    my $res = $self->_execute_request($req);
    if($res->is_success) {
        return $res;
    }
    else {
        if($res->code == $STATUS::FORBIDDEN || $res->code == $STATUS::UNAUTHORIZED){
            # We try again but with a fully refreshed token
            $self->cache->remove($self->_token_cache_key);
            $res = $self->_execute_request($req);
            if($res->is_success){
                return $res;
            }
            elsif($res->code == $STATUS::FORBIDDEN || $res->code == $STATUS::UNAUTHORIZED){
                get_logger->error("Cannot authenticate against SentinelOne API. Please check your configuration.");
                return $pf::provisioner::COMMUNICATION_FAILED;
            }
        }
    }
    get_logger->error("Failure while communicating with SentinelOne API: ".$res->status_line);
    return $pf::provisioner::COMMUNICATION_FAILED;
}

=head2 _execute_request

Execute a request on the SentinelOne API

=cut

sub _execute_request {
    my ($self, $req) = @_;
    $req->header("Authorization", "Token ".$self->token());
    my $ua = LWP::UserAgent->new();
    return $ua->request($req);
}

=head2 authorize

Check whether the device exists or not in the SentinelOne API

MISSING : compliance check

=cut

sub authorize {
    my ($self,$mac) = @_;
    my $logger = get_logger();

    my $info = $self->fetch_agent_info($mac);

    if( $info == $pf::provisioner::COMMUNICATION_FAILED){
        return $info;
    }
    elsif(!$info){
        return $FALSE;
    }
    else {
        if($info->{is_uninstalled}) {
            $logger->info("Agent is uninstalled on device");
            return $FALSE;
        }
        elsif(!$info->{is_active}){
            $logger->info("Agent is not active on device");
            return $FALSE;
        }
        $logger->info("Agent is installed and active.");
        return $TRUE;
    }
}

=head2 _build_uri

Build the API URI based on the configuration

=cut

sub _build_uri {
    my ($self, $type, $version) = @_;
    $version //= $self->api_version;
    my $URIS = {
        login => "/web/api/$version/users/login",
        agent_info => "/web/api/$version/agents",
        activities => "/web/api/$version/activities",
    };
    my $path = $URIS->{$type};
    return $self->protocol."://".$self->host.":".$self->port."/$path";
}

sub _extract_data_from_response {
    my ($self, $response, $version) = @_;
    $version //= $self->api_version;

    if ($version eq "v1.6") {
        return $response;
    }
    else {
        return $response->{data};
    }
}

=head2 _build_api_version

Detects the API version (currently supporting v1.R68 and v2.0)

=cut

sub _build_api_version {
    my ($self) = @_;

    #Try request on v1.6, if it fails with a 404, then we'll assume we use v2.0 since its the only 2 API versions we support
    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request::Common::POST($self->_build_uri("login", "v1.6"), Content => encode_json({username => $self->api_username, password => $self->api_password}), 'Content-Type' => 'application/json');
    my $res = $ua->request($req);

    if($res->code ne "404"){
        return "v1.6";
    }
    else {
        return "v2.0";
    }
}


=head2 pollAndEnforce

Get the uninstalled agents in the last X minutes and put them in pending to force them back into the provisioner

  curl "https://packetfence.sentinelone.net/web/api/v1.6/activities?activity_type__in=51&created_at__gt=`perl -e 'print time*1000 - (3600*1000)'`&token=e015ac434d83f0de2f33839c214c2e542d3913f70d1bf965ed21d975365711b739ba44a6b54973b7"

=cut

sub pollAndEnforce {
    my ($self, $timeframe) = @_;
    my $logger = get_logger();
    $logger->info("Fetching list of uninstalled devices since $timeframe on ".$self->id);
    
    my $uninstalled_devices = $self->uninstalled_devices($timeframe);

    foreach my $device (@$uninstalled_devices) {
        my $macs = $device->{data}->{mac_addresses};
        foreach my $mac (@$macs){
            $logger->info("$mac has uninstalled the SentinelOne agent. Verifying if it is handled of this provisioner.");
            my $profile = pf::Connection::ProfileFactory->instantiate($mac);
            if(my $provisioner = $profile->findProvisioner($mac)){
                if($provisioner->id eq $self->id){
                    # We check via authorize that the agent is still uninstalled
                    unless($self->authorize($mac)){
                        $logger->info("$mac is part of the provisioner and has uninstalled its SentinelOne agent. Putting node in pending.");
                        node_modify($mac, status => $pf::node::STATUS_PENDING);
                        pf::enforcement::reevaluate_access($mac, 'redir.cgi');
                    }
                }
            }
        }
    }
}

=head2 uninstalled_devices

Get the list of devices that have uninstalled the agent in the last X seconds

=cut

sub uninstalled_devices {
    my ($self, $timeframe) = @_;

    my $uri = $self->_build_uri("activities") . "?activity_type__in=51&created_at__gt=".(time*1000 - ($timeframe*1000));
    my $req = HTTP::Request::Common::GET($uri);
    my $res = $self->execute_request($req);
    if($res == $pf::provisioner::COMMUNICATION_FAILED){
        return $res;
    }
    else {
        my $devices = $self->_extract_data_from_response(decode_json($res->decoded_content())); 
        return $devices;
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

