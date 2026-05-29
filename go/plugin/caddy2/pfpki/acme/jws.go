package acme

import (
	"context"
	"crypto"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net/http"

	jose "github.com/go-jose/go-jose/v4"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/gorm"
)

// jwsURLEncoding is RFC 7515's unpadded URL-safe base64 — the alphabet
// every ACME field (nonces, thumbprints, JWS segments) uses. Kept as a
// package-level alias so call sites don't drift between RawURLEncoding
// and URLEncoding by accident.
var jwsURLEncoding = base64.RawURLEncoding

// jwsContext carries everything an ACME handler needs to know about the
// authenticated request: who's making it (Account when known, JWK
// otherwise), what they signed, and the parsed payload bytes. Passed
// via context.Value to the wrapped handler so we don't have to thread
// it through every signature.
type jwsContext struct {
	Profile *models.Profile
	// Exactly one of Account / JWK is non-nil after middleware:
	//   Account is set when the JWS used `kid` (an existing account
	//     posted authenticated to /order, /authz, etc.)
	//   JWK is set when the JWS used `jwk` (new-account, key-rollover
	//     outer JWS, or a revoke-cert signed by the cert's own key).
	Account *models.AcmeAccount
	JWK     *jose.JSONWebKey
	Alg     string
	// Payload is the verified post body of the inner JWS, ready for
	// json.Unmarshal into the handler's expected shape.
	Payload []byte
}

type ctxKey int

const ctxKeyJWS ctxKey = 1

func fromCtx(ctx context.Context) *jwsContext {
	if v, ok := ctx.Value(ctxKeyJWS).(*jwsContext); ok {
		return v
	}
	return nil
}

// acmeAllowedAlgs is RFC 8555 §6.2's permitted signature algorithms.
// HS* are excluded from the outer JWS path (they're only valid for the
// inner EAB JWS, handled in acme/eab.go). go-jose enforces this list
// at parse time by rejecting any signature with a non-listed alg.
var acmeAllowedAlgs = []jose.SignatureAlgorithm{
	jose.ES256, jose.ES384, jose.ES512,
	jose.RS256, jose.RS384, jose.RS512,
	jose.PS256, jose.PS384, jose.PS512,
	jose.EdDSA,
}

// rawProtected is the subset of the JWS protected header ACME cares
// about — we re-decode the protected segment manually because go-jose
// does not surface the raw `url` parameter through its Header struct.
type rawProtected struct {
	Alg   string           `json:"alg"`
	Nonce string           `json:"nonce"`
	URL   string           `json:"url"`
	KID   string           `json:"kid,omitempty"`
	JWK   *jose.JSONWebKey `json:"jwk,omitempty"`
}

// expectedRequestURL reconstructs the canonical URL the client should
// have placed in the protected `url` field. RFC 8555 §6.4 requires this
// to match the request URI exactly (host + path), so a single canon
// implementation lives here.
func expectedRequestURL(r *http.Request) string {
	return baseURL(r) + r.URL.RequestURI()
}

// jwsMiddleware wraps a handler that requires a JWS-authenticated ACME
// request. It performs every check RFC 8555 §6 mandates before
// invoking the handler: content-type, signature, alg, nonce, url, and
// (when `kid` is used) account resolution. On any failure it writes an
// ACME problem document and returns; the handler is never called with
// an unverified context.
//
// mode controls whether the request must carry `jwk` (new-account /
// key rollover / revoke-by-cert-key) or `kid` (every other endpoint).
func jwsMiddleware(h *types.Handler, mode jwsMode, next func(http.ResponseWriter, *http.Request)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		prof, ok := loadProfile(w, r, h)
		if !ok {
			return
		}

		if r.Method != http.MethodPost {
			_ = WriteProblem(w, http.StatusMethodNotAllowed, ErrMalformed, "ACME requires POST")
			return
		}
		if ct := r.Header.Get("Content-Type"); ct != "application/jose+json" {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "Content-Type must be application/jose+json")
			return
		}

		body, err := io.ReadAll(r.Body)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "read body: "+err.Error())
			return
		}

		sig, err := jose.ParseSigned(string(body), acmeAllowedAlgs)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "parse JWS: "+err.Error())
			return
		}
		if len(sig.Signatures) != 1 {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "ACME requires exactly one signature")
			return
		}
		// go-jose surfaces alg/kid/jwk on a typed Header, but drops the
		// ACME-mandated `url` field (and anything else not in its known
		// list). Decode the protected segment ourselves so a single
		// rawProtected drives every header check.
		var protected rawProtected
		rawProt, err := extractProtected(string(body))
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "decode protected header: "+err.Error())
			return
		}
		if err := json.Unmarshal(rawProt, &protected); err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "parse protected header: "+err.Error())
			return
		}

		// `url` check (RFC 8555 §6.4).
		if want := expectedRequestURL(r); protected.URL != want {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed,
				"protected.url mismatch: got "+protected.URL+" want "+want)
			return
		}

		// `nonce` consume (RFC 8555 §6.5). Must succeed exactly once.
		consumed, err := ConsumeNonce(h, protected.Nonce)
		if err != nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}
		if !consumed {
			// Issue a fresh nonce ahead of WriteProblem; once the
			// response header is committed via WriteHeader the
			// Replay-Nonce setter becomes a no-op.
			if tok, perr := IssueNonce(h); perr == nil {
				w.Header().Set("Replay-Nonce", tok)
			}
			_ = WriteProblem(w, http.StatusBadRequest, ErrBadNonce, "nonce was not issued or has been consumed")
			return
		}

		// kid / jwk mutual exclusion + mode enforcement.
		hasKID := protected.KID != ""
		hasJWK := protected.JWK != nil
		if hasKID == hasJWK {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed,
				"protected must carry exactly one of kid or jwk")
			return
		}

		jctx := &jwsContext{Profile: prof, Alg: protected.Alg}

		switch mode {
		case jwsRequireJWK:
			if !hasJWK {
				_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed,
					"this endpoint requires the JWK form")
				return
			}
			jctx.JWK = protected.JWK
			payload, verr := sig.Verify(protected.JWK)
			if verr != nil {
				_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed,
					"signature verify: "+verr.Error())
				return
			}
			jctx.Payload = payload

		case jwsRequireKID:
			if !hasKID {
				_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed,
					"this endpoint requires the kid form")
				return
			}
			acct, jwk, lookupErr := lookupAccountByKID(h, prof.ID, protected.KID)
			if errors.Is(lookupErr, gorm.ErrRecordNotFound) {
				_ = WriteProblem(w, http.StatusUnauthorized, ErrAccountDoesNotExist,
					"kid does not resolve to an account on this profile")
				return
			}
			if lookupErr != nil {
				_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, lookupErr.Error())
				return
			}
			payload, verr := sig.Verify(jwk)
			if verr != nil {
				_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed,
					"signature verify: "+verr.Error())
				return
			}
			jctx.Account = acct
			jctx.JWK = jwk
			jctx.Payload = payload
		}

		// Always rotate the Replay-Nonce on the response so the client
		// can post the next request without a /new-nonce round trip.
		if tok, perr := IssueNonce(h); perr == nil {
			w.Header().Set("Replay-Nonce", tok)
		}

		ctx := context.WithValue(r.Context(), ctxKeyJWS, jctx)
		next(w, r.WithContext(ctx))
	}
}

type jwsMode int

const (
	jwsRequireJWK jwsMode = iota + 1
	jwsRequireKID
)

// lookupAccountByKID resolves an ACME `kid` URL (e.g.
// https://pfpki/.../account/42) to the matching AcmeAccount row + a
// usable JSONWebKey for signature verification.
func lookupAccountByKID(h *types.Handler, profileID uint, kid string) (*models.AcmeAccount, *jose.JSONWebKey, error) {
	var acct models.AcmeAccount
	if err := h.DB.Where("profile_id = ? AND key_id = ?", profileID, kid).First(&acct).Error; err != nil {
		return nil, nil, err
	}
	var jwk jose.JSONWebKey
	if err := json.Unmarshal([]byte(acct.JWK), &jwk); err != nil {
		return nil, nil, err
	}
	return &acct, &jwk, nil
}

// extractProtected returns the raw decoded JSON of a flattened JWS's
// protected header. go-jose parses the header into a typed struct but
// drops unrecognised fields (notably the ACME-mandated `url`); we
// re-parse the segment ourselves to get a complete view.
func extractProtected(jws string) ([]byte, error) {
	// Flattened form is JSON-shaped already.
	if len(jws) > 0 && jws[0] == '{' {
		var outer struct {
			Protected string `json:"protected"`
		}
		if err := json.Unmarshal([]byte(jws), &outer); err != nil {
			return nil, err
		}
		return base64URLDecode(outer.Protected)
	}
	// Compact form: header.payload.signature
	idx := indexByte(jws, '.')
	if idx < 0 {
		return nil, errors.New("not a JWS")
	}
	return base64URLDecode(jws[:idx])
}

func indexByte(s string, b byte) int {
	for i := 0; i < len(s); i++ {
		if s[i] == b {
			return i
		}
	}
	return -1
}

// base64URLDecode handles the URL-safe alphabet with optional padding
// — RFC 8555 JWSes use unpadded RFC 7515 base64url.
func base64URLDecode(s string) ([]byte, error) {
	// stdlib helpers would need a separate import for the encoding pkg;
	// keep a tiny copy here to avoid bloating the surface.
	return jwsURLEncoding.DecodeString(s)
}

// jwsThumbprint returns the RFC 7638 SHA-256 thumbprint of a JWK as a
// URL-safe base64 string. Used as the secondary index on AcmeAccount
// so /new-account can find an existing row in O(1).
func jwsThumbprint(jwk *jose.JSONWebKey) (string, error) {
	tp, err := jwk.Thumbprint(crypto.SHA256)
	if err != nil {
		return "", err
	}
	return jwsURLEncoding.EncodeToString(tp), nil
}
