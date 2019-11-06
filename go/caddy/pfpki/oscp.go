package pfpki

import (
	"bytes"
	"crypto"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"encoding/base64"
	"encoding/hex"
	"encoding/pem"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"math/big"
	"net/http"
	"time"

	"github.com/davecgh/go-spew/spew"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/ocsp"
)

// OCSPResponder struct
type OCSPResponder struct {
	RespKeyFile string
	Strict      bool
	CaCert      *x509.Certificate
	RespCert    *x509.Certificate
	NonceList   [][]byte
	Handler     *Handler
}

// I decided on these defaults based on what I was using
func Responder(pfpki *Handler) *OCSPResponder {
	return &OCSPResponder{
		RespKeyFile: "responder.key",
		Strict:      false,
		CaCert:      nil,
		RespCert:    nil,
		NonceList:   nil,
		Handler:     pfpki,
	}
}

// Creates an OCSP http handler and returns it
func (ocspr *OCSPResponder) makeHandler() func(w http.ResponseWriter, r *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		log.Print(fmt.Sprintf("Got %s request from %s", r.Method, r.RemoteAddr))
		if ocspr.Strict && r.Header.Get("Content-Type") != "application/ocsp-request" {
			log.Println("Strict mode requires correct Content-Type header")
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		b := new(bytes.Buffer)
		switch r.Method {
		case "POST":
			b.ReadFrom(r.Body)
		case "GET":
			log.Println(r.URL.Path)
			gd, err := base64.StdEncoding.DecodeString(r.URL.Path[1:])
			if err != nil {
				log.Println(err)
				w.WriteHeader(http.StatusBadRequest)
				return
			}
			r := bytes.NewReader(gd)
			b.ReadFrom(r)
		default:
			log.Println("Unsupported request method")
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		// parse request, verify, create response
		w.Header().Set("Content-Type", "application/ocsp-response")
		resp, err := ocspr.verify(b.Bytes())
		if err != nil {
			log.Print(err)
			// technically we should return an ocsp error response. but this is probably fine
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		log.Print("Writing response")
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
	Status byte
	Serial *big.Int // wow I totally called it
	// revocation reason may need to be added
	IssueTime         time.Time
	RevocationTime    time.Time
	DistinguishedName string
}

// updates the index if necessary and then searches for the given index in the
// index list
func (ocspr *OCSPResponder) getIndexEntry(s *big.Int, ca CA) (*IndexEntry, error) {

	var cert Cert

	if CertDB := ocspr.Handler.DB.Where("serial_number = ? AND ca_id = ?", s.String(), ca.ID).Find(&cert); CertDB.Error != nil {
		return nil, CertDB.Error
	}
	// serial, _ := new(big.Int).SetString(cert.SerialNumber, 10)
	ent := IndexEntry{Status: StatusValid, Serial: s, IssueTime: cert.Date, RevocationTime: cert.ValidUntil, DistinguishedName: cert.Cn}
	if time.Now().After(cert.ValidUntil) {
		ent.Status = StatusExpired
	}
	if cert.Revoked == 1 {
		ent.Status = StatusRevoked
	}
	return &ent, nil
}

// parses a pem encoded x509 certificate
func parseCertFile(filename string) (*x509.Certificate, error) {
	ct, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	block, _ := pem.Decode(ct)
	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return nil, err
	}
	return cert, nil
}

// parses a PEM encoded PKCS8 private key (RSA only)
func parseKeyFile(filename string) (interface{}, error) {
	kt, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	block, _ := pem.Decode(kt)
	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}
	return key, nil
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

func (ocspr *OCSPResponder) verifyIssuer(req *ocsp.Request) (CA, error) {
	var ca CA
	if CaDB := ocspr.Handler.DB.Where(&CA{IssuerNameHash: hex.EncodeToString(req.IssuerNameHash)}).Find(&ca); CaDB.Error != nil {
		return ca, errors.New("Unable to find Issuer name")
	}

	if CaDB := ocspr.Handler.DB.Where(&CA{IssuerKeyHash: hex.EncodeToString(req.IssuerKeyHash)}).Find(&ca); CaDB.Error != nil {
		return ca, errors.New("Unable to find Key name")
	}
	return ca, nil
}

// takes the der encoded ocsp request, verifies it, and creates a response
func (ocspr *OCSPResponder) verify(rawreq []byte) ([]byte, error) {
	var status int
	var revokedAt time.Time

	// parse the request
	req, exts, err := ocsp.ParseRequest(rawreq)
	if err != nil {
		log.Println(err)
		return nil, err
	}

	//make sure the request is valid

	ca, err := ocspr.verifyIssuer(req)
	if err != nil {
		log.Println(err)
		return nil, err
	}

	ent, err := ocspr.getIndexEntry(req.SerialNumber, ca)
	if err != nil {
		log.Println(err)
		status = ocsp.Unknown
	} else {
		log.Print(fmt.Sprintf("Found entry %+v", ent))
		if ent.Status == StatusRevoked {
			log.Print("This certificate is revoked")
			status = ocsp.Revoked
			revokedAt = ent.RevocationTime
		} else if ent.Status == StatusValid {
			log.Print("This certificate is valid")
			status = ocsp.Good
		}
	}

	catls, err := tls.X509KeyPair([]byte(ca.CaCert), []byte(ca.CaKey))
	if err != nil {
		return nil, err
	}
	keyi, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		return nil, err
	}

	key, ok := keyi.PublicKey.(crypto.Signer)
	if !ok {
		spew.Dump(ent)
		return nil, errors.New("Could not make key a signer")
	}

	// check for nonce extension
	var responseExtensions []pkix.Extension
	nonce := checkForNonceExtension(exts)

	// check if the nonce has been used before
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
		RevocationReason: ocsp.Unspecified,
		IssuerHash:       req.HashAlgorithm,
		RevokedAt:        revokedAt,
		ThisUpdate:       time.Now().AddDate(0, 0, -1).UTC(),
		//adding 1 day after the current date. This ocsp library sets the default date to epoch which makes ocsp clients freak out.
		NextUpdate: time.Now().AddDate(0, 0, 1).UTC(),
		Extensions: exts,
	}

	// make a response to return
	resp, err := ocsp.CreateResponse(ocspr.CaCert, ocspr.RespCert, rtemplate, key)
	if err != nil {
		return nil, err
	}

	return resp, err
}
