package acme

import (
	"crypto/x509"
	"encoding/json"
	"errors"
	"net/http"

	chi "github.com/go-chi/chi/v5"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/gorm"
)

// certByIDHandler implements §7.4.2's cert download: POST-as-GET with
// the cert serial number as the URL parameter. Returns the leaf
// followed by the issuing CA as a PEM chain with the spec-mandated
// Content-Type.
//
// Authorization: the cert's row must belong to the profile the
// authenticated account is enrolled under. The cert.AccountID column
// is not populated by SignCSRForACME today (the pfpki Cert model
// doesn't store an ACME account back-link); we authorise via
// profile match instead, which is sufficient because EAB or
// per-profile policy is the access boundary.
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
		var cert models.Cert
		if err := h.DB.Preload("Ca").
			Where("serial_number = ? AND profile_id = ?", serial, jc.Profile.ID).
			First(&cert).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				_ = WriteProblem(w, http.StatusNotFound, ErrMalformed, "no such certificate")
				return
			}
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
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

// revokeCertHandler implements §7.6's revoke. The endpoint accepts
// either an account-key-authenticated JWS (kid path, supported here)
// or a JWS signed by the cert's own keypair (jwk path with thumbprint
// matching the cert's pubkey — deferred to a follow-up slice).
//
// Authorisation today: kid resolves to an account, the cert's
// ProfileID must equal the account's ProfileID. That matches the
// "issued under the same provisioner" rule pfpki SCEP already
// enforces, and is the most conservative ACME-compatible choice
// until per-cert ACME ownership tracking lands.
func revokeCertHandler(h *types.Handler) http.HandlerFunc {
	inner := func(w http.ResponseWriter, r *http.Request) {
		jc := fromCtx(r.Context())
		if jc == nil || jc.Account == nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, "missing account in JWS context")
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
		// Optional: confirm the supplied DER matches a cert we issued
		// under this profile by serial. We could also compare the
		// whole DER blob against pki_certs.cert; serial+CA match is
		// sufficient because the CA only signs serials it issued.
		serial := leaf.SerialNumber.String()
		var row models.Cert
		if err := h.DB.Where("serial_number = ? AND profile_id = ?", serial, jc.Profile.ID).
			First(&row).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				_ = WriteProblem(w, http.StatusNotFound, ErrMalformed,
					"certificate not issued under this profile")
				return
			}
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
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
		if !found {
			// Race: the cert was revoked by another caller between
			// the lookup above and the revoke. Treat as success per
			// §7.6 idempotency.
			w.WriteHeader(http.StatusOK)
			return
		}
		// §7.6: empty body, 200 OK on success.
		w.WriteHeader(http.StatusOK)
	}
	return jwsMiddleware(h, jwsRequireKID, inner)
}
