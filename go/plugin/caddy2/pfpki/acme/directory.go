package acme

import (
	"encoding/json"
	"net/http"

	chi "github.com/go-chi/chi/v5"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/gorm"
)

// directoryDoc is the RFC 8555 §7.1.1 directory object — the
// well-known URL the client fetches first to learn the rest of the
// endpoints. The `meta` field's `externalAccountRequired` is the
// signal the device's MDM client uses to know it must present an
// EAB-signed outer JWS on /new-account.
type directoryDoc struct {
	NewNonce   string        `json:"newNonce"`
	NewAccount string        `json:"newAccount"`
	NewOrder   string        `json:"newOrder"`
	RevokeCert string        `json:"revokeCert"`
	KeyChange  string        `json:"keyChange"`
	Meta       directoryMeta `json:"meta"`
}

type directoryMeta struct {
	ExternalAccountRequired bool     `json:"externalAccountRequired,omitempty"`
	CaaIdentities           []string `json:"caaIdentities,omitempty"`
	Website                 string   `json:"website,omitempty"`
	TermsOfService          string   `json:"termsOfService,omitempty"`
}

// loadProfile resolves the {profile} chi URL parameter to a pfpki
// Profile row. Returns nil + an HTTP-shaped error on miss; the caller
// has already written the response.
func loadProfile(w http.ResponseWriter, r *http.Request, h *types.Handler) (*models.Profile, bool) {
	name := chi.URLParam(r, "profile")
	if name == "" {
		_ = WriteProblem(w, http.StatusBadRequest, ErrMalformed, "missing profile in URL")
		return nil, false
	}
	var prof models.Profile
	if err := h.DB.Where("name = ?", name).First(&prof).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			_ = WriteProblem(w, http.StatusNotFound, ErrMalformed, "unknown profile")
			return nil, false
		}
		_ = WriteProblem(w, http.StatusInternalServerError, ErrServerInternal, err.Error())
		return nil, false
	}
	if prof.AcmeEnabled != 1 {
		_ = WriteProblem(w, http.StatusForbidden, ErrUnauthorized, "ACME disabled on this profile")
		return nil, false
	}
	return &prof, true
}

// directoryHandler builds the per-profile directory document. We embed
// the profile name in every sub-URL so the client carries the
// "provisioner" routing parameter on every subsequent hop.
func directoryHandler(h *types.Handler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		prof, ok := loadProfile(w, r, h)
		if !ok {
			return
		}
		base := baseURL(r) + acmeMountPath(r) + "/" + prof.Name
		doc := directoryDoc{
			NewNonce:   base + "/new-nonce",
			NewAccount: base + "/new-account",
			NewOrder:   base + "/new-order",
			RevokeCert: base + "/revoke-cert",
			KeyChange:  base + "/key-change",
			Meta: directoryMeta{
				ExternalAccountRequired: prof.AcmeEabRequired == 1,
			},
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Cache-Control", "no-store")
		_ = json.NewEncoder(w).Encode(doc)
	}
}

// baseURL reconstructs scheme://host so we can emit absolute URLs in
// directory + Location headers. Honors X-Forwarded-Proto / -Host when
// pfpki sits behind a reverse proxy.
func baseURL(r *http.Request) string {
	scheme := "https"
	if proto := r.Header.Get("X-Forwarded-Proto"); proto != "" {
		scheme = proto
	} else if r.TLS == nil {
		scheme = "http"
	}
	host := r.Host
	if h := r.Header.Get("X-Forwarded-Host"); h != "" {
		host = h
	}
	return scheme + "://" + host
}

// acmeMountPath returns the URL prefix the ACME router is mounted on
// for THIS request. We support two mounts (the /api/v1/pki/acme variant
// and the bare /acme variant), so the prefix has to come from the
// router rather than be hard-coded.
func acmeMountPath(r *http.Request) string {
	// The chi RouteContext.RoutePath fragment after the /acme/ matches
	// is "/{profile}/...". We want everything from the start of the
	// request path up to the "/{profile}" segment, which we can find
	// by chopping the suffix.
	urlPath := r.URL.Path
	profile := chi.URLParam(r, "profile")
	if profile == "" {
		return urlPath
	}
	idx := lastIndex(urlPath, "/"+profile)
	if idx < 0 {
		return urlPath
	}
	return urlPath[:idx]
}

// lastIndex is strings.LastIndex without pulling in the package for one
// call (the only other strings use in this file would be EqualFold).
func lastIndex(s, sep string) int {
	for i := len(s) - len(sep); i >= 0; i-- {
		if s[i:i+len(sep)] == sep {
			return i
		}
	}
	return -1
}
