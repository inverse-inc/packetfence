#!/usr/bin/perl

=head1 NAME

pfpki_client

=cut

=head1 DESCRIPTION

unit test for pf::pfpki_client

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 15;
use Test::NoWarnings;
use File::Temp qw(tempdir);
use File::Slurp qw(read_file);

use pf::constants qw($TRUE $FALSE);
use pf::util qw(safe_pf_run);
use pf::pfpki_client;

my $dir = tempdir(CLEANUP => 1);

# Build a CA and a server certificate signed by it, then bundle them in a PKCS#12
# the same way pfpki does (leaf certificate + key + issuing CA)
sub make_p12 {
    my ($name, @key_args) = @_;
    my $password = "secret-$name";
    safe_pf_run("openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
        "-subj", "/CN=test-ca-$name", "-keyout", "$dir/$name-ca.key", "-out", "$dir/$name-ca.crt");
    safe_pf_run("openssl", "req", "-new", "-newkey", @key_args, "-nodes",
        "-subj", "/CN=radius-$name", "-keyout", "$dir/$name.key", "-out", "$dir/$name.csr");
    safe_pf_run("openssl", "x509", "-req", "-days", "1", "-in", "$dir/$name.csr",
        "-CA", "$dir/$name-ca.crt", "-CAkey", "$dir/$name-ca.key", "-CAcreateserial", "-out", "$dir/$name.crt");
    safe_pf_run("openssl", "pkcs12", "-export", "-inkey", "$dir/$name.key", "-in", "$dir/$name.crt",
        "-certfile", "$dir/$name-ca.crt", "-passout", "pass:$password", "-out", "$dir/$name.p12");
    return (scalar(read_file("$dir/$name.p12", binmode => ':raw')), $password);
}

{
    my ($p12, $password) = make_p12("rsa", "rsa:2048");
    my ($res, $bundle) = pf::pfpki_client::parse_pkcs12($p12, $password);
    is($res, $TRUE, "RSA PKCS#12 bundle is parsed");
    like($bundle->{certificate}, qr/\A-----BEGIN CERTIFICATE-----.+-----END CERTIFICATE-----\n\z/s, "Single leaf certificate extracted");
    my $leaf = pf::ssl::x509_from_string($bundle->{certificate});
    like($leaf->subject, qr/CN\s*=\s*radius-rsa/, "Leaf certificate is the server certificate");
    my $ca = pf::ssl::x509_from_string($bundle->{ca});
    like($ca->subject, qr/CN\s*=\s*test-ca-rsa/, "CA certificate extracted");
    like($bundle->{private_key}, qr/-----BEGIN RSA PRIVATE KEY-----/, "Private key converted to an RSA key");
    my ($match) = pf::ssl::validate_cert_key_match($leaf, pf::ssl::rsa_from_string($bundle->{private_key}));
    is($match, $TRUE, "Private key matches the certificate");

    ($res, my $msg) = pf::pfpki_client::parse_pkcs12($p12, "wrong-password");
    is($res, $FALSE, "Wrong password is rejected");
}

{
    my ($p12, $password) = make_p12("ec", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1");
    my ($res, $msg) = pf::pfpki_client::parse_pkcs12($p12, $password);
    is($res, $FALSE, "EC private key is rejected");
    like($msg, qr/only RSA keys are supported/, "EC private key error message");
}

{
    no warnings 'redefine';
    local *pf::pfpki_client::api_call = sub { return ($TRUE, { cn => "signed", csr => \1 }) };
    my ($res, $msg) = pf::pfpki_client::cert_bundle(1);
    is($res, $FALSE, "Certificate signed from a CSR cannot be exported");
    like($msg, qr/private key is not stored/, "CSR signed certificate error message");
}

is(pf::pfpki_client::profile_allows_server_auth({ extended_key_usage => "1|2" }), $TRUE, "serverAuth allowed");
is(pf::pfpki_client::profile_allows_server_auth({ extended_key_usage => "2" }), $FALSE, "clientAuth only is not allowed");
is(pf::pfpki_client::profile_allows_server_auth({}), $TRUE, "No extended key usage is not restricted");

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
