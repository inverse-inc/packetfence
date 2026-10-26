package api

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/connector"
)

// pfconnectorRemoteUptime is GET /api/v1/pfconnector-remotes/{connectorID}/uptime?window=1h|24h|30d:
// the tunnel uptime history of a connector (connector/uptime.go).
func (h APIHandler) pfconnectorRemoteUptime() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID := chi.URLParam(r, "connectorID")
		if h.pfconnector(h.ctx, connectorID) == nil {
			http.Error(w, "Unknown PFconnector ID", http.StatusNotFound)
			return
		}
		window := r.URL.Query().Get("window")
		if window == "" {
			window = "24h"
		}
		if _, ok := connector.UptimeWindows[window]; !ok {
			http.Error(w, "window must be 1h, 24h or 30d", http.StatusBadRequest)
			return
		}
		history, err := connector.ReadUptime(r.Context(), connectorID, window, time.Now())
		if err != nil {
			log.LoggerWContext(r.Context()).Error("Unable to read the uptime history of " + connectorID + ": " + err.Error())
			http.Error(w, "Unable to read the uptime history", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(history)
	})
}
