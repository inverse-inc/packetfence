#!/bin/bash
#
#
# Create the update the certs for unittest/UnifiedApi/Controller/Config/Certificates.t

rm -r ca.key ca.pem cert.csr cert.key cert.pem cert.ext

openssl req -x509 -newkey rsa:2048 -keyout ca.key -out ca.pem \
    -sha256 -days 3650 -nodes \
    -subj "/C=FR/ST=Radius/L=Somewhere/O=Example Inc./emailAddress=admin@example.org/CN=Example Server Certificate"\
    -addext "crlDistributionPoints=URI:http://www.example.com/example_ca.crl"


openssl req -new -newkey rsa:2048 -keyout cert.key -out cert.csr \
    -nodes\
    -subj "/C=FR/ST=Radius/O=Example Inc./CN=Example Server Certificate/emailAddress=admin@example.org"

cat > cert.ext << EOF
extendedKeyUsage=serverAuth
crlDistributionPoints=URI:http://www.example.com/example_ca.crl
EOF

openssl x509 -req -in cert.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out cert.pem -days 3650 -sha256\
    -extfile cert.ext

echo Created file ca.key ca.pem cert.key cert.pem

#Certificate:
#    Data:
#        Version: 3 (0x2)
#        Serial Number: 1 (0x1)
#        Signature Algorithm: sha256WithRSAEncryption
#        Issuer: C = FR, ST = Radius, L = Somewhere, O = Example Inc., emailAddress = admin@example.org, CN = Example Certificate Authority
#        Validity
#            Not Before: Jan  9 19:32:17 2019 GMT
#            Not After : Jan  8 19:32:17 2024 GMT
#        Subject: C = FR, ST = Radius, O = Example Inc., CN = Example Server Certificate, emailAddress = admin@example.org
#        Subject Public Key Info:
#            Public Key Algorithm: rsaEncryption
#                RSA Public-Key: (2048 bit)
#                Modulus:
#                    00:cb:e9:a2:61:91:5d:05:82:36:d8:ac:06:68:16:
#                    c3:7f:b6:b8:6d:c0:85:9e:98:0c:2a:59:48:a0:f5:
#                    d1:0f:75:d2:49:cf:fe:17:43:3c:8d:b6:a2:e1:d5:
#                    1c:52:67:72:7f:c0:64:59:00:24:11:c0:34:ac:54:
#                    aa:d4:89:43:7a:9e:06:59:60:e3:ac:81:a1:02:d2:
#                    4c:c4:cd:65:b2:3f:fa:60:77:8c:25:29:ef:64:67:
#                    0d:cf:b7:a8:f1:ed:99:21:dd:e6:f4:fe:cb:8f:35:
#                    4e:16:d6:b2:0a:74:99:03:00:ef:60:a2:c1:e6:c6:
#                    28:1f:d0:15:3e:fd:94:9f:5e:47:06:34:db:29:16:
#                    fd:68:d9:51:75:5f:4c:65:e9:0e:1b:44:b3:13:e0:
#                    8d:a7:78:d0:46:1c:86:7d:3b:26:87:8f:41:a9:b8:
#                    2f:54:ee:d4:03:e4:72:83:93:ba:96:ff:a9:89:bd:
#                    9b:d1:2f:f4:1a:02:1f:b2:bb:53:96:df:7d:db:8f:
#                    1d:11:7e:e4:5c:46:64:b1:2c:17:02:05:5a:18:72:
#                    a4:61:e0:be:61:7f:a0:63:64:bf:bb:50:57:cf:45:
#                    89:25:6b:60:ba:c0:ef:1a:d1:c3:57:fe:c5:47:7b:
#                    ae:2f:ac:e3:42:84:f9:12:18:76:91:79:f6:5e:9b:
#                    93:e7
#                Exponent: 65537 (0x10001)
#        X509v3 extensions:
#            X509v3 Extended Key Usage: 
#                TLS Web Server Authentication
#            X509v3 CRL Distribution Points: 
#
#                Full Name:
#                  URI:http://www.example.com/example_ca.crl
#
#    Signature Algorithm: sha256WithRSAEncryption
#         0a:fb:24:ca:ae:7b:b3:00:73:43:22:9f:bf:fb:6e:0f:91:fa:
#         30:5a:66:63:bf:20:f6:fd:06:73:05:0d:d9:40:a6:2f:be:bd:
#         07:f9:97:f0:29:4c:85:b8:e3:4d:a6:4e:be:fd:c4:f2:67:98:
#         5c:66:64:e4:b7:45:73:d3:7f:cd:1a:28:d4:e1:d6:73:f7:95:
#         5f:06:03:76:14:72:5c:b4:00:16:50:c4:e6:52:84:9b:40:3b:
#         88:3c:16:f6:b4:31:d2:61:d1:f5:0c:b4:1c:ff:83:d8:b4:1b:
#         39:71:e9:99:89:f5:bb:d6:90:f1:13:17:7a:05:41:52:0d:bf:
#         85:06:99:71:db:3b:6e:17:3a:e1:96:48:d5:f1:18:e9:17:09:
#         7d:06:e5:b3:2c:4a:ee:8e:43:45:71:0f:5e:e8:6d:d4:ec:6c:
#         d4:aa:f9:b9:96:ba:f2:31:79:71:f1:4a:43:20:6d:4c:13:5c:
#         6c:f9:4f:0e:1f:2b:e4:23:62:c2:d6:a0:b6:38:03:5c:bc:56:
#         a0:0e:f1:27:51:f8:28:14:52:47:e2:1c:e4:50:36:80:f4:e9:
#         d4:15:7d:18:bd:bf:ee:7a:26:e1:b7:5d:0f:0e:ce:79:ae:2b:
#         fc:59:72:65:05:4d:30:19:c7:78:da:49:36:c9:67:4b:c7:cc:
#         10:a4:c4:59
#-----BEGIN CERTIFICATE-----
#MIID2jCCAsKgAwIBAgIBATANBgkqhkiG9w0BAQsFADCBkzELMAkGA1UEBhMCRlIx
#DzANBgNVBAgMBlJhZGl1czESMBAGA1UEBwwJU29tZXdoZXJlMRUwEwYDVQQKDAxF
#eGFtcGxlIEluYy4xIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUub3JnMSYw
#JAYDVQQDDB1FeGFtcGxlIENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0xOTAxMDkx
#OTMyMTdaFw0yNDAxMDgxOTMyMTdaMHwxCzAJBgNVBAYTAkZSMQ8wDQYDVQQIDAZS
#YWRpdXMxFTATBgNVBAoMDEV4YW1wbGUgSW5jLjEjMCEGA1UEAwwaRXhhbXBsZSBT
#ZXJ2ZXIgQ2VydGlmaWNhdGUxIDAeBgkqhkiG9w0BCQEWEWFkbWluQGV4YW1wbGUu
#b3JnMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAy+miYZFdBYI22KwG
#aBbDf7a4bcCFnpgMKllIoPXRD3XSSc/+F0M8jbai4dUcUmdyf8BkWQAkEcA0rFSq
#1IlDep4GWWDjrIGhAtJMxM1lsj/6YHeMJSnvZGcNz7eo8e2ZId3m9P7LjzVOFtay
#CnSZAwDvYKLB5sYoH9AVPv2Un15HBjTbKRb9aNlRdV9MZekOG0SzE+CNp3jQRhyG
#fTsmh49BqbgvVO7UA+Ryg5O6lv+pib2b0S/0GgIfsrtTlt99248dEX7kXEZksSwX
#AgVaGHKkYeC+YX+gY2S/u1BXz0WJJWtgusDvGtHDV/7FR3uuL6zjQoT5Ehh2kXn2
#XpuT5wIDAQABo08wTTATBgNVHSUEDDAKBggrBgEFBQcDATA2BgNVHR8ELzAtMCug
#KaAnhiVodHRwOi8vd3d3LmV4YW1wbGUuY29tL2V4YW1wbGVfY2EuY3JsMA0GCSqG
#SIb3DQEBCwUAA4IBAQAK+yTKrnuzAHNDIp+/+24PkfowWmZjvyD2/QZzBQ3ZQKYv
#vr0H+ZfwKUyFuONNpk6+/cTyZ5hcZmTkt0Vz03/NGijU4dZz95VfBgN2FHJctAAW
#UMTmUoSbQDuIPBb2tDHSYdH1DLQc/4PYtBs5cemZifW71pDxExd6BUFSDb+FBplx
#2ztuFzrhlkjV8RjpFwl9BuWzLErujkNFcQ9e6G3U7GzUqvm5lrryMXlx8UpDIG1M
#E1xs+U8OHyvkI2LC1qC2OANcvFagDvEnUfgoFFJH4hzkUDaA9OnUFX0Yvb/ueibh
#t10PDs55riv8WXJlBU0wGcd42kk2yWdLx8wQpMRZ
#-----END CERTIFICATE-----
