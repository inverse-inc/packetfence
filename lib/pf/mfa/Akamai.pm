package pf::mfa::Akamai;

=head1 NAME

pf::mfa::Akamai

=cut

=head1 DESCRIPTION

pf::mfa::Akamai

=cut

use strict;
use warnings;
use Moo;
use pf::constants;
use Digest::SHA qw(hmac_sha256 hmac_sha256_hex hmac_sha256_base64);
use JSON::MaybeXS qw(encode_json decode_json );
use WWW::Curl::Easy;
use URI::Escape::XS qw(uri_escape);
use pf::constants qw($TRUE $FALSE);

extends 'pf::mfa';

use pf::log;

sub module_description { 'Akamai MFA' }

=head2 host

The host of the Akamai MFA

=cut

has host => ( is => 'rw', default => "mfa.akamai.com" );

=head2 port

The port of the Akamai MFA

=cut

has port => ( is => 'rw', default => 443 );

=head2 proto

The proto of the Akamai MFA

=cut

has proto => ( is => 'rw', default => "https" );

=head2 app_id

The application id of the Akamai MFA

=cut

has app_id => ( is => 'rw' );

=head2 app_secret

The app_secret of the Akamai MFA

=cut

has app_secret => ( is => 'rw' );

=head2 check_user

Get the devices of the user

=cut

sub check_user {
    my ($self, $username) = @_;
    my $logger = get_logger();

    my ($devices, $error) = $self->_get_curl("/api/v1/verify/check_user?username=$username");

    if ($error == 1) {
        $logger->error("Not able to fetch the devices");
        return;
    }

    my @device = grep {exists $_->{'default'} } @{$devices->{'result'}->{'devices'}};

    if ( grep $_ eq 'push', @{$device[0]->{'methods'}}) {
        my $post_fields = encode_json({device => $device[0]->{'device'}, method => "push", username => $username});

	my ($auth, $error) = $self->_post_curl("/api/v1/verify/start_auth", $post_fields);
        if ($error) {
            return
	}
        my $i = 0;
	while(1) {
            my ($answer, $error) = $self->_get_curl("/api/v1/verify/check_auth?tx=".$auth->{'result'}->{'tx'});
	    if ($answer->{'result'} eq 'allow') {
                return $TRUE;
	    }
	    sleep(5);
            last if ($i++ == 6);
	}
        return $FALSE;
    }
}

=head2 devices_list

Get the devices list of the user

=cut

sub devices_list {

    my ($self, $username) = @_;
    my $logger = get_logger();

    my ($devices, $error) = $self->_get_curl("/api/v1/verify/check_user?username=$username");

    if ($error == 1) {
        $logger->error("Not able to fetch the devices");
        return undef;
    }
    return $devices->{result}->{devices};
}

=head2 push_method

Push on the device

=cut

sub push_method {
    my ($self, $device, $username) = @_;
    my $post_fields = encode_json({device => $device, method => "push", username => $username});

    my ($auth, $error) = $self->_post_curl("/api/v1/verify/start_auth", $post_fields);
    if ($error) {
        return
    }

    my $i = 0;
    while(1) {
        my ($answer, $error) = $self->_get_curl("/api/v1/verify/check_auth?tx=".$auth->{'result'}->{'tx'});
        if ($answer->{'result'} eq 'allow') {
            return $TRUE;
        }
        sleep(5);
        last if ($i++ == 6);
    }
    return $FALSE;
}



sub decode_response {
    my ($self, $code, $response_body) = @_;
    my $logger = get_logger();
    if ( $code != 200 ) {
        $logger->error("Unauthorized to contact Akamai MFA");
        return undef,1;
    }
    elsif($code == 200){
        my $json_response = decode_json($response_body);
        return $json_response,0;
    }
}


=head2 _post_curl

Method used to build a basic curl object

=cut

sub _post_curl {
    my ($self, $uri, $post_fields) = @_;
    my $logger = get_logger();

    $uri = $self->proto."://mfa.akamai.com".$uri;

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

    my $epoc = time();
    my $signature = hmac_sha256_hex($epoc, $self->app_secret);

    $curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPHEADER(), ['Accept: application/json', "X-Pushzero-Signature-Time: ".$epoc, "X-Pushzero-Signature: ".$signature, "X-Pushzero-Id: ".$self->app_id]);

    $logger->debug("Calling Authentication API service using URI : $uri");

    # Starts the actual request
    my $curl_return_code = $curl->perform;
    my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
    return $self->decode_response($response_code, $response_body);
}

=head2 _get_curl

Method used to build a basic curl object

=cut

sub _get_curl {
    my ($self, $uri) = @_;
    my $logger = get_logger();

    $uri = $self->proto."://mfa.akamai.com/".$uri;

    my $curl = WWW::Curl::Easy->new;

    my $response_body = '';
    open(my $fileb, ">", \$response_body);
    $curl->setopt(CURLOPT_URL, $uri );
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0);
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_WRITEDATA,$fileb);
    my $epoc = time();
    my $signature = hmac_sha256_hex($epoc, $self->app_secret);

    $curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPHEADER(), ['Accept: application/json', "X-Pushzero-Signature-Time: ".$epoc, "X-Pushzero-Signature: ".$signature, "X-Pushzero-Id: ".$self->app_id]);

    $logger->debug("Calling Authentication API service using URI : $uri");

    # Starts the actual request
    my $curl_return_code = $curl->perform;
    my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
    return $self->decode_response($response_code, $response_body);
}

=head2 encode_params

Encodes a hash into URL/BODY parameters

=cut

sub encode_params {
    my %hash = @_;
    my @pairs;
    for my $key (keys %hash) {
        push @pairs, join "=", map { uri_escape($_) } $key, $hash{$key};
    }
    return join "&", @pairs;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
