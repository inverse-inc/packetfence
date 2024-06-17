package api

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/inverse-inc/packetfence/go/pfqueueclient"
	"github.com/julienschmidt/httprouter"
	"io/ioutil"
	"net/http"
)

func (h APIHandler) Policy(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	body, err := ioutil.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusUnprocessableEntity)
		res, _ := json.Marshal(map[string]string{
			"message": "Failed to read request body: " + err.Error(),
		})
		fmt.Fprintf(w, string(res))
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
		fmt.Fprintf(w, string(res))
		return
	}

	w.WriteHeader(http.StatusAccepted)
	res, _ := json.Marshal(map[string]string{
		"task_key": taskKey,
	})
	fmt.Fprintf(w, string(res))
	return
}

func (h APIHandler) CVE(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	body, err := ioutil.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusUnprocessableEntity)
		res, _ := json.Marshal(map[string]string{
			"message": "Failed to read request body: " + err.Error(),
		})
		fmt.Fprintf(w, string(res))
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
		fmt.Fprintf(w, string(res))
		return
	}

	w.WriteHeader(http.StatusAccepted)
	res, _ := json.Marshal(map[string]string{
		"task_key": taskKey,
	})
	fmt.Fprintf(w, string(res))
	return
}
