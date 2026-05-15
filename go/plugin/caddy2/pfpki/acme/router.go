package acme

import (
	chi "github.com/go-chi/chi/v5"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

// Mount attaches the ACME endpoints to r under the path
// "/{profile}/...". The same chi.Router can be mounted both under
// /api/v1/pki/acme and under a bare /acme — the caller does the
// mounting via chi.Router.Mount("/acme", acme.Mount(h)).
//
// As Phase 1 lands, the new handlers (account/order/authz/challenge/
// finalize/cert/revoke) attach here. The skeleton serves /directory
// and /new-nonce only.
func Mount(h *types.Handler) chi.Router {
	r := chi.NewRouter()
	r.Route("/{profile}", func(r chi.Router) {
		r.Get("/directory", directoryHandler(h))
		r.Head("/new-nonce", newNonceHandler(h))
		r.Get("/new-nonce", newNonceHandler(h))
	})
	return r
}
