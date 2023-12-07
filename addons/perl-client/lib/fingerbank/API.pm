package fingerbank::API;

=head1 NAME

fingerbank::API

=head1 DESCRIPTION

Object oriented module to work with the Fingerbank Cloud API

=cut

use fingerbank::Config;
use fingerbank::Util;
use HTTP::Request;
use URI;
use URI::https;
use fingerbank::Util qw(is_enabled);
use fingerbank::NullCache;
use fingerbank::Status;
use JSON::MaybeXS;

use Moose;

has 'host' => (is => 'rw');
has 'port' => (is => 'rw');
has 'use_https' => (is => 'rw');
has 'cache' => (is => 'rw', default => sub { fingerbank::NullCache->new });

=head2 new_from_config

Create a new API client from the configured parameters in fingerbank.conf

=cut

sub new_from_config {
    my ($class) = @_;
    my $Config = fingerbank::Config::get_config();
    return $class->new(
        cache => $fingerbank::Config::CACHE,
        map{$_ => $Config->{upstream}->{$_}} qw(host port use_https),
    );
}

=head2 get_lwp_client

Get the LWP client to talk to the API

=cut

sub get_lwp_client {
    my $ua = fingerbank::Util::get_lwp_client(keep_alive => 1);
    $ua->timeout(2);   # An query should not take more than 2 seconds
    return $ua;
}

=head2 build_uri

Given a path, build the URI based on the client configuration

=cut

sub build_uri {
    my ($self, $path) = @_;
    my $proto = is_enabled($self->use_https) ? "https" : "http";
    my $host = $self->host;
    my $port = $self->port;
    my $uri = URI->new("$proto://$host:$port$path");
    return $uri;
}

=head2 build_request

Given a verb and a path, build the HTTP::Request  based on the client configuration

=cut

sub build_request {
    my ($self, $verb, $path, %options) = @_;
    
    my $Config = fingerbank::Config::get_config();

    my $url = $self->build_uri($path);

    unless($options{dont_add_key}) {
        $url->query_form(key => $Config->{'upstream'}{'api_key'});
    }

    my $req = HTTP::Request->new($verb => $url->as_string);

    return $req;
}

=head2 test_key

Test a specific key against the API

=cut

sub test_key {
    my ($self, $key) = @_;
    my $logger = fingerbank::Log::get_logger;

    my $req = $self->build_request("GET", "/api/v2/test/key/$key", dont_add_key => 1);

    my $res = $self->get_lwp_client->request($req);

    if($res->code == $fingerbank::Status::UNAUTHORIZED) {
        $logger->info("Provided key ($key) is invalid");
        return ($res->code, "Invalid key provided")
    } elsif ($res->code == $fingerbank::Status::FORBIDDEN) {
        my $msg = "Forbidden access to API. Possibly under rate limiting. Message was: ".$res->decoded_content;
        $logger->error($msg);
        return ($res->code, $msg);
    } elsif ($res->is_success) {
        $logger->info("Successfuly tested key $key"); 
        return ($res->code, $res->decoded_content);
    } else {
        my $msg = "Error while testing API key. Error was: ".$res->status_line;
        $logger->error($msg);
        return ($res->code, $msg);
    }

}

=head2 account_info

Get the account information for a specific key.
If no key is provided, it will get the account information of the current configured API key

=cut

sub account_info {
    my ($self, $key) = @_;

    $key //= fingerbank::Config::get_config->{upstream}->{api_key};

    my $logger = fingerbank::Log::get_logger;

    my $req = $self->build_request("GET", "/api/v2/users/account_info/$key");

    my $res = $self->get_lwp_client->request($req);

    if($res->is_success) {
        $logger->info("Fetched user account information successfully");
        return ($res->code, decode_json($res->decoded_content));
    }
    else {
        $logger->error("Error while fetching account information");
        return ($res->code, $res->decoded_content);
    }
}

=head2 device_id_from_oui

Find the most probable device ID for a given OUI

=cut

sub device_id_from_oui {
    my ($self, $oui) = @_;

    my $logger = fingerbank::Log::get_logger;

    my $req = $self->build_request("GET", "/api/v2/oui/$oui/to_device_id");

    my $res = $self->get_lwp_client->request($req);

    if($res->is_success) {
        my $result = decode_json($res->decoded_content);
        my $device_id = $result->{device_id};
        $logger->info("Found device ID $device_id for OUI $oui");
        return ($res->code, $device_id);
    }
    else {
        $logger->error("Cannot find device ID for OUI $oui: ".$res->status_line);
        return ($res->code, $res->decoded_content);
    }
}

=head2 device_id_from_oui

Get the outbound communications profile of a device

=cut

sub device_outbound_communications {
    my ($self, $device_id) = @_;

    my $logger = fingerbank::Log::get_logger;

    my $req = $self->build_request("GET", "/api/v2/devices/$device_id/outbound_communications");

    my $res = $self->get_lwp_client->request($req);

    if($res->is_success) {
        my $result = decode_json($res->decoded_content);
        return ($res->code, $result);
    }
    else {
        $logger->error("Cannot find outbound communications for device '$device_id': ".$res->status_line);
        return ($res->code, $res->decoded_content);
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
