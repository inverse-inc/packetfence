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

// authzResponse mirrors RFC 8555 §7.1.4. Challenges are returned
// inline rather than as URLs the client has to fetch separately — the
// spec allows either form, and inline saves a round trip.
type authzResponse struct {
	Identifier identifier          `json:"identifier"`
	Status     string              `json:"status"`
	Expires    string              `json:"expires,omitempty"`
	Wildcard   bool                `json:"wildcard,omitempty"`
	Challenges []challengeResponse `json:"challenges"`
}

// challengeResponse mirrors §7.1.5. The URL is the per-challenge
// endpoint the client POSTs to in order to trigger validation
// (handler lands in the next slice alongside http-01).
type challengeResponse struct {
	Type      string `json:"type"`
	URL       string `json:"url"`
	Status    string `json:"status"`
	Token     string `json:"token"`
	Validated string `json:"validated,omitempty"`
	Error     any    `json:"error,omitempty"`
}

// authzByIDHandler is the POST-as-GET read of an authorization.
// Ownership check: the authz's account must match the JWS account.
func authzByIDHandler(h *types.Handler) http.HandlerFunc {
	inner := func(w http.ResponseWriter, r *http.Request) {
		jc := fromCtx(r.Context())
		if jc == nil || jc.Account == nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, "missing account in JWS context")
			return
		}
		idStr := chi.URLParam(r, "id")
		id, err := strconv.ParseUint(idStr, 10, 64)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "bad authz id")
			return
		}
		var authz models.AcmeAuthz
		if err := h.DB.First(&authz, id).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				_ = WriteProblem(w, http.StatusNotFound, ErrMalformed, "no such authorization")
				return
			}
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}
		if authz.AccountID != jc.Account.ID {
			_ = WriteProblem(w, http.StatusUnauthorized, ErrUnauthorized,
				"authorization belongs to a different account")
			return
		}

		var challenges []models.AcmeChallenge
		if err := h.DB.Where("authz_id = ?", authz.ID).Find(&challenges).Error; err != nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}

		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(buildAuthzResponse(r, jc.Profile.Name, &authz, challenges))
	}
	return jwsMiddleware(h, jwsRequireKID, inner)
}

// buildAuthzResponse converts a stored authz + its challenges into the
// §7.1.4 JSON shape, with absolute challenge URLs.
func buildAuthzResponse(r *http.Request, profileName string, authz *models.AcmeAuthz, challenges []models.AcmeChallenge) authzResponse {
	out := authzResponse{
		Identifier: identifier{Type: authz.IdentifierType, Value: authz.Value},
		Status:     authz.Status,
		Wildcard:   authz.Wildcard,
	}
	if !authz.ExpiresAt.IsZero() {
		out.Expires = authz.ExpiresAt.Format(time.RFC3339)
	}
	for _, ch := range challenges {
		entry := challengeResponse{
			Type:   ch.Type,
			URL:    challengeURL(r, profileName, ch.ID),
			Status: ch.Status,
			Token:  ch.Token,
		}
		if !ch.Validated.IsZero() {
			entry.Validated = ch.Validated.Format(time.RFC3339)
		}
		if ch.Error != "" {
			var prob any
			_ = json.Unmarshal([]byte(ch.Error), &prob)
			entry.Error = prob
		}
		out.Challenges = append(out.Challenges, entry)
	}
	return out
}

func challengeURL(r *http.Request, profileName string, challengeID uint) string {
	return baseURL(r) + acmeMountPath(r) + "/" + profileName + "/chall/" + strconv.FormatUint(uint64(challengeID), 10)
}
