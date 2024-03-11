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
use MIME::Base64 qw(encode_base64 decode_base64);
use Crypt::PK::ECC;
use Data::Dumper;
use pf::util qw(normalize_time);

extends 'pf::mfa';

use pf::log;

sub module_description { 'Akamai MFA' }

sub cache { return pf::CHI->new(namespace => 'mfa'); }


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

=head2 signing_key

The application signing key

=cut

has signing_key => ( is => 'rw' );

=head2 verify_key

The application verify_key

=cut

has verify_key => ( is => 'rw' );

=head2 callback_url

The application callback url

=cut

has callback_url => ( is => 'rw' );

=head2 radius_mfa_method

The RADIUS MFA Method to use

=cut

has radius_mfa_method => ( is => 'rw' );

=head2 split_char

Character that split the username and otp

=cut

has split_char => (is => 'rw' );

our %ACTIONS = (
    "push" => \&push,
    "sms"  => \&generic_method,
    "totp"  => \&totp,
    "phone" => \&generic_method,
    "check_auth" => \&check_auth,
);

our %METHOD_ALIAS =(
    "push"  => "push",
    "sms"   => '^(sms|text)_otp$',
    "phone" => "call_otp"
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
       return $FALSE;
    }
    if (exists($devices->{'result'}->{'policy_decision'})) {
        if ($devices->{'result'}->{'policy_decision'} eq "bypass") {
            $logger->info("Policy decision is bypass, allow access");
            return $TRUE;
        }
        if ($devices->{'result'}->{'policy_decision'} ne "authenticate_user") {
            $logger->error($devices->{'result'}->{'policy_decision'});
            return $FALSE;
        }
    }


    my @default_device;
    if (defined($device)) {
       @default_device = grep { $_->{'device'} eq $device } @{$devices->{'result'}->{'devices'}};
    } else {
       @default_device = grep { $_->{'default'} eq "true" } @{$devices->{'result'}->{'devices'}};
    }

    if ($self->radius_mfa_method eq 'push') {
       if ( grep $_ eq 'push', @{$default_device[0]->{'methods'}}) {
            return $ACTIONS{'push'}->($self,$default_device[0]->{'device'},$username);
       }
    }
    else {
        if (defined $otp) {
            if ($otp =~ /^\d{6,6}$/ || $otp =~ /^\d{16,16}$/) {
                if ( grep $_ eq 'totp', @{$default_device[0]->{'methods'}}) {
                    return $ACTIONS{'totp'}->($self,$default_device[0]->{'device'},$username,$otp,$devices);
                } else {
                    $logger->info("Unsupported method totp on device ".$default_device[0]->{'name'});
                    return $FALSE;
                }
            } elsif ($otp =~ /^\d{8,8}$/) {
                $logger->info("OTP Verification");
                return $ACTIONS{'check_auth'}->($self,$default_device[0]->{'device'},$username,$otp,$devices);
            } elsif ($otp =~ /^(sms|push|phone)(\d?)$/i) {
                my @device = $self->select_phone($devices->{'result'}->{'devices'}, $2);
                my $method = $1;
                foreach my $device (@device) {
                    if ( grep $_ =~ $METHOD_ALIAS{$method}, @{$device->{'methods'}}) {
                        return $ACTIONS{$method}->($self,$device->{'device'},$username,$1,$devices);
                    } else {
                        $logger->info("Unsupported method on device ".$device->{'name'});
                        return $FALSE;
                    }
                }
            } else {
                $logger->info("Method not supported");
                return $FALSE;
            }
        } elsif ($self->radius_mfa_method eq 'sms' || $self->radius_mfa_method eq 'phone') {
            my @device = $self->select_phone($devices->{'result'}->{'devices'}, undef);
            foreach my $device (@device) {
                if ( grep $_ =~ $METHOD_ALIAS{$self->radius_mfa_method}, @{$device->{'methods'}}) {
                    return $ACTIONS{$self->radius_mfa_method}->($self,$device->{'device'},$username,$self->radius_mfa_method);
                } else {
                    $logger->info("Unsupported method on device ".$device->{'name'});
                    return $FALSE;
                }
            }
        } else {
            $logger->error("OTP is empty");
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
    my ($self, $device, $username, $otp, $devices) = @_;
    my $logger = get_logger();
    my $method = "offline_otp";
    if (length($otp) == 16) {
        $method = "bypass_code";
    }
    $logger->info("Trigger $method for user $username on $device");
    my $post_fields = encode_json({device => $device, method => { $method => {"code" => $otp} } , username => $username});
    my ($auth, $error) = $self->_post_curl("/api/v1/verify/start_auth", $post_fields);
    if ($error) {
        return $FALSE;
    }
    if ($auth->{'result'}->{'status'} eq 'allow') {
        $logger->info("Authentication sucessfull on Akamai MFA");
        return $TRUE;
    }
    $logger->info("Authentication denied on Akamai MFA, reason: ". $auth->{'result'}->{'status'}->{'deny'}->{'reason'});
    return $FALSE;
}

=head2 generic_method

generic method

=cut

sub generic_method {
    my ($self, $device, $username, $method) =@_;
    my $logger = get_logger();
    $logger->info("Trigger $method for user $username");
    my $post_fields = encode_json({device => $device, method => $METHOD_LOOKUP{$method}, username => $username});
    my ($auth, $error)= cache->compute($device.$METHOD_LOOKUP{$method}, {expires_in => normalize_time($self->cache_duration)}, sub {
            return $self->_post_curl("/api/v1/verify/start_auth", $post_fields);
        }
    );
    if ($error) {
        return $FALSE;
    }
    # Cache the method to fetch it on the 2nd radius request (TODO: cache expiration should be in config).
    if (!cache->get($username)) {
        my $infos = { username => $username,
                      device   => $device,
                      tx       => $auth->{'result'}->{'tx'},
                    };
        cache->set($username, $infos, normalize_time($self->cache_duration));
    }
    # Remove the authenticated status of the user since the next radius requests will use OTP
    cache->remove($username." authenticated");
    return $FALSE;
}

=head2 push

push method

=cut

sub push {
    my ($self, $device, $username) =@_;
    my $logger = get_logger();
    $logger->info("Trigger push for user $username");
    my $post_fields = encode_json({device => $device, method => "push", username => $username});
    my ($auth, $error)= cache->compute($device."push", {expires_in => normalize_time($self->cache_duration)}, sub {
            return $self->_post_curl("/api/v1/verify/start_auth", $post_fields);
        }
    );
    if ($error) {
        return
    }
    my $i = 0;
    while($TRUE) {
        my ($answer, $error) = $self->_get_curl("/api/v1/verify/check_auth?tx=".$auth->{'result'}->{'tx'});
        return $FALSE if $error;
        if ($answer->{'result'} eq 'allow') {
            return $TRUE;
        }
        sleep(5);
        last if ($i++ == 6);
    }
    return $FALSE;
}

=head2

check_auth

=cut

sub check_auth {
    my ($self, $device, $username, $otp, $devices) = @_;
    my $logger = get_logger();
    if (my $infos = cache->get($username)) {
        my $post_fields = encode_json({tx => $infos->{'tx'}, user_input => $otp});
        my ($return, $error) = $self->_get_curl("/api/v1/verify/check_auth?tx=".$infos->{'tx'}."&user_input=".$otp);
        return $FALSE if $error;
        if ($return->{'result'} eq 'allow') {
            $logger->info("Authentication successfull");
            return $TRUE;
        } else {
            return $FALSE;
        }
    } else {
        foreach my $device (@{$devices->{'result'}->{'devices'}}) {
            if ( grep $_ =~ "hardware_token", @{$device->{'methods'}}) {
                return $ACTIONS{'totp'}->($self,$device->{'device'},$username,$otp);
            }
        }
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

=head2 decode_response

Decode json response

=cut

sub decode_response {
    my ($self, $code, $response_body) = @_;
    my $logger = get_logger();
    if ( $code != 200 ) {
        $logger->error("Unauthorized to contact Akamai MFA: $response_body");
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

    $uri = $self->proto."://".$self->host.$uri;

    $logger->debug($uri);
    $logger->debug(Dumper $post_fields);

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
    $curl->setopt(CURLOPT_TIMEOUT_MS, 3000);

    my $epoc = time();
    my $signature = hmac_sha256_hex($epoc, $self->signing_key);

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

    $uri = $self->proto."://".$self->host.$uri;

    $logger->debug($uri);

    my $curl = WWW::Curl::Easy->new;

    my $response_body = '';
    open(my $fileb, ">", \$response_body);
    $curl->setopt(CURLOPT_URL, $uri );
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0);
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_WRITEDATA,$fileb);
    $curl->setopt(CURLOPT_TIMEOUT_MS, 3000);
    my $epoc = time();
    my $signature = hmac_sha256_hex($epoc, $self->signing_key);

    $curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPHEADER(), ['Accept: application/json', "X-Pushzero-Signature-Time: ".$epoc, "X-Pushzero-Signature: ".$signature, "X-Pushzero-Id: ".$self->app_id]);

    $logger->debug("Calling Authentication API service using URI : $uri");

    # Starts the actual request
    my $curl_return_code = $curl->perform;
    my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
    return $self->decode_response($response_code, $response_body);
}

=head2 verify_response

Verify the Akamai MFA response

=cut

sub verify_response {
    my ($self, $params, $username) = @_;
    my $token = decode_json(decode_base64($params->{token}));
    my $ecc = Crypt::PK::ECC->new->import_key_raw(decode_base64($self->verify_key), 'secp256r1');
    if(!$ecc->verify_message(pack("H*",$token->{signature}), $token->{payload}, "SHA256")) {
        return 0;
    }
    my $response = decode_json($token->{payload});
    if ($response->{response}->{result} eq "ALLOW" && $response->{response}->{username} eq $username) {
        $self->set_mfa_success($username);
        return $TRUE;
    }
    return ($response->{response}->{result} eq "ALLOW" && $response->{response}->{username} eq $username);
}

=head2 redirect_info

Generate redirection information

=cut

sub redirect_info {
    my ($self, $username, $session_id, $relay_state) = @_;
    my $logger = get_logger();
    $logger->info("MFA USERNAME: ".$username);
    my $param;
    my $url = $self->callback_url;
    if ($session_id || $relay_state) {
        $param = '?';
    }
    if($session_id) {
        $url .= $param."CGISESSION_PF=".$session_id;
        $param = '&';
    }
    if($relay_state) {
        $url .= $param."RelayState=".$relay_state;
    }
    my $payload = {
        version => "2.0.0",
        timestamp => time(),
        request => {
            username => $username,
            callback => $url,
        },
    };
    $payload = encode_json($payload);

    my $sig = hmac_sha256_hex($payload, $self->signing_key);

    my $body = {
        app_id => $self->app_id,
        payload => $payload,
        signature => $sig,
    };
    $self->set_redirect($username);
    return {
        challenge_url => $self->proto."://" . $self->host . "/api/v1/bind/challenge/v2",
        challenge_verb => "POST",
        challenge_fields => {
                        token => encode_base64(encode_json($body), ''),
                },
    };
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
