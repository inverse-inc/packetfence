#!/usr/bin/perl

=head1 NAME

pf-ssl

=cut

=head1 DESCRIPTION

unit test for pf::ssl

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

use Test::More tests => 22;
use Test::NoWarnings;

use pf::constants qw($TRUE $FALSE);

# bash recipe to generate:
# * a new CA with a private key
# * a new CSR + private key for a radius cert
#
# and sign radius cert with x509 extensions
#
# CANAME=perl-tests-2
# MYCERT=radius
# # optional
# mkdir $CANAME
# cd $CANAME
# # generate aes encrypted private key
# openssl genrsa -out $CANAME.key 4096
# openssl req -x509 -new -nodes -key $CANAME.key -sha256 -days 7500 -out $CANAME.crt -subj '/C=CA/ST=QC/L=Montreal/O=Inverse/CN=Azure_Test'
# openssl req -new -nodes -out $MYCERT.csr -newkey rsa:4096 -keyout $MYCERT.key -subj "/CN=$MYCERT"
# cat > $MYCERT.v3.ext << EOF
# authorityKeyIdentifier=keyid,issuer
# basicConstraints=CA:FALSE
# subjectAltName = @alt_names
# extendedKeyUsage = serverAuth, clientAuth
# [alt_names]
# email.1 = jsemaan@inverse.ca
# EOF
# openssl x509 -req -in $MYCERT.csr -CA $CANAME.crt -CAkey $CANAME.key -CAcreateserial -out $MYCERT.crt -days 7300 -sha256 -extfile $MYCERT.v3.ext

use_ok("pf::ssl");

my $ss_test_cert = <<EOF;
-----BEGIN CERTIFICATE-----
MIIEsDCCA5igAwIBAgIUPiw95E0gPEI5bysUeOR4VryyUhwwDQYJKoZIhvcNAQEL
BQAwcjELMAkGA1UEBhMCTVgxEjAQBgNVBAgTCUN1Y2FyYWNoYTEbMBkGA1UEBxMS
VmlsbGEgZGUgbG9zIFRhY29zMRUwEwYDVQQKEwxaYW1taXRvY29ycG8xGzAZBgNV
BAMTEnBmLnphbW1pdG9jb3Jwby5teDAeFw0yMTA3MjAxMjU1MjVaFw0yMjA3MjAx
MjU1MjVaMHIxCzAJBgNVBAYTAk1YMRIwEAYDVQQIEwlDdWNhcmFjaGExGzAZBgNV
BAcTElZpbGxhIGRlIGxvcyBUYWNvczEVMBMGA1UEChMMWmFtbWl0b2NvcnBvMRsw
GQYDVQQDExJwZi56YW1taXRvY29ycG8ubXgwggEiMA0GCSqGSIb3DQEBAQUAA4IB
DwAwggEKAoIBAQCYHqHy2/zr/lnWm0nklUJPXsysq/rEd2WIuFyGDCTKUtecLoOO
mAcYbQ+72R9eDwWGYasca6DjJd4V56UaV9TLsnWUmNaPDvydWhmnJkxFlspotq25
oBYn0kiRSX/IynM5I9SGW9b+JiYmnjlxIUP9ZBPq4bbXvZnUq4nMD0jv5C4yE6NM
8ssU8sRHQukZxdC7l0FHo8Ns8wAjRvxk0EnPm9WtXMWh/8CMSpFubX4OvjD/+zsB
ypkNBj3y779beiOZ/IjLL+eur6EgcVYjcp7c1Y6cfC8cOeJTfvA4MoywrMtUt+9N
gpuqzEiFeEbX0ql6CFRQIdXQTF8fo+4ZwW+xAgMBAAGjggE8MIIBODAdBgNVHQ4E
FgQUUJvYNjcpjcWFXaH3R/TBGSfj0dMwga8GA1UdIwSBpzCBpIAUUJvYNjcpjcWF
XaH3R/TBGSfj0dOhdqR0MHIxCzAJBgNVBAYTAk1YMRIwEAYDVQQIEwlDdWNhcmFj
aGExGzAZBgNVBAcTElZpbGxhIGRlIGxvcyBUYWNvczEVMBMGA1UEChMMWmFtbWl0
b2NvcnBvMRswGQYDVQQDExJwZi56YW1taXRvY29ycG8ubXiCFD4sPeRNIDxCOW8r
FHjkeFa8slIcMAwGA1UdEwEB/wQCMAAwCQYDVR0SBAIwADALBgNVHQ8EBAMCAuQw
EwYDVR0lBAwwCgYIKwYBBQUHAwEwEQYJYIZIAYb4QgEBBAQDAgZAMBcGA1UdEQQQ
MA6CASqCCTE5Mi4wLjIuMTANBgkqhkiG9w0BAQsFAAOCAQEAi/rvnlQ/M2Cks0/c
yjwHiqJW6O5wOjRNV8eCy+k/pkMwYa7z8VFgoG0CSNOgW59Vbt9G4yIE2Bj6swLg
WHJExZiZTqozTD92LnQJbguSOW5U2xGZyKR72wlK7gBOpPte85lIG2EKbsGIen4n
rC3G3u5KQK+wBpG5tYfJr3B+sm/bjI0R1cu9eI5q66lBSoHDKfnQv8PZ6wKdp0QT
VWkooOxWyVUXA/Pxu+wuiSbz2qUQSSoV8aMQlG8H6CDDP8lvXrxiA/Sh6Sgj5rwO
04r4W66oEmWsj4x5xZEBWSGR0XsXGlpQTari8Dgi6MTIL4BfROx/uBIB86mZEw52
nwG+Nw==
-----END CERTIFICATE-----
EOF

my $ss_test_key = <<EOF;
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAmB6h8tv86/5Z1ptJ5JVCT17MrKv6xHdliLhchgwkylLXnC6D
jpgHGG0Pu9kfXg8FhmGrHGug4yXeFeelGlfUy7J1lJjWjw78nVoZpyZMRZbKaLat
uaAWJ9JIkUl/yMpzOSPUhlvW/iYmJp45cSFD/WQT6uG2172Z1KuJzA9I7+QuMhOj
TPLLFPLER0LpGcXQu5dBR6PDbPMAI0b8ZNBJz5vVrVzFof/AjEqRbm1+Dr4w//s7
AcqZDQY98u+/W3ojmfyIyy/nrq+hIHFWI3Ke3NWOnHwvHDniU37wODKMsKzLVLfv
TYKbqsxIhXhG19KpeghUUCHV0ExfH6PuGcFvsQIDAQABAoIBABrYBQIjWf2XM+lQ
G/kPcdUpyHqMGsOCwlMfHYy2JePiPJQeDS8jmtTvogAnL4bcpb/yCk0InSqYaxl4
eEUuzKlpg6BGXE6AeYmW9cHuWzVIh810tzFzk5VRYWbqDnezaiPiM8XF/Sl6N+9G
qqJRGXtkprMjQ63MkpHZ94YgCGH0n6A0U/Aabcfb5GOyy283/nz6w308CMmSXKpv
EGy/4/Oha9PjhyCII8vkSEGLjjadeShzDot3Ix057DwGdYckGaBk6maXGGuWQlL9
Xak8NEx268f7vroSjRw199a0Opu94nv9oYSUulxi9eaG/xWkaysH4DDo1g6h6fOA
VuCWMAECgYEAxlHCMNx/bpWzvV8LSwNIl6ru8xfZa6m7s46uzCtAKFRY02wQC5y4
dj4bT+WQXJByFHhlwLnW3IydnG6RZ8z8VXOf38UYaK6RBSfBRgJVEJYiRly6XzlP
b6QhcnNLoPo19jtJpq3+yb+g4MgUm0CXxSY48gXFrPHT0+Q045xK3QECgYEAxFz8
3PgXJXYRLada/M5zLgUY1U2pfi1D3fNRwWraNCFh4MdpkbXId53ZdFy1BrSPGWkC
eWf9VJacLMY1AJgVng9ff4e625RIAU2sfBghne74sctgtXuDd+oRRtuLoECrPrCM
jdvq/vwHpk6JJ5ptuERsvftEskyveM5XopYkorECgYEAmeZUlmpmkcCmrSyWrO2t
ZdWGfSti1EPxn5P4XgSqUyGxlNBlWz2RgGEN/OCfONX3UZ9lBzywWpLctMqxGCZh
I0cJKDPhj0r4y1FgkR26OZbonkXTc5Yb6P0r349Nf2zsd1rm+uxHrvSAui9Knnhv
ztSsmFSWZHF9+w87Y+6jwgECgYA0X7jyFxnVXBBo5OJX25jNBX8CJZy3kssvP97m
f+GDVgQNOCLoQlwdy3RcnP2LtE0WsfN+/kWLckBlkNhCOE5Lwj3uff1Q49PwxQ7k
amtM/JhIk75PqYn/Sechxx0OuTDzn5NdovKi4AYKTZg3f/ET3OxEH+jKxblnt2GY
dAOBgQKBgQCAXgHJH59M6sbNRf/iFThWgU6o+Z3yghnOWhTxD2/mk4Eb3SYf8dwR
YNivd3YtYBoJ3DEwMOTnO6AjGkDPvf0QYzz0ZQuiuWpnelnUGPnikysFfKzH+Vdv
NXaNS0pPpctKCt/JM12+IZcBP7BRg+hUyuTeSKwcUCPZQ28Ho+lTBA==
-----END RSA PRIVATE KEY-----
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
}


my $cert_with_chain_cert = <<EOF;
-----BEGIN CERTIFICATE-----
MIIFXzCCA0egAwIBAgIUHjf4TrkEME68u86k8NE2ErLl7dgwDQYJKoZIhvcNAQEL
BQAwVDELMAkGA1UEBhMCQ0ExCzAJBgNVBAgMAlFDMREwDwYDVQQHDAhNb250cmVh
bDEQMA4GA1UECgwHSW52ZXJzZTETMBEGA1UEAwwKQXp1cmVfVGVzdDAeFw0yMjA2
MDEwODMwNDFaFw00MjA1MjcwODMwNDFaMBExDzANBgNVBAMMBnJhZGl1czCCAiIw
DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK9PGL7z+NeLvqLZDZzDEVG3jXYq
RsBldYr9tRj+Q3CfsBknV2NplAKdmyxN/oQwQlHi2xCuN5zgncpkPfhb+2N2sDhR
hX1CZLMJrbKjQYQM5NEkyXjIYFmkf043YBtHt0y0F5iwjSX+kqzFxJ3Ae4g6XbSr
YMHq2kmOFWLwxqwvCjYoLTkvrJ1yFlCtTTMhs1L0zIOEmj8hHY/pJNdMU7dKDbaF
SMXa539LJscf/5+HBcz0r5Q0fAmfHvlaT1E0JB8jxos1JJyd+0HNR3yzNWFj6HvS
nrq4K0+uiG+sRv9Oo/TgmmhF1/Qe9aN6zxt6/6YSi99n4Kl8fkwCgu4g2qS19VHg
B03+5hNclcKRElk8qcdMdWP0YzXBqT03emJNnCD8CSQ0xQr9Gnq6YCd5827fMbiT
4d5ZVQRa19ewklSJtQSG0eS6VAr7QmIDZJT4NCvjFe2O8mfiBUjwnGULFnqXX9cm
JjhjJ2CZtNfjurBrMQ8KWgQ8/9oqXR57tklk1krV611/foAiM5FfjgJca6MO0jMo
VEXmjBXyul6PKHMvEAo63+VoNb1yUFcM0wJNqsPtSCqnPIDivQ7Tbl9ze2ScAL+/
Dl2pI+iopn8F5Gio/0OCtTe7wVTVZvVUNbmiQBiv79nC6bv3Kg3Y5c61JJa2fTm8
BHD6sSgF/qIPFiUBAgMBAAGjbDBqMB8GA1UdIwQYMBaAFL/3RvMdoX4UvuT4c9YB
jd2cTrFHMAkGA1UdEwQCMAAwHQYDVR0RBBYwFIESanNlbWFhbkBpbnZlcnNlLmNh
MB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjANBgkqhkiG9w0BAQsFAAOC
AgEAsMtkZ3D7pzHOkeT6W/QQPbSenuZf+BuNq+VbMFQadvmJZ5F8I9qCTQcHswVd
L3UloMpgXDXEUSfoHBW83P6QlcsiEkPMeXP2lIgVbdyiNwMyAzTU2aAJA3fE87zS
LRGsaruPAVM2ioLr1QHmKzQgD1qW/2hVX6CV/pqQ3cDiH69e1QTkEKmq/f98RY6r
hAGs+aWV4dE/wnKbVphUoYb8hdU2ftRJ3b6Q6R8z/C7f0qTAIJVEHY3zKEvoONXd
81JYyt4zT87zeTg63MLdvvPycGaxb5YoBFpbKtmQEacfptbjYzr8qj+VosrDzX60
YQ8Y5UfF48aet5n3Xrvao60br+bDrkNKei+6zbBwrlePbb4RMrLM9MGEeHpy6esg
9FsSDwvh0Urwl+mhKvpUpdWyaxvwbUuCXzcB1OBYIk38C6k6omwqKWGMQ5dSao0z
CSSpoc1ewaO8MflKfmbnCTGynse2Ocd4ntVybB81gQlsHM2vwgIFWeUztpQJw5cR
kjWumFkPeu2Tbt87PCdbGjedWlwuJMw/Y2VuTRzJ379EgIPpmCHECUTgX0cDaOpp
a/CtmbBrniL00p8QHGTSOa0gy2N0c1UtBUQ4DUqVUGgxtti1FLcQVFGrZBzm3VRd
MZCaBywssJqm5DO76L4rckZ3GKTyU8NZMu9HP1+CEdasDIQ=
-----END CERTIFICATE-----
EOF

# only to simplify changes later, not used during tests
my $cert_with_chain_cert_private_key= <<EOF;
-----BEGIN PRIVATE KEY-----
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
4DIcAam7vsb1KI9E+gdkgXc0em3rDLctXw==
-----END PRIVATE KEY-----
EOF

my $cert_with_chain_ca = <<EOF;
-----BEGIN CERTIFICATE-----
MIIFiTCCA3GgAwIBAgIUO/2vOYY8K7VwIlSevbT7ZmW1TGAwDQYJKoZIhvcNAQEL
BQAwVDELMAkGA1UEBhMCQ0ExCzAJBgNVBAgMAlFDMREwDwYDVQQHDAhNb250cmVh
bDEQMA4GA1UECgwHSW52ZXJzZTETMBEGA1UEAwwKQXp1cmVfVGVzdDAeFw0yMjA2
MDEwODI5MDVaFw00MjEyMTMwODI5MDVaMFQxCzAJBgNVBAYTAkNBMQswCQYDVQQI
DAJRQzERMA8GA1UEBwwITW9udHJlYWwxEDAOBgNVBAoMB0ludmVyc2UxEzARBgNV
BAMMCkF6dXJlX1Rlc3QwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDJ
3JLj2SLXxkxMhfjhBuBqUFfr/vU1+DktPTk6TH08udFWzilJCZZbWuaXErYdb+1C
ZQwqzXuVl+OYzeIwu7juy+5UN/hpcOyTXj3HAnldCvmMg+pkowxuIhUCeKtUvh4l
8/CycBsQczGXJjSp5JwNf46IYXq1u7O2a6t5Uk97SmqbgQIou7uC2gq7gbi+XgQQ
RK+eqa4S5zLKC8edXMh4EpUjU+04c5cxEjncd7aQbzDWR+FsV0F03Az1gl2V1OlG
AHM/wb7jrf1UySNBUDIxZqbyddHXqhIusMMMB2/gJ2UoHUJ/Zmflh97MX2Ty7Uxi
PqkErX91WxeGmqWLYV44ASL3jFYFVuTJDGo2R+zvLFCESAp8a2171dLebRRLIQLL
0bBLcd3oCVHaslQxzkvnjcjFQPoE1UokahyV+AOhmJsijFxv3u5dMU3q+dLzG7Cr
I1GkSjdoUnKr5c/RfvT139bAmjoWhdVvKWzKqRBOlm6rhj/KFWT0ngMZ4NtmvV9d
vQ8RZTUxdwmj26eCus3OTYxiT1Wn+4WFbr3PwTIPEHAhR9lD9di50C6gVGkgSuYw
iObdX5GfB9L+hfxi0Lw6f0ftexXL/uAahGLBO3P80XyxtpzIN5de2vnTkv4wht6t
i+74eNzbwUJXwbFnR3SoHgogj8kOPB3ljs+Y4/d2CwIDAQABo1MwUTAdBgNVHQ4E
FgQUv/dG8x2hfhS+5Phz1gGN3ZxOsUcwHwYDVR0jBBgwFoAUv/dG8x2hfhS+5Phz
1gGN3ZxOsUcwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAgEAGTRO
RYg7U3tj3OesOzg3GD/PN4TTDgbqTAdde5lUm0DXOTTlojQhf97Z5iynEt+amV/U
fgR/A4FHDtBJT5r4w4NH89AcPAX4LY1UaK7ELkRUAbkrC2JP/v1cwJJqpKlcpLyF
0WReAU5CwCyYr5qMMrwlpd1xULRIil3gZSQvXsNmM0aTDL80eiIW8ulTpQkpJlX2
QwApRlFFmuCDVqfe//fwHTLQOt15F2ew+upiNadCHyZ+Le85tuo05t6Cv5xcJimZ
C1gT7QPHNYz8ZuodXgzTIoo7cMpTt1izs9zjQahdEmIXYp/eSyUf15Og/2V9lLH0
0vJFItgInAlpNysGiHzBNKOF/CL2FZ2zs/5tS/lAI4RBd6WE0m7cTsh33jRwyh3Q
t8WsCqGvztafrufjNJl0/OtDyzdsJdtwv2isBRG4yIQFX/uxo6Jt0r++RiAiIY8D
vyi20T1iU8/9iMRa1m/BQ+3DD9c5PY5iObitF/Qz68cSU1s/D0mAVduK3uyocYgZ
L9M4wLwK+NzyuNaYsSk6OGBmrC8s1cYDCDYeQDc4+0nGH840/K2MP140TzyFB5as
998aryJd27ZB6poYVh5nf7eCnKeHHLUZkqVmgj9O0yoOlGsp/afM+n3L4KSUwMBJ
WR/tuhrVRvjoc5MQZHlBby6jOaUGmXsp3OQq08U=
-----END CERTIFICATE-----
EOF

# only to simplify changes later, not used during tests
my $cert_with_chain_ca_private_key = <<EOF;
-----BEGIN RSA PRIVATE KEY-----
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
-----END RSA PRIVATE KEY-----
EOF

$x509 = pf::ssl::x509_from_string($cert_with_chain_cert);
is(ref($x509), "Crypt::OpenSSL::X509", "x509_from_string returns a Crypt::OpenSSL::X509");

is($x509->subject, "CN=radius", "certificate has the right subject");

my $x509_ca = pf::ssl::x509_from_string($cert_with_chain_ca);
is(ref($x509_ca), "Crypt::OpenSSL::X509", "x509_from_string returns a Crypt::OpenSSL::X509");

{
    my $res;
    is($x509_ca->subject(), "C=CA, ST=QC, L=Montreal, O=Inverse, CN=Azure_Test", "right intermediate subject was found");

    ($res, undef) = pf::ssl::verify_chain($x509, [$x509_ca]);
    is($res, $TRUE, "Cert with custom chain should be valid");
    
    ($res, undef) = pf::ssl::verify_chain($x509, []);
    is($res, $FALSE, "Cert with custom chain shouldn't be valid unless all certs are passed");
}

my $multi_san_cert = <<EOF;
-----BEGIN CERTIFICATE-----
MIIHNDCCBhygAwIBAgIQAkqjsfPxRBK39S6WehRc/zANBgkqhkiG9w0BAQsFADBN
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMScwJQYDVQQDEx5E
aWdpQ2VydCBTSEEyIFNlY3VyZSBTZXJ2ZXIgQ0EwHhcNMjExMTAxMDAwMDAwWhcN
MjIxMDExMjM1OTU5WjBgMQswCQYDVQQGEwJDQTEPMA0GA1UECBMGUXVlYmVjMREw
DwYDVQQHEwhNb250cmVhbDEUMBIGA1UEChMLSW52ZXJzZSBJbmMxFzAVBgNVBAMT
Dnd3dy5pbnZlcnNlLmNhMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEuC5+eGO/
HaKJD6IbGW4MOmrg/Q5Hck90UdQAJFH1OOH6l6NNKpcZMVBzKqefzEY1wSj/dQUx
bnROtGyYggKhsaOCBMYwggTCMB8GA1UdIwQYMBaAFA+AYRyCMWHVLyjnjUY4tCzh
xtniMB0GA1UdDgQWBBS4i+rx6FU3f3vLMHJ0Ttlg/WgDVjCCAY8GA1UdEQSCAYYw
ggGCghJhcGkuZmluZ2VyYmFuay5vcmeCD2NoYXQuaW52ZXJzZS5jYYIMZGVtby5z
b2dvLm51gg5maW5nZXJiYW5rLm9yZ4IOZ2l0LmludmVyc2UuY2GCD2hlbHAuaW52
ZXJzZS5jYYIKaW52ZXJzZS5jYYIWam9sbHlqdW1wZXIuaW52ZXJzZS5jYYIQa2lt
YWkuaW52ZXJzZS5jYYIQbGlzdHMuaW52ZXJzZS5jYYIVbW9uaXRvcmluZy5pbnZl
cnNlLmNhghNwYWNrYWdlcy5pbnZlcnNlLmNhgg9wYWNrZXRmZW5jZS5vcmeCEHBz
b25vLmludmVyc2UuY2GCFHNvZ28tZGVtby5pbnZlcnNlLmNhgg9zb2dvLmludmVy
c2UuY2GCB3NvZ28ubnWCD3dpa2kuaW52ZXJzZS5jYYISd3d3LmZpbmdlcmJhbmsu
b3Jngg53d3cuaW52ZXJzZS5jYYITd3d3LnBhY2tldGZlbmNlLm9yZ4ILd3d3LnNv
Z28ubnUwDgYDVR0PAQH/BAQDAgeAMB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEF
BQcDAjBvBgNVHR8EaDBmMDGgL6AthitodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
c3NjYS1zaGEyLWc2LTEuY3JsMDGgL6AthitodHRwOi8vY3JsNC5kaWdpY2VydC5j
b20vc3NjYS1zaGEyLWc2LTEuY3JsMD4GA1UdIAQ3MDUwMwYGZ4EMAQICMCkwJwYI
KwYBBQUHAgEWG2h0dHA6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzB8BggrBgEFBQcB
AQRwMG4wJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBGBggr
BgEFBQcwAoY6aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hB
MlNlY3VyZVNlcnZlckNBLmNydDAMBgNVHRMBAf8EAjAAMIIBfwYKKwYBBAHWeQIE
AgSCAW8EggFrAWkAdwBGpVXrdfqRIDC1oolp9PN9ESxBdL79SbiFq/L8cP5tRwAA
AXzcs/6cAAAEAwBIMEYCIQCYTH948tekZNl/55gAVkK8zNdBO1XM93bLjxVt5mbJ
RwIhAP4gOBrszJL4ZQEDU2psBoiMBoI4buiE0JwS8J51YxqaAHYAUaOw9f0BeZxW
bbg3eI8MpHrMGyfL956IQpoN/tSLBeUAAAF83LP+3wAABAMARzBFAiAcJVlBBkn4
59uGolzYKAxSjC64ljJ0LTt+PCtRoOp6IQIhAP5L7EhMKIP0pVo+RaE85RRm7CT8
25YDGjGyXT648i+5AHYAQcjKsd8iRkoQxqE6CUKHXk4xixsD6+tLx2jwkGKWBvYA
AAF83LP+ZwAABAMARzBFAiAnq52qCcCOxV62UuARPXdxLJBIWjQcGOc8Vw6rop1L
RgIhAIkcYm7CRrdiSd/xEWkerxhsVYWHjQmQQeohuoMGlwVFMA0GCSqGSIb3DQEB
CwUAA4IBAQBNhSbcp9YgU1xcz4wIY38l95jBChUveHZ/9xSDSw8iGcqE2f98x+Xq
MkaPp1mpYKhKPzsbMeNGSn6veMKSPoIRh0OH0Oi55lxff1QnmDsWW2XmmgOOR8Is
lMSEXh7L3m71/tp5qzqQPkOnOyNs3BSXsoLJOFoa0HJimJCIAxeIOZTjn4+XBEUY
9fKl7PuL/G89yQ3l9wvvSvI53DulG2/RbJgnSmZUyhnw1SrjU1fRJ2zR9glH8A7M
vApr8fkrLMKOqDEiMKs+1iZLm0KWcdzkyxTV+IiJMkS0HEvf64I9clss/A9OspSU
nGmJe3LRdsNx7P7pu57GY8lEv1tWkAO9
-----END CERTIFICATE-----
EOF

$x509= pf::ssl::x509_from_string($multi_san_cert);
my $x509_info = pf::ssl::x509_info($x509);

is($x509_info->{common_name}, "www.inverse.ca", "Common name is properly read in x509_info");
is_deeply($x509_info->{subject_alt_name},['DNS:api.fingerbank.org','DNS:chat.inverse.ca','DNS:demo.sogo.nu','DNS:fingerbank.org','DNS:git.inverse.ca','DNS:help.inverse.ca','DNS:inverse.ca','DNS:jollyjumper.inverse.ca','DNS:kimai.inverse.ca','DNS:lists.inverse.ca','DNS:monitoring.inverse.ca','DNS:packages.inverse.ca','DNS:packetfence.org','DNS:psono.inverse.ca','DNS:sogo-demo.inverse.ca','DNS:sogo.inverse.ca','DNS:sogo.nu','DNS:wiki.inverse.ca','DNS:www.fingerbank.org','DNS:www.inverse.ca','DNS:www.packetfence.org','DNS:www.sogo.nu'],"Subject alternative name is properly read from the x509_info");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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
