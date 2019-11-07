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


## Create a CA

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

## Create a Profile

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

## Create a certificate

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

## Send the certificate by email

```
curl http://127.0.0.1:12345/api/v1/pki/cert/ZaymCert | python -m json.tool
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
curl http://127.0.0.1:12345/api/v1/pki/cert/ZaymCert/mypassword
```

The return content is the p12 file, use the password "mypassword" to open the p12 file.

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
curl -X "DELETE" http://127.0.0.1:12345/api/v1/pki/cert/ZaymCert/{reason}
```
