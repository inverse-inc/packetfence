package pf::provisioner::sepm;
=head1 NAME

pf::provisioner::sepm add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::sepm

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

=head1 Atrributes

=head2 client_id

Client id to connect to the API

=cut

has client_id => (is => 'rw');

=head2 client_secret

Client secret to connect to the API

=cut

has client_secret => (is => 'rw');

=head2 host

Host of the SEPM web API

=cut

has host => (is => 'rw');

=head2 port

Port to connect to the SEPM web API

=cut

has port => (is => 'rw', default => sub { 8446 });

=head2 protocol

Protocol to connect to the SEPM web API

=cut

has protocol => (is => 'rw', default => sub { "https" } );

=head2 access_token

The access token to be authorized on the SEPM web API

=cut

has access_token => (is => 'rw');

=head2 refresh_token

The token to refresh the access token once it expires

=cut

has refresh_token => (is => 'rw');

=head2 agent_download_uri

The URI to download the agent

=cut

has agent_download_uri => (is => 'rw');

=head2 alt_agent_download_uri

The alternative URI to download the agent (Used for 64 bit download)

=cut

has alt_agent_download_uri => (is => 'rw');


sub get_refresh_token {
    my ($self) = @_;
    my $logger = $self->logger;
    return $self->{'refresh_token'}
}

sub set_refresh_token {
    my ($self, $refresh_token) = @_;
    my $logger = $self->logger;
    if (!defined($refresh_token) || $refresh_token eq ''){
        $logger->error("Called set_refresh_token but the refresh token is invalid");
    }
    else{
        $self->{'refresh_token'} = $refresh_token;
        my $cs = pf::ConfigStore::Provisioning->new;
        $logger->info($self->{'id'});
        $cs->update($self->{'id'}, {refresh_token => $refresh_token});
        $cs->commit();
    }

}

sub get_access_token {
    my ($self) = @_;
    my $logger = $self->logger;
    return $self->{'access_token'};
}

sub set_access_token {
    my ($self, $access_token) = @_;
    my $logger = $self->logger;
    if (!defined($access_token) || $access_token eq ''){
        $logger->error("Called set_access_token but the access token is invalid.");
    }
    else{
        $self->{'access_token'} = $access_token;
    }
}

sub refresh_access_token {
    my ($self) = @_;
    my $logger = $self->logger;

    my $refresh_token = $self->get_refresh_token();
    my $curl = WWW::Curl::Easy->new;
    my $url = $self->protocol."://".$self->host.":".$self->port."/sepm/oauth/token?grant_type=refresh_token&client_id=".$self->client_id."&client_secret=".$self->client_secret."&redirect_uri=https://".$self->host.":".$self->port."/sepm&refresh_token=$refresh_token";

    my $response_body = '';
    open(my $fileb, ">", \$response_body);
    $curl->setopt(CURLOPT_URL, $url );
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0) ;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_WRITEDATA,$fileb);

    my $curl_return_code = $curl->perform;
    my $curl_info = $curl->getinfo(CURLINFO_HTTP_CODE); # or CURLINFO_RESPONSE_CODE depending on libcurl version

    if ( $curl_return_code != 0 or $curl_info != 200 ) {
        # Failed to contact the SEPM.;
        $logger->error("Cannot connect to the SEPM to refresh the token");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
    else {
        my $json_response = decode_json($response_body);
        my $updated_config = {};
        my $access_token = $json_response->{'access_token'};
        $refresh_token = $json_response->{'refresh_token'};
        if (defined $access_token && $access_token ne '') {
            $updated_config->{access_token} = $access_token;
            $self->set_access_token($access_token);
        }
        else {
            $logger->error("Cannot update the access token for $self->{id}");
        }

        if (defined $refresh_token && $refresh_token ne '') {
            $updated_config->{refresh_token} = $refresh_token;
        }
        else {
            $logger->error("Cannot update the refresh token for $self->{id}");
        }
        $self->update_config($updated_config);
        $logger->info("Refreshed the token to connect to the SEPM");
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

sub validate_ip_in_sepm {
    my ($self, $ip_to_search) = @_;
    my $logger = $self->logger;
    my $postdata
    = qq(<?xml version="1.0" encoding="UTF-8"?>
    <Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">
        <Body>
            <getComputersByIP xmlns="http://client.webservice.sepm.symantec.com/">
                <ipAddresses xmlns="">$ip_to_search</ipAddresses>
            </getComputersByIP>
        </Body>
    </Envelope>
    );

    my $access_token = $self->get_access_token();
    my $curl = WWW::Curl::Easy->new;
    my $url = $self->protocol.'://' . $self->host . ':' .  $self->port . '/sepm/ws/v1/ClientService';

    my $response_body = '';
    open(my $fileb, ">", \$response_body);
    $curl->setopt(CURLOPT_URL, $url );
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0) ;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_POSTFIELDS, $postdata);
    $curl->setopt(CURLOPT_WRITEDATA,$fileb);
    $curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPHEADER(), ['Content-Type: text/xml;charset=UTF-8', "Authorization: Bearer $access_token"]);

    my $curl_return_code = $curl->perform;
    my $curl_info = $curl->getinfo(CURLINFO_HTTP_CODE); # or CURLINFO_RESPONSE_CODE depending on libcurl version

    if ( $curl_info == 400 ) {
        $logger->error("Unable to contact the SEPM on url ".$url);
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
    elsif($curl_info != 200){
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
    else {
        #check if ip address is there
        #$logger->info($response_body);
        my $xml = XML::Simple->new;
        my $response = $xml->XMLin($response_body, KeyAttr=>{item=>'Body'});

        if( $response->{'S:Body'}->{'ns2:getComputersByIPResponse'}->{'ns2:ComputerResult'}->{'totalNumberOfResults'} >= 1){
            $logger->info("IP $ip_to_search has been found in the SEPM.");
            return 1;

        }
        else{
            $logger->info("IP $ip_to_search has not been found in the SEPM");
            return 0;
        }
    }
}

sub authorize {
    my ($self,$mac) = @_;
    my $ip = pf::ip4log::mac2ip($mac);
    if(defined($ip)){
        my $logger = $self->logger;
        my $result = $self->validate_ip_in_sepm($ip);
        if( $result == $pf::provisioner::COMMUNICATION_FAILED){
            $logger->info("SEPM Oauth access token is not valid anymore.");
            $self->refresh_access_token();
            $result = $self->validate_ip_in_sepm($ip);
        }

        if($result == $pf::provisioner::COMMUNICATION_FAILED){
            $logger->error("Unable to contact SEPM to validate if IP $ip is registered.");
            return $pf::provisioner::COMMUNICATION_FAILED;
        }
        else{
            return $result;
        }
    }

}

=head2 logger

Return the current logger for the provisioner

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
