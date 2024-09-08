package pf::config::crypt;

=head1 NAME

pf::config::crypt -

=head1 DESCRIPTION

pf::config::crypt

=cut

use strict;
use warnings;
use Crypt::KeyDerivation qw(pbkdf2);
use Crypt::Mode::CBC;
use Crypt::PRNG qw(random_bytes);
use Crypt::AuthEnc::GCM qw(gcm_encrypt_authenticate gcm_decrypt_verify);
use MIME::Base64;
use pf::config qw($unified_api_system_user);

my $ITERATION_COUNT = 5000;
my $HASH_TYPE = 'SHA256';
my $LEN = 32;

sub derived_key {
    my ($salt) = @_;
    return pbkdf2($unified_api_system_user->{pass}, $salt, $ITERATION_COUNT, $HASH_TYPE, $LEN);
}

sub encode_tags {
    if (@_ % 2) {
        die "odd number of passed";
    }
    my @parts;
    while (@_) {
        my ($id, $data) = (shift,shift);
        push @parts, "$id:". encode_base64($data, '');
    }

    return join(",", @parts);
}

sub decode_tags {
    my ($data) = @_;
    $data =~ /^PF_ENC\[(.*)\]/;
    my $tags = $1;
    my %parts;
    for my $part (split /\s*,\s*/, $tags) {
        my ($k, $v) = split ':', $part, 2;
        $parts{$k} = decode_base64($v);
    }
    return \%parts;
}

sub pf_encrypt {
    my ($text, $salt) = @_;
    my $iv = random_bytes(16);
    my $derived_key = derived_key($salt);
    my $ad = '';
    my ($ciphertext, $tag) = gcm_encrypt_authenticate('AES', $derived_key, $iv, $ad, $text);
    return 'PF_ENC[' . encode_tags(data => $ciphertext, tag => $tag, iv => $iv, salt => $salt, ad => $ad) . ']';
}

sub pf_decrypt {
    my ($data) = @_;
    my $tags = decode_tags($data);
    my $salt = $tags->{salt};
    my $derived_key = derived_key($salt);
    return gcm_decrypt_verify('AES', $derived_key, $tags->{iv}, $tags->{ad}, $tags->{data}, $tags->{tag});
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

