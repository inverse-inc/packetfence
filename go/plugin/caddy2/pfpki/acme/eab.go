package acme

import (
	"encoding/json"
	"errors"
	"time"

	jose "github.com/go-jose/go-jose/v4"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/gorm"
)

// newAccountPayload is the JSON body of an RFC 8555 §7.3.1 newAccount
// request. We only care about the small subset that the protocol
// requires of the server.
type newAccountPayload struct {
	Contact                []string         `json:"contact,omitempty"`
	TermsOfServiceAgreed   bool             `json:"termsOfServiceAgreed,omitempty"`
	OnlyReturnExisting     bool             `json:"onlyReturnExisting,omitempty"`
	ExternalAccountBinding *json.RawMessage `json:"externalAccountBinding,omitempty"`
}

// eabAllowedAlgs is RFC 8555 §7.3.4's allowed signature algorithms for
// the *inner* JWS — MAC-only, HMAC-SHA{256,384,512}. Asymmetric algs
// here would let an attacker substitute their own key.
var eabAllowedAlgs = []jose.SignatureAlgorithm{
	jose.HS256, jose.HS384, jose.HS512,
}

// validateEAB checks the inner JWS that the new-account request brings
// to prove possession of an admin-issued HMAC key. The contract from
// RFC 8555 §7.3.4 is:
//
//  1. The inner JWS's protected header carries `alg=HS*`, `kid=<KID>`,
//     and `url=<outer request URL>` (same URL the outer JWS signed).
//  2. The inner JWS is signed under the HMAC key whose KID is in (1).
//  3. The inner JWS payload, decoded, equals the outer JWS's JWK
//     serialized as JSON.
//
// On success returns the AcmeExternalAccountKey row whose `KeyID`
// matched; the caller is responsible for binding it to the new account
// (BoundAccountID) inside the same transaction that creates the
// account, so a single EAB can't be replayed.
func validateEAB(h *types.Handler, prof *models.Profile, outerJWK *jose.JSONWebKey, outerURL string, raw *json.RawMessage) (*models.AcmeExternalAccountKey, error) {
	if raw == nil || len(*raw) == 0 {
		return nil, errors.New("externalAccountBinding missing")
	}

	innerJWS, err := jose.ParseSigned(string(*raw), eabAllowedAlgs)
	if err != nil {
		return nil, errors.New("EAB: parse inner JWS: " + err.Error())
	}
	if len(innerJWS.Signatures) != 1 {
		return nil, errors.New("EAB: exactly one signature required")
	}

	// Inner protected header carries the KID + alg + url; pull it raw
	// the same way the outer JWS path does so we see `url`.
	rawProt, err := extractProtected(string(*raw))
	if err != nil {
		return nil, errors.New("EAB: decode protected header: " + err.Error())
	}
	var innerProt rawProtected
	if err := json.Unmarshal(rawProt, &innerProt); err != nil {
		return nil, errors.New("EAB: parse protected header: " + err.Error())
	}
	if innerProt.KID == "" {
		return nil, errors.New("EAB: missing kid")
	}
	if innerProt.URL != outerURL {
		return nil, errors.New("EAB: url mismatch with outer request")
	}
	if innerProt.JWK != nil {
		return nil, errors.New("EAB: inner JWS must use kid, not jwk")
	}

	// Look up the EAB row. We deliberately match on the profile too so
	// a key minted for profile A can't be presented against profile B.
	var eab models.AcmeExternalAccountKey
	if err := h.DB.Where("profile_id = ? AND key_id = ?", prof.ID, innerProt.KID).First(&eab).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("EAB: kid not registered for this profile")
		}
		return nil, err
	}
	if eab.BoundAccountID != 0 {
		return nil, errors.New("EAB: key already bound to an account")
	}

	hmacKey, err := jwsURLEncoding.DecodeString(eab.HMACKey)
	if err != nil {
		return nil, errors.New("EAB: stored HMAC key is not URL-safe base64")
	}

	// Verify the inner signature against the looked-up HMAC key. The
	// returned payload IS the outer JWK serialised as JSON; go-jose
	// already rejected any non-HS* alg above.
	innerPayload, err := innerJWS.Verify(hmacKey)
	if err != nil {
		return nil, errors.New("EAB: HMAC verification failed: " + err.Error())
	}

	// Confirm the inner payload matches the outer JWK byte-for-byte
	// after re-marshalling both into a canonical JSON form.
	outerBytes, err := json.Marshal(outerJWK)
	if err != nil {
		return nil, err
	}
	// We compare by deep-equal of the decoded maps so attribute
	// ordering / whitespace doesn't break a valid EAB.
	if !sameJSON(innerPayload, outerBytes) {
		return nil, errors.New("EAB: inner payload does not match outer JWK")
	}

	return &eab, nil
}

// bindEABToAccount atomically marks the EAB row as consumed by
// accountID. Called inside the new-account transaction so neither a
// successful account creation nor a successful EAB consume can land
// without the other.
func bindEABToAccount(tx *gorm.DB, eabID, accountID uint) error {
	res := tx.Model(&models.AcmeExternalAccountKey{}).
		Where("id = ? AND bound_account_id = 0", eabID).
		Updates(map[string]any{
			"bound_account_id": accountID,
			"bound_at":         time.Now(),
		})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected != 1 {
		return errors.New("EAB: bind raced with another request")
	}
	return nil
}

// sameJSON returns true iff both byte slices decode to identical JSON
// values, ignoring whitespace and field ordering.
func sameJSON(a, b []byte) bool {
	var x, y any
	if err := json.Unmarshal(a, &x); err != nil {
		return false
	}
	if err := json.Unmarshal(b, &y); err != nil {
		return false
	}
	ab, _ := json.Marshal(x)
	bb, _ := json.Marshal(y)
	return string(ab) == string(bb)
}
