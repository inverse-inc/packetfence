package api

import (
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"

	"github.com/go-chi/chi/v5"
	"github.com/inverse-inc/packetfence/go/connector"
)

// proxyConnectorLogs reverse proxies
// /api/v1/pfconnector-remotes/{connectorID}/logs/{name} to the
// connector-remote's local API (:8081) through an on-demand dynreverse
// tunnel. The remote endpoint upgrades to a websocket streaming the log file;
// httputil.ReverseProxy carries the upgrade transparently. Living under
// /pfconnector-remotes, the route inherits the CONNECTORS admin-role
// authorization from the aaa layer.
func (h APIHandler) proxyConnectorLogs() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID := chi.URLParam(r, "connectorID")
		name := chi.URLParam(r, "name")
		if connectorID == "" || name == "" {
			http.Error(w, "PFconnector ID and log name are required", http.StatusBadRequest)
			return
		}

		r.Host = "127.0.0.1:8081"
		// RawQuery is left untouched: it carries the ?lines=N backfill size.
		r.URL.Path = "api/v1/logs/" + name
		r.Header.Set("X-Forwarded-For", "127.0.0.1")

		conn := connector.NewConnectorsContainer(h.ctx)
		remoteCon, err := conn.Get(h.ctx, connectorID).DynReverse(h.ctx, fmt.Sprintf("%s:%s", "127.0.0.1", "8081"))
		if err != nil {
			http.Error(w, "Failed to connect to PFconnector", http.StatusInternalServerError)
			return
		}

		logsURL, err := url.Parse("http://" + remoteCon.Host + ":" + string(remoteCon.Port))
		if err != nil {
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}
		w.Header().Del("Content-Type")
		proxy := httputil.NewSingleHostReverseProxy(logsURL)
		proxy.ServeHTTP(w, r)
	})
}
