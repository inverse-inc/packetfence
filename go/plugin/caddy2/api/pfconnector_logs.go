package api

import (
	"fmt"
	"net/http"
	"net/url"

	"github.com/go-chi/chi/v5"
)

// proxyConnectorLogs reverse proxies the websocket
// /api/v1/pfconnector-remotes/{connectorID}/logs/{name} to the
// connector-remote's local API (:8081) through an on-demand dynreverse
// tunnel. The remote endpoint upgrades to a websocket streaming the log file;
// httputil.ReverseProxy carries the upgrade transparently. Living under
// /pfconnector-remotes, the route inherits the CONNECTORS admin-role
// authorization from the aaa layer.
//
// Only same-origin websocket upgrades are proxied: a plain request would
// render whatever the remote answers in the admin origin. The admin's
// credentials are never sent to the remote.
func (h APIHandler) proxyConnectorLogs() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID := chi.URLParam(r, "connectorID")
		name := chi.URLParam(r, "name")
		if connectorID == "" || name == "" {
			http.Error(w, "PFconnector ID and log name are required", http.StatusBadRequest)
			return
		}
		if !isWebsocketUpgrade(r) {
			http.Error(w, "Only websocket requests are accepted", http.StatusBadRequest)
			return
		}
		if !sameOriginWebsocket(r) {
			http.Error(w, "Cross-origin request refused", http.StatusForbidden)
			return
		}

		conn := h.pfconnector(h.ctx, connectorID)
		if conn == nil {
			http.Error(w, "Unknown PFconnector ID", http.StatusNotFound)
			return
		}
		remoteCon, err := conn.DynReverse(h.ctx, fmt.Sprintf("%s:%s", "127.0.0.1", "8081"))
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
		// RawQuery is left untouched: it carries the backfill (?lines=N or
		// ?since=<RFC 3339>).
		newRemoteWebsocketProxy(logsURL, "/api/v1/logs/"+url.PathEscape(name), nil).ServeHTTP(w, r)
	})
}
