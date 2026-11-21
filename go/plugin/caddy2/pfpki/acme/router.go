package acme

import (
	"net/http"
	"strings"

	chi "github.com/go-chi/chi/v5"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

// Mount attaches the ACME endpoints to r under the path
// "/{profile}/...". The same chi.Router can be mounted both under
// /api/v1/pki/acme and under a bare /acme — the caller does the
// mounting via chi.Router.Mount("/acme", acme.Mount(h)).
func Mount(h *types.Handler) chi.Router {
	r := chi.NewRouter()
	r.Use(requireHTTPS)
	r.Route("/{profile}", func(r chi.Router) {
		r.Get("/directory", directoryHandler(h))
		r.Head("/new-nonce", newNonceHandler(h))
		r.Get("/new-nonce", newNonceHandler(h))
		r.Post("/new-account", newAccountHandler(h))
		r.Post("/account/{id}", accountByIDHandler(h))
		r.Post("/account/{id}/orders", accountOrdersHandler(h))
		r.Post("/key-change", keyChangeHandler(h))
		r.Post("/new-order", newOrderHandler(h))
		r.Post("/order/{id}", orderByIDHandler(h))
		r.Post("/order/{id}/finalize", orderFinalizeHandler(h))
		r.Post("/authz/{id}", authzByIDHandler(h))
		r.Post("/chall/{id}", challengeByIDHandler(h))
		r.Post("/cert/{id}", certByIDHandler(h))
		r.Post("/revoke-cert", revokeCertHandler(h))
	})
	return r
}

// requireHTTPS refuses the requests a reverse proxy received over plain
// HTTP (X-Forwarded-Proto other than https): RFC 8555 §6.1 requires
// HTTPS, and the portal also serves this router on port 80. The portal
// haproxy adds the header, so a client value can't hide a plain HTTP
// request: every value is checked. A request without the header came
// straight to pfpki and is accepted. The http-01 validation is an
// outbound fetch and is not affected.
func requireHTTPS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		for _, header := range r.Header.Values("X-Forwarded-Proto") {
			for _, proto := range strings.Split(header, ",") {
				if !strings.EqualFold(strings.TrimSpace(proto), "https") {
					log.LoggerWContext(r.Context()).Info("ACME " + r.Method + " " + r.URL.Path + " from " +
						r.RemoteAddr + ": refused a request received over " + strings.TrimSpace(proto))
					_ = WriteProblem(w, http.StatusForbidden, ErrMalformed, "ACME requires HTTPS")
					return
				}
			}
		}
		next.ServeHTTP(w, r)
	})
}
