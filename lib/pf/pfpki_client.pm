package pf::pfpki_client;

=head1 NAME

pf::pfpki_client - Fetch certificates, keys and CAs from the PacketFence PKI

=head1 DESCRIPTION

Thin wrapper around the pfpki API (proxied by the unified API under
/api/v1/pki) used to import pfpki certificates and CAs in other parts of the
configuration (RADIUS certificate, provisioners, PKI providers).

Every function returns a list C<($status, $result)> where C<$status> is
C<$TRUE> on success and C<$result> is either the result or an error message.

=cut

use strict;
use warnings;

use File::Temp qw(tempfile);
use File::Slurp qw(write_file);
use pf::api::unifiedapiclient;
use pf::constants qw($TRUE $FALSE);
use pf::log;
use pf::ssl;
use pf::util qw(safe_pf_run);

our $PEM_CERT_RE = qr/(-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----)/s;
our $PEM_KEY_RE = qr/(-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----.+?-----END (?:[A-Z]+ )?PRIVATE KEY-----)/s;

# x509.ExtKeyUsageServerAuth in Go's crypto/x509, as stored by pfpki
our $EXT_KEY_USAGE_SERVER_AUTH = 1;

=head2 api_call

Perform a call against the pfpki API and return its first item

=cut

sub api_call {
    my ($method, $path, $payload) = @_;
    my $response = eval {
        pf::api::unifiedapiclient->default_client->call($method, "/api/v1/pki/$path", $payload);
    };
    if ($@) {
        my $msg = "Unable to contact the PacketFence PKI: $@";
        get_logger->error($msg);
        return ($FALSE, $msg);
    }
    return ($TRUE, $response) if ref($response) ne 'HASH';

    # pfpki answers with a 200 even when the request failed
    if ($response->{error}) {
        get_logger->error("PacketFence PKI error on $path: $response->{error}");
        return ($FALSE, $response->{error});
    }
    my $item = ref($response->{items}) eq 'ARRAY' ? $response->{items}[0] : undef;
    if (!defined($item)) {
        return ($FALSE, "No result returned by the PacketFence PKI for $path");
    }
    return ($TRUE, $item);
}

=head2 ca

Get a CA from pfpki

=cut

sub ca {
    my ($ca_id) = @_;
    return api_call("GET", "ca/$ca_id");
}

=head2 ca_pem

Get the PEM certificate of a CA from pfpki

=cut

sub ca_pem {
    my ($ca_id) = @_;
    my ($status, $ca) = ca($ca_id);
    return ($status, $ca) unless $status;
    return ($FALSE, "The CA $ca_id has no certificate") unless $ca->{cert};
    return ($TRUE, $ca->{cert});
}

=head2 cert

Get a certificate from pfpki

=cut

sub cert {
    my ($cert_id) = @_;
    return api_call("GET", "cert/$cert_id");
}

=head2 profile

Get a profile (template) from pfpki

=cut

sub profile {
    my ($profile_id) = @_;
    return api_call("GET", "profile/$profile_id");
}

=head2 profile_allows_server_auth

Whether the extended key usages of a profile allow server authentication.
A profile without any extended key usage is not restricted.

=cut

sub profile_allows_server_auth {
    my ($profile) = @_;
    my $usages = $profile->{extended_key_usage} // '';
    return $TRUE if $usages eq '';
    return (grep { $_ eq $EXT_KEY_USAGE_SERVER_AUTH } split(/\|/, $usages)) ? $TRUE : $FALSE;
}

=head2 cert_bundle

Get the certificate, its private key and its CA from pfpki.
Returns a hash with the keys certificate, private_key and ca.

=cut

sub cert_bundle {
    my ($cert_id) = @_;
    my ($status, $cert) = cert($cert_id);
    return ($status, $cert) unless $status;
    if ($cert->{csr}) {
        return ($FALSE, "The certificate $cert->{cn} was signed from a CSR, its private key is not stored in the PacketFence PKI");
    }

    my $password = unpack("H*", join('', map { chr(int(rand(256))) } 1..16));
    ($status, my $p12) = api_call("GET", "cert/$cert_id/download/$password");
    return ($status, $p12) unless $status;
    if (ref($p12) || !defined($p12) || length($p12) == 0) {
        return ($FALSE, "The PacketFence PKI did not return a PKCS#12 bundle for the certificate $cert_id");
    }

    return parse_pkcs12($p12, $password);
}

=head2 parse_pkcs12

Extract the certificate, private key and CA from a PKCS#12 bundle

=cut

sub parse_pkcs12 {
    my ($p12, $password) = @_;
    my ($fh, $p12_file) = tempfile(UNLINK => 1);
    write_file($p12_file, { binmode => ':raw' }, $p12);

    my %parts = (
        certificate => ['-clcerts', '-nokeys'],
        ca => ['-cacerts', '-nokeys'],
        private_key => ['-nocerts', '-nodes'],
    );
    my %pem;
    while (my ($part, $args) = each %parts) {
        my $out = _openssl_pkcs12($p12_file, $password, @$args) // '';
        if (length($out) == 0 && $part ne 'ca') {
            unlink $p12_file;
            return ($FALSE, "Unable to read the PKCS#12 bundle returned by the PacketFence PKI");
        }
        $pem{$part} = $out;
    }
    unlink $p12_file;

    my ($certificate) = $pem{certificate} =~ $PEM_CERT_RE;
    my @cas = $pem{ca} =~ /$PEM_CERT_RE/g;
    my ($key) = $pem{private_key} =~ $PEM_KEY_RE;
    return ($FALSE, "No certificate found in the PKCS#12 bundle") unless $certificate;
    return ($FALSE, "No private key found in the PKCS#12 bundle") unless $key;

    # Only RSA keys are supported by the certificate installation (pf::ssl::rsa_from_string)
    my $rsa = eval { pf::ssl::rsa_from_string($key) };
    unless ($rsa) {
        return ($FALSE, "The private key of this certificate is not an RSA key, only RSA keys are supported");
    }

    return ($TRUE, {
        certificate => "$certificate\n",
        private_key => $rsa->get_private_key_string(),
        ca => join('', map { "$_\n" } @cas),
    });
}

sub _openssl_pkcs12 {
    my ($file, $password, @args) = @_;
    local $ENV{PFPKI_P12_PASSWORD} = $password;
    my @cmd = ("openssl", "pkcs12", "-in", $file, "-passin", "env:PFPKI_P12_PASSWORD", @args);
    my $out = safe_pf_run(@cmd, { accepted_exit_status => [1] });
    return $out if defined($out) && length($out);
    # Bundles produced by pfpki use RC2 which OpenSSL 3 only supports through the legacy provider
    return safe_pf_run(@cmd, "-legacy", { accepted_exit_status => [1] });
}

=head2 sign_csr

Have a pfpki profile (template) sign a CSR.
Returns a hash with the keys certificate, ca and warnings.

=cut

sub sign_csr {
    my ($profile_id, $csr) = @_;
    my ($status, $profile) = profile($profile_id);
    return ($status, $profile) unless $status;

    ($status, my $cert) = api_call("POST", "profile/$profile_id/sign_csr", { csr => $csr });
    return ($status, $cert) unless $status;
    return ($FALSE, "The PacketFence PKI did not return a signed certificate") unless $cert->{cert};

    ($status, my $ca) = ca_pem($profile->{ca_id});
    return ($status, $ca) unless $status;

    my @warnings;
    unless (profile_allows_server_auth($profile)) {
        push @warnings, "The template $profile->{name} does not allow the server authentication extended key usage, clients may reject this certificate";
    }

    return ($TRUE, {
        certificate => $cert->{cert},
        ca => $ca,
        warnings => \@warnings,
    });
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
