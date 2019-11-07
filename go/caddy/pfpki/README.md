# API

## Options

```
KeyType:
0 KEY_ECDSA
1 KEY_RSA
2 KEY_DSA

Digest Values:
0 UnknownSignatureAlgorithm
1 MD2WithRSA
2 MD5WithRSA
3 SHA1WithRSA
4 SHA256WithRSA
5 SHA384WithRSA
6 SHA512WithRSA
7 DSAWithSHA1
8 DSAWithSHA256
9 ECDSAWithSHA1
10 ECDSAWithSHA256
11 ECDSAWithSHA384
12 ECDSAWithSHA512
13 SHA256WithRSAPSS
14 SHA384WithRSAPSS
15 SHA512WithRSAPSS
16 PureEd25519

KeyUsage Values:
1 KeyUsageDigitalSignature
2 KeyUsageContentCommitment
4 KeyUsageKeyEncipherment
8 KeyUsageDataEncipherment
16 KeyUsageKeyAgreement
32 KeyUsageCertSign
64 KeyUsageCRLSign
128 KeyUsageEncipherOnly
256 KeyUsageDecipherOnly

ExtendedKeyUsage Values:
0 ExtKeyUsageAny
1 ExtKeyUsageServerAuth
2 ExtKeyUsageClientAuth
3 ExtKeyUsageCodeSigning
4 ExtKeyUsageEmailProtection
5 ExtKeyUsageIPSECEndSystem
6 ExtKeyUsageIPSECTunnel
7 ExtKeyUsageIPSECUser
8 ExtKeyUsageTimeStamping
9 ExtKeyUsageOCSPSigning
10 ExtKeyUsageMicrosoftServerGatedCrypto
11 ExtKeyUsageNetscapeServerGatedCrypto
12 ExtKeyUsageMicrosoftCommercialCodeSigning
13 ExtKeyUsageMicrosoftKernelCodeSigning
```


## Certificate Authority

### Create a CA

```
curl -H "Content-Type: application/json" -d '{"cn":"YzaymCA","mail":"jdoe@email.net","organisation": "Zaym and co ltd","country": "ZA","state": "ZaymState", "locality": "ZaymTown", "streetaddress": "7000 zaym avenue", "postalcode": "H3N 1X1", "keytype": 1, "keysize": 2048, "Digest": 6, "days": 3650, "extendedkeyusage": "1|2", "keyusage": "1|32"}' http://127.0.0.1:12345/api/v1/pki/ca | python -m json.tool
```

```
{
    "result": [
        {
            "ContentType": "",
            "Raw": null,
            "error": "",
            "password": "",
            "status": "ACK"
        }
    ]
}
```

### List all CA

```
curl http://127.0.0.1:12345/api/v1/pki/ca | python -m json.tool
```

Return only the CN of all CA

```
{
    "result": [
        {
            "ContentType": "",
            "Entries": [
                {
                    "CreatedAt": "0001-01-01T00:00:00Z",
                    "DeletedAt": null,
                    "ID": 0,
                    "UpdatedAt": "0001-01-01T00:00:00Z",
                    "cn": "YzaymCA",
                    "country": "",
                    "days": 0,
                    "digest": 0,
                    "keysize": 0,
                    "keytype": 0,
                    "locality": "",
                    "mail": "",
                    "organisation": "",
                    "postalcode": "",
                    "state": "",
                    "streetaddress": ""
                }
            ],
            "Raw": null,
            "error": "",
            "password": "",
            "status": "ACK"
        }
    ]
}
```

### Get a specific CA

```
curl http://127.0.0.1:12345/api/v1/pki/ca/{ca_cn} | python -m json.tool
```

Return all attributes except the private key

```
{
    "result": [
        {
            "ContentType": "",
            "Entries": [
                {
                    "CreatedAt": "0001-01-01T00:00:00Z",
                    "DeletedAt": null,
                    "ID": 0,
                    "UpdatedAt": "0001-01-01T00:00:00Z",
                    "cert": "-----BEGIN CERTIFICATE-----\nMIIENjCCAx6gAwIBAgIBATANBgkqhkiG9w0BAQ0FADCBjTELMAkGA1UEBhMCWkEx\nEjAQBgNVBAgTCVpheW1TdGF0ZTERMA8GA1UEBxMIWmF5bVRvd24xGTAXBgNVBAkT\nEDcwMDAgemF5bSBhdmVudWUxEDAOBgNVBBETB0gzTiAxWDExGDAWBgNVBAoTD1ph\neW0gYW5kIGNvIGx0ZDEQMA4GA1UEAxMHWXpheW1DQTAeFw0xOTExMDcxOTQyMDha\nFw0yOTExMDQxOTQyMDhaMIGNMQswCQYDVQQGEwJaQTESMBAGA1UECBMJWmF5bVN0\nYXRlMREwDwYDVQQHEwhaYXltVG93bjEZMBcGA1UECRMQNzAwMCB6YXltIGF2ZW51\nZTEQMA4GA1UEERMHSDNOIDFYMTEYMBYGA1UEChMPWmF5bSBhbmQgY28gbHRkMRAw\nDgYDVQQDEwdZemF5bUNBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA\nrppNSkJwuU1XrQcsrSNMAmpZvZ8fIMNSbKy1nQ++Cgxdun+Qk4/m9FTLxw0aGJG1\nJvanRtqfkVBVr2deeb4/YaKnmpSGtPIq60XVrr1jwnIeIHTn23LdO2BgORNlkE/I\n/Ny0QbXm9TOabUWpbt29h/piVLCeSaKuoovIEcUDd5w2wzIT9ZBS8ms3TTazRON4\nm0kg96lI+Kw4BdiuBWvx16+6gt7mq0sjh6bqrWiuyh4yHEm2dF2144V+eikXPwmT\nL63g/2rp6cblD0SJ19QMpm5JG7wgZjb6FKVbU6hxarGoRyBrZSkRaFhJ0lKS2mEs\nem6D1vL3wH+IUhPwzARiHwIDAQABo4GeMIGbMA4GA1UdDwEB/wQEAwIChDAdBgNV\nHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwDwYDVR0TAQH/BAUwAwEB/zAdBgNV\nHQ4EFgQUO8dwZCnchi+YaddcRx38rVlrov4wHwYDVR0jBBgwFoAUO8dwZCnchi+Y\naddcRx38rVlrov4wGQYDVR0RBBIwEIEOamRvZUBlbWFpbC5uZXQwDQYJKoZIhvcN\nAQENBQADggEBAKcA8Ge7jr5JFM6rJlXCQD3as9lnW+dcnrnCTCx0XqL0i70l42UZ\nz/Jx4VLI5pvyDx+M7eua/BRVa7tpk+YKuKyq4918ZHPuKFW3wZtmg9Bw32xhE6fu\njHeGaSmH4BXWzTmj9LLyB7GnTOWC48kd5iuhbgYmYtZo++heGbsebWyODRdcRgiZ\npB1wGFlZbsns6SwsGd0A92DzrUjZWABNuval5wrQLhwubqj2p8FELr9JhGNgc9pV\nu/JfZ2Kbpf2K0mi1oVThNYZJF5vCYDH/4TDDFMEGY3s41W3Gbo2sXXLHytNqYlqP\nNRXvpFbkCp7mA5g2R9WG/i4ooti/oLuxoyc=\n-----END CERTIFICATE-----\n",
                    "cn": "YzaymCA",
                    "country": "ZA",
                    "days": 3650,
                    "digest": 6,
                    "extendedkeyusage": "1|2",
                    "keysize": 2048,
                    "keytype": 1,
                    "keyusage": "1|32",
                    "locality": "ZaymTown",
                    "mail": "jdoe@email.net",
                    "organisation": "Zaym and co ltd",
                    "postalcode": "H3N 1X1",
                    "state": "ZaymState",
                    "streetaddress": "7000 zaym avenue"
                }
            ],
            "Raw": null,
            "error": "",
            "password": "",
            "status": "ACK"
        }
    ]
}

```

## Profile

### Create a Profile

```
curl -H "Content-Type: application/json" -d '{"name":"ZaymProfile","caname":"YzaymCA","validity": 365,"keytype": 1,"keysize": 2048, "digest": 6, "keyusage": "", "extendedkeyusage": "", "p12smtpserver": "10.0.0.6", "p12mailpassword": 1, "p12mailsubject": "New certificate", "P12MailFrom": "cert@mail.net", "days": 365}' http://127.0.0.1:12345/api/v1/pki/profile | python -m json.tool
```

```
{
    "result": [
        {
            "ContentType": "",
            "Raw": null,
            "error": "",
            "password": "",
            "status": "ACK"
        }
    ]
}
```

### List all profiles

```
curl http://127.0.0.1:12345/api/v1/pki/profile | python -m json.tool
```

Return only the profile name

```
{
    "result": [
        {
            "ContentType": "",
            "Entries": [
                {
                    "CaID": 0,
                    "CreatedAt": "0001-01-01T00:00:00Z",
                    "DeletedAt": null,
                    "ID": 0,
                    "UpdatedAt": "0001-01-01T00:00:00Z",
                    "ca": {
                        "CreatedAt": "0001-01-01T00:00:00Z",
                        "DeletedAt": null,
                        "ID": 0,
                        "UpdatedAt": "0001-01-01T00:00:00Z",
                        "cn": "",
                        "country": "",
                        "days": 0,
                        "digest": 0,
                        "keysize": 0,
                        "keytype": 0,
                        "locality": "",
                        "mail": "",
                        "organisation": "",
                        "postalcode": "",
                        "state": "",
                        "streetaddress": ""
                    },
                    "caname": "",
                    "digest": 0,
                    "keysize": 0,
                    "keytype": 0,
                    "name": "ZaymProfile",
                    "p12mailfooter": "",
                    "p12mailfrom": "",
                    "p12mailheader": "",
                    "p12mailpassword": 0,
                    "p12mailsubject": "",
                    "p12smtpserver": "",
                    "validity": 0
                }
            ],
            "Raw": null,
            "error": "",
            "password": "",
            "status": "ACK"
        }
    ]
}
```

### Get a specific Profile

```
curl http://127.0.0.1:12345/api/v1/pki/profile/{profile_name} | python -m json.tool
```

```
{
    "result": [
        {
            "ContentType": "",
            "Entries": [
                {
                    "CaID": 0,
                    "CreatedAt": "0001-01-01T00:00:00Z",
                    "DeletedAt": null,
                    "ID": 0,
                    "UpdatedAt": "0001-01-01T00:00:00Z",
                    "ca": {
                        "CreatedAt": "0001-01-01T00:00:00Z",
                        "DeletedAt": null,
                        "ID": 0,
                                                "UpdatedAt": "0001-01-01T00:00:00Z",
                        "cn": "",
                        "country": "",
                        "days": 0,
                        "digest": 0,
                        "keysize": 0,
                        "keytype": 0,
                        "locality": "",
                        "mail": "",
                        "organisation": "",
                        "postalcode": "",
                        "state": "",
                        "streetaddress": ""
                    },
                    "caname": "YzaymCA",
                    "digest": 6,
                    "keysize": 2048,
                    "keytype": 1,
                    "name": "ZaymProfile",
                    "p12mailfooter": "",
                    "p12mailfrom": "cert@mail.net",
                    "p12mailheader": "",
                    "p12mailpassword": 1,
                    "p12mailsubject": "New certificate",
                    "p12smtpserver": "10.0.0.6",
                    "validity": 365
                }
            ],
            "Raw": null,
            "error": "",
            "password": "",
            "status": "ACK"
        }
    ]
}
```

## Certificates

### Create a certificate

```
curl -H "Content-Type: application/json" -d '{"cn":"ZaymCert","mail":"zaym@mail.net","street": "7000 parc avenue","organisation": "inverse", "country": "CA", "state": "Quebec", "locality": "Montreal", "postalcode": "H3N 1X1", "profilename": "ZaymProfile"}' http://127.0.0.1:12345/api/v1/pki/cert | python -m json.tool
```

```
{
    "result": [
        {
            "ContentType": "",
            "Raw": null,
            "error": "",
            "password": "",
            "status": "ACK"
        }
    ]
}
```
### List all Certificates

```
curl http://127.0.0.1:12345/api/v1/pki/cert | python -m json.tool
```

Return only the CN of the certificates

```
{
    "result": [
        {
            "ContentType": "",
            "Entries": [
                {
                    "CaID": 0,
                    "CreatedAt": "0001-01-01T00:00:00Z",
                    "Date": "0001-01-01T00:00:00Z",
                    "DeletedAt": null,
                    "ID": 0,
                    "ProfileID": 0,
                    "SerialNumber": "",
                    "UpdatedAt": "0001-01-01T00:00:00Z",
                    "ValidUntil": "0001-01-01T00:00:00Z",
                    "ca": {
                        "CreatedAt": "0001-01-01T00:00:00Z",
                        "DeletedAt": null,
                        "ID": 0,
                        "UpdatedAt": "0001-01-01T00:00:00Z",
                        "cn": "",
                        "country": "",
                        "days": 0,
                        "digest": 0,
                        "keysize": 0,
                        "keytype": 0,
                        "locality": "",
                        "mail": "",
                        "organisation": "",
                        "postalcode": "",
                        "state": "",
                        "streetaddress": ""
                    },
                    "cn": "ZaymCert",
                    "mail": "",
                    "profile": {
                        "CaID": 0,
                        "CreatedAt": "0001-01-01T00:00:00Z",
                        "DeletedAt": null,
                        "ID": 0,
                        "UpdatedAt": "0001-01-01T00:00:00Z",
                        "ca": {
                            "CreatedAt": "0001-01-01T00:00:00Z",
                            "DeletedAt": null,
                            "ID": 0,
                            "UpdatedAt": "0001-01-01T00:00:00Z",
                            "cn": "",
                            "country": "",
                            "days": 0,
                            "digest": 0,
                            "keysize": 0,
                            "keytype": 0,
                            "locality": "",
                            "mail": "",
                            "organisation": "",
                            "postalcode": "",
                            "state": "",
                            "streetaddress": ""
                        },
                        "caname": "",
                        "digest": 0,
                        "keysize": 0,
                        "keytype": 0,
                        "name": "",
                        "p12mailfooter": "",
                        "p12mailfrom": "",
                        "p12mailheader": "",
                        "p12mailpassword": 0,
                        "p12mailsubject": "",
                        "p12smtpserver": "",
                        "validity": 0
                    }
                }
            ],
            "Raw": null,
            "error": "",
            "password": "",
            "status": "ACK"
        }
    ]
}
```

### Get a specific Profile

```
curl http://127.0.0.1:12345/api/v1/pki/cert/{certificate_cn}| python -m json.tool
```


```
{
    "result": [
        {
            "ContentType": "",
            "Entries": [
                {
                    "CaID": 0,
                    "CreatedAt": "0001-01-01T00:00:00Z",
                    "Date": "0001-01-01T00:00:00Z",
                    "DeletedAt": null,
                    "ID": 0,                                                           
                    "ProfileID": 0,
                    "SerialNumber": "1",
                    "UpdatedAt": "0001-01-01T00:00:00Z",
                    "ValidUntil": "2020-11-06T14:53:12-05:00",
                    "ca": {
                        "CreatedAt": "0001-01-01T00:00:00Z",
                        "DeletedAt": null,
                        "ID": 0,
                        "UpdatedAt": "0001-01-01T00:00:00Z",
                        "cn": "",
                        "country": "",
                        "days": 0,
                        "digest": 0,
                        "keysize": 0,
                        "keytype": 0,
                        "locality": "",
                        "mail": "",
                        "organisation": "",
                        "postalcode": "",
                        "state": "",
                        "streetaddress": ""
                    },
                    "cn": "ZaymCert",
                    "country": "CA",
                    "locality": "Montreal",
                    "mail": "zaym@mail.net",
                    "organisation": "inverse",
                    "postalcode": "H3N 1X1",
                    "profile": {
                        "CaID": 0,
                        "CreatedAt": "0001-01-01T00:00:00Z",
                        "DeletedAt": null,
                        "ID": 0,
                        "UpdatedAt": "0001-01-01T00:00:00Z",
                        "ca": {
                            "CreatedAt": "0001-01-01T00:00:00Z",
                            "DeletedAt": null,
                            "ID": 0,
                            "UpdatedAt": "0001-01-01T00:00:00Z",
                            "cn": "",
                            "country": "",
                            "days": 0,
                            "digest": 0,
                            "keysize": 0,
                            "keytype": 0,
                            "locality": "",
                            "mail": "",
                            "organisation": "",
                            "postalcode": "",
                            "state": "",
                            "streetaddress": ""
                        },
                        "caname": "",
                        "digest": 0,
                        "keysize": 0,
                        "keytype": 0,
                        "name": "",
                        "p12mailfooter": "",
                        "p12mailfrom": "",
                        "p12mailheader": "",
                        "p12mailpassword": 0,
                        "p12mailsubject": "",
                        "p12smtpserver": "",
                        "validity": 0
                    },
                    "profilename": "ZaymProfile",
                    "publickey": "-----BEGIN CERTIFICATE-----\nMIID+jCCAuKgAwIBAgIBATANBgkqhkiG9w0BAQsFADCBjTELMAkGA1UEBhMCWkEx\nEjAQBgNVBAgTCVpheW1TdGF0ZTERMA8GA1UEBxMIWmF5bVRvd24xGTAXBgNVBAkT\nEDcwMDAgemF5bSBhdmVudWUxEDAOBgNVBBETB0gzTiAxWDExGDAWBgNVBAoTD1ph\neW0gYW5kIGNvIGx0ZDEQMA4GA1UEAxMHWXpheW1DQTAeFw0xOTExMDcxOTUzMTJa\nFw0yMDExMDYxOTUzMTJaMIGDMQswCQYDVQQGEwJDQTEPMA0GA1UECBMGUXVlYmVj\nMREwDwYDVQQHEwhNb250cmVhbDEZMBcGA1UECRMQNzAwMCBwYXJjIGF2ZW51ZTEQ\nMA4GA1UEERMHSDNOIDFYMTEQMA4GA1UEChMHaW52ZXJzZTERMA8GA1UEAxMIWmF5\nbUNlcnQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDB6phNrvkJSL69\nSJ9YeLXGI+fCYe5WtMfH67qxRvIcazw1P2GhfpnoCEQBzEQZZp/zqty++5PftYc5\ns/gdkCKW1pTnOJYHa2YB8AXbr88leAcAl/9FlBIutECnXzomkZ7olxLR8isaRnde\nVdTawLAB4OYM8QEojJJuOKgOU8B1xW9mq4wo6G95RAoF8h+hZBMOeIuVvok8Bj+k\nxKyYFqeF28PU91XklrQNYswZcWlrAGY327Y97N+uO7Z3zPN7tTE1wqNhGaY5jiTV\nM6ZffrObWrpqpgL9QOmHBkIpZgQeaCNWe+E0ZKSwnPyNPV4Z3Bkdr/V7uInhlIN8\n++2+8IoTAgMBAAGjbTBrMA8GA1UdJQQIMAYGBFUdJQAwHQYDVR0OBBYEFHETpVEH\nIyhka+RnULpjfpMwKfutMB8GA1UdIwQYMBaAFDvHcGQp3IYvmGnXXEcd/K1Za6L+\nMBgGA1UdEQQRMA+BDXpheW1AbWFpbC5uZXQwDQYJKoZIhvcNAQELBQADggEBAEIx\nOR8HMmjgXFYddPFxC9oLVaPIFv1G3qQuP5ss1S7rWxREELtxNHdGCcfIGqniXkUp\nV4vZypi0ctyZkRkJWb605YDmbuPeWyDaIGTWquoegByHuEVo2Xe5NlAgExIXpfE8\nmNu+5Fe8GRJuTY2mFFV7O9Q/KkozqaBsa/ePxg8QysPvDxlrl18qakLFo+qbs/Z1\nZSF6+KSgReK776O1TkSp8BVoY50vjay2udb4qB1/fNfxQBRDCoQSzwOyc2K2yvMo\n8Fg8rxHgosKx3j/hoDZu7e8ioANdAEy3i5BH3Ib5UK6sZk01/lD/5GacUDiVbziL\nSNRgwW8dsVdOeSYm2t0=\n-----END CERTIFICATE-----\n",
                    "state": "Quebec",
                    "street": "7000 parc avenue"
                }
            ],
            "Raw": null,
            "error": "",
            "password": "",
            "status": "ACK"
        }
    ]
}

```
## Send the certificate by email

```
curl http://127.0.0.1:12345/api/v1/pki/certmgmt/{certificate_cn}| python -m json.tool
```

```
{
    "result": [
        {
            "ContentType": "",
            "Raw": null,
            "error": "",
            "password": "1ftajP9o",
            "status": "ACK"
        }
    ]
}
```

Use the password value to open the p12 file

## Get the certificate in p12 format with a predefined password


```
curl http://127.0.0.1:12345/api/v1/pki/certmgmt/{certificate_cn}/{password}
```

The return content is the p12 file, use the password you defined in place of {password} to open the p12 file.

## Revoke a certificate

Reason option:
0 Unspecified
1 KeyCompromise
2 CACompromise
3 AffiliationChanged
4 Superseded
5 CessationOfOperation
6 CertificateHold
8 RemoveFromCRL
9 PrivilegeWithdrawn
10 AACompromise

```
curl -X "DELETE" http://127.0.0.1:12345/api/v1/pki/certmgmt/ZaymCert/{reason}
```
