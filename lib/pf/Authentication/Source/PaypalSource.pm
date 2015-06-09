package pf::Authentication::Source::PaypalSource;

=head1 NAME

pf::Authentication::Source::PaypalSource add documentation

=cut

=head1 DESCRIPTION

pf::Authentication::Source::PaypalSource

=cut

use strict;
use warnings;
use Moose;
use pf::config qw($FALSE $TRUE $default_pid);
use pf::Authentication::constants;
use pf::util;
use pf::log;
use HTTP::Status qw(is_success);
use WWW::Curl::Easy;
use JSON::XS;
use List::Util qw(first);

extends 'pf::Authentication::Source::BillingSource';

=head2 Attributes

=head2 class

=cut

has '+class' => (default => 'billing');

has '+type' => (default => 'Paypal');

has 'host' => (is => 'rw', default => 'api.sandbox.paypal.com');

has 'proto' => (is => 'rw', default => 'https');

has 'port' => (is => 'rw', default => 443);

has 'client_id' => (is => 'rw');

has 'client_secret' => (is => 'rw');

has 'currency' => (is => 'rw', default => 'USD');

has 'payment_method' => (is => 'rw', default => 'paypal');

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
        $curl->setopt(CURLOPT_USERNAME,       $self->client_id);
        $curl->setopt(CURLOPT_PASSWORD,       $self->client_secret);
    }
    return $curl;
}

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

=head2 _set_body

Set the body for the curl object

=cut

sub _set_body {
    my ($self, $curl, $data) = @_;
    $curl->setopt(CURLOPT_POSTFIELDSIZE, length($data));
    $curl->setopt(CURLOPT_POSTFIELDS,    $data);
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

=head2 get_token

Get a new token from paypal

=cut

sub get_token {
    my ($self)        = @_;
    my $response_body = '';
    my $curl          = $self->curl;
    $self->_set_body($curl, "grant_type=client_credentials");
    $self->_set_url($curl, "v1/oauth2/token");
    my ($code, $response) = $self->_do_request($curl);
    return $response->{access_token};
}

=head2 new_payment

Create a new payment on the Paypal system

=cut

sub new_payment {
    my ($self, $access_token, $payment_info) = @_;
    my $curl = $self->curl;
    $curl->setopt(CURLOPT_HTTPHEADER, ["Content-Type: application/json", "Authorization: Bearer $access_token"]);
    return $self->_send_json($curl, "v1/payments/payment", $payment_info);
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

Prepare the payment from paypal

=cut

sub prepare_payment {
    my ($self, $session, $tier, $params, $path) = @_;
    my $logger  = get_logger();
    my $total   = sprintf("%.2f", $tier->{price});
    my %payment = (
        intent        => 'sale',
        redirect_urls => {
            "return_url" => "http://192.168.56.101:8080/billing/paypal/verify",
            "cancel_url" => "http://192.168.56.101:8080/billing/paypal/cancel"
        },
        "payer" => {"payment_method" => $self->payment_method},
        "transactions" => [{"amount" => {"total" => $total, "currency" => $self->currency}}]
    );
    my $token = $self->get_token;
    $logger->debug(sub {"Token for getting new payment $token"});
    my ($status, $response) = $self->new_payment($token, \%payment);
    if (is_success($status)) {
        $session->{access_token} = $token;
        my %data = (response => $response);
        $data{approval_url} = first {$_->{rel} eq "approval_url"} @{$response->{links}};
        return \%data;
    }
    else {
        $self->handle_error($response);
        die "Error communicating with Paypal";
    }
}

=head2 verify

Verify the payment from paypal

=cut

sub verify {
    my ($self, $session, $parameters, $path) = @_;
    my $paymentId    = $parameters->{paymentId};
    my $payerID      = $parameters->{PayerID};
    my $access_token = $session->{access_token};
    my ($status, $response) = $self->execute_payment($access_token, $paymentId, $payerID);
    if (is_success($status)) {
        my %data = (response => $response);
        return \%data;
    }
    else {
        $self->handle_error($status, $response);
        die "Error communicating with Paypal";
    }
}

=head2 execute_payment

Make the payment live on the paypal system

=cut

sub execute_payment {
    my ($self, $access_token, $paymentId, $payerID) = @_;
    my $curl = $self->curl;
    $curl->setopt(CURLOPT_HTTPHEADER, ["Content-Type: application/json", "Authorization: Bearer $access_token"]);
    return $self->_send_json($curl, "v1/payments/payment/$paymentId/execute/", {payer_id => $payerID});
}

=head2 handle_error

Handle the error from payapl

=cut

sub handle_error {
    my ($self, $status, $error) = @_;
    my $logger = get_logger();
    my $msg =
        "Error communicating with Paypal $status\n"
      . $error->{name} ? "Error Name:  $error->{name}\n" : ""
      . $error->{message} ? "Error Message: $error->{message}\n" : ""
      . $$error->{information_link} ? "Error Information Link: $error->{information_link}\n" : ""
      . $error->{details} ? "Error Details: $error->{details}\n" : "";
    $logger->error($msg);
}

=head2 cancel

Not implemented

=cut

sub cancel {
    my ($self, $session, $parameters, $path) = @_;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
