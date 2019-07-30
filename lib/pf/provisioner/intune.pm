package pf::provisioner::intune;
=head1 NAME

pf::provisioner::intune add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::intune

=cut

use strict;
use warnings;
use Moo;
extends 'pf::provisioner';

use JSON::MaybeXS qw( decode_json );
use pf::util qw(clean_mac);
use WWW::Curl::Easy;
use XML::Simple;
use pf::log;
use pf::ip4log;
use pf::ConfigStore::Provisioning;
use DateTime::Format::RFC3339;
use pf::security_event;

=head1 Atrributes

=head2 tenantID

tenant ID

=cut

has tenantID => => (is => 'rw');

=head2 applicationID

Application ID

=cut

has applicationID => (is => 'rw');

=head2 applicationSecret

application Secret

=cut

has applicationSecret => (is => 'rw');


=head2 loginUrl

Host where to login to get the access token

=cut

has loginUrl => (is => 'rw', default => sub { "login.microsoftonline.com" });

=head2 host

Host of the Microsoft Graph web API

=cut

has host => (is => 'rw', default => sub { "graph.microsoft.com" });

=head2 port

Port to connect to the Microsoft Graph web API

=cut

has port => (is => 'rw', default =>  sub { 443 } );

=head2 protocol

Protocol to connect to the Microsoft Graph web API

=cut

has protocol => (is => 'rw', default => sub { "https" } );

=head2 access_token

The access token to be authorized on the Microsoft Graph web API

=cut

has access_token => (is => 'rw');

=head2 agent_download_uri

The URI to download the agent

=cut

has agent_download_uri => (is => 'rw');

sub get_access_token {
    my ($self) = @_;
    my $logger = get_logger();
    return $self->{'access_token'};
}

sub refresh_access_token {
    my ($self) = @_;
    my $logger = get_logger();

    my $curl = WWW::Curl::Easy->new;
    my $url = $self->protocol."://".$self->host.":".$self->loginUrl."/".$self->tenantID."/oauth2/token";

    my $response_body = '';
    open(my $fileb, ">", \$response_body);
    $curl->setopt(CURLOPT_URL, $url );
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0) ;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_WRITEDATA,$fileb);

    $curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPHEADER(), ["client_id: ".$self->applicationID."\",\"client_secret: ".$self->applicationSecret."\",\"grant_type: client_credentials", "scope: https://graph.microsoft.com/Device.ReadWrite.All", "resource: https://graph.microsoft.com"]);


    my $curl_return_code = $curl->perform;
    my $curl_info = $curl->getinfo(CURLINFO_HTTP_CODE); # or CURLINFO_RESPONSE_CODE depending on libcurl version

    if ( $curl_return_code != 0 or $curl_info != 200 ) {
        # Failed to contact the Graph API.;
        $logger->error("Cannot connect to Graph to refresh the token");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
    else {
        my $json_response = decode_json($response_body);
        my $updated_config = {};
        my $access_token = $json_response->{'access_token'};
        if (defined $access_token && $access_token ne '') {
            $updated_config->{access_token} = $access_token;
        }
        else {
            $logger->error("Cannot update the access token for $self->{id}");
        }

        $self->update_config($updated_config);
        $logger->info("Refreshed the token to connect to the Graph API");
    }
}

=head2 update_config

Update the config for this provisioner

=cut

sub update_config {
    my ($self, $updated_config) = @_;
    my $cs     = pf::ConfigStore::Provisioning->new;
    my $config = $cs->read($self->{id});
    unless ($config) {
        get_logger->error("Error getting configuration for $self->{id}");
        return;
    }
    %$config = (%$config, %$updated_config);
    $cs->update($self->{'id'}, $config);
    return $cs->commit();
}

sub get_device_info {
    my ($self, $mac) = @_;
    my $logger = get_logger();

    my $access_token = $self->get_access_token();
    my $curl = WWW::Curl::Easy->new;
    my $url = $self->protocol.'://' . $self->host . ':' .  $self->port . '/v1.0/deviceManagement/managedDevices?$select=wiFiMacAddress,complianceState';
    
    $logger->debug("Calling Graph API using URL : ".$url);

    my $response_body = '';
    open(my $fileb, ">", \$response_body);
    $curl->setopt(CURLOPT_URL, $url );
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0) ;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_WRITEDATA,$fileb);
    $curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPHEADER(), ['Content-Type: application/json', "Authorization: Bearer $access_token"]);

    my $curl_return_code = $curl->perform;
    my $curl_info = $curl->getinfo(CURLINFO_HTTP_CODE); # or CURLINFO_RESPONSE_CODE depending on libcurl version

    my $json_response = decode_json($response_body);
    use Data::Dumper;
    $logger->warn($json_response);
    $access_token = $json_response->{'access_token'};

    return $self->decode_response($curl_info, $response_body);
}

sub validate_mac_in_intune {
    my ($self, $mac) = @_;
    my $logger = get_logger();
    my $info = $self->get_device_info($mac);
    if($info != $pf::provisioner::COMMUNICATION_FAILED){
        return 1;
    }
    else{
        return 0;
    }
}

sub authorize {
    my ($self,$mac) = @_;
    my $logger = get_logger();

    my $result = $self->validate_mac_in_intune($mac);
    if( $result == $pf::provisioner::COMMUNICATION_FAILED){
        $logger->info("Graph access token is probably not valid anymore.");
        $self->refresh_access_token();
        $result = $self->validate_mac_in_intune($mac);
    }

    if($result == $pf::provisioner::COMMUNICATION_FAILED){
        $logger->error("Unable to contact the Graph API to validate if mac $mac is registered.");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
    else{
        # take the opportunity to check compliance
        $self->verify_compliance($mac);
        return $result;
    }

}

sub verify_compliance {
    my ($self, $mac) = @_;
    my $logger = get_logger();
    my $info = $self->get_device_info($mac);
    if($info != $pf::provisioner::COMMUNICATION_FAILED){
        if($self->{critical_issues_threshold} != 0 && defined($info->{total_critical_issue}) && $info->{total_critical_issue} >= $self->{critical_issues_threshold}){
            $logger->info("Device $mac is not compliant. Raising security_event");
            pf::security_event::security_event_add($mac, $self->{non_compliance_security_event}, ());
        }
    }
    else{
        $logger->warn("Couldn't contact OPSWAT API to validate compliance of $mac");
    }
}

sub pollAndEnforce {
    my ($self, $timeframe) = @_;
    my $logger = get_logger();
    my $result = $self->get_status_changed_devices($timeframe);
    if ( $result == $pf::provisioner::COMMUNICATION_FAILED ){
        $logger->info("OPSWAT Oauth access token is probably not valid anymore.");
        $self->refresh_access_token();
        $result = $self->get_status_changed_devices($timeframe);
    }

    if ( $result == $pf::provisioner::COMMUNICATION_FAILED ){
        $logger->error("Unable to contact the OPSWAT API to poll the changed devices.");
    }
    else{
        foreach my $device (@{$result->{devices}}){
            foreach my $mac (@{$device->{mac_addresses}}){
                $self->verify_compliance($mac);
            }
        }
    }
}

sub get_status_changed_devices {
    my ($self, $timeframe) = @_;
    my $logger = get_logger();

    my $access_token = $self->get_access_token();
    my $curl = WWW::Curl::Easy->new;
    my $url = $self->protocol.'://' . $self->host . ':' .  $self->port . "/o/api/v2.1/devices/status_changed?age=$timeframe&access_token=$access_token";

    $logger->debug("Calling OPSWAT API using URL : ".$url);

    my $response_body = '';
    open(my $fileb, ">", \$response_body);
    $curl->setopt(CURLOPT_URL, $url );
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0) ;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_WRITEDATA,$fileb);

    my $curl_return_code = $curl->perform;
    my $curl_info = $curl->getinfo(CURLINFO_HTTP_CODE); # or CURLINFO_RESPONSE_CODE depending on libcurl version

    $logger->info($curl_info);
    $logger->info($response_body);

    return $self->decode_response($curl_info, $response_body);
}

sub decode_response {
    my ($self, $code, $response_body) = @_;
    my $logger = get_logger();
    if ( $code == 401 ) {
        $logger->error("Unauthorized to contact OPSWAT");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
    elsif($code == 404) {
        $logger->info("Device is not in OPSWAT Metadefender Endpoint. Assuming device doesn't have the agent.");
        my $json_response = decode_json($response_body);
        return $json_response;
    }
    elsif($code != 200){
        $logger->error("Got error code $code when contacting the OPSWAT Metadefender Endpoint API. Here's the response body : $response_body");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
    else {
        my $json_response = decode_json($response_body);
        return $json_response;
    }

}

=head2 logger

Return the current logger for the switch

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
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
