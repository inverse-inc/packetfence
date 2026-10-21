package acme

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	jose "github.com/go-jose/go-jose/v4"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/gorm"
)

// keyChangePayload is the §7.3.5 keyChange object carried by the inner
// JWS: the account URL and the key being replaced.
type keyChangePayload struct {
	Account string          `json:"account"`
	OldKey  json.RawMessage `json:"oldKey"`
}

// keyChangeHandler implements RFC 8555 §7.3.5 account key rollover.
// The outer JWS is kid-signed by the current account key (checked by
// the middleware); its payload is an inner JWS signed by the new key,
// which carries that key as `jwk`, the same `url` and no nonce. The
// inner payload must name this account and its current key. A new key
// already registered on the profile is refused with 409 and the
// Location of the account holding it.
func keyChangeHandler(h *types.Handler) http.HandlerFunc {
	inner := func(w http.ResponseWriter, r *http.Request) {
		jc := fromCtx(r.Context())
		if jc == nil || jc.Account == nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, "missing account in JWS context")
			return
		}

		sig, err := jose.ParseSigned(string(jc.Payload), acmeAllowedAlgs)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "parse inner JWS: "+err.Error())
			return
		}
		if len(sig.Signatures) != 1 {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "inner JWS requires exactly one signature")
			return
		}
		rawProt, err := extractProtected(string(jc.Payload))
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "decode inner protected header: "+err.Error())
			return
		}
		var protected rawProtected
		if err := json.Unmarshal(rawProt, &protected); err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "parse inner protected header: "+err.Error())
			return
		}
		if protected.JWK == nil || protected.KID != "" {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "inner JWS must carry jwk and no kid")
			return
		}
		if protected.Nonce != "" {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "inner JWS must not carry a nonce")
			return
		}
		if protected.URL != expectedRequestURL(r) {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "inner JWS url does not match the outer url")
			return
		}
		newKey := protected.JWK
		if !newKey.Valid() || !newKey.IsPublic() {
			_ = WriteProblem(w, http.StatusBadRequest, ErrBadPublicKey, "new key is not a valid public key")
			return
		}
		body, err := sig.Verify(newKey)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "inner signature verify: "+err.Error())
			return
		}

		var payload keyChangePayload
		if err := json.Unmarshal(body, &payload); err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "decode keyChange: "+err.Error())
			return
		}
		if payload.Account != jc.Account.KeyID {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "keyChange account does not match kid")
			return
		}
		var oldKey jose.JSONWebKey
		if err := json.Unmarshal(payload.OldKey, &oldKey); err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "decode oldKey: "+err.Error())
			return
		}
		oldThumb, err := jwsThumbprint(&oldKey)
		if err != nil || oldThumb != jc.Account.KeyThumbprint {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "oldKey is not the current account key")
			return
		}
		newThumb, err := jwsThumbprint(newKey)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrBadPublicKey, err.Error())
			return
		}
		if newThumb == oldThumb {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "new key is the current account key")
			return
		}
		if writeKeyConflict(w, h.DB, jc.Profile.ID, newThumb) {
			return
		}

		jwkJSON, err := json.Marshal(newKey)
		if err != nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}
		// Guarded on the old thumbprint so two concurrent rollovers
		// can't both succeed; the unique key on (profile_id,
		// key_thumbprint) catches a racing registration of the new key.
		res := h.DB.Model(&models.AcmeAccount{}).
			Where("id = ? AND key_thumbprint = ?", jc.Account.ID, oldThumb).
			Updates(map[string]any{"jwk": string(jwkJSON), "key_thumbprint": newThumb})
		if res.Error != nil {
			if writeKeyConflict(w, h.DB, jc.Profile.ID, newThumb) {
				return
			}
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, res.Error.Error())
			return
		}
		if res.RowsAffected != 1 {
			_ = WriteProblem(w, http.StatusUnauthorized, ErrUnauthorized, "account key changed concurrently")
			return
		}

		auditACMEEvent(r.Context(), h.DB, jc.Profile.Name, jc.Account.KeyID, "acme.account.key-change",
			strconv.FormatUint(uint64(jc.Account.ID), 10), r.Method, requestURLForAudit(r),
			http.StatusOK, map[string]any{"old_key": oldThumb, "new_key": newThumb})

		acct := *jc.Account
		acct.JWK = string(jwkJSON)
		acct.KeyThumbprint = newThumb
		writeAccount(w, r, &acct, http.StatusOK)
	}
	return jwsMiddleware(h, jwsRequireKID, inner)
}

// writeKeyConflict writes the §7.3.5 409 response when another account
// on the profile already uses the key with thumbprint thumb, and
// reports whether it did.
func writeKeyConflict(w http.ResponseWriter, db *gorm.DB, profileID uint, thumb string) bool {
	var other models.AcmeAccount
	err := db.Where("profile_id = ? AND key_thumbprint = ?", profileID, thumb).First(&other).Error
	if err != nil {
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return true
		}
		return false
	}
	w.Header().Set("Location", other.KeyID)
	_ = WriteProblem(w, http.StatusConflict, ErrMalformed, "new key is already in use by another account")
	return true
}
