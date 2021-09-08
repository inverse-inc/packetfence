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
use Digest::SHA qw(hmac_sha256_hex);
use JSON::MaybeXS qw(encode_json decode_json );
use WWW::Curl::Easy;
use pf::constants qw($TRUE $FALSE);


extends 'pf::mfa';

use pf::log;

sub module_description { 'Akamai MFA' }

=head2 host

The host of the Akamai MFA

=cut

has host => ( is => 'rw', default => "mfa.akamai.com" );

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

=head2 radius_mfa_method

The RADIUS MFA Method to use

=cut

has radius_mfa_method => ( is => 'rw' );

=head2 split_char

Caracter that split the username and otp

=cut

has split_char => (is => 'rw' );


our %ACTIONS = (
    "push" => \&push,
    "sms"  => \&generic_method,
    "totp"  => \&totp,
    "phone" => \&generic_method
);

our %METHOD_LOOKUP =(
    "push"  => "push",
    "sms"   => "sms_otp",
    "phone" => "call_otp"
);

=head2 check_user

Get the devices of the user

=cut

sub check_user {
    my ($self, $username, $otp, $device) = @_;
    my $logger = get_logger();
    my ($devices, $error) = $self->_get_curl("/api/v1/verify/check_user?username=$username");

    if ($error == 1) {
        $logger->error("Not able to fetch the devices");
        return;
    }
    my @default_device;
    if (defined($device)) {
        @default_device = grep { $_->{'device'} eq $device } @{$devices->{'result'}->{'devices'}};
    } else {
        @default_device = grep { $_->{'default'} eq "true" } @{$devices->{'result'}->{'devices'}};
    }
    if ($self->radius_mfa_method eq 'push') {
        if ( grep $_ eq 'push', @{$default_device[0]->{'methods'}}) {
            $self->${$ACTIONS{'push'}}->($default_device[0]->{'device'},$username);
        }
    }
    elsif ($self->radius_mfa_method eq 'strip-otp') {
        if ($otp =~ /^\d{6,6}$/ || $otp =~ /^\d{8,8}$/) {
            if ( grep $_ eq 'totp', @{$default_device[0]->{'methods'}}) {
                return $ACTIONS{'totp'}->($self,$default_device[0]->{'device'},$username,$otp);
            }
        } elsif ($otp =~ /^(sms|push|phone)(\d?)$/i) {
            my @device = $self->select_phone($devices->{'result'}->{'devices'}, $2);
	    foreach my $device (@device) {
                return $ACTIONS{$1}->($self,$device->{'device'},$username,$1);
            }
        } else {
            $logger->warn("Method not supported");
            return $FALSE;
        }
    }
}

=head2 select_phone

Select the phone to trigger the MFA

=cut

sub select_phone {
    my ($self, $devices, $phone_id) = @_;
    my $logger = get_logger();
    my @device;
    if (defined($phone_id) && $phone_id ne "") {
        if ($phone_id == 1 || $phone_id == 0) {
            # Return the default phone
            @device = grep { $_->{'default'} == 1} @{$devices};
        }
        # Return the n-1 phone
        @device = @{$devices}[$phone_id-1];
    } else {
        # Return the default phone
        @device = grep { $_->{'default'} == 1 } @{$devices};
    }
    return @device;
}

=head2 totp

totp method

=cut

sub totp {
    my ($self, $device, $username, $otp) = @_;
    my $logger = get_logger();
    my $post_fields = encode_json({device => $device, method => { "offline_otp" => {"code" => $otp} } , username => $username});
    my ($auth, $error) = $self->_post_curl("/api/v1/verify/start_auth", $post_fields);
    if ($error) {
        return $FALSE;
    }
    if ($auth->{'result'}->{'status'} eq 'allow') {
        $logger->warn("Authentication sucessfull on Akamai MFA");
        return $TRUE;
    }
    $logger->warn("Authentication denied on Akamai MFA, reason: ". $auth->{'result'}->{'status'}->{'deny'}->{'reason'});
    return $FALSE;
}

=head2 generic_method

generic method

=cut

sub generic_method {
    my ($self, $device, $username, $method) =@_;
    my $logger = get_logger();
    my $post_fields = encode_json({device => $device, method => $METHOD_LOOKUP{$method}, username => $username});
    my $chi = pf::CHI->new(namespace => 'mfa');
    my ($auth, $error)= $chi->compute($device.$METHOD_LOOKUP{$method}, sub {
            return $self->_post_curl("/api/v1/verify/start_auth", $post_fields);
        }
    );
    if ($error) {
        return $FALSE;
    }
    # Cache the method to fetch it on the 2nd radius request (TODO: cache expiration should be in config).
    if (!$chi->get($username)) {
        $chi->set($username, $device,30);
    }
    return $FALSE;
}

=head2 push

push method

=cut

sub push {
    my ($self, $device, $username) =@_;
    my $logger = get_logger();
    my $post_fields = encode_json({device => $device, method => "push", username => $username});
    my $chi = pf::CHI->new(namespace => 'mfa');
    my ($auth, $error)= $chi->compute($device."push", sub {
            return $self->_post_curl("/api/v1/verify/start_auth", $post_fields);
        }
    );
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

    $uri = "https://mfa.akamai.com/".$uri;

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

    $uri = "https://mfa.akamai.com/".$uri;

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
