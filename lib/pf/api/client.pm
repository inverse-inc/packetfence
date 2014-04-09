package pf::api::client;

=head1 NAME

pf::api::client

=head1 SYNOPSIS

  use pf::api::client;
  my $client = pf::api::client->new;
  my @args = $client->call("echo","packet","fence");

  $client->notify("echo","packet","fence");


=head1 DESCRIPTION

  pf::api::client is the base class for the pf http rpc client

=cut

use strict;
use warnings;

use Log::Log4perl;
use WWW::Curl::Easy;
use Moo;

=head1 Attributes

=head2 proto

  the protocol of the rpc call http or https
  default http

=cut

has proto => ( is => 'rw', default => sub {"http"} );

=head2 host

  the host of the rpc server
  default 127.0.0.1

=cut

has host => ( is => 'rw', default => sub {"127.0.0.1"} );

=head2 port

  the port of the rpc server
  default 9090

=cut

has port => (is => 'rw', default => sub {9090} );

=head2 id

  the id of the message it is incremented after each call
  default 0

=cut

has id => (is => 'rw', default => sub {0} );

has content_type => (is => 'rw');

use constant REQUEST => 0;
use constant RESPONSE => 1;
use constant NOTIFICATION => 2;

=head1 METHODS

=head2 call

  Calls an rpc method

=cut

sub call {
    use bytes;
    my ($self,$function,@args) = @_;
    my $response;
    my $curl = $self->curl;
    my $request = $self->build_request($function,\@args);
    my $response_body;
    $curl->setopt(CURLOPT_POSTFIELDSIZE,length($request));
    $curl->setopt(CURLOPT_POSTFIELDS, $request);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);

    # Starts the actual request
    my $curl_return_code = $curl->perform;

    # Looking at the results...
    if ( $curl_return_code == 0 ) {
        my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
        if($response_code == 200) {
            $response = $self->decode(\$response_body);
        } else {
            die "An error occured while processing the rpc request return code ($response_code)";
        }
    } else {
        my $msg = "An error occured while sending a rpc request: $curl_return_code ".$curl->strerror($curl_return_code)." ".$curl->errbuf;
        die $msg;
    }

    return $self->extractValues($response);
}

=head2 decode

TODO: documention

=cut

sub decode {
    my ($self) = @_;
    return ;
}

=head2 encode

TODO: documention

=cut

sub encode {
    my ($self) = @_;
    return ;
}

=head2 notify

  Send a notification message to the rpc server

=cut

sub notify {
    use bytes;
    my ($self,$function,@args) = @_;
    my $response;
    my $curl = $self->curl;
    my $request = $self->build_notification($function,\@args);
    my $response_body;
    $curl->setopt(CURLOPT_POSTFIELDSIZE,length($request));
    $curl->setopt(CURLOPT_POSTFIELDS, $request);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);

    # Starts the actual request
    my $curl_return_code = $curl->perform;

    # Looking at the results...
    if ( $curl_return_code == 0 ) {
        my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
        if($response_code != 204) {
            die "An error occured while processing the rpc notification request return code ($response_code)";
        }
    } else {
        my $msg = "An error occured while sending a rpc notification request: $curl_return_code ".$curl->strerror($curl_return_code)." ".$curl->errbuf;
        die $msg;
    }
    return;
}

=head2 curl

  Creates a curl object to connect to the rpc server

=cut

sub curl {
    my ($self) = @_;
    my $url = $self->url;
    my $curl = WWW::Curl::Easy->new;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
    $curl->setopt(CURLOPT_NOSIGNAL, 1);
    $curl->setopt(CURLOPT_URL, $url);
    $curl->setopt(CURLOPT_HTTPHEADER, ['Content-Type: ' . $self->content_type]);
    return $curl;
}

=head2 url

  The url to the rpc message to

=cut

sub url {
    my ($self) = @_;
    my $proto = $self->proto;
    my $host = $self->host;
    my $port = $self->port;
    return "${proto}://${host}:${port}";
}

=head2 build_request

  builds the jsonrpc request

=cut

sub build_request {
    my ($self,$function,$args) = @_;
}

=head2 build_notification

  builds the jsonrpc notification request

=cut

sub build_notification {
    my ($self,$function,$args) = @_;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

