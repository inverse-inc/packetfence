package api

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/inverse-inc/packetfence/go/detectparser"
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

	fmt.Println("---- Received body:", string(body))

	pfqueueclient := pfqueueclient.NewPfQueueClient()

	args := &detectparser.PfqueueApiCall{
		Method: "policy-violation",
		Params: body,
	}

	s, err := pfqueueclient.Submit(context.Background(), "fleetdm", "policy", args)
	fmt.Println("submit result is: ", s)
	if err != nil {
		fmt.Println("error is: ", err.Error())
	}

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

	fmt.Println("---- Received body:", string(body))

}
