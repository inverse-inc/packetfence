package pf::Authentication::Source::StripeSource;
=head1 NAME

pf::Authentication::Source::StripeSource add documentation

=cut

=head1 DESCRIPTION

pf::Authentication::Source::StripeSource

=cut

use strict;
use warnings;
use Moose;
use pf::config qw($FALSE $TRUE $default_pid);
use pf::Authentication::constants;
use pf::util;
use HTTP::Status qw(is_success);
use WWW::Curl::Easy;
use JSON::XS;

extends 'pf::Authentication::Source::BillingSource';

=head2 Attributes

=head2 class

=cut

has '+class' => (default => 'billing');

has '+type' => (default => 'Stripe');

has 'host' => (is => 'rw', default => 'api.stripe.com');

has 'proto' => (is => 'rw', default => 'https');

has 'port' => (is => 'rw', default => 443);

has 'test_secret_key' => (is => 'rw');

has 'test_publishable_key' => (is => 'rw');

has 'live_secret_key' => (is => 'rw', required => 1);

has 'live_publishable_key' => (is => 'rw', required => 1);

has 'style' => (is => 'rw', default => 'charge');

=head2 url

  The url to the rpc message to

=cut

sub base_url {
    my ($self) = @_;
    my $proto  = $self->proto;
    my $host   = $self->host;
    my $port   = $self->port;
    return "${proto}://${host}:${port}";
}

=head2 curl

  Creates a curl object to connect to the rpc server

=cut

sub curl {
    my ($self, $function) = @_;
    my $curl = WWW::Curl::Easy->new;
    $curl->setopt(CURLOPT_HEADER,               0);
    $curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
    $curl->setopt(CURLOPT_NOSIGNAL,             1);
    $curl->setopt(CURLOPT_HTTPHEADER, ['Accept: application/json', 'Accept-Language: en_US']);
    if ($self->proto eq 'https') {

        # Removed SSL verification
        $curl->setopt(CURLOPT_SSL_VERIFYHOST, 0);
        $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0);
        $curl->setopt(CURLOPT_USERNAME, $self->secret_key);
        $curl->setopt(CURLOPT_PASSWORD, '');
    }
    return $curl;
}

=head2 _send_json

send json data

=cut

sub _send_json {
    my ($self, $curl, $path, $object) = @_;
    $self->_set_url($curl, $path);
    my $data = encode_json $object;
    $self->_set_body($curl, $data);
    return $self->_do_request($curl);
}

=head2 _set_url

Set the url for the curl object

=cut

sub _set_url {
    my ($self, $curl, $path) = @_;
    my $base_url = $self->base_url;
    $path =~ s#^\/##;
    my $url = "$base_url/$path";
    $curl->setopt(CURLOPT_URL, $url);
}

=head2 _do_request

Send the request and return the status code and body

=cut

sub _do_request {
    my ($self, $curl) = @_;
    my $response_body;
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
    my $curl_return_code = $curl->perform;
    if ($curl_return_code == 0) {
        my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
        my $response      = decode_json($response_body);
        return ($response_code, $response);
    }
    else {
        die "Error send request: " . $curl->errbuf;
    }
}

=head2 prepare_payment

=cut

sub prepare_payment {
    my ($self, $session, $tier, $params, $path) = @_;
    my $token = $params->{stripeToken};
    if( $self->style eq 'charge') {
        $self->charge($tier,$token);
    }
    return {};
}


=head2 charge

=cut

sub charge {
    my ($self, $tier, $token) = @_;
    my $object = {
        amount   => int($tier->{price} * 100),
        currency => $self->currency,
        source   => $token,
    };
    return $self->_send_json("v1/charges", $object);
}

sub publishable_key {
    my ($self) = @_;
    return $self->test_mode ? $self->test_publishable_key : $self->live_publishable_key;
}

sub secret_key {
    my ($self) = @_;
    return $self->test_mode ? $self->test_secret_key : $self->live_secret_key;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

