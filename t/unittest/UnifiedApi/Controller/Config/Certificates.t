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
use lib '/usr/local/pf/lib';
use File::Slurp qw(read_file);
use pf::file_paths qw(
    $server_cert
    $server_key
);

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;

    `cp $pf::file_paths::server_cert $pf::file_paths::server_cert.tmp`;
    $pf::file_paths::server_cert = "$pf::file_paths::server_cert.tmp";
    
    `cp $pf::file_paths::server_key $pf::file_paths::server_key.tmp`;
    $pf::file_paths::server_key = "$pf::file_paths::server_key.tmp";
    
    `cp $pf::file_paths::radius_server_cert $pf::file_paths::radius_server_cert.tmp`;
    $pf::file_paths::radius_server_cert = "$pf::file_paths::radius_server_cert.tmp";
    
    `cp $pf::file_paths::radius_server_key $pf::file_paths::radius_server_key.tmp`;
    $pf::file_paths::radius_server_key = "$pf::file_paths::radius_server_key.tmp";
    
    `cp $pf::file_paths::radius_ca_cert $pf::file_paths::radius_ca_cert.tmp`;
    $pf::file_paths::radius_ca_cert = "$pf::file_paths::radius_ca_cert.tmp";
}

END {
    `rm $pf::file_paths::server_cert`;
    `rm $pf::file_paths::server_key`;
    `rm $pf::file_paths::radius_server_cert`;
    `rm $pf::file_paths::radius_server_key`;
    `rm $pf::file_paths::radius_ca_cert`;
}

#insert known data
#run tests
use Test::More tests => 31;
use Test::Mojo;
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

$t->get_ok('/api/v1/config/certificate/http')
  ->status_is(200)
  ->json_is('/certificate/subject', "C=CA, ST=Quebec, L=Montreal, O=Inverse Inc., CN=pf.inverse.ca")
  ->json_is('/certificate/issuer', "C=CA, ST=Quebec, L=Montreal, O=Inverse Inc., CN=pf.inverse.ca")
  ->json_is('/chain_is_valid/success', 1)
  ->json_is('/cert_key_match/success', 1)
  ->json_is('/certificate/not_before', "Feb  6 15:35:02 2019 GMT")
  ->json_is('/certificate/not_after', "Feb  6 15:35:02 2020 GMT");


my $cert = read_file($server_cert);
my $key = read_file($server_key);

# Replacing by the valid existing ones should work fine
$t->put_ok("/api/v1/config/certificate/http" => json => { certificate => $cert, private_key => $key })
  ->status_is(200);

my $new_cert = <<EOT;
-----BEGIN CERTIFICATE-----
MIIDVzCCAj+gAwIBAgIJAPU3hXnJhgNfMA0GCSqGSIb3DQEBCwUAMEIxCzAJBgNV
BAYTAlhYMRUwEwYDVQQHDAxEZWZhdWx0IENpdHkxHDAaBgNVBAoME0RlZmF1bHQg
Q29tcGFueSBMdGQwHhcNMTkwMjA2MjAzNTU3WhcNMjAwMjA2MjAzNTU3WjBCMQsw
CQYDVQQGEwJYWDEVMBMGA1UEBwwMRGVmYXVsdCBDaXR5MRwwGgYDVQQKDBNEZWZh
dWx0IENvbXBhbnkgTHRkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
wc2ju74NhGuW/tx91KGH93VT09ukC9zkoIef4tRzHcfrVPPl5j3Yk+9vb3kfPiMO
Sk+TivgihbJLVTg5ATxzU0DeCxOg/umG7gxrv5SmSA0yc/gJFbLsJItpHPmSL5Iy
aOnSEMFkSNE6dKxuSexYtT040wAmOcpz0JQPDkLig5Z3D7pOAEMKZofaN2NZgEFe
STECIUaBwfO9/TM9L9azJcv1n4SKxwqW38KGwZ6bSfRJBElWWxRXMI9/r2vTFjTM
+ltN3YrM3T4QMlGr3PTalG46qPh/92sIid4MS1ZukgRPCSLeSSL3Pmj0HyAHdK69
yj65BhuWk5Q+yCiole7STwIDAQABo1AwTjAdBgNVHQ4EFgQUg0R3WmuZOW5YnGHg
FYcg7OpQvdMwHwYDVR0jBBgwFoAUg0R3WmuZOW5YnGHgFYcg7OpQvdMwDAYDVR0T
BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAa/s98r0RPAoVmYZTdBrZOlbWkr/7
17eDE3Eg32I4dqnpJfNz8jrUSwSRFYITWT6nzS24GjZenrm63SLhXvNnGljtFLUZ
mTSR4uApImAyf7E/3w2nEfLiHkbEOB0XPxdoaTvptmmg7tomGbi7fC9Z+QjFiVzL
x3vGiHNmF4p0pCggYE95n3QXK/sbpF65cn7oJZ+bSlUfpqpMUYHGSccO38dm/OJx
wnNtcDy3e7pfFS2u6ouiEYzFx6jRpZedzxatGi/DzuFpHGX+C4tklriC0oLqbLfh
7mJOn4HYGAsn2bjUsZ4JMgJkmqM9n1bbUvwKYiy7girIIA59QGRN3KbqHA==
-----END CERTIFICATE-----
EOT

my $new_key = <<EOT;
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDBzaO7vg2Ea5b+
3H3UoYf3dVPT26QL3OSgh5/i1HMdx+tU8+XmPdiT729veR8+Iw5KT5OK+CKFsktV
ODkBPHNTQN4LE6D+6YbuDGu/lKZIDTJz+AkVsuwki2kc+ZIvkjJo6dIQwWRI0Tp0
rG5J7Fi1PTjTACY5ynPQlA8OQuKDlncPuk4AQwpmh9o3Y1mAQV5JMQIhRoHB8739
Mz0v1rMly/WfhIrHCpbfwobBnptJ9EkESVZbFFcwj3+va9MWNMz6W03diszdPhAy
Uavc9NqUbjqo+H/3awiJ3gxLVm6SBE8JIt5JIvc+aPQfIAd0rr3KPrkGG5aTlD7I
KKiV7tJPAgMBAAECggEAJ++5WtnKLUyCfBhxsZxryVmbIaA0SOGHF3F7SCHhavSk
kQgFixGZjLqdawo5nvNYYYXOcKe7bXOVRIVmcdPELBbE6uFrnrv+uxVCKuN19IkL
qYwmSxtowAseaQMg1b65tpbgW+WORdcfxaU2wPL8QLTR/eEc/3GxtfycsaKkzNqb
hkvqEj8KWYkYdMz8LV/SxLRgbP2yNoVbUHvHsyoM93bE5wLG24v44SOUNrUIt2SW
6oqizx8JGg7l7AwwAIFjzrf/2kx167fC6LIrZ3MZXkw6NaueB7MrAFXbbol9b29Q
bEw5V4ZOsdL5Ffgna8VdheeRUU7vGr5/ZPXogx0RKQKBgQD1sZm/gwT/vXVOnkky
jdYOkRIEQJgThd7sddpOsL8n1JLdaKff2IqtnRWH1INsvf6ilxaYpq5G38Hlod18
lI2ar8f+/WUQhN1iY1BDw2f/Z10BButw4lGMy4vJkULmOb8CPGnutRds49x+HXCm
b5/F7YzxU+E9aTBls/Wyjnk7NQKBgQDJ7s8/Yg6yhfn/XSyPC9H0gx4UUITk7sSo
K3wvqwSCjMTGI6WQtZ24hcpB0PiKkdlcqp+7JnWkK5LbkNLmjvjCCDu4h8TUK2Hc
fQnb7YZlSBF2QYyx6G+C16Yu2oLrEZuSOUVUlJBECyrgooWOBchom17c0MLcdeYq
3Xevs8ID8wKBgQCybToEtLeqqgJJB/aMeijcB0qYP/ixJOVRv/y8bOtFl8DYfip8
C5wanRuHuzN+gzQrC6JjVZj264S6qSRaVt/HWKTbb1Y3+uVzkEA4Fe6usnf+SPIu
1oz2vNNVnOKCo6ktjIY5ztWmRIxaIjMvC51ydiOHFq1alcuJ8HkcJQ+xiQKBgAJ0
qgaOTbl0Eac+XdVbgnEjyxDaLdOO58tXxAncXZCs35O9ST0qSEG/Nsd4IB2nSmpr
FMg03odhlEahSz9Mi8/oQ7mpxQYDhQwmZSFMkS7YIoY6o9hiCEEiGD5HoAH109uC
YMp3iA2bySi0MUWZ4mcLRKsQyt3dfTAWQ2dam0hrAoGBAL/cMrigwk99an9eFzHY
RmofafcxncWvDK+bZyknUkasN9VwQXQgIrszL0n4f1xoH8V7ikEnfmT7eDNqkBZa
R5Xt45s830Mhv+lEGaj2MZ9WapNKaA46CYVKPkHJo9X2YhCGZNLyoKouvL8vjMGR
CGIv2v3Q4mmh7woZMQeIKHwT
-----END PRIVATE KEY-----
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

my $radius_cert = <<EOT;
-----BEGIN CERTIFICATE-----
MIID2jCCAsKgAwIBAgIBAzANBgkqhkiG9w0BAQsFADCBkzELMAkGA1UEBhMCRlIx
DzANBgNVBAgTBlJhZGl1czESMBAGA1UEBxMJU29tZXdoZXJlMRUwEwYDVQQKEwxF
eGFtcGxlIEluYy4xIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUub3JnMSYw
JAYDVQQDEx1FeGFtcGxlIENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0xNjA5MTMx
NDI0NDFaFw0yMTA5MTIxNDI0NDFaMHwxCzAJBgNVBAYTAkZSMQ8wDQYDVQQIEwZS
YWRpdXMxFTATBgNVBAoTDEV4YW1wbGUgSW5jLjEjMCEGA1UEAxMaRXhhbXBsZSBT
ZXJ2ZXIgQ2VydGlmaWNhdGUxIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUu
b3JnMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzc6HbrMvAmcyUzXr
z0TOZPFK/NiU0d1mWNaJWvJo8Ak1aM5xRI8s08vGeHLimo4GBGl1tWEpu4gZIEup
FmZtmtT6WludTMUC/Suq6BlZ2TQtEgHOENJTl9OarC/+bzKEOEs5yysoHIuvR0GV
ywWlFr9PXAA+nXBpNeMePNyCjpI7DlEzNbWNTlT3zWp+A7B4vH+ZrKo2m234j1ek
570gCVemm/416KNX4yNY9nfJZt1fMjA56QbDt1N1xUEE2N4cHVeo/HJVainwVYg4
1d9VuQZRmgblpJQoiBfw9OC2JcjQOWZ6HwSxGZp9gHopQHIOCOZ45fIAQ5RQ8KgA
D2+H1wIDAQABo08wTTATBgNVHSUEDDAKBggrBgEFBQcDATA2BgNVHR8ELzAtMCug
KaAnhiVodHRwOi8vd3d3LmV4YW1wbGUuY29tL2V4YW1wbGVfY2EuY3JsMA0GCSqG
SIb3DQEBCwUAA4IBAQCS5dMPavB1djnc5lhYLa351/dhM+3DyZ6vZM9uadtlwXgE
g6weBJet1m569jRA/y0PsA0eoq9iOzWt9mG4CCCrQ+qrd4YTaO/apiGdsfVkfJPS
E95k2GByLPKPhk+tm7eUD2D5hBknK99lUZoY/4JUd4aoVXM9jfNOLCdEJWx0zAh6
iq0pSN24BwoGV1xBbmvvutm0OvUr9xOM5olPLfuRvIgm94Je8gCxKMNI+0rrgxQT
YXMkghkgHUrps2T3KcKuW80wAc6P9qKy0spr0tuXp8W59YTT3ANzrBH3DeIGQKHU
pVEH4tPlvc7/YqVU5qY0jZY/MGe/dZoyq0tA05VA
-----END CERTIFICATE-----
EOT

my $radius_key = <<EOT;
-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDNzodusy8CZzJT
NevPRM5k8Ur82JTR3WZY1ola8mjwCTVoznFEjyzTy8Z4cuKajgYEaXW1YSm7iBkg
S6kWZm2a1PpaW51MxQL9K6roGVnZNC0SAc4Q0lOX05qsL/5vMoQ4SznLKygci69H
QZXLBaUWv09cAD6dcGk14x483IKOkjsOUTM1tY1OVPfNan4DsHi8f5msqjabbfiP
V6TnvSAJV6ab/jXoo1fjI1j2d8lm3V8yMDnpBsO3U3XFQQTY3hwdV6j8clVqKfBV
iDjV31W5BlGaBuWklCiIF/D04LYlyNA5ZnofBLEZmn2AeilAcg4I5njl8gBDlFDw
qAAPb4fXAgMBAAECggEAWzA9VdFS7O+onrHvj+Deyl8XaLzWA77jkE1OgtuRn3mV
DqEaEtSVeip5//h3ax+ujtnja8Bna048Q9ECVIiB2+6uFsctBUztrBtjGH/TDahO
qAHguhdXLph1mgGR7NcnOoIqU1kF5tAFk779jf0sTs3pbcw18jBSjavaRAE4X86j
D5gGcarND0epjfpVjmZZZBlJA/lBsJMP8xEvwqqDLCkcRszGmQIblDUmtPDa9Wo6
O+EegQaSC4pwiE1pm3jDsNd5f61Cf6Xg3Yw0jbJNwHgE24naEAonxXRp6l0c67r0
DxgczvbCkHDqd4r8LffiIlZL9tgH2qPGQJcAg9IuAQKBgQD4QpAk72PBp0R1RTbp
/B5bMKoAjNwuwJa6LwcwLd3k/fjGha+a4x60JoyuB52FK5u3NO8Df8G44surQf0p
gxferDgDOzQX5V/qunCCLgDZTs2P7Am8C2VAluV1Fq5iu5SNQkbtbPTyCuFgkU1a
Dr9pNE9NyEZFM5oyszlkpFkxgQKBgQDUOSJHVbOKkmk1n8bK4GAhXlHt/nFJ+gH2
J3VexoMEL2PzE+HWsLymyMQP7b7igx1ER2vBXkaDktjBwr2x9mGxE5NCCQ1GRhqU
CvDniF7jOIBUwKwzFduPl2C4f27K4d/FRBFtWpe2G4LMWge7R3SK9lWgmx9/KQ2X
/Hbm7eA1VwKBgQCKEnMap61iicXQNwN4lQjJDMKv9aeLtP7fY8JqsEfF0N5ogveM
fB6acQoyy/d2li9PcHgyCP7T9gbyI4xKZyeCZ2ProCSz2ZVD9hcWv8EnGuXG0q8D
T48rogDR4yBvtwXCnobWC5AbgaOhUo6jtKoON9KXXvh+CloLMpSL/b/BgQKBgQC4
zvRB6KjMIInML9Jes5wjEs8IEM65HCT/Jgd4vCg1ycshUAwX+JqgJy9Nq7zR5lnj
LsrwflerloJ54UtuIV+bY6+WDunna38Tsp9tEP2Io5hltc9/QSaNWcbZg+eId8B1
ObxvXTfGVxjFOhWHikc8CB4zGUMJakezNiCZI0dfSwKBgQC6n41Vha7QVNTLTnan
tXTYmnfB5gDmJiUF/DH/45CjGqUati87lKFYBwjDtn/B1/z7OXET0/s79g7CGkS5
MnrkGjDkG95AS33mfQo7TJTgTYXSm9ME9cEYAYGgMRYjW3iXqMlH3hPtjes2FQOU
VJ9bFOA+bkdWyaaRnLWNT5/QdQ==
-----END PRIVATE KEY-----
EOT

my $radius_ca_cert = <<EOT;
-----BEGIN CERTIFICATE-----
MIIE5DCCA8ygAwIBAgIJAMWCyubM42biMA0GCSqGSIb3DQEBBQUAMIGTMQswCQYD
VQQGEwJGUjEPMA0GA1UECBMGUmFkaXVzMRIwEAYDVQQHEwlTb21ld2hlcmUxFTAT
BgNVBAoTDEV4YW1wbGUgSW5jLjEgMB4GCSqGSIb3DQEJARYRYWRtaW5AZXhhbXBs
ZS5vcmcxJjAkBgNVBAMTHUV4YW1wbGUgQ2VydGlmaWNhdGUgQXV0aG9yaXR5MB4X
DTE2MDkxMzE0MjQ0MVoXDTIxMDkxMjE0MjQ0MVowgZMxCzAJBgNVBAYTAkZSMQ8w
DQYDVQQIEwZSYWRpdXMxEjAQBgNVBAcTCVNvbWV3aGVyZTEVMBMGA1UEChMMRXhh
bXBsZSBJbmMuMSAwHgYJKoZIhvcNAQkBFhFhZG1pbkBleGFtcGxlLm9yZzEmMCQG
A1UEAxMdRXhhbXBsZSBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkwggEiMA0GCSqGSIb3
DQEBAQUAA4IBDwAwggEKAoIBAQDVDCeSEoLX2HyHF/hEYIk9+xIhwZzjeecfX6II
brVXDlIYd0F+asQ6rFVJXsWHVon9OMlPQPBZDIf0klSiK5vtkmYaBbwMsyQv0OEx
tb/gXyT0t3ADhfe3if14QP4YF9SiJFZKxJbAcDt42F9TK3hjZmb2w7Q4R4vvfPAt
vlQTlzWGZ8RdnHGb/3FAX7LYU9mk5Ne3mgHXrsl/Cd64COsO0t6mNAiirCpYNIaJ
H9LbFtELLOkgoGyGmtRFfDGrkfw0l1K3fE1eojZraYQMtpgiszHYlYIgbF/NW+3E
nAFQnUPgUkVmyfpD8qh/xXN7/mPg7x0kf7xnL2efW+wqhjPhAgMBAAGjggE3MIIB
MzAdBgNVHQ4EFgQUH+c/03w+wYTLucxpi43cHIPQ/1kwgcgGA1UdIwSBwDCBvYAU
H+c/03w+wYTLucxpi43cHIPQ/1mhgZmkgZYwgZMxCzAJBgNVBAYTAkZSMQ8wDQYD
VQQIEwZSYWRpdXMxEjAQBgNVBAcTCVNvbWV3aGVyZTEVMBMGA1UEChMMRXhhbXBs
ZSBJbmMuMSAwHgYJKoZIhvcNAQkBFhFhZG1pbkBleGFtcGxlLm9yZzEmMCQGA1UE
AxMdRXhhbXBsZSBDZXJ0aWZpY2F0ZSBBdXRob3JpdHmCCQDFgsrmzONm4jAPBgNV
HRMBAf8EBTADAQH/MDYGA1UdHwQvMC0wK6ApoCeGJWh0dHA6Ly93d3cuZXhhbXBs
ZS5vcmcvZXhhbXBsZV9jYS5jcmwwDQYJKoZIhvcNAQEFBQADggEBAEz667rnrZZE
+S9LqukQ039SoekCQSMBU/RUr9p14IpPaSiUccF1qPm/gQBqsiXH3TugKENbkdXj
t3o87udBm29JHNC57KLaR32yOj0SBjP2/xD3frhngGl7k+GN6cI3FAWNtuOoVnyg
9UHG2x0I+7RKpUAdZHm7eAgk0sLXM5mG0b15gBHcs8CYvH3OhQh9h4eyD9zDEXpN
QG9rki7MgfIm3lypG4OyPij+mHspPF4fLNPbzL5AAknPp3qL9o7R58XLBYabx1z/
0tm6B8s1NVu2Tbag2Yh9r4GzkUzNWo5cIv3rh7iVzYUPWvXrTIQx6igecXGSur/m
ghn3/8F0JeY=
-----END CERTIFICATE-----
EOT

my $new_radius_cert = <<EOT;
-----BEGIN CERTIFICATE-----
MIID2jCCAsKgAwIBAgIBATANBgkqhkiG9w0BAQsFADCBkzELMAkGA1UEBhMCRlIx
DzANBgNVBAgMBlJhZGl1czESMBAGA1UEBwwJU29tZXdoZXJlMRUwEwYDVQQKDAxF
eGFtcGxlIEluYy4xIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUub3JnMSYw
JAYDVQQDDB1FeGFtcGxlIENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0xOTAxMDkx
OTMyMTdaFw0yNDAxMDgxOTMyMTdaMHwxCzAJBgNVBAYTAkZSMQ8wDQYDVQQIDAZS
YWRpdXMxFTATBgNVBAoMDEV4YW1wbGUgSW5jLjEjMCEGA1UEAwwaRXhhbXBsZSBT
ZXJ2ZXIgQ2VydGlmaWNhdGUxIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUu
b3JnMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAy+miYZFdBYI22KwG
aBbDf7a4bcCFnpgMKllIoPXRD3XSSc/+F0M8jbai4dUcUmdyf8BkWQAkEcA0rFSq
1IlDep4GWWDjrIGhAtJMxM1lsj/6YHeMJSnvZGcNz7eo8e2ZId3m9P7LjzVOFtay
CnSZAwDvYKLB5sYoH9AVPv2Un15HBjTbKRb9aNlRdV9MZekOG0SzE+CNp3jQRhyG
fTsmh49BqbgvVO7UA+Ryg5O6lv+pib2b0S/0GgIfsrtTlt99248dEX7kXEZksSwX
AgVaGHKkYeC+YX+gY2S/u1BXz0WJJWtgusDvGtHDV/7FR3uuL6zjQoT5Ehh2kXn2
XpuT5wIDAQABo08wTTATBgNVHSUEDDAKBggrBgEFBQcDATA2BgNVHR8ELzAtMCug
KaAnhiVodHRwOi8vd3d3LmV4YW1wbGUuY29tL2V4YW1wbGVfY2EuY3JsMA0GCSqG
SIb3DQEBCwUAA4IBAQAK+yTKrnuzAHNDIp+/+24PkfowWmZjvyD2/QZzBQ3ZQKYv
vr0H+ZfwKUyFuONNpk6+/cTyZ5hcZmTkt0Vz03/NGijU4dZz95VfBgN2FHJctAAW
UMTmUoSbQDuIPBb2tDHSYdH1DLQc/4PYtBs5cemZifW71pDxExd6BUFSDb+FBplx
2ztuFzrhlkjV8RjpFwl9BuWzLErujkNFcQ9e6G3U7GzUqvm5lrryMXlx8UpDIG1M
E1xs+U8OHyvkI2LC1qC2OANcvFagDvEnUfgoFFJH4hzkUDaA9OnUFX0Yvb/ueibh
t10PDs55riv8WXJlBU0wGcd42kk2yWdLx8wQpMRZ
-----END CERTIFICATE-----
EOT

my $new_radius_key = <<EOT;
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDL6aJhkV0FgjbY
rAZoFsN/trhtwIWemAwqWUig9dEPddJJz/4XQzyNtqLh1RxSZ3J/wGRZACQRwDSs
VKrUiUN6ngZZYOOsgaEC0kzEzWWyP/pgd4wlKe9kZw3Pt6jx7Zkh3eb0/suPNU4W
1rIKdJkDAO9gosHmxigf0BU+/ZSfXkcGNNspFv1o2VF1X0xl6Q4bRLMT4I2neNBG
HIZ9OyaHj0GpuC9U7tQD5HKDk7qW/6mJvZvRL/QaAh+yu1OW333bjx0RfuRcRmSx
LBcCBVoYcqRh4L5hf6BjZL+7UFfPRYkla2C6wO8a0cNX/sVHe64vrONChPkSGHaR
efZem5PnAgMBAAECggEBAIFCsTS4OQds6+ed5NHG3FbxNSgdipZmPA/8WRXvvX7X
aV5xAtksPg53X/lYZoO2H9br1rC0bijydnFnmoLwIF5yHgQ6bxjDc5WeShvXOEgu
VkEghy5nzuEOkqrB+c6ilxfo2qcjfVZirAW+Q05tazGEPjo78j6gDn9cIJu1k6kR
rzPJq6fYiFEHb832YaWmW14lpXvpMX1+CKMEdyxW+M31wH2Q6d7zVx+GqDrC1j5+
fogI2RgzByUdx5rI7fW8wVWTbWyceXJsST6avEfhLTiLJEvElrT+kG0kWDaCAA80
yhiYhR7TVakuYbVwxfUnO0vo3eeP3rHAua/kT78b0EECgYEA/R+BDwGk7cmvBwX3
Kko2D6owNPckdB/Wg5cKZTTGzTK9cFLpBi5XoI52nADOmISLDuy4f+bwDiwzhxeJ
M5wrOwPejAyBgv0hzq0odhuIqfo7t7JMcgb6nIfcTQXiii+IYYGajFj48CVP04uW
imw90C3IrISGIRNTl912Ts1I2IsCgYEAzjryHMt7CDexKZ6LxwgUM5sGkYaVd3+N
XBt+OaF/HQKzENzW52OjPcsfA2lplQZZNoybmzGbP/HRrDkXWhvdSDOZehiZK9d9
ve21FJWnyqEYoFTRXLXiTRcalMFk/OR6f0HMAzfgOPQzcBhodJib+QC7YndRLkFS
369xJU23AZUCgYEAryC/60EI+lhDF8nh00mbE8V9KvgfKZTplwvGbnVQYqKLfQ5w
GQ2xJO3MVG0eg1mY2I+hqyR9zGB6mioHjEStiFxJ+n2gkZ9PZ65YQzcTm/78mEDt
MStw8yHwov3CWjc+1a+U3SuluIkoLMX0Nvti3QkAQZRDNNkpSfY4p5bSorcCgYAl
oQ/IPUCHsVG8HFe4yzqUZ/b82qevFDEA22terJ769iEiNIlp0v5YKhXQk41WScBB
ecpyuMxxEHiHiis+n9Lyd6fLZW2dWEZzP0pJJT1mdZp+trs0xWMzWcHZ3qfElRPc
4G6PL8TT34r7Kxj0HVxoRL/sKYVAgV7TvblRayq3OQKBgEL2yHVP6vhr8IqGmlN0
+0605/GpnAODBU6W32zSzpw/3sE7TunTGkXqeVimPjUdkGJmAXr6HwfaaeYfCn4x
AI7JqfyX5HWLrqa4Ja6YtC9IKFQ9HIt8HO1AmTIq0NpyuuX04QAOpYkhrkOq7LSz
wq6IWJCpe1N0QBxucRkbu0ll
-----END PRIVATE KEY-----
EOT

my $new_radius_ca_cert = <<EOT;
-----BEGIN CERTIFICATE-----
MIIE5DCCA8ygAwIBAgIJAOOFxlLSB8QIMA0GCSqGSIb3DQEBCwUAMIGTMQswCQYD
VQQGEwJGUjEPMA0GA1UECAwGUmFkaXVzMRIwEAYDVQQHDAlTb21ld2hlcmUxFTAT
BgNVBAoMDEV4YW1wbGUgSW5jLjEgMB4GCSqGSIb3DQEJARYRYWRtaW5AZXhhbXBs
ZS5vcmcxJjAkBgNVBAMMHUV4YW1wbGUgQ2VydGlmaWNhdGUgQXV0aG9yaXR5MB4X
DTE5MDEwOTE5MzIxN1oXDTI0MDEwODE5MzIxN1owgZMxCzAJBgNVBAYTAkZSMQ8w
DQYDVQQIDAZSYWRpdXMxEjAQBgNVBAcMCVNvbWV3aGVyZTEVMBMGA1UECgwMRXhh
bXBsZSBJbmMuMSAwHgYJKoZIhvcNAQkBFhFhZG1pbkBleGFtcGxlLm9yZzEmMCQG
A1UEAwwdRXhhbXBsZSBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkwggEiMA0GCSqGSIb3
DQEBAQUAA4IBDwAwggEKAoIBAQC4I76eNx3PEX9GGivyiSbBEjnlyQZ2heG/EwC6
Xa3j0nOvT5EQBHiGKZCsjLxxsedHRjEfb5iFdh1vgbqksMTa6zh2dR6XUsEx7k5y
4k2d9lmrgLPye+bMjFjWJazKYSgDuIPYt/7xcVbVnSdZyeHHhg+UEHfeUZlQD3Ca
MlW3gCXC1rfNWiOi5cxvrAomc1wh6UGY4wyRh7ZtqhgDOGYrhZDzW9rfaXcm3dJI
FlFohzQPc48k7vVjm95q1v6c8P8yXu0l8bE1tC7JI/HMMjW91gXnD4GHthS0W7vN
4iJxjOEJliVpwE4iRmH7Stc55WqoQ/21z8s2OabUWuhJEaVzAgMBAAGjggE3MIIB
MzAdBgNVHQ4EFgQUk2Kcoim0WMIpRC37TCOwvhINFW8wgcgGA1UdIwSBwDCBvYAU
k2Kcoim0WMIpRC37TCOwvhINFW+hgZmkgZYwgZMxCzAJBgNVBAYTAkZSMQ8wDQYD
VQQIDAZSYWRpdXMxEjAQBgNVBAcMCVNvbWV3aGVyZTEVMBMGA1UECgwMRXhhbXBs
ZSBJbmMuMSAwHgYJKoZIhvcNAQkBFhFhZG1pbkBleGFtcGxlLm9yZzEmMCQGA1UE
AwwdRXhhbXBsZSBDZXJ0aWZpY2F0ZSBBdXRob3JpdHmCCQDjhcZS0gfECDAPBgNV
HRMBAf8EBTADAQH/MDYGA1UdHwQvMC0wK6ApoCeGJWh0dHA6Ly93d3cuZXhhbXBs
ZS5vcmcvZXhhbXBsZV9jYS5jcmwwDQYJKoZIhvcNAQELBQADggEBAJWYhQFlvbGR
H+Cf112EB7aeABXjiiIDbtrU1jxHytRGSqNf2JOjikHrjTSsJeZCNdve5tPAkW7m
+1fxx4Ba5P/aTRwmmk0nzgakqHh6nw6WpO6WuIY0wXnG5HnhJbvNJ/FHUKt7gUNZ
yFp4aqwaTji9jUqbGzqpQlqFWwmqVnsvm2Yq/8PGUzbbMcZ6BBHjTl7UgtW+oRKT
Dx5o7pL8v9UIExHulivegGBS0Bee9lLcZ05mWeYyJIQ4p7KqLFGu/Jd/2cGYk97o
m8ZbKzanpO0Edoe9qddtxT/Ei+fNcPZgCN+X/0D5m/JuGcHE7fFWlkXmxUzNXsCa
AONIqvjkLq0=
-----END CERTIFICATE-----
EOT

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

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
