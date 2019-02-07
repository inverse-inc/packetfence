package pf::api::jsonrestclient;

=head1 NAME

pf::api::jsonrestclient

=head1 SYNOPSIS

  use pf::api::jsonrestclient;
  my $client = pf::api::jsonrestclient->new;
  my @args = $client->call("echo","packet","fence");

  $client->notify("echo","packet","fence");


=head1 DESCRIPTION

  pf::api::jsonrestclient is a json REST client over http
  It will always post a JSON payload to a defined URL

=cut

use strict;
use warnings;

use JSON::MaybeXS;
use pf::config qw(%Config);
use pf::log;
use WWW::Curl::Easy;
use Moo;
use HTTP::Status qw(:constants);

=head1 Attributes

=head2 username

the username of the JSON REST call

=cut

has username => ( is => 'rw', default => sub {$Config{'webservices'}{'user'}} );

=head2 password

the password of the JSON REST call

=cut

has password => ( is => 'rw', default => sub {$Config{'webservices'}{'pass'}} );

=head2 proto

the protocol of the JSON REST call http or https
default http

=cut

has proto => ( is => 'rw', default => sub {$Config{'webservices'}{'proto'}} );

=head2 host

the host of the JSON REST server
default 127.0.0.1

=cut

has host => ( is => 'rw', default => sub {$Config{'webservices'}{'host'}} );

=head2 port

the port of the JSON REST server
default 9090

=cut

has port => (is => 'rw', default => sub {$Config{'webservices'}{'port'}} );

=head2 method

  the method to use to send the request (post/get)
  default post

=cut

has method => (is => 'rw', default => sub {"post"} );

=head2 connect_timeout_ms

Curl connection timeout in milli seconds

=cut

has connect_timeout_ms => (is => 'rw', default => sub {0}) ;

=head2 timeout_ms

Curl transfer timeout in milli seconds

=cut

has timeout_ms => (is => 'rw', default => sub {0} ) ;

use constant REQUEST => 0;
use constant RESPONSE => 2;
use constant NOTIFICATION => 2;

=head1 METHODS

=head2 call

Calls an JSON REST method

=cut

sub call {
    use bytes;
    my ($self,$path,$args) = @_;
    my $response;
    my $curl = $self->curl($path);

    if ($self->method eq 'post') {
        my $request = $self->build_json_rest_payload($args);
        $curl->setopt(CURLOPT_POSTFIELDSIZE, length($request));
        $curl->setopt(CURLOPT_POSTFIELDS, $request);
    }
    my $response_body;
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0);

    # Starts the actual request
    my $curl_return_code = $curl->perform;

    # Looking at the results...
    if ( $curl_return_code == 0 ) {
        my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
        if($response_code == 200) {
            $response = decode_json($response_body);
            if(exists($response->{error})){
                die $response->{error}{message};
            }
        } elsif($response_code == 202) {
            return; 
        }else {
            $response = decode_json($response_body);
            die $response->{error}{message};
        }
    } else {
        my $msg = "An error occured while sending a JSON REST request: $curl_return_code ".$curl->strerror($curl_return_code)." ".$curl->errbuf;
        die $msg;
    }

    return @{$response->{result}};
}

=head2 curl

  Creates a curl object to connect to the JSON REST server

=cut

sub curl {
    my ($self, $path) = @_;
    my $url = $self->url($path);
    my $curl = WWW::Curl::Easy->new;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
    $curl->setopt(CURLOPT_NOSIGNAL, 1);
    $curl->setopt(CURLOPT_URL, $url);
    $curl->setopt(CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    $curl->setopt(CURLOPT_CONNECTTIMEOUT_MS, $self->connect_timeout_ms // 0);
    $curl->setopt(CURLOPT_TIMEOUT_MS, $self->timeout_ms // 0);
    if($self->proto eq 'https') {
        if($self->username && $self->password) {
            $curl->setopt(CURLOPT_USERNAME, $self->username);
            $curl->setopt(CURLOPT_PASSWORD, $self->password);
        }

        $curl->setopt(CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
        # Removed SSL verification
        $curl->setopt(CURLOPT_SSL_VERIFYHOST, 0);
        $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0);
    }
    return $curl;
}

=head2 url

  The url to the JSON REST request to

=cut

sub url {
    my ($self, $path) = @_;
    my $proto = $self->proto;
    my $host = $self->host;
    my $port = $self->port;
    return "${proto}://${host}:${port}$path";
}

=head2 build_json_rest_payload

  builds the json rest request

=cut

sub build_json_rest_payload {
    my ($self,$args) = @_;
    return encode_json $args;
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


