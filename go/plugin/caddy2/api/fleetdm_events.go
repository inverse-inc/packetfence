package api

import (
	"context"
	"encoding/json"
	"io"
	"net/http"

	"github.com/inverse-inc/packetfence/go/pfqueueclient"
)

func (h APIHandler) Policy() http.HandlerFunc {

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			w.WriteHeader(http.StatusUnprocessableEntity)
			res, _ := json.Marshal(map[string]string{
				"message": "Failed to read request body: " + err.Error(),
			})
			w.Write(res)
			return
		}
		defer r.Body.Close()

		pfqueueclient := pfqueueclient.NewPfQueueClient()
		args := map[string]interface{}{
			"type":    "fleetdm_policy",
			"payload": string(body),
		}
		taskKey, err := pfqueueclient.Submit(context.Background(), "general", "fleetdm", args)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			res, _ := json.Marshal(map[string]string{
				"message": "failed to write policy violation event to pfqueue: " + err.Error(),
			})
			w.Write(res)
			return
		}

		w.WriteHeader(http.StatusAccepted)
		res, _ := json.Marshal(map[string]string{
			"task_key": taskKey,
		})
		w.Write(res)
		return
	})
}

func (h APIHandler) CVE() http.HandlerFunc {

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			w.WriteHeader(http.StatusUnprocessableEntity)
			res, _ := json.Marshal(map[string]string{
				"message": "Failed to read request body: " + err.Error(),
			})
			w.Write(res)
			return
		}
		defer r.Body.Close()

		pfqueueclient := pfqueueclient.NewPfQueueClient()
		args := map[string]interface{}{
			"type":    "fleetdm_cve",
			"payload": string(body),
		}
		taskKey, err := pfqueueclient.Submit(context.Background(), "general", "fleetdm", args)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			res, _ := json.Marshal(map[string]string{
				"message": "failed to write CVE event to pfqueue: " + err.Error(),
			})
			w.Write(res)
			return
		}

		w.WriteHeader(http.StatusAccepted)
		res, _ := json.Marshal(map[string]string{
			"task_key": taskKey,
		})
		w.Write(res)
		return
	})
}
