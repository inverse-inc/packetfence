package acme

import (
	"crypto/rand"
	"encoding/base64"
	"net/http"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

// nonceTTL is how long a freshly minted nonce stays valid before the
// cleanup cron drops it. RFC 8555 doesn't pin a number; clients are
// expected to consume nonces immediately after receiving them, so a
// short window is fine and limits the size of the table under load.
const nonceTTL = 30 * time.Minute

// nonceByteLen sets the length of the URL-safe-base64 token. 256 bits
// of randomness is way more than RFC 8555's "unguessable" bar.
const nonceByteLen = 32

// IssueNonce mints a fresh nonce, persists it, and returns the wire
// token. Used by both the dedicated /new-nonce handler and any other
// handler that wants to set a Replay-Nonce header (RFC 8555 §6.5
// requires every successful response to include one).
func IssueNonce(h *types.Handler) (string, error) {
	buf := make([]byte, nonceByteLen)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	token := base64.RawURLEncoding.EncodeToString(buf)
	row := models.AcmeNonce{Token: token, ExpiresAt: time.Now().Add(nonceTTL)}
	if err := h.DB.Create(&row).Error; err != nil {
		return "", err
	}
	return token, nil
}

// ConsumeNonce is the single-use guard: deletes the row matching token
// inside one transaction and returns ok=true iff exactly one row was
// affected. Used by JWS middleware once it lands; lives here so the
// implementation stays next to IssueNonce.
func ConsumeNonce(h *types.Handler, token string) (bool, error) {
	if token == "" {
		return false, nil
	}
	res := h.DB.Where("token = ? AND expires_at > ?", token, time.Now()).
		Delete(&models.AcmeNonce{})
	if res.Error != nil {
		return false, res.Error
	}
	return res.RowsAffected == 1, nil
}

// newNonceHandler serves both HEAD (the spec'd verb, used by every
// real ACME client) and GET (convenience for ad-hoc tools). Either way
// the nonce travels in the Replay-Nonce header; the body is empty.
func newNonceHandler(h *types.Handler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, ok := loadProfile(w, r, h); !ok {
			return
		}
		token, err := IssueNonce(h)
		if err != nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}
		w.Header().Set("Replay-Nonce", token)
		// Per RFC 8555 §7.2 a Cache-Control: no-store is mandatory for
		// /new-nonce so middleboxes don't replay a single nonce to many
		// devices.
		w.Header().Set("Cache-Control", "no-store")
		// HEAD must return 200; GET returns 204 per the spec example.
		if r.Method == http.MethodHead {
			w.WriteHeader(http.StatusOK)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}
}
