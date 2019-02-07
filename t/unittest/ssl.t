#!/usr/bin/perl

=head1 NAME

pfconfig-tenant-scoped

=cut

=head1 DESCRIPTION

unit test for pfconfig-tenant-scoped

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 16;
use Test::NoWarnings;

use pf::constants qw($TRUE $FALSE);

use_ok("pf::ssl");

my $ss_test_cert = <<EOF;
-----BEGIN CERTIFICATE-----
MIIDtzCCAp+gAwIBAgIJAI/Np4F2VCuoMA0GCSqGSIb3DQEBCwUAMHIxCzAJBgNV
BAYTAk1YMRIwEAYDVQQIDAlDdWNhcmFjaGExGzAZBgNVBAcMElZpbGxhIGRlIGxv
cyBUYWNvczEVMBMGA1UECgwMWmFtbWl0b2NvcnBvMRswGQYDVQQDDBJwZi56YW1t
aXRvY29ycG8ubXgwHhcNMTkwMjA1MTg0ODEzWhcNMjkwMjAyMTg0ODEzWjByMQsw
CQYDVQQGEwJNWDESMBAGA1UECAwJQ3VjYXJhY2hhMRswGQYDVQQHDBJWaWxsYSBk
ZSBsb3MgVGFjb3MxFTATBgNVBAoMDFphbW1pdG9jb3JwbzEbMBkGA1UEAwwScGYu
emFtbWl0b2NvcnBvLm14MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
uC2v1nHDcnv75xD18rqlEGIZqr/oU5rZhLPKqHZe7icnucKu7D6e8A8L91uRZemd
OU9OF8ZjyoD1Fto8fK3jBKHgYldozOdC90xJwo+OZlQppTqFBacW1bCEUVx1B6nE
44JU96H9nJapK5tHBRz7zVm6iQM8ceQ+Tzqz57THwrykuRiagpne51xVTNneTSle
7inIUHX26wrGAIPgEN/0bDdqkJJTrvaqGrDw6q3edofSr9QJahMQ95qRyNrH7k/7
/7xyho8+oaWgTzq2fZov5OPhtHPC0cq5dWe4Y9fHK6caOvQj+FwBU/EIYdHv8jxM
LQWQ++OiT9Lnu8egw3u+dQIDAQABo1AwTjAdBgNVHQ4EFgQUJKrp5BqOrZpxxS7V
J/1Lh5pBHewwHwYDVR0jBBgwFoAUJKrp5BqOrZpxxS7VJ/1Lh5pBHewwDAYDVR0T
BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAACHXyeGrCg6tiOCQAbOvY1cNZQj1
6AksrRFB004H0S1970oXs9TaTdY8ZvYDOKlOIJVouAYcisjnWxtqbZnmesGm5jQN
9dhQ48pchh3ofuUSnbNY7WEVH2XwZgNBL+NHZCZqbdJ/7KsB/Npa43WSwBmQ8mnO
JH7ycUQKIT1v3ujQ2vXTn4HuUsip9v9zPgE3PRODNpdg9MlpagsckzflKDPSFOfa
j11hLTQ8XuUWCW/yGttu1sNYSyfgAoEaXBVEgW6nzqXQg4FIzWj40Hhhdb6Iy7/R
vQv8nn9VQxP/hBUa6c9FQpUYXq/hP+Oc9IKuyTYpJUYMsYYQIJ2DCn7brg==
-----END CERTIFICATE-----

EOF

my $ss_test_key = <<EOF;
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC4La/WccNye/vn
EPXyuqUQYhmqv+hTmtmEs8qodl7uJye5wq7sPp7wDwv3W5Fl6Z05T04XxmPKgPUW
2jx8reMEoeBiV2jM50L3TEnCj45mVCmlOoUFpxbVsIRRXHUHqcTjglT3of2clqkr
m0cFHPvNWbqJAzxx5D5POrPntMfCvKS5GJqCmd7nXFVM2d5NKV7uKchQdfbrCsYA
g+AQ3/RsN2qQklOu9qoasPDqrd52h9Kv1AlqExD3mpHI2sfuT/v/vHKGjz6hpaBP
OrZ9mi/k4+G0c8LRyrl1Z7hj18crpxo69CP4XAFT8Qhh0e/yPEwtBZD746JP0ue7
x6DDe751AgMBAAECggEAVHjPzwD6bUWkMUQ8KYmlLzBvKTs/aSj6Xry/VCiGPaBD
vhUmeT/3UY71JAwhUaal76UJ4imhlz0yK7sIRv7RwkwkR7ZjYKcotZeNtOh2nUQ4
nYmLfR43gOamqVJIcq1QmjAqnDD1yp3nFRLwrc2vR23B+hk73dibI2d/H+RwQkXO
ehZ7fu01mFyT4HOJiFm0Dc2LsbB+d1aq2wj7qM1lBiL6S9ik7pl7dFEA/TM7+3kn
8BsC/RRKIOp1G2j7n9rPLCh8LLtrHGHsC5yC/adgc7fa739pCUSeDAjAyXgyJz8T
8EKzvaQuQiBAp9Bw+Gx+lmSJHSAan26Wy76KiU0IgQKBgQD1GE1FB4oTOZ6Tmsns
KdAvXs5xzdmn9dcoDnKWFaVhv1RnwV6wGd9Ok4RbYcL9/xKdnIR+IHtRgdnOa2jd
xEvRq8SrtvAG6W7IXknQPFYlOS8ZKV7yMfyyLaMTOkRqQBCkwu0NztRPurKboTbC
Lm1F8dMCSym8/Yg2cl0xKQkZUQKBgQDAX4elOHzkalH7bmAOPqSXNudtempurRI2
UJsr0QKeXU4di5qVke+8kigyAUak/u85mH1Jkg93vNjHz9wceYJO9ZY9FTmp8xLz
JeTnDdrXJsFZRHTdFk+6qDTShXbaCa0EumtzBvgiYFjJUCg6e1FS5Hx4kP+8en+D
H114jCBJ5QKBgHukL87D9+as6Y9ixbxqd4h+Fj0Y8FUn0st1Rl7qOozt/UF+Lis+
UgWMq3eCAOErXRO/kqMh9bPvgpX8X2GIlgsG0OcjGUETX3ya/DedSIPsrhLOaQRb
LTQhi6O2gC7tdLf5UabmkPpLn7CdCke5Lgzb6mu8ySh66c01skeLgPiRAoGBAKbA
J+xnkprMLlQr0MeINVN+HA0h17AoBWlfZaINgp+TcWra4BxWa+ChMIZn5LyQ3vyl
2bQ0D4RTBfXtj3Z/PR0EdD5ub5WJRhvN9STzNYbZ6S9fz4z1EhdSRrdVSTimunsm
vIzwtZXWvh+Cg9xtmIip1dsMlSDjbjRSs8sSa8qhAoGAX+r7dmv5JvcPaLgJGFne
fWnRlqvNhdQQru6q85ZeQvkqYRZ4Sczx6x8rQXsEHKwpE0ZWAcq6qX2Zajzix9Lm
7rqw+7OW4mcArFJERmPGqIhTiwdp+jZ7p66xZbdBe9UzyklJLVaz2HBNjmuIS2AF
8ujPnPuSPIyt9NXAdSdwi9c=
-----END PRIVATE KEY-----
EOF

my $ss_test_key2 = <<EOF;
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAuqrAPqRddzS/0LWuzxpZzEybCu13JMhjZodO35iCEnYa/Wc1
6abeakEw43K/xtw/S3oc1s/osoHUNAXlZrhw1PKIKkwu/EAjswRKI4fBcvHduXwy
BCdIzqk9AOAAmfnUd1ozmdYZ2zB/vVQQbh211Wgn2miR6XcEEdKSHTgaKhdmJ4p8
g8Q6uUN0Ak4geaE3P4vPfamrSDwcivRrUfZkTEXy2RyEnsxWENWKl/3dH0p/1r2x
Fh1TvOoeWAm0aOJAE6NYb+XoZyApEf+ibj84NsySLPu210oZKRf6khu5A3PW7zz+
iWwuwX+fW9dLfqaPbXlrnR2S9xzxsgMgBjpYNwIDAQABAoIBAGbChR53AXUUNtxA
iEE+slyDd36mh0Zagk35AvSYUlKzbdw+KzG7SQmZZb5wdx6UNMvqJ2IiBmnuitEw
xb6snoC8GzWdxufar0xneiDhJR+QAo2Pz0D2F2CdThXjOrGJFOu3Xly7vnQp2Mhz
NLBJ7sXSls3nbxvlBvqAvysSrWSpllrFes2i6/V31St21lZ395Nf+y5vQjHvODl6
3rWe/avLSVHfMHWuDCiH+xqmeCXERNBGziOQd/tRtF9Vr7zlkTPyc9LZEE9Eheng
yOHSjfkTiQO3v6Tt3B3TpXdavReFyEsNckzUo3Wj8Wa3aKTh0SIQXEkbhn/bvR4N
O4qEEZECgYEA+AEpfcwQBLADYwpyRgybFBzPRp9iklboF56AnzLW/LPpI0fABl3m
U4zPmE4ZdFl0AydBAWY+NOxymVQzX0sL/UMX19HJ/Bq3ek24sAQoceFnScmcCrdB
spcgwlmGDpWixmbaqwmLtP/tsEO13NhUvl6UzQcdQ0AKMSbsJr1Lob0CgYEAwK9b
LfP9xLND/ifBRiTi9M4hSkfqerpIm7BbnR2tYZYrlj2AEaA0bt0PPpPY1moZ6BjO
AB8kgXX0tGvcPiLsJL8QQEdHgtM41bguWQOzk+n0mhC+2+5v5+Y439f3tiKU2fmM
eryqne2f57llke147aBfma3xjhdNz2ObSKU47wMCgYEAg+L6Ua/HhPallnHju2TQ
w61efUwde31EB+t+syqyMcjrXpu1fq1I432qmHBQERPRIiwp4bihtDtZ5jhk6XRb
d9/KOjeSlsMOd7gFU3WinI0mBJN2rCwwf+zmuvQo2nCxE5l3CCYXabYAjRA1ErDo
wCRENZRm93CC+wib5S4dnnECgYAdxjsRs8U/8u+Lw3rjKuoDKCMOxmQeSNDVdgAC
HEbhcIIVujUjBB12ECS957y3DTgpnEOg0y8h7ic9BfnHhD/3QaryM9GCDr+Wjtpi
mObT8XABqprDg2m5bOLW/BlkBJ35vM0PXj4DH2f5N7XRQd/Q4FpFdhKAgWtdo6eo
JxfQHwKBgQCi+9I8LkyT8hIOyzvJbe2Jb4P9sp/TSubossXB1PfBt/RroCIulf6c
sQpGiwTln9zsYaL1V8VWHD9xVJVaX0VQw6efke96FaMFq8xT+uXUnBow1HUn2RKs
IlP4belLPpWJwT55VwI6Ihk+IaV+dOTZJhkA7/XkHncRXUNiS32qCA==
-----END RSA PRIVATE KEY-----
EOF

my $rsa = pf::ssl::rsa_from_string($ss_test_key);
is(ref($rsa), "Crypt::OpenSSL::RSA", "rsa_from_string returns a Crypt::OpenSSL::RSA");

my $rsa_bad_cert = pf::ssl::rsa_from_string($ss_test_key2);
is(ref($rsa), "Crypt::OpenSSL::RSA", "rsa_from_string returns a Crypt::OpenSSL::RSA");

my $x509 = pf::ssl::x509_from_string($ss_test_cert);
is(ref($x509), "Crypt::OpenSSL::X509", "x509_from_string returns a Crypt::OpenSSL::X509");

is($x509->subject, "C=MX, ST=Cucaracha, L=Villa de los Tacos, O=Zammitocorpo, CN=pf.zammitocorpo.mx", "certificate has the right subject");

is(pf::ssl::validate_cert_key_match($x509, $rsa), $TRUE, "Cert/key that are matching should match");

{
    my ($res, $msg) = pf::ssl::validate_cert_key_match($x509, $rsa_bad_cert);
    is($res, $FALSE, "Cert/key that aren't matching shouldn't match");
}

{
    my ($res, $inter) = pf::ssl::fetch_all_intermediates($x509);
    is(scalar(@$inter), 0, "Self-signed cert shouldn't yield any intermediates");

    ($res, undef) = pf::ssl::verify_chain($x509, $inter);
    is($res, $TRUE, "Self-signed certificate should be a valid chain");

}

my $packetfence_org_cert = <<EOF;
-----BEGIN CERTIFICATE-----
MIIGVzCCBT+gAwIBAgISA3hObDhC0sjQ6D3btc+eq772MA0GCSqGSIb3DQEBCwUA
MEoxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MSMwIQYDVQQD
ExpMZXQncyBFbmNyeXB0IEF1dGhvcml0eSBYMzAeFw0xOTAxMTkwOTU1MDlaFw0x
OTA0MTkwOTU1MDlaMBoxGDAWBgNVBAMTD3BhY2tldGZlbmNlLm9yZzCCAiIwDQYJ
KoZIhvcNAQEBBQADggIPADCCAgoCggIBAL82/5rsndzRbZEm3WoDECplQEEKlGRB
l2a5UAsTTq0OcGQ6cwHLYD+FLFgu51wwYuWPjT/bhRiskY/l5oBK0gubLA/6+fOf
rqtnzD5TIhPFjP0COBj0l1O/ZwmPuaw8FjTgHUTwUTQY7hbIZxCMaCGWxOo/Y4CV
zqbN8MYKZMFwzblPTOSFsyl3p/5hFdSCn9iUefCRmzc2/r31mJtiaEBuIwOBEboH
0Ybc5IA8ehOkq047thyQMynkjx01s63iY5sDCtTPKcZPoTbJPONMoSztvil4lVah
rWCseudetkHIcBeNL3U/Fo8rq0RyIAdkTS2OwAevrp+g+S6VHwDil5LL/9uQKC1g
y4KRwTrKtLcwO0+oXpBtF21EO1IEQRuU6NxReO5BftZF7IV7SguqTfe6fV8hUT+B
VsU2kFU1XkzFPgUHjwdtO/uTdbPVpbM9oLqh9rSPY5wl/4dPBOedTnQ/wsoyOT0w
qiroHnjjWtLL+JvPWR7oMRDXqOs5+uwraXjwXM8PI8T7v1YaahHZhnxmF042h6M/
Or6at/7iWENXm7RNNyF1u0lBINgY9mUd9IdPzj6sOvRkGB9w7lvv3JR2U26fIFgl
ggnbAMSNDij6VlwFbPusrz+pVfwiyRbYnnw2T4MhXTcEhZaXjIhg4WHihtZGIZJ5
XpGaUwxoiHnxAgMBAAGjggJlMIICYTAOBgNVHQ8BAf8EBAMCBaAwHQYDVR0lBBYw
FAYIKwYBBQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFCUL
EObYpNFaRg5mFqYUBYIBjKeKMB8GA1UdIwQYMBaAFKhKamMEfd265tE5t6ZFZe/z
qOyhMG8GCCsGAQUFBwEBBGMwYTAuBggrBgEFBQcwAYYiaHR0cDovL29jc3AuaW50
LXgzLmxldHNlbmNyeXB0Lm9yZzAvBggrBgEFBQcwAoYjaHR0cDovL2NlcnQuaW50
LXgzLmxldHNlbmNyeXB0Lm9yZy8wGgYDVR0RBBMwEYIPcGFja2V0ZmVuY2Uub3Jn
MEwGA1UdIARFMEMwCAYGZ4EMAQIBMDcGCysGAQQBgt8TAQEBMCgwJgYIKwYBBQUH
AgEWGmh0dHA6Ly9jcHMubGV0c2VuY3J5cHQub3JnMIIBBQYKKwYBBAHWeQIEAgSB
9gSB8wDxAHYA4mlLribo6UAJ6IYbtjuD1D7n/nSI+6SPKJMBnd3x2/4AAAFoZcAI
VQAABAMARzBFAiATLYjWgASyQG9Z91lp0VXOuKRggtRtI3MExp2KXUftIgIhAM/Y
bBQyI7YxFuvRAwwlWsN6PkguACuNbwIwCwHgy/noAHcAY/Lbzeg7zCzPC3KEJ1dr
M6SNYXePvXWmOLHHaFRL2I0AAAFoZcAGaQAABAMASDBGAiEA+SVkISEdAv+B3x5y
uCYfnntpLk2HWm9bBn/K/Rcv7PwCIQCMVl8lkvEO1TW+zRars2oMM5tBxCKodwT5
VOJAuagVODANBgkqhkiG9w0BAQsFAAOCAQEAILgClshZb3WOajEAompucIlwaNKS
zo+DXRORIv1gZjqJqbglQhsf1WMM2x8iaCkF6ZC80U12NWe+ihmYKKKoan1aVL9t
HQGec0pjijF4EyXmP5tJj3x8vVzxOqWqmW1x6vaG9LxRQ6vEEqvqLVwZGerfAoFU
X5YdOmKJH1HA9R/w6Ok5jOTBGvxN36VPw0YlBzE3ry6Fg79oscLeusNiGQrn7lwS
xhCotd4ONf45lQeS2ZRP7sk8upAJ001ZRVCYeFrmcikN+M7qTzvzcOK5VKjb6GYZ
qKGW2Exn2hIuVy0bl7qHsX4++PJ3bsyET9tJ7EuXR+n89DM4lkfhCEiZsg==
-----END CERTIFICATE-----
EOF

$x509 = pf::ssl::x509_from_string($packetfence_org_cert);
is(ref($x509), "Crypt::OpenSSL::X509", "x509_from_string returns a Crypt::OpenSSL::X509");

is($x509->subject, "CN=packetfence.org", "certificate has the right subject");

{
    my ($res, $inter) = pf::ssl::fetch_all_intermediates($x509);
    is(scalar(@$inter), 1, "right amount of intermediates was found");
    is($inter->[0]->subject(), "C=US, O=Let's Encrypt, CN=Let's Encrypt Authority X3", "right intermediate subject was found");
    
    ($res, undef) = pf::ssl::verify_chain($x509, $inter);
    is($res, $TRUE, "certificate with a valid chain should be a valid chain");
    
    ($res, undef) = pf::ssl::verify_chain($x509, []);
    is($res, $FALSE, "certificate with a missing chain shouldn't be a valid chain");
}



=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
