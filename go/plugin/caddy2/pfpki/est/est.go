// Package est implements the server side of Enrollment over Secure
// Transport (RFC 7030, with the RFC 8951 clarifications) on top of the
// pfpki profiles.
//
// Each EST-enabled profile is an EST label:
//
//	GET  /.well-known/est[/<profile>]/cacerts
//	GET  /.well-known/est[/<profile>]/csrattrs
//	POST /.well-known/est[/<profile>]/simpleenroll
//	POST /.well-known/est[/<profile>]/simplereenroll
//	POST /.well-known/est[/<profile>]/serverkeygen
//
// Without a label the first EST-enabled profile is used. cacerts and
// csrattrs are anonymous; the enrollment operations authenticate the
// client with HTTP Basic against the profile's EST credentials. TLS is
// terminated in front of pfpki, so the TLS client-certificate
// authentication of RFC 7030 3.3.2 is not available.
package est

import (
	"bytes"
	"crypto"
	"crypto/rand"
	"crypto/subtle"
	"crypto/x509"
	"encoding/asn1"
	"encoding/base64"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/textproto"
	"strings"

	chi "github.com/go-chi/chi/v5"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"github.com/inverse-inc/pkcs7"
	"gorm.io/gorm"
)

const (
	mimeCACerts   = "application/pkcs7-mime"
	mimeCertsOnly = "application/pkcs7-mime; smime-type=certs-only"
	mimePKCS8     = "application/pkcs8"

	// maxCSRSize bounds the base64 PKCS#10 body of an enrollment.
	maxCSRSize = 64 << 10
)

var oidSubjectAltName = asn1.ObjectIdentifier{2, 5, 29, 17}

// Mount returns the EST router. The caller mounts it under
// /.well-known/est (and /pki/est for the API front end).
func Mount(h *types.Handler) chi.Router {
	r := chi.NewRouter()
	routes := func(r chi.Router) {
		r.Get("/cacerts", caCertsHandler(h))
		r.Get("/csrattrs", csrAttrsHandler(h))
		r.Post("/simpleenroll", enrollHandler(h, false))
		r.Post("/simplereenroll", enrollHandler(h, true))
		r.Post("/serverkeygen", serverKeyGenHandler(h))
	}
	routes(r)
	r.Route("/{profile}", routes)
	return r
}

func logInfo(r *http.Request, msg string) {
	log.LoggerWContext(r.Context()).Info(fmt.Sprintf("EST %s %s from %s: %s", r.Method, r.URL.Path, r.RemoteAddr, msg))
}

// profileFor resolves the EST label of the request. It writes the error
// response itself and returns nil when there is no usable profile.
func profileFor(h *types.Handler, w http.ResponseWriter, r *http.Request) *models.Profile {
	name := chi.URLParam(r, "profile")
	prof, err := models.GetESTProfile(h.DB, name)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			logInfo(r, fmt.Sprintf("no EST-enabled profile %q", name))
			http.Error(w, "unknown EST label", http.StatusNotFound)
		} else {
			log.LoggerWContext(r.Context()).Error("EST: unable to load the profile: " + err.Error())
			http.Error(w, "internal error", http.StatusInternalServerError)
		}
		return nil
	}
	return prof
}

// authenticate checks the HTTP Basic credentials against the profile.
func authenticate(prof *models.Profile, w http.ResponseWriter, r *http.Request) bool {
	user, pass, ok := r.BasicAuth()
	valid := ok && prof.EstPassword != "" &&
		subtle.ConstantTimeCompare([]byte(pass), []byte(prof.EstPassword)) == 1 &&
		(prof.EstUsername == "" || subtle.ConstantTimeCompare([]byte(user), []byte(prof.EstUsername)) == 1)
	if !valid {
		w.Header().Set("WWW-Authenticate", fmt.Sprintf(`Basic realm="EST %s"`, prof.Name))
		http.Error(w, "unauthorized", http.StatusUnauthorized)
	}
	return valid
}

func caCertsHandler(h *types.Handler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		prof := profileFor(h, w, r)
		if prof == nil {
			return
		}
		ca, err := caCertificate(prof)
		if err != nil {
			log.LoggerWContext(r.Context()).Error("EST: " + err.Error())
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		writePKCS7(w, mimeCACerts, ca.Raw)
	}
}

// csrAttrsHandler answers that the server has no CSR attributes to
// request (RFC 7030 4.5.2): the Subject is built from the profile.
func csrAttrsHandler(h *types.Handler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if prof := profileFor(h, w, r); prof == nil {
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}
}

func enrollHandler(h *types.Handler, reenroll bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		prof := profileFor(h, w, r)
		if prof == nil || !authenticate(prof, w, r) {
			return
		}
		csr, err := readCSR(r)
		if err != nil {
			logInfo(r, err.Error())
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		cert, ok := issue(h, w, r, prof, csr, reenroll)
		if !ok {
			return
		}
		der, err := pemToDER(cert.Cert)
		if err != nil {
			log.LoggerWContext(r.Context()).Error("EST: " + err.Error())
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		logInfo(r, fmt.Sprintf("issued certificate serial %s for CN %q under profile %q", cert.SerialNumber, cert.Cn, prof.Name))
		writePKCS7(w, mimeCertsOnly, der)
	}
}

// serverKeyGenHandler generates the key pair on behalf of the client
// (RFC 7030 4.4). The private key is returned unencrypted as PKCS#8,
// protected by the TLS session as the RFC allows.
func serverKeyGenHandler(h *types.Handler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		prof := profileFor(h, w, r)
		if prof == nil || !authenticate(prof, w, r) {
			return
		}
		clientCSR, err := readCSR(r)
		if err != nil {
			logInfo(r, err.Error())
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		_, _, key, err := certutils.GenerateKey(*prof.KeyType, prof.KeySize)
		if err != nil {
			log.LoggerWContext(r.Context()).Error("EST: unable to generate the key: " + err.Error())
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		signer, ok := key.(crypto.Signer)
		if !ok {
			http.Error(w, "the profile key type does not support server-side key generation", http.StatusNotImplemented)
			return
		}

		// Re-sign the client's Subject and SubjectAltName with the new key.
		tmpl := &x509.CertificateRequest{RawSubject: clientCSR.RawSubject}
		for _, ext := range clientCSR.Extensions {
			if ext.Id.Equal(oidSubjectAltName) {
				tmpl.ExtraExtensions = append(tmpl.ExtraExtensions, ext)
			}
		}
		csrDER, err := x509.CreateCertificateRequest(rand.Reader, tmpl, signer)
		if err != nil {
			log.LoggerWContext(r.Context()).Error("EST: unable to create the CSR: " + err.Error())
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		csr, err := x509.ParseCertificateRequest(csrDER)
		if err != nil {
			log.LoggerWContext(r.Context()).Error("EST: unable to parse the CSR: " + err.Error())
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		cert, ok := issue(h, w, r, prof, csr, false)
		if !ok {
			return
		}
		certDER, err := pemToDER(cert.Cert)
		if err != nil {
			log.LoggerWContext(r.Context()).Error("EST: " + err.Error())
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		keyDER, err := x509.MarshalPKCS8PrivateKey(key)
		if err != nil {
			log.LoggerWContext(r.Context()).Error("EST: unable to encode the key: " + err.Error())
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		p7, err := pkcs7.DegenerateCertificate(certDER)
		if err != nil {
			log.LoggerWContext(r.Context()).Error("EST: " + err.Error())
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		var body bytes.Buffer
		mw := multipart.NewWriter(&body)
		for _, part := range []struct {
			mime string
			der  []byte
		}{{mimePKCS8, keyDER}, {mimeCertsOnly, p7}} {
			pw, err := mw.CreatePart(textproto.MIMEHeader{
				"Content-Type":              {part.mime},
				"Content-Transfer-Encoding": {"base64"},
			})
			if err == nil {
				_, err = pw.Write(base64Lines(part.der))
			}
			if err != nil {
				log.LoggerWContext(r.Context()).Error("EST: " + err.Error())
				http.Error(w, "internal error", http.StatusInternalServerError)
				return
			}
		}
		mw.Close()

		logInfo(r, fmt.Sprintf("generated key and issued certificate serial %s for CN %q under profile %q", cert.SerialNumber, cert.Cn, prof.Name))
		w.Header().Set("Content-Type", "multipart/mixed; boundary="+mw.Boundary())
		w.WriteHeader(http.StatusOK)
		w.Write(body.Bytes())
	}
}

// issue runs the issuance and maps its errors to HTTP statuses.
func issue(h *types.Handler, w http.ResponseWriter, r *http.Request, prof *models.Profile, csr *x509.CertificateRequest, reenroll bool) (*models.Cert, bool) {
	cert, err := models.IssueESTCert(h.DB, r.Context(), *prof, csr, reenroll)
	if err != nil {
		if errors.Is(err, models.ErrESTPolicy) {
			logInfo(r, err.Error())
			http.Error(w, err.Error(), http.StatusForbidden)
		} else {
			log.LoggerWContext(r.Context()).Error("EST: issuance failed: " + err.Error())
			http.Error(w, "internal error", http.StatusInternalServerError)
		}
		return nil, false
	}
	return cert, true
}

// readCSR decodes the PKCS#10 body. RFC 8951 makes it base64; a raw DER
// body is accepted as well.
func readCSR(r *http.Request) (*x509.CertificateRequest, error) {
	body, err := io.ReadAll(io.LimitReader(r.Body, maxCSRSize+1))
	if err != nil {
		return nil, fmt.Errorf("unable to read the request: %w", err)
	}
	if len(body) > maxCSRSize {
		return nil, errors.New("the CSR is too large")
	}
	der, err := base64.StdEncoding.DecodeString(strings.Join(strings.Fields(string(body)), ""))
	if err != nil {
		der = body
	}
	csr, err := x509.ParseCertificateRequest(der)
	if err != nil {
		return nil, fmt.Errorf("invalid PKCS#10 request: %w", err)
	}
	if err := csr.CheckSignature(); err != nil {
		return nil, fmt.Errorf("invalid CSR signature: %w", err)
	}
	return csr, nil
}

func caCertificate(prof *models.Profile) (*x509.Certificate, error) {
	der, err := pemToDER(prof.Ca.Cert)
	if err != nil {
		return nil, fmt.Errorf("CA of profile %q: %w", prof.Name, err)
	}
	return x509.ParseCertificate(der)
}

func pemToDER(s string) ([]byte, error) {
	block, _ := pem.Decode([]byte(s))
	if block == nil || block.Type != "CERTIFICATE" {
		return nil, errors.New("no PEM certificate")
	}
	return block.Bytes, nil
}

// writePKCS7 answers with a base64 certs-only PKCS#7 (RFC 7030 4.1.3, 4.2.3).
func writePKCS7(w http.ResponseWriter, mime string, der []byte) {
	p7, err := pkcs7.DegenerateCertificate(der)
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", mime)
	w.Header().Set("Content-Transfer-Encoding", "base64")
	w.WriteHeader(http.StatusOK)
	w.Write(base64Lines(p7))
}

// base64Lines encodes der in 64-column LF-terminated lines, which both EST
// clients and base64(1) accept (base64 -d rejects CR).
func base64Lines(der []byte) []byte {
	enc := base64.StdEncoding.EncodeToString(der)
	var b bytes.Buffer
	for len(enc) > 64 {
		b.WriteString(enc[:64])
		b.WriteByte('\n')
		enc = enc[64:]
	}
	b.WriteString(enc)
	b.WriteByte('\n')
	return b.Bytes()
}
