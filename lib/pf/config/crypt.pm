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
use pf::file_paths qw($system_init_key_file);

our $PREFIX = 'PF_ENC[';
our $ITERATION_COUNT = 5000;
our $HASH_TYPE = 'SHA256';
our $LEN = 32;
our $SYSTEM_INIT_KEY = '';
our $DERIVED_KEY;

BEGIN {
    $ITERATION_COUNT = 5000;
    $HASH_TYPE = 'SHA256';
    $LEN = 32;
    my $val = $ENV{PF_SYSTEM_INIT_KEY};
    if ($val) {
        $SYSTEM_INIT_KEY = $val;
    } else {
        open(my $fh, "<", $system_init_key_file) or die "open($system_init_key_file): $!";
        local $/ = undef;
        $SYSTEM_INIT_KEY = <$fh>;
        close($fh);
    }
}

sub derived_key {
    return pbkdf2($SYSTEM_INIT_KEY, 'packetfence', $ITERATION_COUNT, $HASH_TYPE, $LEN);
}

BEGIN {
    if ($SYSTEM_INIT_KEY eq '') {
        die "system init key";
    }

    $DERIVED_KEY = derived_key();
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
    my ($text) = @_;
    if (rindex($text, $PREFIX, 0) == 0) {
        return $text;
    }

    my $iv = random_bytes(12);
    my $ad = '';
    my ($ciphertext, $tag) = gcm_encrypt_authenticate('AES', $DERIVED_KEY, $iv, $ad, $text);
    return 'PF_ENC[' . encode_tags(data => $ciphertext, tag => $tag, iv => $iv, ad => $ad) . ']';
}

sub pf_decrypt {
    my ($data) = @_;
    if (rindex($data, $PREFIX, 0) != 0) {
        return $data;
    }
    my $tags = decode_tags($data);
    return gcm_decrypt_verify('AES', $DERIVED_KEY, $tags->{iv}, $tags->{ad}, $tags->{data}, $tags->{tag});
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

