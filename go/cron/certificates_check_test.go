package maint

import (
	"testing"
)

func TestCertCheck(t *testing.T) {

	pem := `
-----BEGIN CERTIFICATE-----
MIID2jCCAsKgAwIBAgIBATANBgkqhkiG9w0BAQsFADCBkzELMAkGA1UEBhMCRlIx
DzANBgNVBAgMBlJhZGl1czESMBAGA1UEBwwJU29tZXdoZXJlMRUwEwYDVQQKDAxF
eGFtcGxlIEluYy4xIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUub3JnMSYw
JAYDVQQDDB1FeGFtcGxlIENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0yMDA0MjMx
MTQ0NTFaFw0yNTA0MjIxMTQ0NTFaMHwxCzAJBgNVBAYTAkZSMQ8wDQYDVQQIDAZS
YWRpdXMxFTATBgNVBAoMDEV4YW1wbGUgSW5jLjEjMCEGA1UEAwwaRXhhbXBsZSBT
ZXJ2ZXIgQ2VydGlmaWNhdGUxIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUu
b3JnMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1e1pedfXWXRuu7jX
dyhCx4SKW2gEncpAxZratAlxdMSjZ9huI8xn7ISWIDFYPnItWSvJiA5gWJFqkJbn
HTQWMnxFVq0xrWxYvAWATvrjzhl3DJW8Zp1OzY81w9pcuGEeFJ4+/7qlbA9ENx3r
PX875BYXHA8ivK3yjGamrBgMOAMyTSICA/Uao6M7J/hKT7tuQJ3A1GAAT016u++p
w0JMbrA3oYeOltMHh1xbIjxsLINna4ZVPLd8AuhZ/OpNGrmADfH2HeipwszBrUMo
ld54sp57B1s1lAXMsyEW9t3mF4ZpkJH6A5377k0VNTiJSwNgnqI3F9wlCyJF7/Sw
+5WInwIDAQABo08wTTATBgNVHSUEDDAKBggrBgEFBQcDATA2BgNVHR8ELzAtMCug
KaAnhiVodHRwOi8vd3d3LmV4YW1wbGUuY29tL2V4YW1wbGVfY2EuY3JsMA0GCSqG
SIb3DQEBCwUAA4IBAQBUcwANHYWdOQSm0Wz8dvC0a9SpuHy788GRdQG8G0KM5iuf
rXiw4Op8UXFk+NTJyIFdvmq7WfrdVRB7MMqBSkzdc7XooYGm9KPpnl1ysdzooAE7
BEG6FlxNYkBOClQf3enK2a0TtOH/qvaV8eqmz9VIIX0oYAijhbYwUEd+r7WAyz7u
STs99/M5xiQp8C2LU150QTyN8unpj0DdiHg+n9sRAHPS36WcpY5Ug1pvSBGf594g
rP4Jpxt4LoXCDQ+YqlxAs3AXBQc6mM8Gx9FyN5l1xWtHNutODpuUXAGrdHb70EyL
Kj44MrvVS4fJuIO7ADRRh5gQG8xe6Y9PoxDVFnwI
-----END CERTIFICATE-----
`
	c := &CertificatesCheck{}
	err := c.VerifyContents("", []byte(pem))
	if err != nil {
		t.Error(err.Error())
	}
	pem = `
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 1 (0x1)
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=FR, ST=Radius, L=Somewhere, O=Example Inc./emailAddress=admin@example.org, CN=Example Certificate Authority
        Validity
            Not Before: Apr 23 11:44:51 2020 GMT
            Not After : Apr 22 11:44:51 2025 GMT
        Subject: C=FR, ST=Radius, O=Example Inc., CN=Example Server Certificate/emailAddress=admin@example.org
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:d5:ed:69:79:d7:d7:59:74:6e:bb:b8:d7:77:28:
                    42:c7:84:8a:5b:68:04:9d:ca:40:c5:9a:da:b4:09:
                    71:74:c4:a3:67:d8:6e:23:cc:67:ec:84:96:20:31:
                    58:3e:72:2d:59:2b:c9:88:0e:60:58:91:6a:90:96:
                    e7:1d:34:16:32:7c:45:56:ad:31:ad:6c:58:bc:05:
                    80:4e:fa:e3:ce:19:77:0c:95:bc:66:9d:4e:cd:8f:
                    35:c3:da:5c:b8:61:1e:14:9e:3e:ff:ba:a5:6c:0f:
                    44:37:1d:eb:3d:7f:3b:e4:16:17:1c:0f:22:bc:ad:
                    f2:8c:66:a6:ac:18:0c:38:03:32:4d:22:02:03:f5:
                    1a:a3:a3:3b:27:f8:4a:4f:bb:6e:40:9d:c0:d4:60:
                    00:4f:4d:7a:bb:ef:a9:c3:42:4c:6e:b0:37:a1:87:
                    8e:96:d3:07:87:5c:5b:22:3c:6c:2c:83:67:6b:86:
                    55:3c:b7:7c:02:e8:59:fc:ea:4d:1a:b9:80:0d:f1:
                    f6:1d:e8:a9:c2:cc:c1:ad:43:28:95:de:78:b2:9e:
                    7b:07:5b:35:94:05:cc:b3:21:16:f6:dd:e6:17:86:
                    69:90:91:fa:03:9d:fb:ee:4d:15:35:38:89:4b:03:
                    60:9e:a2:37:17:dc:25:0b:22:45:ef:f4:b0:fb:95:
                    88:9f
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication
            X509v3 CRL Distribution Points: 

                Full Name:
                  URI:http://www.example.com/example_ca.crl

    Signature Algorithm: sha256WithRSAEncryption
         54:73:00:0d:1d:85:9d:39:04:a6:d1:6c:fc:76:f0:b4:6b:d4:
         a9:b8:7c:bb:f3:c1:91:75:01:bc:1b:42:8c:e6:2b:9f:ad:78:
         b0:e0:ea:7c:51:71:64:f8:d4:c9:c8:81:5d:be:6a:bb:59:fa:
         dd:55:10:7b:30:ca:81:4a:4c:dd:73:b5:e8:a1:81:a6:f4:a3:
         e9:9e:5d:72:b1:dc:e8:a0:01:3b:04:41:ba:16:5c:4d:62:40:
         4e:0a:54:1f:dd:e9:ca:d9:ad:13:b4:e1:ff:aa:f6:95:f1:ea:
         a6:cf:d5:48:21:7d:28:60:08:a3:85:b6:30:50:47:7e:af:b5:
         80:cb:3e:ee:49:3b:3d:f7:f3:39:c6:24:29:f0:2d:8b:53:5e:
         74:41:3c:8d:f2:e9:e9:8f:40:dd:88:78:3e:9f:db:11:00:73:
         d2:df:a5:9c:a5:8e:54:83:5a:6f:48:11:9f:e7:de:20:ac:fe:
         09:a7:1b:78:2e:85:c2:0d:0f:98:aa:5c:40:b3:70:17:05:07:
         3a:98:cf:06:c7:d1:72:37:99:75:c5:6b:47:36:eb:4e:0e:9b:
         94:5c:01:ab:74:76:fb:d0:4c:8b:2a:3e:38:32:bb:d5:4b:87:
         c9:b8:83:bb:00:34:51:87:98:10:1b:cc:5e:e9:8f:4f:a3:10:
         d5:16:7c:08
-----BEGIN CERTIFICATE-----
MIID2jCCAsKgAwIBAgIBATANBgkqhkiG9w0BAQsFADCBkzELMAkGA1UEBhMCRlIx
DzANBgNVBAgMBlJhZGl1czESMBAGA1UEBwwJU29tZXdoZXJlMRUwEwYDVQQKDAxF
eGFtcGxlIEluYy4xIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUub3JnMSYw
JAYDVQQDDB1FeGFtcGxlIENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0yMDA0MjMx
MTQ0NTFaFw0yNTA0MjIxMTQ0NTFaMHwxCzAJBgNVBAYTAkZSMQ8wDQYDVQQIDAZS
YWRpdXMxFTATBgNVBAoMDEV4YW1wbGUgSW5jLjEjMCEGA1UEAwwaRXhhbXBsZSBT
ZXJ2ZXIgQ2VydGlmaWNhdGUxIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUu
b3JnMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1e1pedfXWXRuu7jX
dyhCx4SKW2gEncpAxZratAlxdMSjZ9huI8xn7ISWIDFYPnItWSvJiA5gWJFqkJbn
HTQWMnxFVq0xrWxYvAWATvrjzhl3DJW8Zp1OzY81w9pcuGEeFJ4+/7qlbA9ENx3r
PX875BYXHA8ivK3yjGamrBgMOAMyTSICA/Uao6M7J/hKT7tuQJ3A1GAAT016u++p
w0JMbrA3oYeOltMHh1xbIjxsLINna4ZVPLd8AuhZ/OpNGrmADfH2HeipwszBrUMo
ld54sp57B1s1lAXMsyEW9t3mF4ZpkJH6A5377k0VNTiJSwNgnqI3F9wlCyJF7/Sw
+5WInwIDAQABo08wTTATBgNVHSUEDDAKBggrBgEFBQcDATA2BgNVHR8ELzAtMCug
KaAnhiVodHRwOi8vd3d3LmV4YW1wbGUuY29tL2V4YW1wbGVfY2EuY3JsMA0GCSqG
SIb3DQEBCwUAA4IBAQBUcwANHYWdOQSm0Wz8dvC0a9SpuHy788GRdQG8G0KM5iuf
rXiw4Op8UXFk+NTJyIFdvmq7WfrdVRB7MMqBSkzdc7XooYGm9KPpnl1ysdzooAE7
BEG6FlxNYkBOClQf3enK2a0TtOH/qvaV8eqmz9VIIX0oYAijhbYwUEd+r7WAyz7u
STs99/M5xiQp8C2LU150QTyN8unpj0DdiHg+n9sRAHPS36WcpY5Ug1pvSBGf594g
rP4Jpxt4LoXCDQ+YqlxAs3AXBQc6mM8Gx9FyN5l1xWtHNutODpuUXAGrdHb70EyL
Kj44MrvVS4fJuIO7ADRRh5gQG8xe6Y9PoxDVFnwI
-----END CERTIFICATE-----
`
	err = c.VerifyContents("", []byte(pem))
	if err != nil {
		t.Error(err.Error())
	}

	pem = `
-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAlRuRnThUjU8/prwYxbty
WPT9pURI3lbsKMiB6Fn/VHOKE13p4D8xgOCADpdRagdT6n4etr9atzDKUSvpMtR3
CP5noNc97WiNCggBjVWhs7szEe8ugyqF23XwpHQ6uV1LKH50m92MbOWfCtjU9p/x
qhNpQQ1AZhqNy5Gevap5k8XzRmjSldNAFZMY7Yv3Gi+nyCwGwpVtBUwhuLzgNFK/
yDtw2WcWmUU7NuC8Q6MWvPebxVtCfVp/iQU6q60yyt6aGOBkhAX0LpKAEhKidixY
nP9PNVBvxgu3XZ4P36gZV6+ummKdBVnc3NqwBLu5+CcdRdusmHPHd5pHf4/38Z3/
6qU2a/fPvWzceVTEgZ47QjFMTCTmCwNt29cvi7zZeQzjtwQgn4ipN9NibRH/Ax/q
TbIzHfrJ1xa2RteWSdFjwtxi9C20HUkjXSeI4YlzQMH0fPX6KCE7aVePTOnB69I/
a9/q96DiXZajwlpq3wFctrs1oXqBp5DVrCIj8hU2wNgB7LtQ1mCtsYz//heai0K9
PhE4X6hiE0YmeAZjR0uHl8M/5aW9xCoJ72+12kKpWAa0SFRWLy6FejNYCYpkupVJ
yecLk/4L1W0l6jQQZnWErXZYe0PNFcmwGXy1Rep83kfBRNKRy5tvocalLlwXLdUk
AIU+2GKjyT3iMuzZxxFxPFMCAwEAAQ==
-----END PUBLIC KEY-----
-----BEGIN CERTIFICATE-----
MIID2jCCAsKgAwIBAgIBATANBgkqhkiG9w0BAQsFADCBkzELMAkGA1UEBhMCRlIx
DzANBgNVBAgMBlJhZGl1czESMBAGA1UEBwwJU29tZXdoZXJlMRUwEwYDVQQKDAxF
eGFtcGxlIEluYy4xIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUub3JnMSYw
JAYDVQQDDB1FeGFtcGxlIENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0yMDA0MjMx
MTQ0NTFaFw0yNTA0MjIxMTQ0NTFaMHwxCzAJBgNVBAYTAkZSMQ8wDQYDVQQIDAZS
YWRpdXMxFTATBgNVBAoMDEV4YW1wbGUgSW5jLjEjMCEGA1UEAwwaRXhhbXBsZSBT
ZXJ2ZXIgQ2VydGlmaWNhdGUxIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUu
b3JnMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1e1pedfXWXRuu7jX
dyhCx4SKW2gEncpAxZratAlxdMSjZ9huI8xn7ISWIDFYPnItWSvJiA5gWJFqkJbn
HTQWMnxFVq0xrWxYvAWATvrjzhl3DJW8Zp1OzY81w9pcuGEeFJ4+/7qlbA9ENx3r
PX875BYXHA8ivK3yjGamrBgMOAMyTSICA/Uao6M7J/hKT7tuQJ3A1GAAT016u++p
w0JMbrA3oYeOltMHh1xbIjxsLINna4ZVPLd8AuhZ/OpNGrmADfH2HeipwszBrUMo
ld54sp57B1s1lAXMsyEW9t3mF4ZpkJH6A5377k0VNTiJSwNgnqI3F9wlCyJF7/Sw
+5WInwIDAQABo08wTTATBgNVHSUEDDAKBggrBgEFBQcDATA2BgNVHR8ELzAtMCug
KaAnhiVodHRwOi8vd3d3LmV4YW1wbGUuY29tL2V4YW1wbGVfY2EuY3JsMA0GCSqG
SIb3DQEBCwUAA4IBAQBUcwANHYWdOQSm0Wz8dvC0a9SpuHy788GRdQG8G0KM5iuf
rXiw4Op8UXFk+NTJyIFdvmq7WfrdVRB7MMqBSkzdc7XooYGm9KPpnl1ysdzooAE7
BEG6FlxNYkBOClQf3enK2a0TtOH/qvaV8eqmz9VIIX0oYAijhbYwUEd+r7WAyz7u
STs99/M5xiQp8C2LU150QTyN8unpj0DdiHg+n9sRAHPS36WcpY5Ug1pvSBGf594g
rP4Jpxt4LoXCDQ+YqlxAs3AXBQc6mM8Gx9FyN5l1xWtHNutODpuUXAGrdHb70EyL
Kj44MrvVS4fJuIO7ADRRh5gQG8xe6Y9PoxDVFnwI
-----END CERTIFICATE-----
`
	err = c.VerifyContents("", []byte(pem))
	if err != nil {
		t.Error(err.Error())
	}

	pem = `
-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAlRuRnThUjU8/prwYxbty
WPT9pURI3lbsKMiB6Fn/VHOKE13p4D8xgOCADpdRagdT6n4etr9atzDKUSvpMtR3
CP5noNc97WiNCggBjVWhs7szEe8ugyqF23XwpHQ6uV1LKH50m92MbOWfCtjU9p/x
qhNpQQ1AZhqNy5Gevap5k8XzRmjSldNAFZMY7Yv3Gi+nyCwGwpVtBUwhuLzgNFK/
yDtw2WcWmUU7NuC8Q6MWvPebxVtCfVp/iQU6q60yyt6aGOBkhAX0LpKAEhKidixY
nP9PNVBvxgu3XZ4P36gZV6+ummKdBVnc3NqwBLu5+CcdRdusmHPHd5pHf4/38Z3/
6qU2a/fPvWzceVTEgZ47QjFMTCTmCwNt29cvi7zZeQzjtwQgn4ipN9NibRH/Ax/q
TbIzHfrJ1xa2RteWSdFjwtxi9C20HUkjXSeI4YlzQMH0fPX6KCE7aVePTOnB69I/
a9/q96DiXZajwlpq3wFctrs1oXqBp5DVrCIj8hU2wNgB7LtQ1mCtsYz//heai0K9
PhE4X6hiE0YmeAZjR0uHl8M/5aW9xCoJ72+12kKpWAa0SFRWLy6FejNYCYpkupVJ
yecLk/4L1W0l6jQQZnWErXZYe0PNFcmwGXy1Rep83kfBRNKRy5tvocalLlwXLdUk
AIU+2GKjyT3iMuzZxxFxPFMCAwEAAQ==
-----END PUBLIC KEY-----
`
	err = c.VerifyContents("", []byte(pem))
	if err == nil {
		t.Error("Certificate data found")
	}

}
