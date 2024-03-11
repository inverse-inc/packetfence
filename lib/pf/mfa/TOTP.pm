package pf::mfa::TOTP;

=head1 NAME

pf::mfa::TOTP

=cut

=head1 DESCRIPTION

pf::mfa::TOTP

=cut

use strict;
use warnings;
use Moo;
use pf::person;
use pf::constants qw($TRUE $FALSE);
use pf::log;
use Digest::SHA qw(hmac_sha1_hex);
use pf::util qw(normalize_time);

extends 'pf::mfa';

=head2 radius_mfa_method

The RADIUS MFA Method to use

=cut

has radius_mfa_method => ( is => 'rw' );

=head2 split_char

Character that split the username and otp

=cut

has split_char => (is => 'rw' );

sub module_description { 'Generic TOTP MFA' }

=head2 check_user

Get the devices of the user

=cut

sub check_user {
    my ($self, $username, $otp, $device) = @_;
    my $logger = get_logger();
    if ($self->radius_mfa_method eq 'strip-otp' || $self->radius_mfa_method eq 'second-password') {
        if ($otp =~ /^\d{6,6}$/) {
            return $self->verify_otp($username, $otp);
        } else {
            $logger->warn("Method not supported");
            return $FALSE;
        }
    }
}

sub verify_otp {
    my ($self, $username, $otp) = @_;
    my $logger = get_logger();
    my $person = person_view($username);
    if (defined $person->{otp} && $person->{otp} ne '') {
        my $local_otp = $self->generateCurrentNumber($person->{otp});
        if ($otp == $local_otp) {
            $self->set_mfa_success($username);
            $logger->info("OTP token match");
            return $TRUE;
        }
        $logger->info("OTP token doesnt match");
        return $FALSE;
    }
    $logger->info("The user who try to authenticate hasn't enrolled");
    return $FALSE;
}

sub generateCurrentNumber {
    my ($self, $otp) = @_;

    my $paddedTime = sprintf("%016x", int(time() / 30));
    my $data = pack('H*', $paddedTime);
    my $key = $self->decodeBase32($otp);

    my $hmac = hmac_sha1_hex($data, $key);

    my $offset = hex(substr($hmac, -1));
    my $encrypted = hex(substr($hmac, $offset * 2, 8)) & 0x7fffffff;

    my $token = $encrypted % 1000000;
    return sprintf("%06d", $token);

}

sub decodeBase32 {
    my ($self, $val) = @_;

    $val =~ tr|A-Z2-7|\0-\37|;
    $val = unpack('B*', $val);

    $val =~ s/000(.....)/$1/g;
    my $len = length($val);
    $val = substr($val, 0, $len & ~7) if $len & 7;

    $val = pack('B*', $val);
    return $val;
}

=head2 redirect_info

Generate redirection information

=cut

sub redirect_info {
    my ($self, $username) = @_;
    my $logger = get_logger();
    $logger->info("MFA USERNAME: ".$username);
    my ($exist, $otp) = $self->generate_otp($username);
    $self->set_redirect($username);
    return {
        exist => $exist,
        username => $username,
        otp => $otp
    };
}

sub generate_otp {
    my ($self ,$username) = @_;
    my $person = person_view($username);
    if ($person && exists($person->{otp}) && defined $person->{otp} && $person->{otp} ne '') {
        get_logger->debug("Returning OTP key $person->{otp} for user $username");
        return ($TRUE, $person->{otp});
    }
    else {
        my @chars = ("A".."Z", "2".."7");
        my $length = scalar(@chars);
        my $base32Secret = "";
        for (my $i = 0; $i < 16; $i++) {
            $base32Secret .= $chars[rand($length)];
        }
        person_modify($username,otp => $base32Secret);
        get_logger->info("OTP key has been generated for user ".$username);
        return ($FALSE, $base32Secret);
    }
}


=head2 verify_response

Verify the response

=cut

sub verify_response {
    my ($self, $params, $username) = @_;
    return $self->verify_otp($username, $params->{otp});
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
