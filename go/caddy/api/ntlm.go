package api

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"github.com/inverse-inc/packetfence/go/caddy/ntlm"
	"github.com/julienschmidt/httprouter"
	"net/http"
)

func (h APIHandler) ntlmTest(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	type response struct {
		Status  int    `json:"status"`
		Message string `json:"message"`
	}

	type payload struct {
		Id       string `json:"id"`
		Password string `json:"machine_account_password"`
	}

	ctx := context.Background()
	domainConfig, err := ntlm.GetDomainConfig(ctx)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		res := &response{
			Status:  http.StatusInternalServerError,
			Message: "Unable to connect to pfconfig service",
		}
		j, _ := json.Marshal(res)
		fmt.Fprintf(w, string(j))
		return
	}

	b := bytes.NewBuffer(nil)
	b.ReadFrom(r.Body)
	req := &payload{}
	err = json.Unmarshal(b.Bytes(), req)
	if err != nil {
		w.WriteHeader(http.StatusUnprocessableEntity)
		res := &response{
			Status:  http.StatusUnprocessableEntity,
			Message: "Unknown payload format, expected JSON format with id and password",
		}
		j, _ := json.Marshal(res)
		fmt.Fprintf(w, string(j))
		return
	}

	sectionConf, exists := domainConfig.Element[req.Id]
	if !exists {
		w.WriteHeader(http.StatusNotFound)
		res := &response{
			Status:  http.StatusNotFound,
			Message: "Unknown domain " + req.Id + ", record not found",
		}
		j, _ := json.Marshal(res)
		fmt.Fprintf(w, string(j))
		return
	}

	ntlmAuthPort, exists := sectionConf.(map[string]interface{})["ntlm_auth_port"]
	if !exists {
		w.WriteHeader(http.StatusInternalServerError)
		res := &response{
			Status:  http.StatusInternalServerError,
			Message: "Unable to find listening port for domain " + req.Id,
		}
		j, _ := json.Marshal(res)
		fmt.Fprintf(w, string(j))
		return
	}

	passed, err := ntlm.CheckMachineAccountWithGivenPassword(ctx, ntlmAuthPort.(string), req.Password)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		res := &response{
			Status:  http.StatusInternalServerError,
			Message: err.Error(),
		}
		j, _ := json.Marshal(res)
		fmt.Fprintf(w, string(j))
		return
	}

	if !passed {
		w.WriteHeader(http.StatusUnauthorized)
		res := &response{
			Status:  http.StatusUnauthorized,
			Message: "Machine account check failed",
		}
		j, _ := json.Marshal(res)
		fmt.Fprintf(w, string(j))
		return
	}

	w.WriteHeader(http.StatusOK)
	res := &response{
		Status:  http.StatusOK,
		Message: "Machine account test OK",
	}
	j, _ := json.Marshal(res)
	fmt.Fprintf(w, string(j))

}

// {"id":"asas","message":"Settings updated","status":200} - save
// {"id":"adasd","message":"'adasd' created","status":201}
