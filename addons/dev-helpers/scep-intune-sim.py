#!/usr/bin/env python3
"""
scep-intune-sim.py - emulate a Windows / Intune SCEP client against the PacketFence PKI.

What a Windows device enrolled in Intune does when it receives a SCEP profile:

  1. GET  <url>?operation=GetCACaps&message=<ca-id>
  2. GET  <url>?operation=GetCACert&message=<ca-id>
  3. Generates an RSA key (software KSP), builds a PKCS#10 CSR with:
       - the Subject from the profile (CN=..., etc.)
       - the SANs from the profile (UPN otherName, DNS, email)
       - keyUsage + extendedKeyUsage inside an extensionRequest attribute
       - a challengePassword attribute holding the Intune-issued encrypted challenge
       - Microsoft "request client info" / "OS version" attributes
  4. Wraps the CSR in PKCS#7 EnvelopedData encrypted to the CA/RA cert (AES-256 or 3DES),
     then in PKCS#7 SignedData signed by a self-signed cert built from the same key, with the
     SCEP attributes messageType=19 (PKCSReq), transactionID, senderNonce.
  5. POST <url>?operation=PKIOperation  (Content-Type: application/x-pki-message)
  6. Parses the CertRep, decrypts the EnvelopedData with its own key, pulls the issued cert.

PacketFence (go/plugin/caddy2/pfpki) then either checks the static SCEP challenge of the
template, or, when "Cloud Integration" is enabled on the template, forwards the raw CSR to
Intune's ScepRequestValidationFEService which validates the challenge, subject, SAN, key
usage, key length and EKU against the SCEP profile targeted to the device.

Only Intune can mint a valid challenge, so against a cloud-enabled template you either pass a
real challenge captured from a Windows device (--challenge / --challenge-file) or you accept
that Intune will answer ChallengePasswordMissing / ChallengeDeserializationError, which still
proves the whole PF -> Intune API round trip.

Dependencies: cryptography, asn1crypto, pycryptodome
  python3 -m venv ~/.venv-scep && ~/.venv-scep/bin/pip install cryptography asn1crypto pycryptodome

Examples
  # template WITHOUT cloud integration (static SCEP challenge configured on the template)
  scep-intune-sim.py https://pf.example.com/scep/MyTemplate -k --challenge 'the-static-challenge' \
      --subject 'CN=DESKTOP-ABC123' --san-upn 'DESKTOP-ABC123@corp.example.com'

  # template WITH Intune cloud integration, real challenge captured from a Windows device
  scep-intune-sim.py https://pf.example.com/scep/IntuneTemplate -k --challenge-file challenge.txt \
      --subject 'CN=DESKTOP-ABC123' --san-upn 'DESKTOP-ABC123@corp.example.com' --san-dns desktop-abc123.corp.example.com

  # same, no challenge: exercises PF -> Intune validateRequest, expect FAILURE + "ChallengePasswordMissing" in pfpki logs
  scep-intune-sim.py https://pf.example.com/scep/IntuneTemplate -k -v --dump

Outputs <out>.key/.csr/.crt/-ca.crt (default prefix scep-sim) and a JSON summary on stdout; exit 0 only on SUCCESS.
"""

import argparse
import base64
import datetime as dt
import hashlib
import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request

from asn1crypto import algos, cms, core, csr as a_csr, x509 as a_x509
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID
from cryptography.x509.name import _ASN1Type
from Crypto.Cipher import AES, DES, DES3

# --------------------------------------------------------------------------------------
# SCEP / Microsoft OIDs
# --------------------------------------------------------------------------------------
OID_MESSAGE_TYPE = "2.16.840.1.113733.1.9.2"
OID_PKI_STATUS = "2.16.840.1.113733.1.9.3"
OID_FAIL_INFO = "2.16.840.1.113733.1.9.4"
OID_SENDER_NONCE = "2.16.840.1.113733.1.9.5"
OID_RECIPIENT_NONCE = "2.16.840.1.113733.1.9.6"
OID_TRANSACTION_ID = "2.16.840.1.113733.1.9.7"

OID_CHALLENGE_PASSWORD = "1.2.840.113549.1.9.7"
OID_EXTENSION_REQUEST = "1.2.840.113549.1.9.14"
OID_MS_UPN = "1.3.6.1.4.1.311.20.2.3"
OID_MS_OS_VERSION = "1.3.6.1.4.1.311.13.2.3"
OID_MS_ENROLLMENT_CSP = "1.3.6.1.4.1.311.13.2.2"
OID_MS_REQUEST_CLIENT_INFO = "1.3.6.1.4.1.311.21.20"

MSG_PKCSREQ = "19"
MSG_CERTREP = "3"

PKI_STATUS = {"0": "SUCCESS", "2": "FAILURE", "3": "PENDING"}
FAIL_INFO = {"0": "badAlg", "1": "badMessageCheck", "2": "badRequest", "3": "badTime", "4": "badCertId"}

# Teach asn1crypto about the SCEP signed attributes so it can build and parse them.
class SetOfPrintableString(core.SetOf):
    _child_spec = core.PrintableString


class SetOfOctetString(core.SetOf):
    _child_spec = core.OctetString


cms.CMSAttributeType._map.update({
    OID_MESSAGE_TYPE: "scep_message_type",
    OID_PKI_STATUS: "scep_pki_status",
    OID_FAIL_INFO: "scep_fail_info",
    OID_SENDER_NONCE: "scep_sender_nonce",
    OID_RECIPIENT_NONCE: "scep_recipient_nonce",
    OID_TRANSACTION_ID: "scep_transaction_id",
})
cms.CMSAttribute._oid_specs.update({
    "scep_message_type": SetOfPrintableString,
    "scep_pki_status": SetOfPrintableString,
    "scep_fail_info": SetOfPrintableString,
    "scep_sender_nonce": SetOfOctetString,
    "scep_recipient_nonce": SetOfOctetString,
    "scep_transaction_id": SetOfPrintableString,
})


def log(msg, *a):
    print(msg % a if a else msg, file=sys.stderr)


def die(msg, *a):
    log("ERROR: " + msg, *a)
    sys.exit(1)


# --------------------------------------------------------------------------------------
# HTTP
# --------------------------------------------------------------------------------------
class Http:
    UA = "Mozilla/4.0 (compatible; Win32; NDES client 10.0.22621.1/1.0)"

    def __init__(self, base_url, insecure, timeout, verbose):
        self.base_url = base_url
        self.timeout = timeout
        self.verbose = verbose
        ctx = ssl.create_default_context()
        if insecure:
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
        self.opener = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx))

    def _url(self, operation, message):
        q = {"operation": operation}
        if message is not None:
            q["message"] = message
        return self.base_url + "?" + urllib.parse.urlencode(q, quote_via=urllib.parse.quote)

    def do(self, operation, message=None, body=None):
        url = self._url(operation, message)
        req = urllib.request.Request(url, data=body, method="POST" if body is not None else "GET")
        req.add_header("User-Agent", self.UA)
        if body is not None:
            req.add_header("Content-Type", "application/x-pki-message")
        if self.verbose:
            log("> %s %s%s", req.method, url if len(url) < 160 else url[:160] + "...(%d chars)" % len(url),
                " (%d bytes)" % len(body) if body else "")
        try:
            with self.opener.open(req, timeout=self.timeout) as r:
                data = r.read()
                ctype = r.headers.get("Content-Type", "")
                if self.verbose:
                    log("< %s %s, %d bytes", r.status, ctype, len(data))
                return r.status, ctype, data
        except urllib.error.HTTPError as e:
            data = e.read()
            log("< HTTP %s %s", e.code, e.reason)
            if data:
                log("< body: %s", data[:2000].decode("utf-8", "replace"))
            die("%s failed", operation)


# --------------------------------------------------------------------------------------
# Key / CSR / self-signed cert
# --------------------------------------------------------------------------------------
def parse_subject(s):
    """'CN=foo,O=bar,OU=baz' -> x509.Name (order kept as typed)."""
    known = {
        "CN": NameOID.COMMON_NAME, "O": NameOID.ORGANIZATION_NAME, "OU": NameOID.ORGANIZATIONAL_UNIT_NAME,
        "C": NameOID.COUNTRY_NAME, "ST": NameOID.STATE_OR_PROVINCE_NAME, "L": NameOID.LOCALITY_NAME,
        "E": NameOID.EMAIL_ADDRESS, "EMAIL": NameOID.EMAIL_ADDRESS, "EMAILADDRESS": NameOID.EMAIL_ADDRESS,
        "DC": NameOID.DOMAIN_COMPONENT, "SN": NameOID.SURNAME, "GN": NameOID.GIVEN_NAME,
        "SERIALNUMBER": NameOID.SERIAL_NUMBER, "STREET": NameOID.STREET_ADDRESS,
        "POSTALCODE": NameOID.POSTAL_CODE, "TITLE": NameOID.TITLE, "UID": NameOID.USER_ID,
    }
    attrs = []
    for part in [p for p in s.replace("/", ",").split(",") if p.strip()]:
        if "=" not in part:
            die("bad subject component %r", part)
        k, v = part.split("=", 1)
        k = k.strip().upper()
        oid = known.get(k) or x509.ObjectIdentifier(k)
        attrs.append(x509.NameAttribute(oid, v.strip()))
    return x509.Name(attrs)


def build_key(key_size, key_file):
    if key_file and os.path.exists(key_file):
        with open(key_file, "rb") as f:
            key = serialization.load_pem_private_key(f.read(), password=None)
        log("Reusing private key %s", key_file)
        return key
    key = rsa.generate_private_key(public_exponent=65537, key_size=key_size)
    if key_file:
        with open(key_file, "wb") as f:
            f.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.TraditionalOpenSSL,
                                      serialization.NoEncryption()))
        os.chmod(key_file, 0o600)
    return key


def upn_san(upn):
    # otherName { id-ms-upn, UTF8String upn }
    return x509.OtherName(x509.ObjectIdentifier(OID_MS_UPN), core.UTF8String(upn).dump())


def build_csr(args, key):
    b = x509.CertificateSigningRequestBuilder().subject_name(parse_subject(args.subject))

    sans = []
    for u in args.san_upn or []:
        sans.append(upn_san(u))
    for d in args.san_dns or []:
        sans.append(x509.DNSName(d))
    for e in args.san_email or []:
        sans.append(x509.RFC822Name(e))
    if sans:
        b = b.add_extension(x509.SubjectAlternativeName(sans), critical=False)

    ku = set(args.key_usage.split(","))
    b = b.add_extension(x509.KeyUsage(
        digital_signature="digitalSignature" in ku, key_encipherment="keyEncipherment" in ku,
        content_commitment="nonRepudiation" in ku, data_encipherment="dataEncipherment" in ku,
        key_agreement="keyAgreement" in ku, key_cert_sign=False, crl_sign=False,
        encipher_only=False, decipher_only=False), critical=True)

    ekus = []
    for e in args.eku.split(","):
        e = e.strip()
        if not e:
            continue
        ekus.append({"clientAuth": ExtendedKeyUsageOID.CLIENT_AUTH, "serverAuth": ExtendedKeyUsageOID.SERVER_AUTH,
                     "emailProtection": ExtendedKeyUsageOID.EMAIL_PROTECTION,
                     "smartcardLogon": x509.ObjectIdentifier("1.3.6.1.4.1.311.20.2.2"),
                     "anyExtendedKeyUsage": ExtendedKeyUsageOID.ANY_EXTENDED_KEY_USAGE}.get(e, None)
                    or x509.ObjectIdentifier(e))
    if ekus:
        b = b.add_extension(x509.ExtendedKeyUsage(ekus), critical=False)

    # challengePassword: PrintableString is what NDES/Windows sends; Intune challenges are base64 text
    if args.challenge is not None:
        tag = _ASN1Type.UTF8String if args.challenge_utf8 else _ASN1Type.PrintableString
        b = b.add_attribute(x509.ObjectIdentifier(OID_CHALLENGE_PASSWORD), args.challenge.encode(), _tag=tag)

    if not args.no_ms_attributes:
        # szOID_OS_VERSION -> IA5String "10.0.22631.2"
        b = b.add_attribute(x509.ObjectIdentifier(OID_MS_OS_VERSION), args.os_version.encode(), _tag=_ASN1Type.IA5String)

    # the CSR itself is always SHA-256 signed (as Windows does); the SCEP digest is negotiated separately
    csr = b.sign(key, hashes.SHA256())
    if args.no_ms_attributes:
        return csr
    return add_ms_attributes(csr, key, args)


class EnrollmentCSP(core.Sequence):
    _fields = [("key_spec", core.Integer), ("provider", core.BMPString), ("signature", core.BitString)]


class RequestClientInfo(core.Sequence):
    _fields = [("client_id", core.Integer), ("machine", core.UTF8String), ("user", core.UTF8String), ("process", core.UTF8String)]


class SetOfEnrollmentCSP(core.SetOf):
    _child_spec = EnrollmentCSP


class SetOfRequestClientInfo(core.SetOf):
    _child_spec = RequestClientInfo


a_csr.CSRAttributeType._map.update({OID_MS_ENROLLMENT_CSP: "ms_enrollment_csp", OID_MS_REQUEST_CLIENT_INFO: "ms_request_client_info"})
a_csr.CRIAttribute._oid_specs.update({"ms_enrollment_csp": SetOfEnrollmentCSP, "ms_request_client_info": SetOfRequestClientInfo})


def add_ms_attributes(csr, key, args):
    """cryptography cannot emit SEQUENCE-valued CSR attributes, so append the two Microsoft ones
    with asn1crypto and re-sign the CertificationRequestInfo."""
    req = a_csr.CertificationRequest.load(csr.public_bytes(serialization.Encoding.DER))
    cri = req["certification_request_info"]
    attrs = list(cri["attributes"])
    # szOID_ENROLLMENT_CSP_PROVIDER: what Windows sends for "Enroll to Software KSP"
    attrs.append(a_csr.CRIAttribute({"type": "ms_enrollment_csp", "values": [EnrollmentCSP({
        "key_spec": 1, "provider": "Microsoft Software Key Storage Provider", "signature": core.BitString(())})]}))
    # szOID_REQUEST_CLIENT_INFO: client id 5 = certificate enrollment through the OMA-DM client (Intune)
    attrs.append(a_csr.CRIAttribute({"type": "ms_request_client_info", "values": [RequestClientInfo({
        "client_id": 5, "machine": args.machine_name,
        "user": args.user_name or (args.machine_name + "\\SYSTEM"), "process": "omadmclient.exe"})]}))
    new_cri = a_csr.CertificationRequestInfo({
        "version": cri["version"], "subject": cri["subject"], "subject_pk_info": cri["subject_pk_info"],
        "attributes": a_csr.CRIAttributes(attrs)})
    sig = key.sign(new_cri.dump(), padding.PKCS1v15(), hashes.SHA256())
    new_req = a_csr.CertificationRequest({
        "certification_request_info": new_cri,
        "signature_algorithm": algos.SignedDigestAlgorithm({"algorithm": "sha256_rsa"}),
        "signature": sig})
    return x509.load_der_x509_csr(new_req.dump())


def build_self_signed(key, subject, digest):
    now = dt.datetime.now(dt.timezone.utc)
    algo = hashes.SHA256()  # cryptography refuses SHA-1 for cert signatures; irrelevant to the SCEP digest
    return (x509.CertificateBuilder()
            .subject_name(subject).issuer_name(subject)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now - dt.timedelta(minutes=5))
            .not_valid_after(now + dt.timedelta(days=7))
            .add_extension(x509.KeyUsage(True, False, True, False, False, False, False, False, False), critical=True)
            .sign(key, algo))


# --------------------------------------------------------------------------------------
# PKCS#7 building
# --------------------------------------------------------------------------------------
def pkcs7_pad(data, bs):
    n = bs - (len(data) % bs)
    return data + bytes([n]) * n


def pkcs7_unpad(data):
    return data[:-data[-1]]


def enveloped_data(plaintext, recipient_der, cipher_name):
    rcpt = a_x509.Certificate.load(recipient_der)
    rcpt_pub = x509.load_der_x509_certificate(recipient_der).public_key()

    if cipher_name == "aes256":
        key, iv = os.urandom(32), os.urandom(16)
        ct = AES.new(key, AES.MODE_CBC, iv).encrypt(pkcs7_pad(plaintext, 16))
        alg = cms.EncryptionAlgorithm({"algorithm": "aes256_cbc", "parameters": core.OctetString(iv)})
    elif cipher_name == "aes128":
        key, iv = os.urandom(16), os.urandom(16)
        ct = AES.new(key, AES.MODE_CBC, iv).encrypt(pkcs7_pad(plaintext, 16))
        alg = cms.EncryptionAlgorithm({"algorithm": "aes128_cbc", "parameters": core.OctetString(iv)})
    elif cipher_name == "des3":
        key, iv = DES3.adjust_key_parity(os.urandom(24)), os.urandom(8)
        ct = DES3.new(key, DES3.MODE_CBC, iv).encrypt(pkcs7_pad(plaintext, 8))
        alg = cms.EncryptionAlgorithm({"algorithm": "tripledes_3key", "parameters": core.OctetString(iv)})
    else:
        die("unsupported cipher %s", cipher_name)

    enc_key = rcpt_pub.encrypt(key, padding.PKCS1v15())
    ktri = cms.KeyTransRecipientInfo({
        "version": "v0",
        "rid": cms.RecipientIdentifier(name="issuer_and_serial_number", value=cms.IssuerAndSerialNumber({
            "issuer": rcpt.issuer, "serial_number": rcpt.serial_number})),
        "key_encryption_algorithm": cms.KeyEncryptionAlgorithm({"algorithm": "rsaes_pkcs1v15"}),
        "encrypted_key": enc_key,
    })
    ed = cms.EnvelopedData({
        "version": "v0",
        "recipient_infos": cms.RecipientInfos([cms.RecipientInfo(name="ktri", value=ktri)]),
        "encrypted_content_info": cms.EncryptedContentInfo({
            "content_type": "data", "content_encryption_algorithm": alg, "encrypted_content": ct}),
    })
    return cms.ContentInfo({"content_type": "enveloped_data", "content": ed}).dump()


def signed_data(content, signer_cert, key, digest, extra_attrs):
    hasher = hashlib.sha256 if digest == "sha256" else hashlib.sha1
    dalg = "sha256" if digest == "sha256" else "sha1"
    cert_a = a_x509.Certificate.load(signer_cert.public_bytes(serialization.Encoding.DER))

    attrs = [
        cms.CMSAttribute({"type": "content_type", "values": [cms.ContentType("data")]}),
        cms.CMSAttribute({"type": "signing_time", "values": [cms.Time(name="utc_time", value=dt.datetime.now(dt.timezone.utc))]}),
        cms.CMSAttribute({"type": "message_digest", "values": [core.OctetString(hasher(content).digest())]}),
    ] + extra_attrs
    signed_attrs = cms.CMSAttributes(attrs)
    # signature is over the DER of the attributes as SET OF (tag 0x31), not the implicit [0]
    tbs = signed_attrs.dump()
    sig = key.sign(tbs, padding.PKCS1v15(), hashes.SHA256() if digest == "sha256" else hashes.SHA1())

    si = cms.SignerInfo({
        "version": "v1",
        "sid": cms.SignerIdentifier(name="issuer_and_serial_number", value=cms.IssuerAndSerialNumber({
            "issuer": cert_a.issuer, "serial_number": cert_a.serial_number})),
        "digest_algorithm": algos.DigestAlgorithm({"algorithm": dalg}),
        "signed_attrs": signed_attrs,
        "signature_algorithm": algos.SignedDigestAlgorithm({"algorithm": "rsassa_pkcs1v15"}),
        "signature": sig,
    })
    sd = cms.SignedData({
        "version": "v1",
        "digest_algorithms": cms.DigestAlgorithms([algos.DigestAlgorithm({"algorithm": dalg})]),
        "encap_content_info": cms.ContentInfo({"content_type": "data", "content": core.OctetString(content)}),
        "certificates": cms.CertificateSet([cms.CertificateChoices(name="certificate", value=cert_a)]),
        "signer_infos": cms.SignerInfos([si]),
    })
    return cms.ContentInfo({"content_type": "signed_data", "content": sd}).dump()


def scep_attr(oid_name, value):
    return cms.CMSAttribute({"type": oid_name, "values": [value]})


# --------------------------------------------------------------------------------------
# Response parsing
# --------------------------------------------------------------------------------------
def parse_certrep(der, ca_cert, our_key, our_cert, expect_txid, expect_nonce, verbose):
    ci = cms.ContentInfo.load(der)
    if ci["content_type"].native != "signed_data":
        die("CertRep is not SignedData (%s)", ci["content_type"].native)
    sd = ci["content"]
    si = sd["signer_infos"][0]
    attrs = {a["type"].native: a["values"][0].native for a in si["signed_attrs"]}

    # verify the CA signed it
    dalg = si["digest_algorithm"]["algorithm"].native
    halg = {"sha1": hashes.SHA1(), "sha256": hashes.SHA256(), "sha384": hashes.SHA384(), "sha512": hashes.SHA512()}[dalg]
    tbs = si["signed_attrs"].untag().dump() if hasattr(si["signed_attrs"], "untag") else si["signed_attrs"].dump()
    try:
        ca_cert.public_key().verify(si["signature"].native, tbs, padding.PKCS1v15(), halg)
        sig_ok = "signature by CA verified (%s)" % dalg
    except Exception as e:  # noqa
        sig_ok = "SIGNATURE DID NOT VERIFY against GetCACert cert: %s" % e

    status = attrs.get("scep_pki_status")
    log("CertRep: messageType=%s pkiStatus=%s (%s) %s", attrs.get("scep_message_type"), status,
        PKI_STATUS.get(status, "?"), sig_ok)
    if attrs.get("scep_transaction_id") != expect_txid:
        log("WARNING: transactionID mismatch: sent %s got %s", expect_txid, attrs.get("scep_transaction_id"))
    if attrs.get("scep_recipient_nonce") != expect_nonce:
        log("WARNING: recipientNonce does not echo our senderNonce")

    if status == "2":
        fi = attrs.get("scep_fail_info")
        die("enrollment FAILED: failInfo=%s (%s)", fi, FAIL_INFO.get(fi, "?"))
    if status == "3":
        die("enrollment PENDING (manual approval on the server); no cert issued")
    if status != "0":
        die("unknown pkiStatus %r", status)

    env_der = sd["encap_content_info"]["content"].native
    if env_der is None:
        die("SUCCESS but no enveloped content?")
    plaintext = decrypt_enveloped(env_der, our_key, our_cert, verbose)

    deg = cms.ContentInfo.load(plaintext)
    if deg["content_type"].native != "signed_data":
        die("decrypted payload is not degenerate SignedData")
    certs = [x509.load_der_x509_certificate(c.chosen.dump()) for c in deg["content"]["certificates"]]
    our_pub = our_key.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
    issued = [c for c in certs if c.public_key().public_bytes(serialization.Encoding.DER,
                                                               serialization.PublicFormat.SubjectPublicKeyInfo) == our_pub]
    if not issued:
        die("no certificate in the CertRep matches our public key (got %d certs)", len(certs))
    return issued[0], certs


def decrypt_enveloped(der, key, our_cert, verbose):
    ci = cms.ContentInfo.load(der)
    if ci["content_type"].native != "enveloped_data":
        die("expected EnvelopedData, got %s", ci["content_type"].native)
    ed = ci["content"]
    ktri = None
    for ri in ed["recipient_infos"]:
        if ri.name == "ktri":
            ktri = ri.chosen
            break
    if ktri is None:
        die("no KeyTransRecipientInfo in EnvelopedData")
    kea = ktri["key_encryption_algorithm"]["algorithm"].native
    if kea == "rsaes_pkcs1v15":
        sym_key = key.decrypt(ktri["encrypted_key"].native, padding.PKCS1v15())
    elif kea == "rsaes_oaep":
        sym_key = key.decrypt(ktri["encrypted_key"].native,
                              padding.OAEP(padding.MGF1(hashes.SHA1()), hashes.SHA1(), None))
    else:
        die("unsupported key encryption algorithm %s", kea)

    eci = ed["encrypted_content_info"]
    alg = eci["content_encryption_algorithm"]
    algname = alg["algorithm"].native
    ct = eci["encrypted_content"].native
    if verbose:
        log("CertRep payload encrypted with %s, key transport %s", algname, kea)

    if algname in ("aes128_cbc", "aes192_cbc", "aes256_cbc"):
        iv = alg["parameters"].native
        pt = pkcs7_unpad(AES.new(sym_key, AES.MODE_CBC, iv).decrypt(ct))
    elif algname in ("aes128_gcm", "aes192_gcm", "aes256_gcm"):
        p = alg["parameters"]
        nonce, taglen = p["nonce"].native, p["icv_len"].native
        c = AES.new(sym_key, AES.MODE_GCM, nonce=nonce, mac_len=taglen)
        pt = c.decrypt_and_verify(ct[:-taglen], ct[-taglen:])
    elif algname == "tripledes_3key":
        iv = alg["parameters"].native
        pt = pkcs7_unpad(DES3.new(sym_key, DES3.MODE_CBC, iv).decrypt(ct))
    elif algname == "des":
        iv = alg["parameters"].native
        pt = pkcs7_unpad(DES.new(sym_key, DES.MODE_CBC, iv).decrypt(ct))
    else:
        die("unsupported content encryption algorithm %s", algname)
    return pt


def describe_cert(c):
    def name(n):
        return ", ".join("%s=%s" % (a.rfc4514_attribute_name, a.value) for a in n)
    out = {"subject": name(c.subject), "issuer": name(c.issuer), "serial": format(c.serial_number, "x"),
           "not_before": c.not_valid_before_utc.isoformat(), "not_after": c.not_valid_after_utc.isoformat(),
           "sha1": c.fingerprint(hashes.SHA1()).hex()}
    try:
        san = c.extensions.get_extension_for_class(x509.SubjectAlternativeName).value
        out["san"] = [str(g.value) if not isinstance(g, x509.OtherName) else "UPN:%s" % core.load(g.value).native for g in san]
    except x509.ExtensionNotFound:
        pass
    try:
        out["eku"] = [e.dotted_string for e in c.extensions.get_extension_for_class(x509.ExtendedKeyUsage).value]
    except x509.ExtensionNotFound:
        pass
    return out


# --------------------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("url", help="SCEP URL, e.g. https://pf.example.com/scep/IntuneTemplate")
    ap.add_argument("--subject", default=None, help="CSR subject, e.g. 'CN=DESKTOP-ABC123' (default CN=<machine-name>)")
    ap.add_argument("--machine-name", default="DESKTOP-PFSIM01", help="Windows device name used in MS attributes / default CN")
    ap.add_argument("--user-name", default=None, help="user in the MS request-client-info attribute (user SCEP profile)")
    ap.add_argument("--san-upn", action="append", help="SAN UPN otherName, repeatable (user@domain or device GUID form)")
    ap.add_argument("--san-dns", action="append", help="SAN dNSName, repeatable")
    ap.add_argument("--san-email", action="append", help="SAN rfc822Name, repeatable")
    ap.add_argument("--key-size", type=int, default=2048, choices=[1024, 2048, 3072, 4096], help="RSA key size (Intune default 2048)")
    ap.add_argument("--key-usage", default="digitalSignature,keyEncipherment", help="comma list as in the Intune profile")
    ap.add_argument("--eku", default="clientAuth", help="comma list: clientAuth,serverAuth,smartcardLogon or dotted OIDs")
    ap.add_argument("--challenge", help="challengePassword: Intune encrypted challenge or the template static challenge")
    ap.add_argument("--challenge-file", help="read the challenge from a file (whitespace stripped)")
    ap.add_argument("--challenge-utf8", action="store_true", help="encode challenge as UTF8String instead of PrintableString")
    ap.add_argument("--digest", default=None, choices=["sha1", "sha256"], help="force digest (default: from GetCACaps)")
    ap.add_argument("--cipher", default=None, choices=["aes256", "aes128", "des3"], help="force envelope cipher (default: from GetCACaps)")
    ap.add_argument("--get", action="store_true", help="send PKIOperation as GET even if server advertises POSTPKIOperation")
    ap.add_argument("--ca-id", default="PacketFence", help="'message' sent with GetCACaps/GetCACert (Windows sends the CA identifier)")
    ap.add_argument("--ca-cert", help="use this CA/RA cert (PEM/DER) instead of GetCACert")
    ap.add_argument("--os-version", default="10.0.22631.2", help="value of the MS OS version attribute")
    ap.add_argument("--no-ms-attributes", action="store_true", help="omit the Microsoft CSR attributes")
    ap.add_argument("--out", default="scep-sim", help="output prefix (writes <out>.key, <out>.csr, <out>.crt, <out>-ca.crt)")
    ap.add_argument("--reuse-key", action="store_true", help="reuse <out>.key if present (renewal-like)")
    ap.add_argument("--insecure", "-k", action="store_true", help="skip TLS verification")
    ap.add_argument("--timeout", type=float, default=60.0)
    ap.add_argument("--dump", action="store_true", help="also write the raw PKIOperation request/response (.p7 files)")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    if args.challenge_file:
        with open(args.challenge_file) as f:
            args.challenge = f.read().strip()
    if args.subject is None:
        args.subject = "CN=" + args.machine_name

    http = Http(args.url, args.insecure, args.timeout, args.verbose)

    # 1. GetCACaps
    _, _, caps_raw = http.do("GetCACaps", args.ca_id)
    caps = {c.strip() for c in caps_raw.decode("ascii", "replace").splitlines() if c.strip()}
    log("GetCACaps: %s", " ".join(sorted(caps)) or "(empty)")
    digest = args.digest or ("sha256" if "SHA-256" in caps else "sha1")
    cipher = args.cipher or ("aes256" if "AES" in caps else "des3")
    use_post = ("POSTPKIOperation" in caps) and not args.get
    args.digest, args.cipher = digest, cipher
    log("Using digest=%s cipher=%s PKIOperation via %s", digest, cipher, "POST" if use_post else "GET")

    # 2. GetCACert
    if args.ca_cert:
        with open(args.ca_cert, "rb") as f:
            raw = f.read()
        ca_cert = x509.load_pem_x509_certificate(raw) if b"-----BEGIN" in raw else x509.load_der_x509_certificate(raw)
        ra_cert = ca_cert
    else:
        _, ctype, ca_raw = http.do("GetCACert", args.ca_id)
        if "x-x509-ca-ra-cert" in ctype or ca_raw[:1] == b"\x30" and b"\x2a\x86\x48\x86\xf7\x0d\x01\x07\x02" in ca_raw[:32]:
            deg = cms.ContentInfo.load(ca_raw)
            certs = [x509.load_der_x509_certificate(c.chosen.dump()) for c in deg["content"]["certificates"]]
            # RA/encryption cert = one not self-signed if present, else the first
            ra_cert = next((c for c in certs if c.subject != c.issuer), certs[0])
            ca_cert = next((c for c in certs if c.subject == c.issuer), certs[0])
            log("GetCACert: degenerate PKCS#7 with %d certs", len(certs))
        else:
            ca_cert = x509.load_der_x509_certificate(ca_raw)
            ra_cert = ca_cert
    with open(args.out + "-ca.crt", "wb") as f:
        f.write(ca_cert.public_bytes(serialization.Encoding.PEM))
    log("CA/RA cert: %s (sha1 %s)", ", ".join("%s=%s" % (a.rfc4514_attribute_name, a.value) for a in ra_cert.subject),
        ra_cert.fingerprint(hashes.SHA1()).hex())

    # 3. key + CSR + self-signed
    key = build_key(args.key_size, args.out + ".key" if args.reuse_key else None)
    if not args.reuse_key:
        with open(args.out + ".key", "wb") as f:
            f.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.TraditionalOpenSSL,
                                      serialization.NoEncryption()))
        os.chmod(args.out + ".key", 0o600)
    csr = build_csr(args, key)
    with open(args.out + ".csr", "wb") as f:
        f.write(csr.public_bytes(serialization.Encoding.PEM))
    log("CSR: subject=%s challenge=%s", args.subject,
        ("(%d chars)" % len(args.challenge)) if args.challenge is not None else "NONE")
    self_cert = build_self_signed(key, csr.subject, digest)

    # 4. PKCSReq
    pub_der = key.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
    txid = hashlib.sha1(pub_der).hexdigest().upper()  # Windows derives it from the key too
    nonce = os.urandom(16)
    env = enveloped_data(csr.public_bytes(serialization.Encoding.DER), ra_cert.public_bytes(serialization.Encoding.DER), cipher)
    pkcsreq = signed_data(env, self_cert, key, digest, [
        scep_attr("scep_transaction_id", core.PrintableString(txid)),
        scep_attr("scep_message_type", core.PrintableString(MSG_PKCSREQ)),
        scep_attr("scep_sender_nonce", core.OctetString(nonce)),
    ])
    if args.dump:
        with open(args.out + "-req.p7", "wb") as f:
            f.write(pkcsreq)
    log("PKCSReq: transactionID=%s, %d bytes", txid, len(pkcsreq))

    # 5. PKIOperation
    if use_post:
        _, ctype, rep = http.do("PKIOperation", None, body=pkcsreq)
    else:
        _, ctype, rep = http.do("PKIOperation", base64.b64encode(pkcsreq).decode())
    if args.dump:
        with open(args.out + "-rep.p7", "wb") as f:
            f.write(rep)
    if "x-pki-message" not in ctype:
        log("WARNING: response Content-Type is %r, expected application/x-pki-message", ctype)
        if not rep[:1] == b"\x30":
            die("non-PKCS#7 response body: %s", rep[:500].decode("utf-8", "replace"))

    # 6. CertRep
    issued, chain = parse_certrep(rep, ca_cert, key, self_cert, txid, nonce, args.verbose)
    with open(args.out + ".crt", "wb") as f:
        f.write(issued.public_bytes(serialization.Encoding.PEM))
    log("Issued certificate written to %s.crt (key in %s.key)", args.out, args.out)
    print(json.dumps({"result": "SUCCESS", "transaction_id": txid, "certificate": describe_cert(issued),
                      "chain_certs": len(chain), "files": {"key": args.out + ".key", "csr": args.out + ".csr",
                                                           "cert": args.out + ".crt", "ca": args.out + "-ca.crt"}}, indent=2))


if __name__ == "__main__":
    main()
