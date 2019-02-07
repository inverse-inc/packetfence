package pf::Authentication::Source::AuthorizeNetSource;

=head1 NAME

pf::Authentication::Source::AuthorizeNetSource

=cut

=head1 DESCRIPTION

Object oriented class to interact with Authorize.Net payment gateway using Accept.js

=cut

use strict;
use warnings;
use Moose;

use pf::Authentication::constants;
use pf::config qw($default_pid $fqdn);
use pf::constants qw($FALSE $TRUE);
use pf::log;
use pf::util;

use LWP::UserAgent;
use XML::Simple;

extends 'pf::Authentication::Source::BillingSource';
with 'pf::Authentication::CreateLocalAccountRole';


=head2 Attributes

=cut

has '+class'            => (default => 'billing');

has '+type'             => (default => 'AuthorizeNet');

has 'acceptjs_uri'      => (is => 'rw');

has 'acceptjs_prod_uri' => (is => 'rw', default => 'https://js.authorize.net/v1/Accept.js');

has 'acceptjs_test_uri' => (is => 'rw', default => 'https://jstest.authorize.net/v1/Accept.js');

has 'api_uri'           => (is => 'rw');

has 'api_prod_uri'      => (is => 'rw', default => 'https://api.authorize.net/xml/v1/request.api');

has 'api_test_uri'      => (is => 'rw', default => 'https://apitest.authorize.net/xml/v1/request.api');

has 'api_login_id'      => (is => 'rw', required => 1);

has 'transaction_key'   => (is => 'rw', required => 1);

has 'public_client_key' => (is => 'rw', required => 1);

has 'domains'           => (is => 'rw', required => 1, default => '*.authorize.net');


=head2 prepare_payment

Prepare the payment from authorize.net

=cut

sub prepare_payment {
    my ($self, $session, $tier, $params, $uri) = @_;

    $self->_set_uris();

    return {};
}


=head2 verify

Verify the payment from authorize.net

=cut

sub verify {
    my ($self, $session, $parameters, $uri) = @_;
    my $logger = pf::log::get_logger;

    my $error_message;

    unless ( defined $parameters->{'dataValue'} ) {
        $error_message = "No Payment Nonce found";
        $logger->warn($error_message);
        die $error_message;
    }

    $self->_set_uris();

    my $response = $self->process_transaction($parameters, $session->{'tier'});
    $logger->debug("Authorize.Net response: ".Dumper($response));

    unless ( $response->{'transactionResponse'}->{'responseCode'} == 1 ) {
        my $msg = "Unable to process payment: ".$response->{transactionResponse}->{errors}->{error}->{errorText};
        $logger->error($msg);
        die $msg ;
    }

    return {};
}


=head2 cancel

Not implemented

=cut

sub cancel {
    my ($self, $session, $parameters, $uri) = @_;
    return {};
}


=head2 _set_uris

=cut

sub _set_uris {
    my ( $self ) = @_;
    my $logger = pf::log::get_logger;

    if ( $self->test_mode ) {
        $logger->debug("Running in test mode");
        $self->acceptjs_uri($self->acceptjs_test_uri);
        $self->api_uri($self->api_test_uri);
    }
    else {
        $logger->debug("Running in production mode");
        $self->acceptjs_uri($self->acceptjs_prod_uri);
        $self->api_uri($self->api_prod_uri);
    }
}

=head2 process_transaction

Process the transaction with Authorize.net using the amount and the payment nonce

=cut

sub process_transaction {
    my ( $self, $params, $tier ) = @_;
    my $logger = pf::log::get_logger;

    my $api_login_id = $self->api_login_id;
    my $transaction_key = $self->transaction_key;
    my $currency = $self->currency;

    my $transaction_xml = <<XMLREQUEST
<?xml version="1.0" encoding="UTF-8"?>
<createTransactionRequest xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
    <merchantAuthentication>
        <name>$api_login_id</name>
        <transactionKey>$transaction_key</transactionKey>
    </merchantAuthentication>
    <transactionRequest>
        <transactionType>authCaptureTransaction</transactionType>
        <amount>$tier->{'price'}</amount>
        <currencyCode>$currency</currencyCode>
        <payment>
            <opaqueData>
                <dataDescriptor>$params->{'dataDesc'}</dataDescriptor>
                <dataValue>$params->{'dataValue'}</dataValue>
            </opaqueData>
        </payment>
    </transactionRequest>
</createTransactionRequest>
XMLREQUEST
;

    my $ua = LWP::UserAgent->new;
    my $response = $ua->post($self->api_uri, Content => $transaction_xml);

    my $xml = new XML::Simple;
    return $xml->XMLin($response->decoded_content(), NoAttr => 1);
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
