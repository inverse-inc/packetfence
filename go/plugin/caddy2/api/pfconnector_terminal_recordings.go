package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"regexp"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/connector"
)

// Terminal session recordings of a connector-remote (asciicast v2 files the
// remote writes for every terminal connection), relayed from its
// /api/v1/terminal-recordings routes over a dynreverse tunnel:
//
//	GET /api/v1/terminal/{connectorID}/recordings          list (JSON)
//	GET /api/v1/terminal/{connectorID}/recordings/{name}   the .cast file (?download=1 for an attachment)
//
// Deliberately under /terminal rather than /pfconnector-remotes: the
// transcript of a shell on the connector host is as sensitive as the shell
// itself, and the /terminal prefix requires CONNECTORS_UPDATE for every
// method (aaa/authorization.go) where /pfconnector-remotes would grant a GET
// to CONNECTORS_READ.

// recordingName mirrors the connector-remote's file name check.
var recordingName = regexp.MustCompile(`^\d{8}T\d{6}Z-[A-Za-z0-9_.-]{1,64}?(-\d{1,2})?\.cast$`)

// AdminUserHeader carries the PacketFence admin username to the
// connector-remote when a terminal session is activated; the remote stores
// it in the header of the session's recordings.
const AdminUserHeader = "X-PF-Admin-User"

// pfconnectorTerminalRecordings is GET /terminal/{connectorID}/recordings.
func (h APIHandler) pfconnectorTerminalRecordings() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID, _ := url.PathUnescape(chi.URLParam(r, "connectorID"))
		if connectorID == "" {
			writeJSONMessage(w, http.StatusBadRequest, "PFconnector ID is required")
			return
		}
		conn := connector.NewConnectorsContainer(h.ctx).Get(h.ctx, connectorID)
		if conn == nil {
			writeJSONMessage(w, http.StatusNotFound, "Unknown PFconnector ID")
			return
		}
		status, reply, err := h.callConnectorRemoteAPIRaw(conn, "GET", "/api/v1/terminal-recordings", nil, 20*time.Second)
		if err != nil {
			log.LoggerWContext(r.Context()).Error(fmt.Sprintf("Unable to list the terminal recordings of connector-remote %s: %s", connectorID, err))
			writeJSONMessage(w, http.StatusBadGateway, "Unable to reach the connector-remote")
			return
		}
		if status == http.StatusNotFound {
			writeJSONMessage(w, http.StatusNotFound, "This connector-remote does not expose its terminal recordings: upgrade it first")
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		if json.Valid(reply) {
			w.Write(reply)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"message": string(reply)})
	})
}

// proxyTerminalRecording streams one recording file from the
// connector-remote (GET /terminal/{connectorID}/recordings/{name}); a
// reverse proxy rather than a buffered call since a long session can weigh
// tens of megabytes. The ?download=1 query goes through so the remote sets
// the attachment disposition.
func (h APIHandler) proxyTerminalRecording() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID, _ := url.PathUnescape(chi.URLParam(r, "connectorID"))
		name, _ := url.PathUnescape(chi.URLParam(r, "name"))
		if connectorID == "" || !recordingName.MatchString(name) {
			writeJSONMessage(w, http.StatusBadRequest, "PFconnector ID and a valid recording name are required")
			return
		}
		conn := connector.NewConnectorsContainer(h.ctx).Get(h.ctx, connectorID)
		if conn == nil {
			writeJSONMessage(w, http.StatusNotFound, "Unknown PFconnector ID")
			return
		}
		remoteCon, err := conn.DynReverse(h.ctx, "127.0.0.1:8081")
		if err != nil {
			writeJSONMessage(w, http.StatusBadGateway, "Unable to reach the connector-remote")
			return
		}
		target, err := url.Parse("http://" + remoteCon.Host + ":" + string(remoteCon.Port))
		if err != nil {
			writeJSONMessage(w, http.StatusInternalServerError, "Internal Server Error")
			return
		}
		log.LoggerWContext(r.Context()).Info(fmt.Sprintf("Terminal recording %s of connector %s served to %s", name, connectorID, r.Header.Get("X-PacketFence-Username")))

		r.URL.Path = "/api/v1/terminal-recordings/" + name
		r.URL.RawPath = ""
		r.Host = target.Host
		r.Header.Set("X-Forwarded-For", "127.0.0.1")
		w.Header().Del("Content-Type")
		proxy := httputil.NewSingleHostReverseProxy(target)
		director := proxy.Director
		proxy.Director = func(req *http.Request) {
			director(req)
			stripAdminCredentials(req)
		}
		proxy.ModifyResponse = func(res *http.Response) error {
			// The remote is only semi-trusted: never let its reply render
			// in the admin origin.
			res.Header.Set("X-Content-Type-Options", "nosniff")
			res.Header.Set("Cache-Control", "no-store")
			if res.StatusCode == http.StatusOK {
				res.Header.Set("Content-Type", "application/x-asciicast; charset=utf-8")
			}
			return nil
		}
		proxy.ServeHTTP(w, r)
	})
}
