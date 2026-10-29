package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"

	"github.com/go-chi/chi/v5"
)

// Start, stop and restart of the NTLM authentication services of a
// connector-remote's host from the admin interface. The connector-remote
// relays the request to its host through a trigger file (it has no access to
// the host's systemd), so the answer is a 202: the unit's state follows in
// the status endpoint ("host_services" of the system info), as the host
// writes it back.

// hostServiceActions are the actions the admin may request.
var hostServiceActions = map[string]bool{"start": true, "stop": true, "restart": true}

// hostServiceRe mirrors the allowlist of the connector-remote's
// /api/v1/service/{action} and of its host script: the two NTLM units and
// the per-domain instances of the NTLM API.
var hostServiceRe = regexp.MustCompile(`^packetfence-ntlm-auth-(api-remote|join-remote|api-domain-remote@[A-Za-z0-9][A-Za-z0-9._-]{0,63})\.service$`)

// pfconnectorRemoteService relays {"service": "<unit>"} as a start, stop or
// restart request to the connector-remote.
func (h APIHandler) pfconnectorRemoteService() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID := chi.URLParam(r, "connectorID")
		if connectorID == "" {
			http.Error(w, "PFconnector ID is required", http.StatusBadRequest)
			return
		}
		action := chi.URLParam(r, "action")
		if !hostServiceActions[action] {
			http.Error(w, fmt.Sprintf("Unknown service action %q", action), http.StatusBadRequest)
			return
		}
		var req struct {
			Service string `json:"service"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Service == "" {
			http.Error(w, "The service name is required", http.StatusBadRequest)
			return
		}
		if !hostServiceRe.MatchString(req.Service) {
			http.Error(w, fmt.Sprintf("Service %q is not an NTLM authentication service of a connector-remote host", req.Service), http.StatusBadRequest)
			return
		}

		conn := h.pfconnector(h.ctx, connectorID)
		if conn == nil {
			http.Error(w, "Unknown PFconnector ID", http.StatusNotFound)
			return
		}

		body, _ := json.Marshal(map[string]string{"service": req.Service})
		h.relayConnectorRemoteAPI(w, r, conn, "POST", "/api/v1/service/"+action, bytes.NewReader(body),
			fmt.Sprintf("%s %s on connector-remote %s", action, req.Service, connectorID), "Unable to reach the connector-remote to act on the service")
	})
}
