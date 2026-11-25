package ocspresponder

import (
	"bytes"
	"crypto"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"encoding/hex"
	"encoding/pem"
	"errors"
	"io"
	"log"
	"math/big"
	"sync"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/ocsp"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/gorm"
)

// parsedCA is a cached, decoded representation of pki_cas.{cert,key}. We
// keep it keyed by row ID and re-parse when the row's UpdatedAt changes.
// The OCSP responder is constructed per request (see handlers.Responder),
// so caching has to live at package scope to survive.
type parsedCA struct {
	cert      *x509.Certificate
	key       crypto.Signer
	updatedAt time.Time
}

var caCache sync.Map // key: models.CA.ID (uint) → *parsedCA

// hsmKeyPair looks up the certificate and the key of a CA held in an HSM
// (replaced in tests).
var hsmKeyPair = func(ca models.CA, db *gorm.DB) (*x509.Certificate, crypto.Signer, error) {
	return ca.KeyPair(db)
}

// hsmSigner is the cached key of a CA held in an HSM. A failed signature
// drops it from the cache: its token session may be gone (the hsm package
// then closes the context) or the HSM settings changed (the old context
// is closed), so the next use looks the key up again in a new session.
type hsmSigner struct {
	crypto.Signer
	id    uint
	entry *parsedCA
}

func (s hsmSigner) Sign(r io.Reader, digest []byte, opts crypto.SignerOpts) ([]byte, error) {
	sig, err := s.Signer.Sign(r, digest, opts)
	if err != nil {
		caCache.CompareAndDelete(s.id, s.entry)
	}
	return sig, err
}

// loadCAMaterial returns a parsed cert + signer for ca, using a cached copy
// whenever the row's UpdatedAt hasn't moved. PEM parsing is the dominant
// CPU cost on the OCSP path (≈5 parses per request before this cache).
// For a key held in an HSM, the cache saves the HSM row read and the
// PKCS#11 key lookup; the key is dropped from it when it fails to sign.
func loadCAMaterial(ca models.CA, db *gorm.DB) (*x509.Certificate, crypto.Signer, error) {
	if v, ok := caCache.Load(ca.ID); ok {
		p := v.(*parsedCA)
		if p.updatedAt.Equal(ca.UpdatedAt) {
			return p.cert, p.key, nil
		}
	}

	if ca.InHSM() {
		cert, key, err := hsmKeyPair(ca, db)
		if err != nil {
			return nil, nil, err
		}
		p := &parsedCA{cert: cert, updatedAt: ca.UpdatedAt}
		p.key = hsmSigner{Signer: key, id: ca.ID, entry: p}
		caCache.Store(ca.ID, p)
		return cert, p.key, nil
	}

	certBlock, _ := pem.Decode([]byte(ca.Cert))
	if certBlock == nil {
		return nil, nil, errors.New("ocsp: CA cert PEM decode failed")
	}
	cert, err := x509.ParseCertificate(certBlock.Bytes)
	if err != nil {
		return nil, nil, err
	}

	keyBlock, _ := pem.Decode([]byte(ca.Key))
	if keyBlock == nil {
		return nil, nil, errors.New("ocsp: CA key PEM decode failed")
	}
	signer, err := parseSigner(keyBlock)
	if err != nil {
		return nil, nil, err
	}

	p := &parsedCA{cert: cert, key: signer, updatedAt: ca.UpdatedAt}
	caCache.Store(ca.ID, p)
	return cert, signer, nil
}

// parseSigner accepts PKCS#1 ("RSA PRIVATE KEY") and PKCS#8 ("PRIVATE KEY")
// blocks; the cert types pfpki signs (RSA, ECDSA, Ed25519) all satisfy
// crypto.Signer.
func parseSigner(block *pem.Block) (crypto.Signer, error) {
	if rsaKey, err := x509.ParsePKCS1PrivateKey(block.Bytes); err == nil {
		return rsaKey, nil
	}
	if pkcs8Key, err := x509.ParsePKCS8PrivateKey(block.Bytes); err == nil {
		if s, ok := pkcs8Key.(crypto.Signer); ok {
			return s, nil
		}
		return nil, errors.New("ocsp: PKCS8 key does not implement crypto.Signer")
	}
	if ecKey, err := x509.ParseECPrivateKey(block.Bytes); err == nil {
		return ecKey, nil
	}
	return nil, errors.New("ocsp: unsupported CA key encoding")
}

// OCSPResponder answers OCSP requests for the CAs of the PKI.
type OCSPResponder struct {
	CaCert  *x509.Certificate
	Handler *types.Handler
}

// Answer is a signed OCSP response with the validity window it carries,
// which the HTTP handler turns into the cache headers of RFC 5019.
type Answer struct {
	DER        []byte
	ThisUpdate time.Time
	NextUpdate time.Time
}

// I only know of two types, but more can be added later
const (
	StatusValid   = 'V'
	StatusRevoked = 'R'
	StatusExpired = 'E'
)

type IndexEntry struct {
	Status            byte
	Serial            *big.Int
	IssueTime         time.Time
	RevocationTime    time.Time
	Reason            int
	DistinguishedName string
}

func (ocspr *OCSPResponder) getCertificateStatus(s *big.Int, ca models.CA) (*IndexEntry, error) {

	var cert models.Cert
	var revokedcert models.RevokedCert
	var ent IndexEntry
	// Search for the certificate that match the serial and has been signed by the CA
	if CertDB := ocspr.Handler.DB.Where(&models.Cert{SerialNumber: s.String(), CaID: ca.ID}).Find(&cert); CertDB.RowsAffected >= 1 {
		ent = IndexEntry{Status: StatusValid, Serial: s, IssueTime: cert.Date, RevocationTime: cert.ValidUntil, DistinguishedName: cert.Cn}
		if time.Now().After(cert.ValidUntil) {
			ent.Status = StatusExpired
		}
		return &ent, nil
	}

	// Check in revoked Certificates
	if CertDB := ocspr.Handler.DB.Where(&models.RevokedCert{SerialNumber: s.String(), CaID: ca.ID}).Find(&revokedcert); CertDB.RowsAffected >= 1 {
		ent = IndexEntry{Status: StatusRevoked, Serial: s, IssueTime: revokedcert.Date, RevocationTime: revokedcert.Revoked, Reason: revokedcert.CRLReason, DistinguishedName: revokedcert.Cn}
		if time.Now().Unix() < revokedcert.Revoked.Unix() {
			ent.Status = StatusValid
		}
		return &ent, nil
	}
	return nil, nil
}

// takes a list of extensions and returns the nonce extension if it is present
func checkForNonceExtension(exts []pkix.Extension) *pkix.Extension {
	nonce_oid := asn1.ObjectIdentifier{1, 3, 6, 1, 5, 5, 7, 48, 1, 2}
	for _, ext := range exts {
		if ext.Id.Equal(nonce_oid) {
			log.Println("Detected nonce extension")
			return &ext
		}
	}
	return nil
}

// Error is a request the responder can't answer with a signed response;
// Status is the OCSP response status to send back instead (RFC 6960
// section 2.3).
type Error struct {
	Status ocsp.ResponseStatus
	Err    error
}

func (e *Error) Error() string {
	if e.Err == nil {
		return e.Status.String()
	}
	return e.Status.String() + ": " + e.Err.Error()
}

func (e *Error) Unwrap() error { return e.Err }

func responderError(status ocsp.ResponseStatus, err error) *Error {
	return &Error{Status: status, Err: err}
}

// ErrorResponse returns the unsigned DER OCSP response that carries the
// error status of err: internalError when err is not an *Error.
func ErrorResponse(err error) (ocsp.ResponseStatus, []byte) {
	status := ocsp.InternalError
	var e *Error
	if errors.As(err, &e) {
		status = e.Status
	}
	switch status {
	case ocsp.Malformed:
		return status, ocsp.MalformedRequestErrorResponse
	case ocsp.TryLater:
		return status, ocsp.TryLaterErrorResponse
	case ocsp.Unauthorized:
		return status, ocsp.UnauthorizedErrorResponse
	default:
		return ocsp.InternalError, ocsp.InternalErrorErrorResponse
	}
}

// errUnknownIssuer is a request for a CA this PKI doesn't hold.
var errUnknownIssuer = errors.New("ocsp: the issuer of the request is not a CA of this PKI")

// verifyIssuer returns the CA of the request: the one whose key has the
// issuer key hash of the request. Its issuer name hash is checked against
// the CA certificate once loaded (see issuerNameMatches): the name hash
// stored in pki_cas is the hash of the CA's issuer, not of its subject,
// which only agree for a root CA.
func (ocspr *OCSPResponder) verifyIssuer(req *ocsp.Request) (models.CA, error) {
	var ca models.CA
	if len(req.IssuerKeyHash) == 0 || len(req.IssuerNameHash) == 0 {
		return ca, errUnknownIssuer
	}
	res := ocspr.Handler.DB.Where("issuer_key_hash = ?", hex.EncodeToString(req.IssuerKeyHash)).Limit(1).Find(&ca)
	if res.Error != nil {
		return ca, res.Error
	}
	if res.RowsAffected == 0 {
		return ca, errUnknownIssuer
	}
	return ca, nil
}

// issuerNameMatches tells whether the issuer name hash of req is the hash
// of the subject of cacert (RFC 6960 section 4.1.1).
func issuerNameMatches(req *ocsp.Request, cacert *x509.Certificate) bool {
	if !req.HashAlgorithm.Available() {
		return false
	}
	h := req.HashAlgorithm.New()
	h.Write(cacert.RawSubject)
	return bytes.Equal(h.Sum(nil), req.IssuerNameHash)
}

// Verify answers the DER OCSP request rawreq with a signed DER response.
func (ocspr *OCSPResponder) Verify(rawreq []byte) ([]byte, error) {
	a, err := ocspr.Respond(rawreq)
	if err != nil {
		return nil, err
	}
	return a.DER, nil
}

// Respond answers the DER OCSP request rawreq. When it can't, the error is
// an *Error with the OCSP status to answer (see ErrorResponse):
// malformedRequest for a request that doesn't parse, unauthorized for a
// CA this PKI doesn't hold, tryLater when the HSM of the CA fails and
// internalError for the rest.
func (ocspr *OCSPResponder) Respond(rawreq []byte) (*Answer, error) {
	var status int
	var revokedAt time.Time
	var reason int
	reason = ocsp.Unspecified

	req, exts, err := ocsp.ParseRequest(rawreq)
	if err != nil {
		return nil, responderError(ocsp.Malformed, err)
	}

	ca, err := ocspr.verifyIssuer(req)
	if errors.Is(err, errUnknownIssuer) {
		return nil, responderError(ocsp.Unauthorized, err)
	}
	if err != nil {
		return nil, responderError(ocsp.InternalError, err)
	}
	// A failure of the HSM holding the CA key is most likely transient
	// (token session, network): tryLater. A software key that doesn't
	// load won't come back by itself.
	failStatus := ocsp.InternalError
	if ca.InHSM() {
		failStatus = ocsp.TryLater
	}

	ent, err := ocspr.getCertificateStatus(req.SerialNumber, ca)

	if err != nil || ent == nil {
		status = ocsp.Unknown
	} else {
		if ent.Status == StatusRevoked {
			status = ocsp.Revoked
			revokedAt = ent.RevocationTime
			reason = ent.Reason
		} else if ent.Status == StatusValid {
			status = ocsp.Good
		}
	}

	// Look up the (cert, signer) pair once. The cache avoids 3 cert parses
	// and 2 key parses per OCSP request on the previous code path.
	cacert, key, err := loadCAMaterial(ca, ocspr.Handler.DB)
	if err != nil {
		return nil, responderError(failStatus, err)
	}
	if !issuerNameMatches(req, cacert) {
		return nil, responderError(ocsp.Unauthorized, errUnknownIssuer)
	}
	ocspr.CaCert = cacert

	// Echo back the client's nonce extension if present. We intentionally
	// do NOT track seen nonces across requests: this responder is
	// reconstructed per HTTP request (see handlers.Responder), so any
	// per-instance list never sees a second request — the previous code
	// path was both a bug (zero-initialised slice of 10 nils) and an
	// unbounded-growth foot-gun if it ever did survive.
	var responseExtensions []pkix.Extension
	if nonce := checkForNonceExtension(exts); nonce != nil {
		responseExtensions = append(responseExtensions, *nonce)
	}

	// construct response template
	now := time.Now().UTC()
	thisUpdate, nextUpdate := now.AddDate(0, 0, -1), now.AddDate(0, 0, 1)
	rtemplate := ocsp.Response{
		Status:           status,
		SerialNumber:     req.SerialNumber,
		Certificate:      cacert,
		RevocationReason: reason,
		IssuerHash:       req.HashAlgorithm,
		RevokedAt:        revokedAt,
		ThisUpdate:       thisUpdate,
		NextUpdate:       nextUpdate,
		Extensions:       responseExtensions,
	}

	// make a response to return
	resp, err := ocsp.CreateResponse(cacert, cacert, rtemplate, key)
	if err != nil && ca.InHSM() {
		// The cached HSM key failed (and was dropped from the cache):
		// look it up again once, in a new session.
		if cacert, key, err = loadCAMaterial(ca, ocspr.Handler.DB); err == nil {
			rtemplate.Certificate = cacert
			resp, err = ocsp.CreateResponse(cacert, cacert, rtemplate, key)
		}
	}
	if err != nil {
		return nil, responderError(failStatus, err)
	}

	return &Answer{DER: resp, ThisUpdate: thisUpdate, NextUpdate: nextUpdate}, nil
}
