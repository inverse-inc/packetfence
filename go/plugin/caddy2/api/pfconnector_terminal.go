package api

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/go-redis/redis"
	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/julienschmidt/httprouter"
)

func (h APIHandler) pfconnectorTerminalGet(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
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

	var PfconnectorConfiguration pfconfigdriver.PfConfPfconnector
	pfconfigdriver.FetchDecodeSocket(r.Context(), &PfconnectorConfiguration)

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

	defer redis.Close()
	// Check if the Redis server is reachable
	if err := redis.Ping().Err(); err != nil {
		http.Error(w, "Redis server is not reachable", http.StatusInternalServerError)
		return
	}
	newUUID := uuid.New()
	// Store the new UUID in Redis
	if err := redis.Set("terminal:"+newUUID.String(), req.PFconnectorID, 60*time.Second).Err(); err != nil {
		http.Error(w, "Failed to store PFconnector ID", http.StatusInternalServerError)
		return
	}
	redirect := reply{
		RedirectURL: "http://10.0.0.250:8081/api/v1//authorize/" + newUUID.String(),
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(redirect); err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}

}
