package pf::mfa::Akamai_bind_v2;

=head1 NAME

pf::mfa::Akamai_bind_v2

=cut

=head1 DESCRIPTION

pf::mfa::Akamai

=cut

use strict;
use warnings;
use Moo;
use pf::constants;
use Digest::SHA qw(hmac_sha256_hex);
use JSON::MaybeXS qw(encode_json decode_json );
use MIME::Base64 qw(encode_base64 decode_base64);
use Crypt::PK::ECC;


extends 'pf::mfa';

use pf::log;

sub module_description { 'Akamai Bind v2 MFA' }

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

=head2 callback_url

The application callback url

=cut

has callback_url => ( is => 'rw' );

=head2 signing_key

The application signing key

=cut

has signing_key => ( is => 'rw' );

=head2 verify_key

The application verify_key

=cut

has verify_key => ( is => 'rw' );

sub verify_response {
    my ($self, $params, $username) = @_;
    my $token = decode_json(decode_base64($params->{token}));
    my $ecc = Crypt::PK::ECC->new->import_key_raw(decode_base64($self->verify_key), 'secp256r1');
    if(!$ecc->verify_message(pack("H*",$token->{signature}), $token->{payload}, "SHA256")) {
        return 0;
    }
    my $response = decode_json($token->{payload});
    return ($response->{response}->{result} eq "ALLOW" && $response->{response}->{username} eq $username);
}

sub redirect_info {
    my ($self, $username) = @_;
    my $logger = get_logger();
    $logger->warn("MFA USERNAME: ".$username);
    my $payload = {
        version => "2.0.0",
        timestamp => time(),
        request => {
            username => $username,
            callback => $self->callback_url,
        },
    };
    $payload = encode_json($payload);

    my $sig = hmac_sha256_hex($payload, $self->signing_key);

    my $body = {
        app_id => $self->app_id,
        payload => $payload,
        signature => $sig,
    };

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
