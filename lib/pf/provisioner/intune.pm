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
use WWW::Curl::Form;
use pf::constants;
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

=head2 windows_agent_download_uri

URI to download the windows agent

=cut

has windows_agent_download_uri => (is => 'rw');

=head2 mac_osx_agent_download_uri

URI to download the Mac OSX agent

=cut

has mac_osx_agent_download_uri => (is => 'rw');

=head2 ios_agent_download_uri

URI to download the ios agent

=cut

has ios_agent_download_uri => (is => 'rw');

=head2 android_agent_download_uri

URI to download the Android agent

=cut

has android_agent_download_uri => (is => 'rw');

=head2 domains

Domains that needs to be allowed to fetch the agent

=cut

has domains => (is => 'rw');

sub get_access_token {
    my ($self) = @_;
    my $logger = get_logger();
    return $self->{'access_token'};
}

sub refresh_access_token {
    my ($self) = @_;
    my $logger = get_logger();

    my $curl = WWW::Curl::Easy->new;
    my $url = $self->protocol."://".$self->loginUrl.":".$self->port."/".$self->tenantID."/oauth2/token";

    my $response_body = '';
    open(my $fileb, ">", \$response_body);
    $curl->setopt(CURLOPT_URL, $url );
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0) ;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_WRITEDATA,$fileb);

    my $postdata = new WWW::Curl::Form;
    $postdata->formadd("client_id",$self->applicationID);
    $postdata->formadd("client_secret",$self->applicationSecret);
    $postdata->formadd("grant_type","client_credentials");
    $postdata->formadd("scope","https://graph.microsoft.com/Device.ReadWrite.All");
    $postdata->formadd("resource","https://graph.microsoft.com");

    $curl->setopt(CURLOPT_HTTPPOST, $postdata);

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
            $self->{'access_token'} = $access_token;
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

    unless ($self->get_access_token()) {
        $self->refresh_access_token();
    }
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
    return $self->decode_response($curl_info, $response_body);
}

sub authorize {
    my ($self,$mac) = @_;
    my $logger = get_logger();

    my $result = $self->get_device_info($mac);
    if( $result == $pf::provisioner::COMMUNICATION_FAILED){
        $logger->info("Graph access token is probably not valid anymore.");
        $self->refresh_access_token();
        $result = $self->get_device_info($mac);
    }

    if($result == $pf::provisioner::COMMUNICATION_FAILED){
        $logger->error("Unable to contact the Graph API to validate if mac $mac is registered.");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
    else{
        # take the opportunity to check compliance
        return $self->verify_compliance($mac, $result);
    }

}

sub verify_compliance {
    my ($self, $mac, $info) = @_;
    my $logger = get_logger();
    # Format the mac to the azure format
    my $azuremac = uc($mac);
    $azuremac =~ s/://g;


    if($info != $pf::provisioner::COMMUNICATION_FAILED){

        foreach my $entry (@{$info->{value}}) {
            if ($entry->{wiFiMacAddress} eq $azuremac) {
                $logger->warn($azuremac);
                if ($entry->{complianceState} ne 'compliant') {
                    $logger->info("Device $mac is not compliant. Raising security_event");
                    pf::security_event::security_event_add($mac, $self->{non_compliance_security_event}, ());
                    return $FALSE;
                } else {
                    return $TRUE;
                }
            }
        }
        return $FALSE;
    }
    else{
        $logger->warn("Couldn't contact Graph API to validate compliance of $mac");
        return $FALSE;
    }
}

sub decode_response {
    my ($self, $code, $response_body) = @_;
    my $logger = get_logger();
    if ( $code == 401 ) {
        $logger->error("Unauthorized to contact Graph");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
    elsif($code == 404) {
        $logger->info("Device is not in Graph Endpoint. Assuming device doesn't have the agent.");
        my $json_response = decode_json($response_body);
        return $json_response;
    }
    elsif($code != 200){
        $logger->error("Got error code $code when contacting the Graph API. Here's the response body : $response_body");
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

