package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/go-redis/redis"
	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func (h APIHandler) proxyTerminal() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

		connectorID := chi.URLParam(r, "connectorID")
		if connectorID == "" {
			http.Error(w, "PFconnector ID is required", http.StatusBadRequest)
			return
		}

		r.URL.Path = strings.TrimPrefix(r.URL.Path, "/api/v1/terminal/"+connectorID)

		r.Host = "127.0.0.1:8081"
		r.URL.Path = "api/v1/terminal" + r.URL.Path
		r.Header.Set("X-Forwarded-For", "127.0.0.1")

		// Todo - retrieve from redis
		// Open to the remote API
		conn := connector.NewConnectorsContainer(h.ctx)
		remoteCon, err := conn.Get(h.ctx, connectorID).DynReverse(h.ctx, fmt.Sprintf("%s:%s", "127.0.0.1", "8081"))

		if err != nil {
			http.Error(w, "Failed to connect to PFconnector", http.StatusInternalServerError)
			return
		}
		port := string(remoteCon.Port)

		TerminalURL, err := url.Parse("http://" + remoteCon.Host + ":" + port)
		if err != nil {
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}
		proxy := httputil.NewSingleHostReverseProxy(TerminalURL)

		proxy.ServeHTTP(w, r)
	})
}

func (h APIHandler) pfconnectorTerminalGet() http.HandlerFunc {

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

		type request struct {
			PFconnectorID string `json:"pfconnector_id"`
		}

		type reply struct {
			RedirectURL string `json:"redirect_url"`
		}
		body, err := io.ReadAll(r.Body)

		if err != nil {
			http.Error(w, "Failed to read request body", http.StatusBadRequest)
			return
		}
		var req request
		json.Unmarshal(body, &req)

		if len(req.PFconnectorID) == 0 {
			http.Error(w, "PFconnector ID is required", http.StatusBadRequest)
			return
		}

		PfconnectorConfiguration := pfconfigdriver.GetType[pfconfigdriver.PfConfPfconnector](r.Context())
		var network string
		if strings.HasPrefix(PfconnectorConfiguration.RedisServer, "/") {
			network = "unix"
		} else {
			network = "tcp"
		}

		redis := redis.NewClient(&redis.Options{
			Addr:    PfconnectorConfiguration.RedisServer,
			Network: network,
		})
		// Ensure the Redis client is closed after use
		defer redis.Close()

		// Check if the Redis server is reachable
		if err := redis.Ping().Err(); err != nil {
			http.Error(w, "Redis server is not reachable", http.StatusInternalServerError)
			return
		}
		newUUID := uuid.New()
		// Store the new UUID in Redis
		if err := redis.Set("terminal:"+newUUID.String(), req.PFconnectorID, 0).Err(); err != nil {
			http.Error(w, "Failed to store PFconnector ID", http.StatusInternalServerError)
			return
		}

		ips := redis.Get("ips:" + req.PFconnectorID).Val()
		ipList := strings.Split(ips, ",")

		redirect := reply{
			RedirectURL: "http://" + ipList[0] + ":8081/api/v1/authorize/" + newUUID.String(),
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		if err := json.NewEncoder(w).Encode(redirect); err != nil {
			http.Error(w, "Failed to encode response", http.StatusInternalServerError)
			return
		}
	})
}
