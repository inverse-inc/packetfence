package acme

import (
	"bytes"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"net/http"

	chi "github.com/go-chi/chi/v5"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/gorm"
)

// errCertNotIssued is returned by loadIssuedCert when no certificate
// with the given serial was issued under the profile, or when the
// presented DER is not the certificate pfpki issued for that serial.
var errCertNotIssued = errors.New("certificate not issued under this profile")

// loadIssuedCert finds the pki_certs row for serial under profileID
// and parses the stored leaf. When der is non-nil the presented
// certificate must be byte-for-byte the one pfpki issued: a lookup by
// serial alone would let a caller pair a victim's serial with a
// self-made certificate carrying their own key, and then pass the
// certificate-key check in revoke-cert.
func loadIssuedCert(db *gorm.DB, profileID uint, serial string, der []byte) (*models.Cert, *x509.Certificate, error) {
	var row models.Cert
	if err := db.Preload("Ca").
		Where("serial_number = ? AND profile_id = ?", serial, profileID).
		First(&row).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil, errCertNotIssued
		}
		return nil, nil, err
	}
	block, _ := pem.Decode([]byte(row.Cert))
	if block == nil {
		return nil, nil, errors.New("stored certificate is not PEM")
	}
	issued, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return nil, nil, err
	}
	if der != nil && !bytes.Equal(issued.Raw, der) {
		return nil, nil, errCertNotIssued
	}
	return &row, issued, nil
}

// certByIDHandler implements §7.4.2's cert download: POST-as-GET with
// the cert serial number as the URL parameter. Returns the leaf
// followed by the issuing CA as a PEM chain with the spec-mandated
// Content-Type.
//
// Authorization: the certificate must have been issued to the
// authenticated account (pki_certs.acme_account_id, set by finalize).
func certByIDHandler(h *types.Handler) http.HandlerFunc {
	inner := func(w http.ResponseWriter, r *http.Request) {
		jc := fromCtx(r.Context())
		if jc == nil || jc.Account == nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, "missing account in JWS context")
			return
		}
		serial := chi.URLParam(r, "id")
		if serial == "" {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "missing cert id")
			return
		}
		cert, _, err := loadIssuedCert(h.DB, jc.Profile.ID, serial, nil)
		if err != nil {
			if errors.Is(err, errCertNotIssued) {
				_ = WriteProblem(w, http.StatusNotFound, ErrMalformed, "no such certificate")
				return
			}
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}
		if cert.AcmeAccountID != jc.Account.ID {
			_ = WriteProblem(w, http.StatusUnauthorized, ErrUnauthorized,
				"certificate was not issued to this account")
			return
		}
		w.Header().Set("Content-Type", "application/pem-certificate-chain")
		// Leaf then issuing CA — the order the spec expects.
		_, _ = w.Write([]byte(cert.Cert))
		_, _ = w.Write([]byte(cert.Ca.Cert))
	}
	return jwsMiddleware(h, jwsRequireKID, inner)
}

// revokePayload is the §7.6 request body: a base64url-encoded DER cert
// plus an optional integer reason (RFC 5280 CRLReason).
type revokePayload struct {
	Certificate string `json:"certificate"`
	Reason      *int   `json:"reason,omitempty"`
}

// revokeCertHandler implements §7.6's revoke. Two authorisations are
// accepted, exactly as the spec lists them:
//
//   - kid: the account the JWS resolves to must be the account the
//     certificate was issued to (pki_certs.acme_account_id).
//   - jwk: the JWS must be signed by the certificate's own key pair,
//     i.e. the JWK's public key equals the issued leaf's public key.
//
// In both cases the presented DER must be the certificate pfpki
// issued for that serial. Any account on the profile being able to
// revoke any certificate under it would let one compromised device
// take the whole fleet off the network.
func revokeCertHandler(h *types.Handler) http.HandlerFunc {
	inner := func(w http.ResponseWriter, r *http.Request) {
		jc := fromCtx(r.Context())
		if jc == nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, "missing JWS context")
			return
		}
		var payload revokePayload
		if err := json.Unmarshal(jc.Payload, &payload); err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "decode payload: "+err.Error())
			return
		}
		der, err := jwsURLEncoding.DecodeString(payload.Certificate)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed,
				"certificate field is not URL-safe base64: "+err.Error())
			return
		}
		leaf, err := x509.ParseCertificate(der)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed,
				"parse certificate: "+err.Error())
			return
		}
		serial := leaf.SerialNumber.String()
		row, issued, err := loadIssuedCert(h.DB, jc.Profile.ID, serial, der)
		if err != nil {
			if errors.Is(err, errCertNotIssued) {
				_ = WriteProblem(w, http.StatusNotFound, ErrMalformed, err.Error())
				return
			}
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}

		if jc.Account != nil {
			if row.AcmeAccountID != jc.Account.ID {
				_ = WriteProblem(w, http.StatusUnauthorized, ErrUnauthorized,
					"certificate was not issued to this account")
				return
			}
		} else {
			if jc.JWK == nil || !publicKeysEqual(jc.JWK.Key, issued.PublicKey) {
				_ = WriteProblem(w, http.StatusUnauthorized, ErrUnauthorized,
					"JWS key does not match the certificate key")
				return
			}
		}

		// RFC 5280 §5.3.1: 0=unspecified, 4=superseded, etc.; only
		// validate range, not specific values — the CA may surface
		// new reasons in future profiles.
		reason := 0
		if payload.Reason != nil {
			if *payload.Reason < 0 || *payload.Reason > 10 {
				_ = WriteProblem(w, http.StatusBadRequest, ErrBadRevocationReason,
					"reason out of RFC 5280 range")
				return
			}
			reason = *payload.Reason
		}

		// Hand off to the existing pfpki revoke path; it handles
		// inserting into pki_revoked_certs and removing from pki_certs
		// in one transaction.
		helper := models.Cert{DB: h.DB, Ctx: r.Context()}
		found, err := helper.RevokeBySerial(row.CaName, serial, reason)
		if err != nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}
		actor := requestActor(jc)
		if !found {
			// Race: the cert was revoked by another caller between
			// the lookup above and the revoke. Treat as success per
			// §7.6 idempotency, but still emit an audit row so the
			// double-revoke is observable.
			auditACMEEvent(r.Context(), h.DB, jc.Profile.Name, actor, "acme.cert.revoke",
				serial, r.Method, requestURLForAudit(r), http.StatusOK,
				map[string]any{"reason": reason, "already_revoked": true})
			w.WriteHeader(http.StatusOK)
			return
		}
		auditACMEEvent(r.Context(), h.DB, jc.Profile.Name, actor, "acme.cert.revoke",
			serial, r.Method, requestURLForAudit(r), http.StatusOK,
			map[string]any{"reason": reason})
		// §7.6: empty body, 200 OK on success.
		w.WriteHeader(http.StatusOK)
	}
	return jwsMiddleware(h, jwsAllowEither, inner)
}

// publicKeysEqual compares two public keys by their DER
// SubjectPublicKeyInfo encoding, which covers every key type the JWS
// allowlist admits (RSA, ECDSA, Ed25519).
func publicKeysEqual(a, b any) bool {
	da, err := x509.MarshalPKIXPublicKey(a)
	if err != nil {
		return false
	}
	db, err := x509.MarshalPKIXPublicKey(b)
	if err != nil {
		return false
	}
	return bytes.Equal(da, db)
}
