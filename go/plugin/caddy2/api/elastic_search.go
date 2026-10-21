package api

import (
	"encoding/json"
	"net/http"
	"os"

	"github.com/julienschmidt/httprouter"
)

func (h APIHandler) handleElasticsearch(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	info := struct {
		Host string `json:"host"`
		Port string `json:"port"`
		User string `json:"user"`
		Pass string `json:"pass"`
	}{
		Host: os.Getenv("KIBANA_HOST"),
		Port: os.Getenv("KIBANA_PORT"),
		User: os.Getenv("KIBANA_USER"),
		Pass: os.Getenv("KIBANA_PASS"),
	}

	json.NewEncoder(w).Encode(info)
}
