package pf::pki_provider::packetfence_pki;

=head1 NAME

pf::pki_provider::packetfence_pki

=cut

=head1 DESCRIPTION

pf::pki_provider::packetfence_pki

=cut

use strict;
use warnings;
use Moo;
use WWW::Curl::Easy;
use pf::constants;
use URI::Escape::XS qw(uri_escape uri_unescape);

extends 'pf::pki_provider';

use pf::log;

sub module_description { 'PacketFence PKI' }

=head2 host

The host of the packetfence_pki pki service

=cut

has host => ( is => 'rw', default => "127.0.0.1" );

=head2 port

The port of the packetfence_pki pki service

=cut

has port => ( is => 'rw', default => 9393 );

=head2 proto

The proto of the packetfence_pki pki service

=cut

has proto => ( is => 'rw', default => "https" );

=head2 username

The username to connect to the packetfence_pki pki service

=cut

has username => ( is => 'rw' );

=head2 password

The password to connect to the packetfence_pki pki service

=cut

has password => ( is => 'rw' );

=head2 profile

The profile to use for the packetfence_pki pki service

=cut

has profile => ( is => 'rw' );

sub _post_curl {
    my ($self, $uri, $post_fields) = @_;
    my $logger = get_logger();

    $uri = $self->proto."://".$self->host.":".$self->port.$uri;

    my $username = $self->username;
    my $password = $self->password;
    my $curl = WWW::Curl::Easy->new;
    my $request = $post_fields;

    my $response_body = '';
    $curl->setopt(CURLOPT_POSTFIELDSIZE,length($request));
    $curl->setopt(CURLOPT_POSTFIELDS, $request);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
    $curl->setopt(CURLOPT_NOSIGNAL, 1);
    $curl->setopt(CURLOPT_URL, $uri);
    $curl->setopt(CURLOPT_SSL_VERIFYHOST, 0);
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0);
    $curl->setopt(CURLOPT_USERNAME, $username);
    $curl->setopt(CURLOPT_PASSWORD, $password);

    $logger->debug("Calling PacketFence PKI service using URI : $uri");

    # Starts the actual request
    my $curl_return_code = $curl->perform;

    my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
    return ($curl_return_code, $response_code, $response_body, $curl);


}

=head2 get_bundle

Get the certificate bundle from the packetfence_pki pki service

=cut

sub get_bundle {
    my ($self,$args) = @_;
    my $logger = get_logger();

    my $email = $args->{'certificate_email'};
    my $cn = $args->{'certificate_cn'};
    my $organisation = $self->organization;
    my $state = $self->state;
    my $profile = $self->profile;
    my $country = $self->country;
    my $certpwd = $args->{'certificate_pwd'};

    my $uri = "/pki/cert/rest/get/".uri_escape($cn)."/";

    my $post_fields =
      "mail=" . uri_escape($email)
      . "&organisation=" . uri_escape($organisation)
      . "&st=" . uri_escape($state)
      . "&country=" . uri_escape($country)
      . "&profile=" . uri_escape($profile)
      . "&pwd=" . uri_escape($certpwd);

    my ($curl_return_code, $response_code, $response_body, $curl) = $self->_post_curl($uri, $post_fields);
    if ($curl_return_code == 0 && $response_code == 200) {
        return $response_body;
    }
    else {
        my $curl_error = $curl->errbuf;
        $logger->error("certificate could not be acquire, check out logs on the pki. Server replied with $response_body. Curl error : $curl_error");
        return undef;
    }


}

=head2 revoke

Revoke the certificate for a user

=cut

sub revoke {
    my ($self, $cn) = @_;
    my $logger = get_logger();
    my $uri = "/pki/cert/rest/revoke/".$cn."/";
    my $post_fields =
      "CRLReason=" . uri_escape("superseded");

    my ($curl_return_code, $response_code, $response_body, $curl) = $self->_post_curl($uri, $post_fields);
    if ($curl_return_code == 0 && $response_code == 200) {
        $logger->info("Revoked certificate for CN $cn");
        return $TRUE;
    }
    else {
        my $curl_error = $curl->errbuf;
        $logger->error("Certificate for CN $cn could not be revoked. Server replied with $response_body. Curl error : $curl_error");
        return $FALSE;
    }


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
