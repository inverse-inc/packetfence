package acme

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	chi "github.com/go-chi/chi/v5"
	jose "github.com/go-jose/go-jose/v4"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/gorm"
)

// challengeByIDHandler is the §7.5.1 "respond to challenge" endpoint.
// Two distinct uses share the same URL by RFC 8555 design:
//
//   - Empty payload: POST-as-GET, just returns current challenge state.
//   - Non-empty payload: client is telling us "I've placed the
//     response, validate it now". We synchronously perform the type-
//     specific check (http-01 today; device-attest-01 in Phase 2) and
//     transition the state machine.
//
// State transitions on success:
//
//	challenge: pending → valid (with Validated timestamp)
//	authz:     pending → valid (when any challenge of the authz becomes valid)
//	order:     pending → ready  (when all authzs on the order are valid)
//
// On validator failure we move challenge → invalid + record the
// problem doc; the authz/order stay pending so the client can retry
// with a fresh nonce.
func challengeByIDHandler(h *types.Handler) http.HandlerFunc {
	inner := func(w http.ResponseWriter, r *http.Request) {
		jc := fromCtx(r.Context())
		if jc == nil || jc.Account == nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, "missing account in JWS context")
			return
		}
		idStr := chi.URLParam(r, "id")
		id, err := strconv.ParseUint(idStr, 10, 64)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "bad challenge id")
			return
		}

		var challenge models.AcmeChallenge
		if err := h.DB.First(&challenge, id).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				_ = WriteProblem(w, http.StatusNotFound, ErrMalformed, "no such challenge")
				return
			}
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}
		// Ownership: walk challenge → authz → account, verify equal to
		// the JWS account.
		var authz models.AcmeAuthz
		if err := h.DB.First(&authz, challenge.AuthzID).Error; err != nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}
		if authz.AccountID != jc.Account.ID {
			_ = WriteProblem(w, http.StatusUnauthorized, ErrUnauthorized,
				"challenge belongs to a different account")
			return
		}

		// RFC 8555 §6.3: POST-as-GET uses an empty-string payload
		// (the literal two bytes `""`). §7.5.1: a `{}` payload is the
		// client telling us "I've placed the response, validate me
		// now". Treat anything that decoded into a JSON object as a
		// trigger; the empty-string sentinel means "just poll".
		trigger := string(jc.Payload) != `""` && string(jc.Payload) != ""

		if trigger && challenge.Status == "pending" {
			if err := validateChallenge(r, h, jc, &challenge, &authz); err != nil {
				// validator already wrote the failure state; nothing
				// more to do — fall through to response.
				_ = err
			}
			// Reload so the response reflects the post-validation state.
			_ = h.DB.First(&challenge, challenge.ID).Error
			_ = h.DB.First(&authz, authz.ID).Error
		}

		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Link", `<`+authzURL(r, jc.Profile.Name, authz.ID)+`>;rel="up"`)
		_ = json.NewEncoder(w).Encode(challengeResponse{
			Type:   challenge.Type,
			URL:    challengeURL(r, jc.Profile.Name, challenge.ID),
			Status: challenge.Status,
			Token:  challenge.Token,
			Validated: func() string {
				if challenge.Validated.IsZero() {
					return ""
				}
				return challenge.Validated.Format(time.RFC3339)
			}(),
		})
	}
	return jwsMiddleware(h, jwsRequireKID, inner)
}

// validateChallenge dispatches on challenge.Type, runs the
// type-specific check, and commits the post-validation state changes
// in a transaction. Errors are recorded on the challenge.Error column
// as a stringified ACME problem doc so /authz/{id} reads can surface
// them; the function still returns a Go error for the caller's log.
func validateChallenge(r *http.Request, h *types.Handler, jc *jwsContext, ch *models.AcmeChallenge, authz *models.AcmeAuthz) error {
	var thumbprint string
	if jc.JWK != nil {
		t, err := jwsThumbprint(jc.JWK)
		if err != nil {
			return err
		}
		thumbprint = t
	} else {
		// jc.Account.JWK is the canonical stored JWK; re-parse it
		// because kid-mode requests don't surface the JWK pointer.
		var jwk jose.JSONWebKey
		if err := json.Unmarshal([]byte(jc.Account.JWK), &jwk); err != nil {
			return err
		}
		t, err := jwsThumbprint(&jwk)
		if err != nil {
			return err
		}
		thumbprint = t
	}

	var validateErr error
	switch ch.Type {
	case "http-01":
		validateErr = http01Validate(r.Context(), authz.Value, ch.Token, thumbprint)
	default:
		validateErr = errors.New("unsupported challenge type: " + ch.Type)
	}

	return h.DB.Transaction(func(tx *gorm.DB) error {
		now := time.Now()
		if validateErr != nil {
			problem := Problem{
				Type:   ErrUnauthorized,
				Detail: validateErr.Error(),
				Status: http.StatusUnauthorized,
			}
			pb, _ := json.Marshal(problem)
			return tx.Model(&models.AcmeChallenge{}).Where("id = ?", ch.ID).
				Updates(map[string]any{
					"status": "invalid",
					"error":  string(pb),
				}).Error
		}
		// Challenge succeeded → mark it valid + bump the authz to
		// valid. The order's status update happens in a second pass
		// because it depends on all authzs reaching valid.
		if err := tx.Model(&models.AcmeChallenge{}).Where("id = ?", ch.ID).
			Updates(map[string]any{"status": "valid", "validated": now}).Error; err != nil {
			return err
		}
		if err := tx.Model(&models.AcmeAuthz{}).Where("id = ?", authz.ID).
			Update("status", "valid").Error; err != nil {
			return err
		}
		return maybePromoteOrder(tx, authz.OrderID)
	})
}

// maybePromoteOrder flips an order from pending to ready iff every one
// of its referenced authzs has reached the `valid` state. Called from
// each challenge-success path; idempotent so concurrent validations of
// the same order land in a consistent state.
func maybePromoteOrder(tx *gorm.DB, orderID uint) error {
	var order models.AcmeOrder
	if err := tx.First(&order, orderID).Error; err != nil {
		return err
	}
	if order.Status != "pending" {
		// Either already ready/processing/valid, or invalid — leave alone.
		return nil
	}
	ids := parseAuthzIDs(order.AuthzIDs)
	if len(ids) == 0 {
		return nil
	}
	var validCount int64
	if err := tx.Model(&models.AcmeAuthz{}).
		Where("id IN ? AND status = ?", ids, "valid").
		Count(&validCount).Error; err != nil {
		return err
	}
	if int(validCount) != len(ids) {
		// Some authz is still pending or has gone invalid; don't
		// flip the order yet.
		return nil
	}
	return tx.Model(&models.AcmeOrder{}).Where("id = ?", orderID).
		Update("status", "ready").Error
}
