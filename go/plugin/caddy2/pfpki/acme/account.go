package acme

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	chi "github.com/go-chi/chi/v5"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/gorm"
)

// accountResponse is the JSON shape RFC 8555 §7.1.2 specifies for
// account objects returned by /new-account and /account/{id}.
type accountResponse struct {
	Status                 string   `json:"status"`
	Contact                []string `json:"contact,omitempty"`
	TermsOfServiceAgreed   bool     `json:"termsOfServiceAgreed,omitempty"`
	ExternalAccountBinding any      `json:"externalAccountBinding,omitempty"`
	Orders                 string   `json:"orders,omitempty"`
}

// newAccountHandler implements RFC 8555 §7.3. The middleware has
// already done the heavy lifting: JWS verified, nonce consumed,
// fresh Replay-Nonce headed, the embedded JWK + payload bytes in ctx.
//
// onlyReturnExisting paths short-circuit before any insert; happy path
// computes the thumbprint, returns 200 on hit, creates + returns 201 on
// miss.
func newAccountHandler(h *types.Handler) http.HandlerFunc {
	inner := func(w http.ResponseWriter, r *http.Request) {
		jc := fromCtx(r.Context())
		if jc == nil || jc.JWK == nil {
			// Defensive — middleware shouldn't dispatch here without a JWK.
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, "missing JWS context")
			return
		}

		var payload newAccountPayload
		if err := json.Unmarshal(jc.Payload, &payload); err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "decode payload: "+err.Error())
			return
		}

		thumb, err := jwsThumbprint(jc.JWK)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrBadPublicKey, err.Error())
			return
		}

		// Existing-account lookup happens regardless of
		// onlyReturnExisting; it's the same query, just a different
		// downstream branch.
		var existing models.AcmeAccount
		err = h.DB.Where("profile_id = ? AND key_thumbprint = ?", jc.Profile.ID, thumb).
			First(&existing).Error
		switch {
		case err == nil:
			// Already registered → 200 + Location. A deactivated account
			// is final (§7.3.6). An expired one is renewed: the key
			// holder is re-registering, and the key can't open a second
			// account on this profile.
			if existing.Status != "valid" {
				_ = WriteProblem(w, http.StatusUnauthorized, ErrUnauthorized, "account is "+existing.Status)
				return
			}
			if accountExpired(&existing, time.Now()) {
				existing.ExpiresAt = accountExpiry(jc.Profile)
				if err := h.DB.Model(&models.AcmeAccount{}).Where("id = ?", existing.ID).
					Update("expires_at", existing.ExpiresAt).Error; err != nil {
					_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
					return
				}
			}
			writeAccount(w, r, &existing, http.StatusOK)
			return
		case !errors.Is(err, gorm.ErrRecordNotFound):
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}

		if payload.OnlyReturnExisting {
			_ = WriteProblem(w, http.StatusBadRequest, ErrAccountDoesNotExist,
				"onlyReturnExisting set and no account matches the supplied key")
			return
		}

		// EAB gate. When profile demands it, the payload MUST carry a
		// valid externalAccountBinding inner JWS; missing or invalid
		// → 401 externalAccountRequired.
		var eab *models.AcmeExternalAccountKey
		if jc.Profile.AcmeEabRequired == 1 {
			outerURL := expectedRequestURL(r)
			eab, err = validateEAB(h, jc.Profile, jc.JWK, outerURL, payload.ExternalAccountBinding)
			if err != nil {
				_ = WriteProblem(w, http.StatusUnauthorized, ErrExternalAccountRequired, err.Error())
				return
			}
		}

		// Marshal contact + JWK for storage. We persist the JWK as
		// JSON so the JWS middleware can re-decode it verbatim on
		// every subsequent /account-authenticated request.
		jwkJSON, err := json.Marshal(jc.JWK)
		if err != nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}
		contactJSON, _ := json.Marshal(payload.Contact)

		newRow := models.AcmeAccount{
			ProfileID:     jc.Profile.ID,
			KeyThumbprint: thumb,
			JWK:           string(jwkJSON),
			Status:        "valid",
			Contact:       string(contactJSON),
			ExpiresAt:     accountExpiry(jc.Profile),
		}

		// Create the account + (when EAB is in play) bind the EAB key
		// inside one transaction so neither half can land alone.
		err = h.DB.Transaction(func(tx *gorm.DB) error {
			if err := tx.Create(&newRow).Error; err != nil {
				return err
			}
			// Now we know the row's ID; compute the canonical Location
			// URL (`kid`) and persist it so future kid-authenticated
			// requests can find this row.
			kid := accountURL(r, jc.Profile.Name, newRow.ID)
			if err := tx.Model(&models.AcmeAccount{}).
				Where("id = ?", newRow.ID).
				Update("key_id", kid).Error; err != nil {
				return err
			}
			newRow.KeyID = kid

			if eab != nil {
				if err := bindEABToAccount(tx, eab.ID, newRow.ID); err != nil {
					return err
				}
				newRow.ExternalAccountKeyID = eab.KeyID
				if err := tx.Model(&models.AcmeAccount{}).
					Where("id = ?", newRow.ID).
					Update("external_account_key_id", eab.KeyID).Error; err != nil {
					return err
				}
			}
			return nil
		})
		if err != nil {
			// A concurrent new-account for the same key won the race and
			// tripped the (profile_id, key_thumbprint) unique key: answer
			// as for any existing account (§7.3.1).
			var winner models.AcmeAccount
			if h.DB.Where("profile_id = ? AND key_thumbprint = ?", jc.Profile.ID, thumb).
				First(&winner).Error == nil {
				writeAccount(w, r, &winner, http.StatusOK)
				return
			}
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}

		auditACMEEvent(r.Context(), h.DB, jc.Profile.Name, thumb, "acme.account.create",
			strconv.FormatUint(uint64(newRow.ID), 10), r.Method, requestURLForAudit(r),
			http.StatusCreated, map[string]any{
				"contact": payload.Contact,
				"eab_key": newRow.ExternalAccountKeyID,
				"key_id":  newRow.KeyID,
			})

		writeAccount(w, r, &newRow, http.StatusCreated)
	}
	return jwsMiddleware(h, jwsRequireJWK, inner)
}

// accountUpdatePayload is the §7.3.2 / §7.3.6 account update body.
// Contact is a pointer so an absent field leaves the stored contacts
// alone while an explicit empty list clears them.
type accountUpdatePayload struct {
	Status               string    `json:"status,omitempty"`
	Contact              *[]string `json:"contact,omitempty"`
	TermsOfServiceAgreed bool      `json:"termsOfServiceAgreed,omitempty"`
}

// accountByIDHandler serves /account/{id} (the kid URL handed back in
// Location): a POST-as-GET returns the account, a JSON payload updates
// its contacts (§7.3.2) or deactivates it (§7.3.6). A deactivated
// account is final; the JWS middleware refuses its kid from then on.
func accountByIDHandler(h *types.Handler) http.HandlerFunc {
	inner := func(w http.ResponseWriter, r *http.Request) {
		jc, ok := ownAccount(w, r)
		if !ok {
			return
		}
		if isPostAsGet(jc.Payload) {
			writeAccount(w, r, jc.Account, http.StatusOK)
			return
		}
		var payload accountUpdatePayload
		if err := json.Unmarshal(jc.Payload, &payload); err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "decode payload: "+err.Error())
			return
		}
		if payload.Status != "" && payload.Status != "deactivated" {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed,
				"status may only be set to deactivated")
			return
		}

		acct := *jc.Account
		updates := map[string]any{}
		if payload.Contact != nil {
			contactJSON, _ := json.Marshal(*payload.Contact)
			acct.Contact = string(contactJSON)
			updates["contact"] = acct.Contact
		}
		action := "acme.account.update"
		if payload.Status == "deactivated" {
			acct.Status = "deactivated"
			updates["status"] = acct.Status
			action = "acme.account.deactivate"
		}
		if len(updates) > 0 {
			err := h.DB.Transaction(func(tx *gorm.DB) error {
				if err := tx.Model(&models.AcmeAccount{}).Where("id = ?", acct.ID).
					Updates(updates).Error; err != nil {
					return err
				}
				if acct.Status != "deactivated" {
					return nil
				}
				// §7.3.6: cancel what the account still had in flight.
				return tx.Model(&models.AcmeOrder{}).
					Where("account_id = ? AND status IN ?", acct.ID, []string{"pending", "ready"}).
					Update("status", "invalid").Error
			})
			if err != nil {
				_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
				return
			}
			auditACMEEvent(r.Context(), h.DB, jc.Profile.Name, acct.KeyID, action,
				strconv.FormatUint(uint64(acct.ID), 10), r.Method, requestURLForAudit(r),
				http.StatusOK, map[string]any{"status": acct.Status, "contact": payload.Contact})
		}
		writeAccount(w, r, &acct, http.StatusOK)
	}
	return jwsMiddleware(h, jwsRequireKID, inner)
}

// accountOrdersHandler serves the §7.1.2.1 orders list advertised in
// the account object: the URLs of the account's orders, and only
// those.
func accountOrdersHandler(h *types.Handler) http.HandlerFunc {
	inner := func(w http.ResponseWriter, r *http.Request) {
		jc, ok := ownAccount(w, r)
		if !ok {
			return
		}
		var ids []uint
		if err := h.DB.Model(&models.AcmeOrder{}).Where("account_id = ?", jc.Account.ID).
			Order("id").Pluck("id", &ids).Error; err != nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}
		urls := make([]string, 0, len(ids))
		for _, id := range ids {
			urls = append(urls, orderURL(r, jc.Profile.Name, id))
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string][]string{"orders": urls})
	}
	return jwsMiddleware(h, jwsRequireKID, inner)
}

// ownAccount returns the JWS context once the {id} URL parameter is
// checked against the kid-authenticated account: each account may only
// act on itself. On failure the problem has been written.
func ownAccount(w http.ResponseWriter, r *http.Request) (*jwsContext, bool) {
	jc := fromCtx(r.Context())
	if jc == nil || jc.Account == nil {
		_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, "missing account in JWS context")
		return nil, false
	}
	acctID, err := strconv.ParseUint(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "bad account id")
		return nil, false
	}
	if uint(acctID) != jc.Account.ID {
		_ = WriteProblem(w, http.StatusUnauthorized, ErrUnauthorized, "kid does not match URL")
		return nil, false
	}
	return jc, true
}

// isPostAsGet reports whether a verified JWS payload is the §6.3
// POST-as-GET empty payload. The JSON empty string is accepted too,
// as some clients send that instead of a zero-length payload.
func isPostAsGet(payload []byte) bool {
	return len(payload) == 0 || string(payload) == `""`
}

// accountExpiry is the expiry a new or renewed account gets. A profile
// expiry of zero or less means accounts don't expire.
func accountExpiry(prof *models.Profile) time.Time {
	if prof.AcmeAccountExpiry <= 0 {
		return time.Time{}
	}
	return time.Now().AddDate(0, 0, prof.AcmeAccountExpiry)
}

// accountExpired reports whether acct is past its expiry; a zero
// ExpiresAt never expires.
func accountExpired(acct *models.AcmeAccount, now time.Time) bool {
	return !acct.ExpiresAt.IsZero() && !acct.ExpiresAt.After(now)
}

// writeAccount emits the AcmeAccount as a §7.1.2 response. Used for
// both /new-account replies (existing-200 / new-201) and /account/{id}.
func writeAccount(w http.ResponseWriter, r *http.Request, acct *models.AcmeAccount, status int) {
	var contact []string
	if acct.Contact != "" {
		_ = json.Unmarshal([]byte(acct.Contact), &contact)
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Location", acct.KeyID)
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(accountResponse{
		Status:  acct.Status,
		Contact: contact,
		Orders:  acct.KeyID + "/orders",
	})
}

// accountURL is the canonical Location header value (== kid) for an
// account, built off the same baseURL helper directory.go uses so all
// emitted URLs stay consistent under reverse-proxy headers.
func accountURL(r *http.Request, profileName string, accountID uint) string {
	return baseURL(r) + acmeMountPath(r) + "/" + profileName + "/account/" + strconv.FormatUint(uint64(accountID), 10)
}
