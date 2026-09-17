#!/usr/bin/perl

=head1 NAME

Nodes

=cut

=head1 DESCRIPTION

unit test for Certificates

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

use File::Slurp qw(read_file write_file);
use File::Copy;
use File::Temp;

my @TEMP_FILES;

sub use_temp_file {
    my ($name_ref) = @_;
    my ($fh, $filename) = File::Temp::tempfile( UNLINK => 1, DIR => '/usr/local/pf/conf');
    copy($$name_ref, $fh);
    $$name_ref = $filename;
    push @TEMP_FILES, $fh;
}

BEGIN {
    use_temp_file(\$pf::file_paths::server_cert);
    use_temp_file(\$pf::file_paths::server_key);
    use_temp_file(\$pf::file_paths::radius_server_cert);
    use_temp_file(\$pf::file_paths::radius_server_key);
    use_temp_file(\$pf::file_paths::radius_ca_cert);
}

use pf::file_paths qw(
    $server_cert
    $server_key
);

use pf::ConfigStore::Pf;
use Utils;
my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Pf");

#insert known data
#run tests
use Test::More tests => 43;
use Test::Mojo;
use Test::NoWarnings;

my $t = Test::Mojo->new('pf::UnifiedApi');

$t->get_ok('/api/v1/config/certificate/http/info')
  ->status_is(200)
  ->json_is('/certificate/subject', "C=CA, ST=QC, L=Montreal, O=Inverse, CN=127.0.0.1, emailAddress=support\@inverse.ca")
  ->json_is('/certificate/issuer', "C=CA, ST=QC, L=Montreal, O=Inverse, CN=127.0.0.1, emailAddress=support\@inverse.ca")
  ->json_is('/certificate/serial', '4EA79E85EEE8FDD9F59E21235DDEB940A13958A7')
  ->json_is('/chain_is_valid/success', 1)
  ->json_is('/cert_key_match/success', 1)
  ->json_is('/certificate/not_before', "Jul 20 14:00:12 2021 GMT")
  ->json_is('/certificate/not_after', "Jul 18 14:00:12 2031 GMT");


my $cert = read_file($server_cert);
my $key = read_file($server_key);

# Replacing by the valid existing ones should work fine
$t->put_ok("/api/v1/config/certificate/http" => json => { certificate => $cert, private_key => $key })
  ->status_is(200);

my $new_cert = <<EOT;
-----BEGIN CERTIFICATE-----
MIIEvDCCA6SgAwIBAgIUcYjeqGSuqVvjD6AG0VFvgCiNuEwwDQYJKoZIhvcNAQEL
BQAwdjELMAkGA1UEBhMCQ0ExCzAJBgNVBAgTAlFDMREwDwYDVQQHEwhNb250cmVh
bDEQMA4GA1UEChMHSW52ZXJzZTESMBAGA1UEAxMJMTI3LjAuMC4xMSEwHwYJKoZI
hvcNAQkBFhJzdXBwb3J0QGludmVyc2UuY2EwHhcNMjEwNzIwMTQwMjM0WhcNMzEw
NzE4MTQwMjM0WjB2MQswCQYDVQQGEwJDQTELMAkGA1UECBMCUUMxETAPBgNVBAcT
CE1vbnRyZWFsMRAwDgYDVQQKEwdJbnZlcnNlMRIwEAYDVQQDEwkxMjcuMC4wLjEx
ITAfBgkqhkiG9w0BCQEWEnN1cHBvcnRAaW52ZXJzZS5jYTCCASIwDQYJKoZIhvcN
AQEBBQADggEPADCCAQoCggEBAMjafJt9cM1EM8ysf0pkPYdPDc6fIK94LrrOTDcI
qqFadqcHIhoBAoc3IJ8Qwo3CXW9+CBtpXJ0CtOWbhLZPyTwIGRn0wk2JSYPgkQf/
qXaebcMi/qERVvUJzi/7W9UhASCvkMipMxI5jH1c8CaZKg3QYpBIUCsQRBaZQCaW
cPYCeQ8f+Lq9rTMqJEeQaAluz3n/mZ7LO6opnVFNbAnb4p6ZNgkFg5INBv36xEaS
UiNbXIKUqRpqhL1++HnZp+cdOxIC3bF6YcIU4gzlKR3BGRzovQvaR/6LgrVxS2/T
FrL3UDTWXl1lal32KJt16XdqEOQBLG3ag5pBfffwMGegav8CAwEAAaOCAUAwggE8
MB0GA1UdDgQWBBSoOYdAIhcTFBqCAmTWjV0mi42P3TCBswYDVR0jBIGrMIGogBSo
OYdAIhcTFBqCAmTWjV0mi42P3aF6pHgwdjELMAkGA1UEBhMCQ0ExCzAJBgNVBAgT
AlFDMREwDwYDVQQHEwhNb250cmVhbDEQMA4GA1UEChMHSW52ZXJzZTESMBAGA1UE
AxMJMTI3LjAuMC4xMSEwHwYJKoZIhvcNAQkBFhJzdXBwb3J0QGludmVyc2UuY2GC
FHGI3qhkrqlb4w+gBtFRb4AojbhMMAwGA1UdEwEB/wQCMAAwCQYDVR0SBAIwADAL
BgNVHQ8EBAMCAuQwEwYDVR0lBAwwCgYIKwYBBQUHAwEwEQYJYIZIAYb4QgEBBAQD
AgZAMBcGA1UdEQQQMA6CASqCCTE5Mi4wLjIuMTANBgkqhkiG9w0BAQsFAAOCAQEA
oM1TGHLkUCOV3saiTMjuH6TU4FUuSJDu7Wu8uGwI1NQiyaBYiLlp+maZmdodwRbx
9iKwloCpRWY/DFXUpNIFbqlsEAkiJ8Ea4b/zPjmiKBoe4xZazhARPK89pGujuy14
sl1M22aDCKVx0m5tmxLzKXO4NSNjAZNHtGcDfpsNC1J5IrF3b8ulOv+/eST774Jj
gqXPEmjeLUzr4YXVnggRfLuDR1F4VQy5XXnkFitj9cm3a+v+wGIO/PQIyrcDGj62
QLJhJVn1WzugOPf5zb1ciR2qxNuXziq+iyYOp214aeh3bpbQtNHtHM5RQe+c2CVR
6DE7uAoOmgNe+6GU2nKVJQ==
-----END CERTIFICATE-----
EOT

my $new_key = <<EOT;
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAyNp8m31wzUQzzKx/SmQ9h08Nzp8gr3guus5MNwiqoVp2pwci
GgEChzcgnxDCjcJdb34IG2lcnQK05ZuEtk/JPAgZGfTCTYlJg+CRB/+pdp5twyL+
oRFW9QnOL/tb1SEBIK+QyKkzEjmMfVzwJpkqDdBikEhQKxBEFplAJpZw9gJ5Dx/4
ur2tMyokR5BoCW7Pef+Znss7qimdUU1sCdvinpk2CQWDkg0G/frERpJSI1tcgpSp
GmqEvX74edmn5x07EgLdsXphwhTiDOUpHcEZHOi9C9pH/ouCtXFLb9MWsvdQNNZe
XWVqXfYom3Xpd2oQ5AEsbdqDmkF99/AwZ6Bq/wIDAQABAoIBAAIVgkV6v7jhhEgT
Yh67e4fz4gjKzeQEMzfs/A12IY8bCTAietAaQpR0lfoQinQ+GAoYHK1sInHenVHk
kzPxD/13eAs05u83BXRA2EBk/rUkX68upcW2EFjqiSEmUoWbmg9kwvPSDZ2ay0Jh
vHwqCq2qA9vLZEmOGabCYFAGL5Xd2/vosgfvFT/Vb3W366GIJxNMVddPvfOfZ3co
AlvPHi9duU+boy2wW2cL4QpM+uigEYZghDhxPNoyHonc4b/fHX1DmU29HlN5nmRM
5dJkfWOAHFGHO/797cza5h1WZxKTwfF0RgHCODRnUsyMkUdYY5n/SK5oxhbCvRoi
0WaddAECgYEA88MVIH4/TbV6yaLrDxm9DzP3fco8nKZstpY0qHl6ZrvzrMPyG2oT
4axCK5G5tZxbSpeTPs97hXWvhKZHM5JGf/I4HLLsDuZbTIEObd3qWwzl0aI6Hvcb
b+8fHp+dS8FmbELJBjTW+NKXso9noSdZYXbUOsqpxFVXfZuH6H9nuL8CgYEA0u/t
gKh/bvUlFC9rnaj/1A6JL4osQ2UcHXwMJYPHIhpmCMS4AUG/guiUbDcY6LkUV8YY
iAykuLeh/+FX3vcmB8gKikdurPzgCMbV7rdwbL+inH1e1V4N5IzVkx/TwYoZutSb
Gab3Hbu8IEKBjBw8wJlEB5aYdyl/Iqq+SmEfncECgYEAthfsJ1rH9Uf1kr0GdUBX
8Ax0/F3gC3FzUq5AZf5hRm9vJ4c0y+/hLDsfLybsINPNippSX6Bk+JyiYihIlijW
S2vpKN8r4jGI0Ey0N7SIBj5LS9+xJUKZF3P8vkakHVw7I/J78wvz7up6ceQYmNUp
OtqmzchpK4ZJFkbiLvdFx0cCgYEAm7jgv0Clg0abLwGrEuN2qhhpEp2Q+9gjH2k6
ll9onTab6RFBPjxJo90L5a/vRa+M4xeteJLM8Ekw4XR8qHAQtWHq1hbSEAdHZXNU
8DygVMhMxfaQEjizTOzjpw+yBolrYVAfiJqIiHzV74LpnIQkHZOIc4mr2RzbbL5c
aRC2hIECgYBIoOXW3olhd6Kt6V3LXu3mO/pB0X2IZ47+OR2rvmfhDSsT38xWw6VE
n61QRhBqEMOFDMjt4zynyoIN0pJiHZCDkP41joe0IByUeMq5X3KYC/FB50gasu/e
X1l9tlAkxFEeHfW2Er7Whj5x6X35irHGRFb/L1bdcXQqBtwHrG4pIQ==
-----END RSA PRIVATE KEY-----
EOT

# Replacing by a new cert for a different key shouldn't be valid
$t->put_ok("/api/v1/config/certificate/http" => json => { certificate => $new_cert, private_key => $key })
    ->status_is(422);

# Replacing by a new key that doesn't match the cert shouldn't be valid
$t->put_ok("/api/v1/config/certificate/http" => json => { certificate => $cert, private_key => $new_key })
    ->status_is(422);

# Replacing with a new self-signed should be valid
$t->put_ok("/api/v1/config/certificate/http" => json => { certificate => $new_cert, private_key => $new_key })
    ->status_is(200);

# Generate independent CA/server bundles with validity relative to this run.
# Fixed PEM fixtures eventually expire and turn the successful update into a 422.
sub generate_radius_bundle {
    my ($name) = @_;
    my $dir = File::Temp::tempdir(CLEANUP => 1);
    write_file("$dir/server.ext", "basicConstraints=critical,CA:FALSE\n"
        . "keyUsage=critical,digitalSignature,keyEncipherment\n"
        . "extendedKeyUsage=serverAuth\n");
    my @commands = (
        ['genrsa', '-out', "$dir/ca.key", '2048'],
        ['req', '-new', '-x509', '-batch', '-key', "$dir/ca.key",
         '-sha256', '-days', '30', '-subj', "/CN=$name CA",
         '-addext', 'basicConstraints=critical,CA:TRUE',
         '-addext', 'keyUsage=critical,keyCertSign,cRLSign',
         '-out', "$dir/ca.crt"],
        ['genrsa', '-out', "$dir/server.key", '2048'],
        ['req', '-new', '-batch', '-key', "$dir/server.key",
         '-subj', "/CN=$name server", '-out', "$dir/server.csr"],
        ['x509', '-req', '-in', "$dir/server.csr", '-CA', "$dir/ca.crt",
         '-CAkey', "$dir/ca.key", '-set_serial', '1', '-sha256',
         '-days', '30', '-extfile', "$dir/server.ext", '-out', "$dir/server.crt"],
    );
    for my $args (@commands) {
        system('openssl', @$args) == 0
            or BAIL_OUT("Unable to generate $name certificate bundle (openssl $args->[0], status $?)");
    }

    return map { scalar read_file("$dir/$_") } qw(server.crt server.key ca.crt);
}

my ($radius_cert, $radius_key, $radius_ca_cert) = generate_radius_bundle('radius');
my ($new_radius_cert, $new_radius_key, $new_radius_ca_cert) = generate_radius_bundle('new radius');

# Replacing by the valid existing ones should work fine
$t->put_ok("/api/v1/config/certificate/radius" => json => { certificate => $radius_cert, private_key => $radius_key, ca => $radius_ca_cert })
  ->status_is(200);

# Provide cert from another CA without chain check ignore flag
$t->put_ok("/api/v1/config/certificate/radius" => json => { certificate => $new_radius_cert, private_key => $new_radius_key, ca => $radius_ca_cert })
  ->status_is(422);

# Provide cert from another CA with the chain check ignore flag set to false
$t->put_ok("/api/v1/config/certificate/radius?check_chain=false" => json => { certificate => $new_radius_cert, private_key => $new_radius_key, ca => $radius_ca_cert })
  ->status_is(200);

# Provide cert from another CA with the chain check ignore flag set to true
$t->put_ok("/api/v1/config/certificate/radius?check_chain=true" => json => { certificate => $new_radius_cert, private_key => $new_radius_key, ca => $radius_ca_cert })
  ->status_is(422);

# Provide cert from another CA with the new CA
$t->put_ok("/api/v1/config/certificate/radius" => json => { certificate => $new_radius_cert, private_key => $new_radius_key, ca => $new_radius_ca_cert })
  ->status_is(200);

# Empty CA payload should be rejected
$t->put_ok("/api/v1/config/certificate/radius" => json => { certificate => $new_radius_cert, private_key => $new_radius_key, ca => "" })
  ->status_is(422)
  ->json_is('/message', "A Certification Authority certificate is required.");

# Missing CA key should be rejected
$t->put_ok("/api/v1/config/certificate/radius" => json => { certificate => $new_radius_cert, private_key => $new_radius_key })
  ->status_is(422)
  ->json_is('/message', "A Certification Authority certificate is required.");

# Unparseable CA payload should be rejected
$t->put_ok("/api/v1/config/certificate/radius" => json => { certificate => $new_radius_cert, private_key => $new_radius_key, ca => "-----BEGIN CERTIFICATE-----\nnot a cert\n-----END CERTIFICATE-----\n" })
  ->status_is(422)
  ->json_is('/message', "Failed to parse Certification Authority certificate.");

# test CSR with missing information
$t->post_ok("/api/v1/config/certificate/radius/generate_csr" => json => {})
  ->status_is(422);

# test CSR with valid information
$t->post_ok("/api/v1/config/certificate/radius/generate_csr" => json => {
        "country" => "CA", 
        "state" => "Quebec", 
        "locality" => "Montreal", 
        "organization_name" => "Inverse Inc.", 
        "common_name" => "csrtest.inverse.ca",
    })
  ->status_is(200);

# test CSR with extra information
$t->post_ok("/api/v1/config/certificate/radius/generate_csr" => json => {
        "country" => "CA",
        "state" => "Quebec",
        "locality" => "Montreal",
        "organization_name" => "Inverse Inc.",
        "common_name" => "csrtest.inverse.ca",
        "subject_alt_names" => "csrtest1.inverse.ca,csrtest2.inverse.ca",
    })
  ->status_is(200);

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
