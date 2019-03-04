package pf::Authentication::Source::PaypalSource;

=head1 NAME

pf::Authentication::Source::PaypalSource

=cut

=head1 DESCRIPTION

pf::Authentication::Source::PaypalSource

=cut

use strict;
use warnings;
use Moose;
use pf::config qw($default_pid $fqdn %Config);
use pf::constants;
use pf::Authentication::constants;
use pf::util;
use pf::log;
use WWW::Curl::Easy;
use JSON::MaybeXS;
use List::Util qw(first pairmap);
use URI::Escape qw(uri_escape uri_unescape);
use HTTP::Status qw(is_success :constants);
use IPC::Open2;

our $PAYPAL_SANDBOX_URL = 'https://www.sandbox.paypal.com/cgi-bin/webscr';
our $PAYPAL_URL = 'https://www.paypal.com/cgi-bin/webscr';

extends 'pf::Authentication::Source::BillingSource';
with 'pf::Authentication::CreateLocalAccountRole';

=head2 Attributes

=head2 class

=cut

has '+class' => (default => 'billing');

has '+type' => (default => 'Paypal');

has 'identity_token' => ( isa => 'Str', is => 'rw', required => 1);

has 'domains' => (isa => 'Str', is => 'rw', required => 1, default => '*.paypal.com,*.paypalobjects.com');

has 'cert_id' => ( isa => 'Str', is => 'rw', required => 1);

has 'cert_file' => ( isa => 'Str', is => 'rw', required => 1);

has 'key_file' => ( isa => 'Str', is => 'rw', required => 1);

has 'paypal_cert_file' => ( isa => 'Str', is => 'rw', required => 1);

has 'email_address' => (isa => 'Str', is => 'rw', required => 1);

has 'payment_type' => (isa => 'Str', is => 'rw', required => 1);

has 'url' => (is => 'rw', builder => '_get_paypal_url', lazy => 1);

=head2 prepare_payment

Prepare the payment from paypal

=cut

sub prepare_payment {
    my ($self, $session, $tier, $params, $uri) = @_;
    return {
        encrypted => $self->encrypt_form($session, $tier, $params),
    };
}

=head2 encrypt_form


=cut

sub encrypt_form {
    my ($self, $session, $tier, $params) = @_;
    my $cert_file = $self->cert_file;
    my $key_file = $self->key_file;
    my $paypal_cert_file = $self->paypal_cert_file;
    my $openssl_binary = $Config{services}{openssl_binary};
    my $cmd = "$openssl_binary smime -sign -signer \"$cert_file\" "
          . "-inkey \"$key_file\" -outform der -nodetach -binary "
          . "| $openssl_binary smime -encrypt -des3 -binary -outform pem "
          . "\"$paypal_cert_file\"";
    my $pid = open2(my $reader, my $writer,$cmd) || die "Error encrypting form data\n";
    my %params = (
        cmd => $self->payment_type,
        currency_code => $self->currency,
        cert_id => $self->cert_id,
        amount => $tier->{price},
        item_name => $tier->{name},
        item_number => $tier->{id},
        cancel_return => $self->cancel_url,
        'return' => $self->verify_url,
        notify_url => $self->verify_url,
        business => $self->email_address,
    );

    # Write our parameters that we need to be encrypted to the openssl
    # process.
    while (my ($key, $value) =  each %params) {
        print $writer "$key=$value\n";
    }
    # close the writer file-handle
    close($writer);

    # read in the lines from openssl
    my @lines = <$reader>;

    # close the reader file-handle which probably closes the openssl processes
    close($reader);
    waitpid($pid,0);

    # combine them into one variable
    my $encrypted = join('', @lines);
    return $encrypted;
}

=head2 verify

Verify the payment from paypal
http://192.168.56.101/billing/PaypalEncryption/verify?tx=91R50174XG355921T&st=Completed&amt=12%2e00&cc=USD&cm=&item_number=&sig=JZROGcx8t8Sgb0mFxteT1EfSK5FIQkBbmHr%2fMDpCswUpoMIj%2bTTv0SEh4DNATwoTPDVjAEt7lGqP14JwqmJ2Z2bepK0nZl2BqChrXwmPipFCrtVARAS83U3LOEvXaB5t0aFBfYS0oJSt2FDdOP2ISr4F7%2fzX9dSHjaFOWsHkJlw%3d

=cut

=head2 verify

Verify the payment from paypal

=cut

sub verify {
    my ($self, $session, $parameters, $uri) = @_;
    my $txn    = $parameters->{tx};
    my $identity_token = $self->identity_token;
    unless (defined $txn ) {
        die "Invalid parameters provided";
    }
    my ($status, $response) = $self->_notify_synch($txn);
    if (is_success($status)) {
        if ($response->{STATUS} eq 'SUCCESS') {
            my %data = (response => $response);
            return \%data;
        } else {
            die "Invalid transaction";
        }
    } else {
        $self->handle_error($status, $response);
        die "Error communicating with Paypal";
    }
}

=head2 _do_request

Send the request and return the status code and body

=cut

sub _do_request {
    my ($self, $curl) = @_;
    my $response_body;
    $self->_set_url($curl, $self->_get_paypal_url);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
    my $curl_return_code = $curl->perform;
    if ($curl_return_code == 0) {
        my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
        return ($response_code, $response_body);
    }
    else {
        die "Error send request: " . $curl->errbuf;
    }
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
    my ($self, $curl, $url) = @_;
    $curl->setopt(CURLOPT_URL, $url);
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
    # Paypal now requires minimum TLS 1.2
    $curl->setopt(CURLOPT_SSLVERSION, 6);
    return $curl;
}

=head2 _build_query

Build a query string from a list of parameters

=cut

sub _build_query {
    my (@params) = @_;
    my $query = join("&", pairmap {"$a=" . uri_escape($b)} @params );
    return $query;
}

=head2 _notify_synch

Calls the notify-synch command

=cut

sub _notify_synch {
    my ($self, $txn) = @_;
    my $curl = $self->curl;
    $self->_set_body($curl, _build_query(tx => $txn, at => $self->identity_token, cmd => '_notify-synch'));
    my ($code, $response) = $self->_do_request($curl);
    if (is_success($code)) {
        my ($status, @params) = split(/\n/, $response);
        my %response = map {my ($k, $v) = split('=', $_); uri_unescape($k), uri_unescape($v)} @params;
        $response{STATUS} = $status;
        return ($code, \%response);
    } else {
        die "Error communicationg with paypal";
    }
}

=head2 _notify_validate

Validate a notify message

=cut

sub _notify_validate {
    my ($self, $query) = @_;
    my $curl = $self->curl;
    $self->_set_body($curl, "cmd=_notify-validate&" . $query);
    my ($code, $response) = $self->_do_request($curl);
    if (is_success($code)) {
        return ($code, $response);
    } else {
        die "Error communicationg with paypal";
    }
}

=head2 _get_paypal_url

Get the paypal url to use

=cut

sub _get_paypal_url {
    my ($self) = @_;
    return $self->test_mode ? $PAYPAL_SANDBOX_URL : $PAYPAL_URL;
}

=head2 handle_hook

Handle hook

=cut

sub handle_hook {
    my ($self, $headers, $content) = @_;
    my ($status, $response) = $self->_notify_validate($content);
    if (is_success($status)) {
        if ($response eq 'VERIFIED') {
        } else {
        }
    }
    return HTTP_OK;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
