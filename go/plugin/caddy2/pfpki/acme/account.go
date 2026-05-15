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
			// Already registered → 200 + Location.
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
			ExpiresAt:     time.Now().AddDate(0, 0, jc.Profile.AcmeAccountExpiry),
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

// accountByIDHandler serves GET /account/{id} (the kid URL handed back
// in Location) and POST /account/{id} for status / contact updates.
// For now only the GET path is implemented — updates land with the
// account-mutation work item later in Phase 1.
func accountByIDHandler(h *types.Handler) http.HandlerFunc {
	inner := func(w http.ResponseWriter, r *http.Request) {
		jc := fromCtx(r.Context())
		if jc == nil || jc.Account == nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, "missing account in JWS context")
			return
		}
		id := chi.URLParam(r, "id")
		acctID, err := strconv.ParseUint(id, 10, 64)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "bad account id")
			return
		}
		if uint(acctID) != jc.Account.ID {
			// Each account may only act on itself.
			_ = WriteProblem(w, http.StatusUnauthorized, ErrUnauthorized, "kid does not match URL")
			return
		}
		writeAccount(w, r, jc.Account, http.StatusOK)
	}
	return jwsMiddleware(h, jwsRequireKID, inner)
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
