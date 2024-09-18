package pf::util::wpa;

use strict;
use warnings;

use List::Util qw(minstr maxstr);
use pf::log;
use Crypt::PBKDF2;
use Digest::SHA qw(hmac_sha1);
use Crypt::KeyDerivation qw(pbkdf2);
use bytes;

my $PKE = "Pairwise key expansion";

sub strip_hex_prefix {
    my ($s) = @_;
    $s =~ s/^0x//g;
    return $s;
}

sub prf512 {
    my ($key,$A,$B) = @_;
    my $blen = 64;
    my $i    = 0;
    my $R    = '';
    while($i<=(($blen*8+159)/160)) {
        my $hmacsha1 = hmac_sha1($A.chr(0x00).$B.chr($i), $key);
        $i+=1;
        $R = $R.$hmacsha1;
    }
    return bytes_range($R, 0, $blen);
}

sub bytes_range {
    my ($str, $start, $end) = @_;
    if(!defined $end) {
        $end = length($str);
    }
    my $size = $end - $start;
    return substr($str, $start, $size);
}

sub calculate_pmk_slow {
    my ($ssid, $psk) = @_;
    my $pbkdf2 = Crypt::PBKDF2->new(
        iterations => 4096,
        output_len => 32,
    );
     
    my $pmk = bytes_range($pbkdf2->PBKDF2($ssid, $psk), 0, 32);

    get_logger->debug("PTK is ".unpack("H*", $pmk));
    return $pmk;
}

sub calculate_pmk {
    my ($ssid, $psk) = @_;
    my $pmk = pbkdf2($psk, $ssid, 4096, 'SHA1', 32);
    get_logger->debug("PTK is ".unpack("H*", $pmk));
    return $pmk;
}

sub calculate_ptk {
    my ($pmk, $mac_ap, $mac_cl, $anonce, $snonce) = @_;
    my $key_data = minstr($mac_ap, $mac_cl) . maxstr($mac_ap, $mac_cl) . minstr($anonce,$snonce) . maxstr($anonce,$snonce);
    my $ptk = prf512($pmk, $PKE, $key_data);
    get_logger->debug("PTK is ".unpack("H*", $ptk));
    return $ptk;
}

sub snonce_from_eapol_key_frame {
    my ($eapol_key_frame) = @_;
    return bytes_range($eapol_key_frame, 17, 49);
}

sub match_mic {
    my ($ptk, $eapol_key_frame) = @_; 

    # extract the MIC from the packet and zero it out to calculate the MIC based on the PTK
    my $packet_mic = bytes_range($eapol_key_frame, 81, 97);
    $eapol_key_frame = bytes_range($eapol_key_frame, 0, 81) . chr(0x0) x 16 . bytes_range($eapol_key_frame, 97);

    my $kck = bytes_range($ptk, 0, 16);
    get_logger->debug("KCK is ".unpack("H*", $kck));

    my $mic = bytes_range(hmac_sha1($eapol_key_frame, $kck), 0, 16);

    my $packet_mic_hex = unpack("H*", $packet_mic);
    my $mic_hex = unpack("H*", $mic);
    get_logger->debug("Computed MIC of packet is $mic_hex and MIC inside the packet is $packet_mic_hex");

    return $packet_mic_hex eq $mic_hex;
}

1;
