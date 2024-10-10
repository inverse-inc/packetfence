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

use File::Slurp qw(read_file);
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
use Test::More tests => 34;
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

my $radius_cert = <<EOT;
-----BEGIN CERTIFICATE-----
MIID2jCCAsKgAwIBAgIBATANBgkqhkiG9w0BAQsFADCBkzELMAkGA1UEBhMCRlIx
DzANBgNVBAgMBlJhZGl1czESMBAGA1UEBwwJU29tZXdoZXJlMRUwEwYDVQQKDAxF
eGFtcGxlIEluYy4xIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUub3JnMSYw
JAYDVQQDDB1FeGFtcGxlIENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0yMTA5MDYw
ODA5MjZaFw0yNjA5MDUwODA5MjZaMHwxCzAJBgNVBAYTAkZSMQ8wDQYDVQQIDAZS
YWRpdXMxFTATBgNVBAoMDEV4YW1wbGUgSW5jLjEjMCEGA1UEAwwaRXhhbXBsZSBT
ZXJ2ZXIgQ2VydGlmaWNhdGUxIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUu
b3JnMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1QdPxaniWPX1nkf0
WMV0i5/0EtCrBUJNnL50CMl0lhZWt00leTKPbNZQupLWd+cYcUrjgCFkGBO4kiw6
fznkRIfHEglWzpU8pArzAVY7OxKT1DOH3mxO0nwoDxBHGo6usB8oa58suwG0nvEs
1ug4v3RVDcYC74UljPMwRqTswUIABQIsMcqiOr2zFxh+EYqgF+zU6DmvYj58d7hg
e/RRvVDFzfEMIL+emjMjhhPZyo3uS/BVD8vxcSXcg4QEeowy9KdWsY8E4kYK7T5W
1GLYvsvl+uPIy+UGeEsPSeJ3tKrExf63QAyi1ugZNIefzm78IYRMkebSKPDGqWq4
REl1sQIDAQABo08wTTATBgNVHSUEDDAKBggrBgEFBQcDATA2BgNVHR8ELzAtMCug
KaAnhiVodHRwOi8vd3d3LmV4YW1wbGUuY29tL2V4YW1wbGVfY2EuY3JsMA0GCSqG
SIb3DQEBCwUAA4IBAQCsRAYFF4CnpwfVhgZwQzSVgvZ694X6AOSwScUbVR+CyWwf
8e4LGh2UPg1kETx3h8Pn4AUppKkP6eJqy/XOtfEVkZ2zfX0RNpw2wwq7V+UMO8jE
ybQGzOzL3Od0yImGd/i044lh4Pjdy9yMPUrTyqok89HOOpSHacuFK8jolw57U/2s
2XCCcA7aLt8Auk1n2uTHR/dDCygwIUKMr2vCfqpDpD3Z1/+jDr+lGfj53WvVXpGC
5iLT/VRFlbF3diz1kaJID9NgbCbI12CgFEtgYgoqUrsuTy/ReCNHeftfh5/DOgaS
3PEPL06fEGfvXy9vJPg+dj4jDOhQN3oDdJBTfc20
-----END CERTIFICATE-----
EOT

my $radius_key = <<EOT;
-----BEGIN PRIVATE KEY-----
MIIEwAIBADANBgkqhkiG9w0BAQEFAASCBKowggSmAgEAAoIBAQDVB0/FqeJY9fWe
R/RYxXSLn/QS0KsFQk2cvnQIyXSWFla3TSV5Mo9s1lC6ktZ35xhxSuOAIWQYE7iS
LDp/OeREh8cSCVbOlTykCvMBVjs7EpPUM4febE7SfCgPEEcajq6wHyhrnyy7AbSe
8SzW6Di/dFUNxgLvhSWM8zBGpOzBQgAFAiwxyqI6vbMXGH4RiqAX7NToOa9iPnx3
uGB79FG9UMXN8Qwgv56aMyOGE9nKje5L8FUPy/FxJdyDhAR6jDL0p1axjwTiRgrt
PlbUYti+y+X648jL5QZ4Sw9J4ne0qsTF/rdADKLW6Bk0h5/ObvwhhEyR5tIo8Map
arhESXWxAgMBAAECggEBAIFtwc/smbNHLQYP3auZvGegtWBBG8dEM3eKV2GHVKhj
xif0XVI3n+CWjdHtqRSMedNLltGgd/oQ8VEOQjRObhwdCpwwxGcbUQ6yAFbNl4sa
jGqfLGu9Dl7gRE5yq2C9U/F53MsWmMy+ComPKpkf2mqoOYz2w43XLatnjes+BQKd
BRykqosfeFdx9Oeo6MuzMZUUIjmza7LQBOtKHnC2GZdzNEjP3x2gsoJROJeuotUC
RwR2qmuZCZ8tumkE0t9ycOTs76P8A1EoqAgFGZxYc9tzqCZx4dYPfWkTrV/LzWm5
mWE3dNDRp28oUSmnD0d9iuilooVK5Ul+gJHeLksBrmECgYEA75m1Cbe6EqmXl0ir
JxLaBrNcRus2Tu7fyV2JYdhvXIGeS/SAUQli9fxV4lYMBcWhCUH6l9uT30MqGofG
3zprdrhTeqLOERRxeUisZe9+FfmgQ+61coHFbGjTCSGzxP1ht0yabZnrgddZ3Z74
FEduUIU8uHGJISQ0HULzlRSpqm0CgYEA45wCwOHR5FMKVP2X4ry5zDHuAHtF7GNm
xse9szsrSytjMS+UF5k764aa34jI8mFliHPxF2rlmgCsmnorKeC43/yDC/McM2hT
UgcIgvuw+nK5jg1MqyFdxq0BF8N+JJ6hDJTqm4Eh6WFIJt6OmbGi2iTpHM5vcgJi
nPn/wg7frdUCgYEAgIz9XtteUAkBtj9c5Lfulk3BIqOsHal4E/fFb+PJy94XajUi
a1gX6laaVbdI+AfSoL7vjm5W5iCJBHb4smgLpES9NT0IRo2rXCErrf1SrsOhwxDd
9TO/Eq0jHPEiHHy94rSM3mUIwD8kjg1umKLCgx0ZOPRhWJCuDU0Ql1ngtfkCgYEA
ksTDMcVsJyM1AmEUU+0GkhmQM1dKW4gtefjK5ow8+pfbupfHkwAIl3OQ4pu9mC4d
3sOEr2kK7SeKJYKp2rNCA408o7P8d1nKgJZwcqYCFT1tUaBZ0/AMHFTq43v4F30C
tK5CKkw2pdtJP2c75Pea37f1adHkI0xOcpLyzRvyOJECgYEAiPuliNX4+PNH67Qe
sPtzt+i3pHFBkRY6Opjdnd5is2oGyUaD9GzYHDm5Qmu7m7zpQSYXGerG5djSSXgJ
mqQDYX8dcGfc7L7M94SjqbvkeEK7yy+X8Y/eSHI8EWasTetlAfaSAEFiLd+aA0xK
ZO87PsLqYGne7mG+7DpUuTuSMc4=
-----END PRIVATE KEY-----
EOT

my $radius_ca_cert = <<EOT;
-----BEGIN CERTIFICATE-----
MIIE+jCCA+KgAwIBAgIUD/HDoiLKZeBrForMLnsrr1RrhtowDQYJKoZIhvcNAQEL
BQAwgZMxCzAJBgNVBAYTAkZSMQ8wDQYDVQQIDAZSYWRpdXMxEjAQBgNVBAcMCVNv
bWV3aGVyZTEVMBMGA1UECgwMRXhhbXBsZSBJbmMuMSAwHgYJKoZIhvcNAQkBFhFh
ZG1pbkBleGFtcGxlLm9yZzEmMCQGA1UEAwwdRXhhbXBsZSBDZXJ0aWZpY2F0ZSBB
dXRob3JpdHkwHhcNMjEwOTA2MDgwOTI2WhcNMjYwOTA1MDgwOTI2WjCBkzELMAkG
A1UEBhMCRlIxDzANBgNVBAgMBlJhZGl1czESMBAGA1UEBwwJU29tZXdoZXJlMRUw
EwYDVQQKDAxFeGFtcGxlIEluYy4xIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1w
bGUub3JnMSYwJAYDVQQDDB1FeGFtcGxlIENlcnRpZmljYXRlIEF1dGhvcml0eTCC
ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOyJFEiScMsOM5Y91E1jEpc+
jJZMhx/6z+G8RmOwM5FXdCed1rb0f6kHtw4wWnUdvJ6hN5pbLgXKe0mPTDw8quE5
BXUT3BRNdYHATw8ZlHbf5FoxQ1nqI8En6ORDPjt4x0RyJsCueBbsZku0m6eyV9zb
vNEcx4aRMFcIFxHFs/2ai9EVloVxD/5BcloYxWPp1STYtsmLBPJrtxBGG+qoFvYl
eTAJH11s0447qHq+KU7PeyDp+McEzlm2QaeauoC9d0nTkt0fzfYGgI60MCC/GZDV
F9ezhpXojOJNOH3dkln47EsEvypdL7XA1ALE20iqf79dTBQHBbVjJY9NpSdFC9UC
AwEAAaOCAUIwggE+MB0GA1UdDgQWBBRuYmWCYEg30hNGn2GAlkq5tCdi9TCB0wYD
VR0jBIHLMIHIgBRuYmWCYEg30hNGn2GAlkq5tCdi9aGBmaSBljCBkzELMAkGA1UE
BhMCRlIxDzANBgNVBAgMBlJhZGl1czESMBAGA1UEBwwJU29tZXdoZXJlMRUwEwYD
VQQKDAxFeGFtcGxlIEluYy4xIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUu
b3JnMSYwJAYDVQQDDB1FeGFtcGxlIENlcnRpZmljYXRlIEF1dGhvcml0eYIUD/HD
oiLKZeBrForMLnsrr1RrhtowDwYDVR0TAQH/BAUwAwEB/zA2BgNVHR8ELzAtMCug
KaAnhiVodHRwOi8vd3d3LmV4YW1wbGUub3JnL2V4YW1wbGVfY2EuY3JsMA0GCSqG
SIb3DQEBCwUAA4IBAQCc9Jd89nzOmdkYdRPsaQBGJSoWO1AIQz1sbHNVxpuMu+9e
i070jfP6LVcf+XKQUFJFGw2o6cOiDG9sxWNe5UM72QoenH2bBrjUxw7J5aA2u3Ap
bdJ5vhHENWPxkKGtv7CZOuqlWq0ThRcy0XEAzfqi42tEaGCQlxocfkJYAL4YlFfo
2pFYM18d68EPxKiPOJNJmatqqRoQfhpda7QovUo/FFIBeg/QlwDmqx1OeC7j+m2F
xvUqFefN8kWzUGXts4Okz53z18q2GhhJKS8NKua/8bOhI7jSWoJ4BaDiz5aqEq4B
b6eY3BSmAxkBiwX6V7JRn/Z+KKYAO/3HYpNBHfqE
-----END CERTIFICATE-----
EOT

my $new_radius_cert = <<EOT;
-----BEGIN CERTIFICATE-----
MIID6jCCAtKgAwIBAgIUaodF67xnMPb4Uw5HG9KtVVya7ccwDQYJKoZIhvcNAQEL
BQAwgZAxCzAJBgNVBAYTAkZSMQ8wDQYDVQQIDAZSYWRpdXMxEjAQBgNVBAcMCVNv
bWV3aGVyZTEVMBMGA1UECgwMRXhhbXBsZSBJbmMuMSAwHgYJKoZIhvcNAQkBFhFh
ZG1pbkBleGFtcGxlLm9yZzEjMCEGA1UEAwwaRXhhbXBsZSBTZXJ2ZXIgQ2VydGlm
aWNhdGUwHhcNMjQwMTEwMTU0MDAyWhcNMzQwMTA3MTU0MDAyWjB8MQswCQYDVQQG
EwJGUjEPMA0GA1UECAwGUmFkaXVzMRUwEwYDVQQKDAxFeGFtcGxlIEluYy4xIzAh
BgNVBAMMGkV4YW1wbGUgU2VydmVyIENlcnRpZmljYXRlMSAwHgYJKoZIhvcNAQkB
FhFhZG1pbkBleGFtcGxlLm9yZzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
ggEBAM57cWmMf9V97L/o+4fwSz2/6c02M1clol+08yc8rumRtWjHxMS/ORGckEjW
lt4DTaa8KvaBmyKf1JrdnUQ3iy6zTuUnNpKZQcSPtydX18KKcK8tbOdqxFcpNkcN
EjeHPZ15kmNAF0kaXAV93YNV7WLogaZmli5ngZzFies/jZSDNnrdCrc0SthS9oet
iccQmuxlifRtKkKsKNdPjcx2QlEh7wThS4EdExqQHCAzdG3V8QDRzcFa+StSprCi
+E6mda+s4AfhbOgA7xpXNb6CbewBhxpHaD1pTAs1Ja/9KzCbD5XvT/lCX4EIpyi0
mYxL/LnOBiXF1nspA7Vt5yHy32ECAwEAAaNPME0wEwYDVR0lBAwwCgYIKwYBBQUH
AwEwNgYDVR0fBC8wLTAroCmgJ4YlaHR0cDovL3d3dy5leGFtcGxlLmNvbS9leGFt
cGxlX2NhLmNybDANBgkqhkiG9w0BAQsFAAOCAQEAPY0PCTtNKQ5ZwSzb5rMBCNjh
id9Clclm9Fhbc8buCo96dkfeWyeIPtxIOzCOSt8k+jQOmuQnWDfaJa9mQmIHu8qX
bS1Dyx1IBePMEeqcdLSwiqkOJ24N505h3UOofe3ny7xbZG3pAxGD3gXYP2cMP+SQ
HCrQEUNKdAlShQUCKyvIDdB2QO4buH2KRWCOpg6X3dBA7lurDUg6NYFd0ZuExZ8t
ZGu7HXTv2bUXgnSTp9vz1KAq2hbMgpwhw+bS8UV5nWOxWS+k7uAiTsA4qc85rNRo
/4foH+plIc24BlEJaruHobPmJsmayKBfXI/Ov7Rux2TZ/DPDtPcMqaAtPI0h6w==
-----END CERTIFICATE-----
EOT

my $new_radius_key = <<EOT;
-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDOe3FpjH/Vfey/
6PuH8Es9v+nNNjNXJaJftPMnPK7pkbVox8TEvzkRnJBI1pbeA02mvCr2gZsin9Sa
3Z1EN4sus07lJzaSmUHEj7cnV9fCinCvLWznasRXKTZHDRI3hz2deZJjQBdJGlwF
fd2DVe1i6IGmZpYuZ4GcxYnrP42UgzZ63Qq3NErYUvaHrYnHEJrsZYn0bSpCrCjX
T43MdkJRIe8E4UuBHRMakBwgM3Rt1fEA0c3BWvkrUqawovhOpnWvrOAH4WzoAO8a
VzW+gm3sAYcaR2g9aUwLNSWv/Sswmw+V70/5Ql+BCKcotJmMS/y5zgYlxdZ7KQO1
bech8t9hAgMBAAECggEBAMRMpSCEOw/bXJWCSIcPEmkNJ5g5nAuQstKsM7Isxdk1
9jI8ITwu03GD18P3hoxgtZT7NRkPVE5Rhw0H/ThaWc63Fx1R71blrpnRS31yzKOd
e81+sRc88JYwjvJzYcs6noA0kNAcoUaVccCizVHMAhfTFVb+Fm7dZmKFhj4JOG9j
rDsHo/o0qT2Icb1NalY7DvcIBhoQXZr7SVh9C/eZCn5arXL3vh/cteh5ZGQyDxBa
jGPsxIwxOfSNlmP+X2ewO8izCt0BqwlQXGXke7FG4XuDv713Bie8FsP+jsSy/8Jr
pD+/4qrrhh1Tkg8MAqTEtDvXQz+jtpOeduANQ0iy3sECgYEA+tH6XXPZ1G0lUK1f
NHAq/e8Bwjy9Y5l9NwFPhy7o6l/i3htVaEjSvsNIGGSyNifIfUoCQ5dInJ5izDO2
eDVqpj6CHi9uke1uEsyoKzuykhY0fspJkKk3lUL/ArjQ+/YTg7PHNoQ/xGs61B3i
pS/7OBylsECaW3pZDBQQOHQk/DkCgYEA0r8PsFuQY5VCDiTTtyBu0oXzVm/f9zJq
DpHg3Ni9WLNsojje2jxLAzDlPkOnIS53JOvjRb2GnrYu4gu7HnPE0z9CBeyhBZue
AkvyOu0a0SFLn8iBFFECh8XRnYOc7blfBs86DJW+ji4TeshD46akgoaA69rtPTvi
e9VmQ6gazGkCgYEAy4Q/qz6KnKQnaAwVOR5etAcQHURdxAhSIqSsnBsDINHG6sOx
DFoyrlkUEb77H5guRQMdTSze3T5jGiBHychGDjigKdAA3uWRsC1hsxrQbVsZI1wO
TxQPJszi0JmX8SodcXsZhPHQMBd195F8St7g8AnGo3n4BYwD3xoUg0oyjHkCgYB3
oG62a/NVI7eAMdVf4PAnXlPXn9+hASQEqzfaBMnOXOLwXpnZhVoLMKkgI+Ttx+Nn
uOKkhsWwt7d7Jq+LxKlYRFMk68InXcNeiF+ypT6QsXas93KV5rop+ddXswrUQmI3
ik/oLuQg7vStwJoQ0loVoWXy+62pEaIpKuRGyViU6QKBgQCpJwOQK2wFpNTK7zWw
2tVaIHTHevXIa3Z56jvkd9TmBbexiXZKkiR098JbhUZZ5puzpD9+Pg0qPBWDPJXl
grPpT9rkRdERxQekGGPycQ/6SUK7hdLnxx5VXBXfd3RpFJH6ZR0KgUtTvDUvYFfi
umlhAxItRKeBsTwBswPAfnkAzA==
-----END PRIVATE KEY-----
EOT

my $new_radius_ca_cert = <<EOT;
-----BEGIN CERTIFICATE-----
MIIEPTCCAyWgAwIBAgIUMnIF4/JZTAEIADC37//OI/UD1QwwDQYJKoZIhvcNAQEL
BQAwgZAxCzAJBgNVBAYTAkZSMQ8wDQYDVQQIDAZSYWRpdXMxEjAQBgNVBAcMCVNv
bWV3aGVyZTEVMBMGA1UECgwMRXhhbXBsZSBJbmMuMSAwHgYJKoZIhvcNAQkBFhFh
ZG1pbkBleGFtcGxlLm9yZzEjMCEGA1UEAwwaRXhhbXBsZSBTZXJ2ZXIgQ2VydGlm
aWNhdGUwHhcNMjQwMTEwMTU0MDAyWhcNMzQwMTA3MTU0MDAyWjCBkDELMAkGA1UE
BhMCRlIxDzANBgNVBAgMBlJhZGl1czESMBAGA1UEBwwJU29tZXdoZXJlMRUwEwYD
VQQKDAxFeGFtcGxlIEluYy4xIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUu
b3JnMSMwIQYDVQQDDBpFeGFtcGxlIFNlcnZlciBDZXJ0aWZpY2F0ZTCCASIwDQYJ
KoZIhvcNAQEBBQADggEPADCCAQoCggEBAMVl06vvO4VO42zf+JBLiJrNYj3bORry
o3WTwYRSK+oAUYAtcRdlTvuQMrsi+B0IiqdqKzT3Fk+zIBBwkAqKv7gautF/l0zJ
ifmAhl8CmxHI1LdeqN2Wlw0alSEdciwJkACt8GWY3Y3ta9KNU4yCtHtPTwKlNfri
FQCjcfX0/ktFvgjsuKDGInbDJYKQpyHCmdkfWRxswOn7lBtriWB7+hd7M0xMRRQJ
QaPxYRb2czSk43FjLG4NetLktATSR1atgls4QPAwGgWfa0qtmMn6Wcdc+SIGHo1U
00YqEpF4fkDeS9OEyMKp76L2oJsp8xPepTas+H6F7LpVdh+v9e4We8MCAwEAAaOB
jDCBiTAdBgNVHQ4EFgQUxTiw2bbEIuzFKdeEXstMT6EI6FMwHwYDVR0jBBgwFoAU
xTiw2bbEIuzFKdeEXstMT6EI6FMwDwYDVR0TAQH/BAUwAwEB/zA2BgNVHR8ELzAt
MCugKaAnhiVodHRwOi8vd3d3LmV4YW1wbGUuY29tL2V4YW1wbGVfY2EuY3JsMA0G
CSqGSIb3DQEBCwUAA4IBAQB/qzAF1O59MjCF/dgfHFA+JuP78h2ZYKCpLU4efnOV
LvEcw6UR8sEjinGzU+0VuTHue7A1El7uZNX53BNkgbGqqRLQKsuVHU++teIK1W7q
CvMnvNr4IV+aze3ZKBuCOEuckkTPV3uz1RPGEPoXmw2Ng4rg1NDpg4+/7mjqc0wJ
ldlEVLgnWtGxczoikScFHwcrqYCmF9yhoQ9TJloLTFjXxosJLEMUeW8+tMGOjOHG
TVxAFrzPGyI6VP0w7/i29j0bXrfJnRff69gYQkrtyaov8zkeZuVmBVg7egZJCDe6
CzgeCV0xwhfDteky12T4F/nTyZoD1rijH5hZlXQFIv/0
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
