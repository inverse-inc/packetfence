package ocspresponder

import (
	"bytes"
	"crypto"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"encoding/base64"
	"encoding/hex"
	"encoding/pem"
	"errors"
	"log"
	"math/big"
	"net/http"
	"sync"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/ocsp"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
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

// loadCAMaterial returns a parsed cert + signer for ca, using a cached copy
// whenever the row's UpdatedAt hasn't moved. PEM parsing is the dominant
// CPU cost on the OCSP path (≈5 parses per request before this cache).
func loadCAMaterial(ca models.CA) (*x509.Certificate, crypto.Signer, error) {
	if v, ok := caCache.Load(ca.ID); ok {
		p := v.(*parsedCA)
		if p.updatedAt.Equal(ca.UpdatedAt) {
			return p.cert, p.key, nil
		}
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

// OCSPResponder struct
type OCSPResponder struct {
	RespKeyFile string
	Strict      bool
	CaCert      *x509.Certificate
	RespCert    *x509.Certificate
	NonceList   [][]byte
	Handler     *types.Handler
}

// Creates an OCSP http handler and returns it
func (ocspr *OCSPResponder) makeHandler() func(w http.ResponseWriter, r *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		if ocspr.Strict && r.Header.Get("Content-Type") != "application/ocsp-request" {
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		b := new(bytes.Buffer)
		switch r.Method {
		case "POST":
			b.ReadFrom(r.Body)
		case "GET":
			gd, err := base64.StdEncoding.DecodeString(r.URL.Path[1:])
			if err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}
			r := bytes.NewReader(gd)
			b.ReadFrom(r)
		default:
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		w.Header().Set("Content-Type", "application/ocsp-response")
		resp, err := ocspr.Verify(b.Bytes())
		if err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		w.Write(resp)
	}
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

func (ocspr *OCSPResponder) verifyIssuer(req *ocsp.Request) (models.CA, error) {
	var ca models.CA
	if CaDB := ocspr.Handler.DB.Where(&models.CA{IssuerNameHash: hex.EncodeToString(req.IssuerNameHash)}).Find(&ca); CaDB.Error != nil {
		return ca, errors.New("Unable to find Issuer name")
	}

	if CaDB := ocspr.Handler.DB.Where(&models.CA{IssuerKeyHash: hex.EncodeToString(req.IssuerKeyHash)}).Find(&ca); CaDB.Error != nil {
		return ca, errors.New("Unable to find Key name")
	}

	return ca, nil
}

func (ocspr *OCSPResponder) Verify(rawreq []byte) ([]byte, error) {
	var status int
	var revokedAt time.Time
	var reason int
	reason = ocsp.Unspecified

	req, exts, err := ocsp.ParseRequest(rawreq)
	if err != nil {
		return nil, err
	}

	ca, err := ocspr.verifyIssuer(req)
	if err != nil {
		return nil, err
	}

	ent, err := ocspr.getCertificateStatus(req.SerialNumber, ca)

	if err != nil {
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
	cacert, key, err := loadCAMaterial(ca)
	if err != nil {
		return nil, err
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
	rtemplate := ocsp.Response{
		Status:           status,
		SerialNumber:     req.SerialNumber,
		Certificate:      cacert,
		RevocationReason: reason,
		IssuerHash:       req.HashAlgorithm,
		RevokedAt:        revokedAt,
		ThisUpdate:       now.AddDate(0, 0, -1),
		NextUpdate:       now.AddDate(0, 0, 1),
		Extensions:       responseExtensions,
	}

	// make a response to return
	resp, err := ocsp.CreateResponse(cacert, cacert, rtemplate, key)
	if err != nil {
		return nil, err
	}

	return resp, err
}
