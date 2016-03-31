package pf::provisioner::sentinelone;
=head1 NAME

pf::provisioner::opswat add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::opswat

=cut

use strict;
use warnings;
use Moo;
extends 'pf::provisioner';

use JSON::MaybeXS qw( decode_json );
use pf::constants;
use pf::util qw(clean_mac);
use LWP::UserAgent;
use HTTP::Request::Common;
use pf::log;
use pf::constants::provisioning qw($SENTINEL_ONE_TOKEN_EXPIRY);

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

has host => (is => 'rw', required => 1);

=head2 port

Port to connect to the SentinelOne web API

=cut

has port => (is => 'rw', default =>  sub { 443 } );

=head2 protocol

Protocol to connect to the SentinelOne web API

=cut

has protocol => (is => 'rw', default => sub { "https" } );

=head2 win_agent_download_uri

URI to download the windows agent

=cut

has win_agent_download_uri => (is => 'rw');

=head2 mac_osx_agent_download_uri

URI to download the Mac OSX agent

=cut

has mac_osx_agent_download_uri => (is => 'rw');

sub cache {
    my ($self) = @_;
    return pf::CHI->new(namespace => 'provisioning');
}

sub _token_cache_key {
    my ($self) = @_;
    return $self->id."-token";
}

sub token {
    my ($self) = @_;
    my $logger = get_logger();
    return $self->cache->compute($self->_token_cache_key, sub { $self->fetch_token() }, { expires_in => $SENTINEL_ONE_TOKEN_EXPIRY });
}

sub fetch_token {
    my ($self) = @_;
    my $logger = get_logger();

    my $ua = LWP::UserAgent->new();

    my $req = HTTP::Request::Common::POST($self->_build_uri("/web/api/v1.6/users/login"), [username => $self->api_username, password => $self->api_password]);

    my $res = $ua->request($req);

    if($res->is_success){
        my $info = decode_json($res->decoded_content);
        my $token = $info->{token};
        $logger->debug("Got token : $token");
        return $token;
    }
    else {
        $logger->error("Failed to get token from SentinelOne API : ".$res->status_line);
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
}

sub fetch_agent_info {
    my ($self, $mac) = @_;
    my $logger = get_logger;
    my $uri = $self->_build_uri("/web/api/v1.6/agents?query=$mac");
    my $req = HTTP::Request::Common::GET($uri);
    my $res = $self->execute_request($req);
    if($res == $pf::provisioner::COMMUNICATION_FAILED){
        return $res;
    }
    else {
        my $devices = decode_json($res->decoded_content()); 
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
            $logger->error("Device $mac returned multiple results in Sentinel One. This is not normal. Acting as if communications failed.");
            return $pf::provisioner::COMMUNICATION_FAILED;
        }
    }
}

sub execute_request {
    my ($self, $req) = @_;
    my $res = $self->_execute_request($req);
    if($res->is_success) {
        return $res;
    }
    else {
        if($res->code == 401){
            # We try again but with a fully refreshed token
            $self->cache->remove($self->_token_cache_key);
            $res = $self->_execute_request($req);
            if($res->is_success){
                return $res;
            }
            elsif($res->code == 401){
                get_logger->error("Cannot authenticate against SentinelOne API. Please check your configuration.");
                return $pf::provisioner::COMMUNICATION_FAILED;
            }
        }
    }
    return $res;
}

sub _execute_request {
    my ($self, $req) = @_;
    $req->header("Authorization", "Token ".$self->token());
    my $ua = LWP::UserAgent->new();
    return $ua->request($req);
}

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
        return $info->{is_active};
    }
}

sub _build_uri {
    my ($self, $path) = @_;
    return $self->protocol."://".$self->host.":".$self->port."/$path";
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

