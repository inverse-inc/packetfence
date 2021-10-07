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
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 20;
use Test::NoWarnings;

use pf::constants qw($TRUE $FALSE);

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
MIIFcjCCA1qgAwIBAgIBATANBgkqhkiG9w0BAQsFADBUMQswCQYDVQQGEwJDQTEL
MAkGA1UECBMCUUMxETAPBgNVBAcTCE1vbnRyZWFsMRAwDgYDVQQKEwdJbnZlcnNl
MRMwEQYDVQQDDApBenVyZV9UZXN0MB4XDTIxMDUyNTE2MjA1MloXDTIyMDUyNTE2
MjA1MlowETEPMA0GA1UEAxMGcmFkaXVzMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
MIICCgKCAgEAt5Sbm2IrAlf2d8W6t/om5PcRzU5C5Z5vvNByV7hZ6DfkFF2HWToO
KwDvTpdmB1Q+oI2wY1R6DHTUyYAiAIiGHnMwORyAUdeB+tPGyhsz7nWgcvKM7+or
J+CkZTngvrh/6Me9bQ0YG0bzZLaw1VT0gOuOEGygy3Xz8gFiaOMf/gVEtlqg8khh
GuRI0tQrUSTKES1Zlzx/97+a7JmpODRuMKMg2clNX4a40VBSXONONJZLXdC7ly4T
pjDz7q6eT+8v46+bYG7of416NX9d9cLjQirbPJDRb7V9NmhnHbD6NyA3WZIC/sWQ
79PYxVhgxHqK0/ddWRa7936sjboKtu+PkgDMg5ozoAWZkSsmSH18wF24MVO5lk7f
GMV0CH7PjZjF0w1+lRSjJcIv4wluZdAg1zhe/UUmDNpt3MeV/k705B8Cm7pHKpHx
t1cBNKrQruDWTtEETg6GABvpCk/PeUNF6QhobU3894BHCCFyHIjlVK7meyZ9dYYv
XLYhwVuLOV+KIQZWMdE/EQppS2e4EfapyoSCl7bVbvAppDJ8dVCVJmET5G74wMRy
6qN1JiMe5xRIvmVmCCyWbRIiQ1FtPFJ20Mtsp0j5fgmbpi10n4Ywbh3FDAYoLK7K
JqGhnMXdrX0bN4MecQlPy0gVMUUyow6cXjbVFASe7kTpspixuMhBRPECAwEAAaOB
kTCBjjAOBgNVHQ8BAf8EBAMCB4AwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUF
BwMCMB0GA1UdDgQWBBQaQYd4TQclI/UZok+c0jwZtkKsVzAfBgNVHSMEGDAWgBSb
VZDIUoq4rr4Cq5t+eAggDuAe5jAdBgNVHREEFjAUgRJqc2VtYWFuQGludmVyc2Uu
Y2EwDQYJKoZIhvcNAQELBQADggIBAF20oFUW/vtpLJyh+hvY4SACGrUpUF0coqzu
vsEb3ijmLM67qIR/+QIKOTdeZKyWH+2eMhiiNr7K4/f+kiIJLaB8AI9hs15uth9u
lZwmOAQ4K23enF4mnQf7Dgxxa0M+QQr1IPC6+PNSffLnwu6F3fxnqFNP99Tr9IP4
JZeznJvJ4FLNDXyxx1KHgjq8UEBGFXpdbMF/W2ydDhtYmjnkXFyGYjpaPbsQ8uOO
97IpIEq3nj9ZNRJNFyiXdPpDtyd6Vk6u80JzZIhH11nFS9crEry7mnUl2+uTIjm2
MK6GlIcLFrZjojX1lNXge6iP9yOAIkfn+6RcrX392yD+tc84TxXaTU/T6DMZAGV6
CCL6a2F9tfcC8gBM1YAka3BlXmMmzxAaFSLquJBbRtYWOpChF6+lQr00zqkK6Max
E15esc6u/snU48V2V4ICj434tJA7k43UOfwt1GAZXA0rYHcjG9DL8c/k5zzUW1it
ag+cuTvB/rqsGQ3hZPxNkmuoelp59uf8A6YjkHmhgP3spoOj79W7P394XVpd5VMD
RuR+/kr6L1BuwBxpckAak5xgtLTfnV3fDL7j3HOOu3qrsGH23Uetbh0SY4kJ9VA9
AYK5gYCyQml6CcDmdqtXNRCK1UQzqp2X/yWCHw4tit6J3yOL1ipUN/0v0/HtL48v
WbiT0yk7
-----END CERTIFICATE-----
EOF

my $cert_with_chain_ca = <<EOF;
-----BEGIN CERTIFICATE-----
MIIFlTCCA32gAwIBAgIBATANBgkqhkiG9w0BAQsFADBUMQswCQYDVQQGEwJDQTEL
MAkGA1UECBMCUUMxETAPBgNVBAcTCE1vbnRyZWFsMRAwDgYDVQQKEwdJbnZlcnNl
MRMwEQYDVQQDDApBenVyZV9UZXN0MB4XDTIxMDUyNTE2MTUxM1oXDTIzMDYxNDE2
MTUxM1owVDELMAkGA1UEBhMCQ0ExCzAJBgNVBAgTAlFDMREwDwYDVQQHEwhNb250
cmVhbDEQMA4GA1UEChMHSW52ZXJzZTETMBEGA1UEAwwKQXp1cmVfVGVzdDCCAiIw
DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALFCtJldN89BgnCAGRcbzG1eAn1R
d0zl5mmip8onRl/woVE2w4dZK7F9VSvu6Nj7qIZz6PNhNvK/Y90GQm72mbZLiEh3
eGjfbrwpL4YhE8X+3Di/EMMXrTwolr4q35g/Ghju3UndonRj7KQVr+pmwN0gTaAR
m0P3celliAnRbSWMPRSn7b8m/UoHOauwzPsJX4y9sK57QGTyT1JfoypSoCRplx5+
KIbhxqvfrwCUwJ6DSk9Q0XrXxSJjRG4l0o0h6TfZ0ZA4bxG868vGv4Wm4rXdLZsV
Xe2QJ+U29Kye3aYj0pQAxadWQW/C/k0Ff19QJyoMIJXD5PXOHs/m+5econFIlu1+
oRSSUZgtx/YqRa7FBLX9YeHA8oG3a3Kum+qVvW8WX3Pf7UXJXSngbnvCNPB/FWlW
ZJgpzSqmAP7Ht1XHiOSXTn81Sg1yqH9gnJi/1wWCYRAE+SEjMr4vJzPwi1RdiumS
v8qizYvfB6FUqYYdQfK+IWLRy5sEj/JQ8CgrXRROWKSpZ7svWZLHd9m74jMKbWKs
gerDttxjxV9HxJ+6cQiuMxNK3crksAnQvrDoMzy+7ES2tWQsAX2Kj+VuVEafniNb
yPwE7zU4yJ7/EYqQ8e4WoQgMTz+IvYSeoUrDLZI/Dmryy7e4/02IALsiKL1d0A8t
A//uxd2dhv0SGfNZAgMBAAGjcjBwMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE
FJtVkMhSiriuvgKrm354CCAO4B7mMB8GA1UdIwQYMBaAFJtVkMhSiriuvgKrm354
CCAO4B7mMB0GA1UdEQQWMBSBEmpzZW1hYW5AaW52ZXJzZS5jYTANBgkqhkiG9w0B
AQsFAAOCAgEATOUDQ4hSQnetpdyLLKCkx/+PUZqF73o7gcr2XQKw/y9VaqScHOq6
s7xM3D2+bgCVB5SbtoBeq9krhbHzqEJHVbqnqvn5aSph0BSrztn94D1UfOkiIDyU
KegVk7GZbiEBKSjPhorpawd6zv+J2VsJxcwEJGihIxuOGQIz9w+Qa6SuQ9iU7Oqi
f27UrxBkWvYuETfKc+JiBAHPFf7UHGd+lXV0hfDqe8kyh2PB9I+n2Ls/MjtaoM6u
xUiNGkGkFgkjlxJulMI6MeF+DRxC5Te+uy/oPTuwpjloYSKX7ImlGmQlp2SVJQxB
OFr3hY74papUpieaLpJ++GmHfOXwqY3g9ukZ87UgRLaU5VWD6Ai3KAHLSHfxo2Np
YZrdDbL66yDqD38VabQM41HNp60ffxIEZtavil+FTiCEIIRezUr+TV6glX8bSGgb
QcDX7W71tP4zP+gOnqijemHcBVSmWl98Vc7LEc1KSCgrIzwjT8tqlU/7eYDjUDRo
40wHJcpEeqdGVNkbXnRuQoRoKqVUDsUhb6HKeUswliyF6QHfrG+gs2F71JVp7iLl
rI6c9xVbZtbGsh7bMcITVH5xZLCQ9SVxVOk3oqc3gt+I4R42JuhdoELnduzrFdcg
o6bPxmxnICBhixNfdrKAlIQag7MIG+sc+MX/ihRgwcOB9dq8RVuJng0=
-----END CERTIFICATE-----
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
