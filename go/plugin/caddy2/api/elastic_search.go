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
		Host: os.Getenv("PFCONFIG_ELASTICSEARCH_HOST"),
		Port: os.Getenv("PFCONFIG_ELASTICSEARCH_PORT"),
		User: os.Getenv("PFCONFIG_ELASTICSEARCH_USER"),
		Pass: os.Getenv("PFCONFIG_ELASTICSEARCH_PASS"),
	}

	json.NewEncoder(w).Encode(info)
}
