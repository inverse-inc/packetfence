package acme

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	chi "github.com/go-chi/chi/v5"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/gorm"
)

// identifier mirrors RFC 8555 §9.7.7's identifier object — a typed
// (type,value) pair such as {"type":"dns","value":"a.example"}.
type identifier struct {
	Type  string `json:"type"`
	Value string `json:"value"`
}

// newOrderPayload is the §7.4 request body.
type newOrderPayload struct {
	Identifiers []identifier `json:"identifiers"`
	NotBefore   string       `json:"notBefore,omitempty"`
	NotAfter    string       `json:"notAfter,omitempty"`
}

// orderResponse mirrors §7.1.3. Authorizations and Finalize are
// absolute URLs computed per-request so they survive reverse-proxy
// rewrites (same baseURL helper directory.go uses).
type orderResponse struct {
	Status         string       `json:"status"`
	Expires        string       `json:"expires,omitempty"`
	Identifiers    []identifier `json:"identifiers"`
	NotBefore      string       `json:"notBefore,omitempty"`
	NotAfter       string       `json:"notAfter,omitempty"`
	Authorizations []string     `json:"authorizations"`
	Finalize       string       `json:"finalize"`
	Certificate    string       `json:"certificate,omitempty"`
	Error          any          `json:"error,omitempty"`
}

// newOrderHandler implements RFC 8555 §7.4. kid-authenticated (the
// account exists; the JWS middleware has resolved jc.Account). Creates
// the order, per-identifier authzs, and per-authz http-01 challenge
// rows inside one transaction so a half-built order can never escape.
func newOrderHandler(h *types.Handler) http.HandlerFunc {
	inner := func(w http.ResponseWriter, r *http.Request) {
		jc := fromCtx(r.Context())
		if jc == nil || jc.Account == nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, "missing account in JWS context")
			return
		}

		var payload newOrderPayload
		if err := json.Unmarshal(jc.Payload, &payload); err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "decode payload: "+err.Error())
			return
		}
		if len(payload.Identifiers) == 0 {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "identifiers must be non-empty")
			return
		}

		// Identifier-type gate: a profile that omits AcmeAllowedIdentifiers
		// rejects every type. The default profile-create form should
		// pre-seed "dns,ip" so this isn't a footgun in production.
		allowed := splitCSV(jc.Profile.AcmeAllowedIdentifiers)
		for _, ident := range payload.Identifiers {
			if !contains(allowed, ident.Type) {
				_ = WriteProblem(w, http.StatusBadRequest, ErrRejectedIdentifier,
					"identifier type "+strconv.Quote(ident.Type)+" not allowed on this profile")
				return
			}
			// Empty values are always invalid regardless of type.
			if strings.TrimSpace(ident.Value) == "" {
				_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "identifier value is empty")
				return
			}
		}

		identifiersJSON, _ := json.Marshal(payload.Identifiers)

		// Expiry windows are profile-driven; per the spec the order's
		// `expires` is purely a hint to the client about when the
		// server may garbage-collect it.
		orderExpiry := time.Now().AddDate(0, 0, jc.Profile.AcmeOrderExpiry)
		authzExpiry := time.Now().Add(time.Duration(jc.Profile.AcmeAuthzExpiry) * time.Hour)

		notBefore, notAfter := parseValidityHints(payload.NotBefore, payload.NotAfter)

		order := models.AcmeOrder{
			AccountID:   jc.Account.ID,
			Status:      "pending",
			ExpiresAt:   orderExpiry,
			Identifiers: string(identifiersJSON),
			NotBefore:   notBefore,
			NotAfter:    notAfter,
		}

		var authzIDs []uint
		err := h.DB.Transaction(func(tx *gorm.DB) error {
			if err := tx.Create(&order).Error; err != nil {
				return err
			}
			for _, ident := range payload.Identifiers {
				authz := models.AcmeAuthz{
					AccountID:      jc.Account.ID,
					OrderID:        order.ID,
					IdentifierType: ident.Type,
					Value:          ident.Value,
					Status:         "pending",
					ExpiresAt:      authzExpiry,
				}
				if err := tx.Create(&authz).Error; err != nil {
					return err
				}
				authzIDs = append(authzIDs, authz.ID)

				// Seed one challenge per authz. The type depends on what
				// the identifier is + what the profile allows:
				//   - permanent-identifier + profile lists "apple" in
				//     AcmeAttestationFormats  -> device-attest-01
				//   - dns/ip                                    -> http-01
				// dns-01 lands as a follow-up when an operator needs
				// it; today the http-01 path is sufficient for all
				// non-Apple flows.
				chType := pickChallengeType(ident.Type, jc.Profile.AcmeAttestationFormats)
				challenge := models.AcmeChallenge{
					AuthzID: authz.ID,
					Type:    chType,
					Token:   randomToken(),
					Status:  "pending",
				}
				if err := tx.Create(&challenge).Error; err != nil {
					return err
				}
			}
			// AuthzIDs is a CSV of the row PKs we just inserted; lets
			// /order/{id} reconstruct its authorizations[] without an
			// extra JOIN.
			ids := make([]string, len(authzIDs))
			for i, id := range authzIDs {
				ids[i] = strconv.FormatUint(uint64(id), 10)
			}
			return tx.Model(&models.AcmeOrder{}).
				Where("id = ?", order.ID).
				Update("authz_ids", strings.Join(ids, ",")).Error
		})
		if err != nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}

		loc := orderURL(r, jc.Profile.Name, order.ID)
		w.Header().Set("Location", loc)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(buildOrderResponse(r, jc.Profile.Name, &order, authzIDs))
	}
	return jwsMiddleware(h, jwsRequireKID, inner)
}

// finalizePayload is the §7.4 request body the client sends to
// /order/{id}/finalize: a base64url-encoded CSR DER.
type finalizePayload struct {
	CSR string `json:"csr"`
}

// orderFinalizeHandler implements §7.4 finalize. Preconditions:
//   - Order must exist and belong to the JWS account.
//   - Order must be in `ready` state (all authzs valid).
//   - Posted CSR must be parseable and self-signature-valid.
//   - CSR's CN/SANs must be a subset of the order's identifiers.
//
// On success, the cert is signed via models.SignCSRForACME (the
// single integration seam with the existing pfpki issuance code), the
// order's CertSerialNumber + status flip in one transaction, and we
// return the updated order body. The client then polls /order/{id}
// until status==valid and downloads the cert from /cert/{serial}.
func orderFinalizeHandler(h *types.Handler) http.HandlerFunc {
	inner := func(w http.ResponseWriter, r *http.Request) {
		jc := fromCtx(r.Context())
		if jc == nil || jc.Account == nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, "missing account in JWS context")
			return
		}
		idStr := chi.URLParam(r, "id")
		id, err := strconv.ParseUint(idStr, 10, 64)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "bad order id")
			return
		}
		// Pre-load the profile with its CA so SignCSRForACME has
		// everything it needs without a second SELECT inside the
		// signing path.
		var prof models.Profile
		if err := h.DB.Preload("Ca").First(&prof, jc.Profile.ID).Error; err != nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}
		var order models.AcmeOrder
		if err := h.DB.First(&order, id).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				_ = WriteProblem(w, http.StatusNotFound, ErrMalformed, "no such order")
				return
			}
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}
		if order.AccountID != jc.Account.ID {
			_ = WriteProblem(w, http.StatusUnauthorized, ErrUnauthorized, "order belongs to a different account")
			return
		}
		if order.Status != "ready" {
			_ = WriteProblem(w, http.StatusForbidden, ErrOrderNotReady,
				"order status is "+order.Status+", finalize requires ready")
			return
		}

		var payload finalizePayload
		if err := json.Unmarshal(jc.Payload, &payload); err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "decode payload: "+err.Error())
			return
		}
		csrDER, err := jwsURLEncoding.DecodeString(payload.CSR)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrBadCSR, "csr field is not URL-safe base64: "+err.Error())
			return
		}

		// Decode identifiers from storage into the shape SignCSRForACME
		// expects (no acme→models import dependency).
		var raw []identifier
		if order.Identifiers != "" {
			_ = json.Unmarshal([]byte(order.Identifiers), &raw)
		}
		ids := make([]models.AcmeIdentifier, len(raw))
		for i, x := range raw {
			ids[i] = models.AcmeIdentifier{Type: x.Type, Value: x.Value}
		}

		cert, err := models.SignCSRForACME(h.DB, r.Context(), prof, csrDER, ids)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrBadCSR, err.Error())
			return
		}

		// Order transition: ready → valid + record the cert serial so
		// /cert/{serial} can resolve it later.
		if err := h.DB.Model(&models.AcmeOrder{}).Where("id = ?", order.ID).
			Updates(map[string]any{
				"status":            "valid",
				"cert_serial_number": cert.SerialNumber,
			}).Error; err != nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}
		// Refresh the in-memory copy so the response reflects the new
		// state.
		order.Status = "valid"
		order.CertSerialNumber = cert.SerialNumber

		loc := orderURL(r, jc.Profile.Name, order.ID)
		w.Header().Set("Location", loc)
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(buildOrderResponse(r, jc.Profile.Name, &order, parseAuthzIDs(order.AuthzIDs)))
	}
	return jwsMiddleware(h, jwsRequireKID, inner)
}

// orderByIDHandler is the RFC 8555 §6.3 POST-as-GET read of an order.
// Empty body in the JWS payload; the kid in the protected header
// authenticates the request. Ownership check: the order's account must
// match the JWS account, otherwise return 401 unauthorized.
func orderByIDHandler(h *types.Handler) http.HandlerFunc {
	inner := func(w http.ResponseWriter, r *http.Request) {
		jc := fromCtx(r.Context())
		if jc == nil || jc.Account == nil {
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, "missing account in JWS context")
			return
		}
		idStr := chi.URLParam(r, "id")
		id, err := strconv.ParseUint(idStr, 10, 64)
		if err != nil {
			_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "bad order id")
			return
		}
		var order models.AcmeOrder
		if err := h.DB.First(&order, id).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				_ = WriteProblem(w, http.StatusNotFound, ErrMalformed, "no such order")
				return
			}
			_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
			return
		}
		if order.AccountID != jc.Account.ID {
			// Per §7.4: a client can only inspect its own orders.
			_ = WriteProblem(w, http.StatusUnauthorized, ErrUnauthorized,
				"order belongs to a different account")
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(buildOrderResponse(r, jc.Profile.Name, &order, parseAuthzIDs(order.AuthzIDs)))
	}
	return jwsMiddleware(h, jwsRequireKID, inner)
}

// buildOrderResponse converts a stored AcmeOrder into the §7.1.3 JSON
// shape, including absolute URLs for each authz + the finalize endpoint.
func buildOrderResponse(r *http.Request, profileName string, order *models.AcmeOrder, authzIDs []uint) orderResponse {
	var identifiers []identifier
	if order.Identifiers != "" {
		_ = json.Unmarshal([]byte(order.Identifiers), &identifiers)
	}
	authURLs := make([]string, 0, len(authzIDs))
	for _, id := range authzIDs {
		authURLs = append(authURLs, authzURL(r, profileName, id))
	}
	resp := orderResponse{
		Status:         order.Status,
		Expires:        order.ExpiresAt.Format(time.RFC3339),
		Identifiers:    identifiers,
		Authorizations: authURLs,
		Finalize:       orderURL(r, profileName, order.ID) + "/finalize",
	}
	if !order.NotBefore.IsZero() {
		resp.NotBefore = order.NotBefore.Format(time.RFC3339)
	}
	if !order.NotAfter.IsZero() {
		resp.NotAfter = order.NotAfter.Format(time.RFC3339)
	}
	if order.CertSerialNumber != "" {
		resp.Certificate = baseURL(r) + acmeMountPath(r) + "/" + profileName + "/cert/" + order.CertSerialNumber
	}
	if order.Error != "" {
		var prob any
		_ = json.Unmarshal([]byte(order.Error), &prob)
		resp.Error = prob
	}
	return resp
}

// orderURL is the canonical /order/{id} URL. authzURL is the same for
// /authz/{id}. Both honor the reverse-proxy headers via baseURL().
func orderURL(r *http.Request, profileName string, orderID uint) string {
	return baseURL(r) + acmeMountPath(r) + "/" + profileName + "/order/" + strconv.FormatUint(uint64(orderID), 10)
}
func authzURL(r *http.Request, profileName string, authzID uint) string {
	return baseURL(r) + acmeMountPath(r) + "/" + profileName + "/authz/" + strconv.FormatUint(uint64(authzID), 10)
}

// splitCSV trims whitespace from each entry and drops empties.
func splitCSV(s string) []string {
	out := make([]string, 0)
	for _, part := range strings.Split(s, ",") {
		p := strings.TrimSpace(part)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

func contains(xs []string, want string) bool {
	for _, x := range xs {
		if x == want {
			return true
		}
	}
	return false
}

// parseAuthzIDs is the inverse of the CSV join in newOrderHandler.
// Bad entries are silently dropped — the row was server-built, so an
// unparseable entry would be a real bug and should fail loudly upstream
// rather than crash on a 400.
func parseAuthzIDs(csv string) []uint {
	if csv == "" {
		return nil
	}
	parts := strings.Split(csv, ",")
	out := make([]uint, 0, len(parts))
	for _, p := range parts {
		if n, err := strconv.ParseUint(strings.TrimSpace(p), 10, 64); err == nil {
			out = append(out, uint(n))
		}
	}
	return out
}

// parseValidityHints handles the client's optional notBefore/notAfter
// hints. RFC 8555 says the server MAY honor them; we treat them as
// best-effort and silently fall back to zero-time on parse failure,
// which the finalize path interprets as "use the profile default".
func parseValidityHints(nb, na string) (time.Time, time.Time) {
	var notBefore, notAfter time.Time
	if nb != "" {
		notBefore, _ = time.Parse(time.RFC3339, nb)
	}
	if na != "" {
		notAfter, _ = time.Parse(time.RFC3339, na)
	}
	return notBefore, notAfter
}

// pickChallengeType maps (identifier-type, profile attestation policy)
// to the challenge type the server should issue. The policy is
// per-profile so two profiles on the same pfpki can run different
// proof flows in parallel (e.g. one corp-managed-Apple profile with
// device-attest-01, one DevOps profile with http-01).
func pickChallengeType(identifierType, attestationFormatsCSV string) string {
	if identifierType == "permanent-identifier" {
		for _, f := range splitCSV(attestationFormatsCSV) {
			if f == "apple" {
				return "device-attest-01"
			}
		}
	}
	return "http-01"
}

// randomToken returns a 32-byte URL-safe base64 string suitable for an
// ACME challenge token (§8.3 mandates ≥128 bits of entropy).
func randomToken() string {
	var buf [32]byte
	_, _ = rand.Read(buf[:])
	return base64.RawURLEncoding.EncodeToString(buf[:])
}
