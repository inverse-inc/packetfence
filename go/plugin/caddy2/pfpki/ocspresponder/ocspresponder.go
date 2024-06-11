package ocspresponder

import (
	"bytes"
	"crypto"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"log"
	"math/big"
	"net/http"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/ocsp"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

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

	//Assign the good ca to the reply
	cacert, err := certutils.ParseCertFile(ca.Cert)

	if err != nil {
		return nil, err
	}
	ocspr.CaCert = cacert

	catls, err := tls.X509KeyPair([]byte(ca.Cert), []byte(ca.Key))
	if err != nil {
		return nil, err
	}
	keyi, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		return nil, err
	}

	pkey, err := certutils.ParseRsaPrivateKeyFromPemStr(ca.Key)

	key, ok := pkey.(crypto.Signer)
	if !ok {
		return nil, errors.New("Could not make key a signer")
	}

	var responseExtensions []pkix.Extension
	nonce := checkForNonceExtension(exts)

	if ocspr.NonceList == nil {
		ocspr.NonceList = make([][]byte, 10)
	}

	if nonce != nil {
		for _, n := range ocspr.NonceList {
			if bytes.Compare(n, nonce.Value) == 0 {
				return nil, errors.New("This nonce has already been used")
			}
		}

		ocspr.NonceList = append(ocspr.NonceList, nonce.Value)
		responseExtensions = append(responseExtensions, *nonce)
	}

	// construct response template
	rtemplate := ocsp.Response{
		Status:           status,
		SerialNumber:     req.SerialNumber,
		Certificate:      keyi,
		RevocationReason: reason,
		IssuerHash:       req.HashAlgorithm,
		RevokedAt:        revokedAt,
		ThisUpdate:       time.Now().AddDate(0, 0, -1).UTC(),
		NextUpdate:       time.Now().AddDate(0, 0, 1).UTC(),
		Extensions:       exts,
	}

	// make a response to return
	resp, err := ocsp.CreateResponse(ocspr.CaCert, ocspr.CaCert, rtemplate, key)
	if err != nil {
		return nil, err
	}

	return resp, err
}
