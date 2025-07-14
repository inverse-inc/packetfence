package api

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"os"
	"strconv"

	"github.com/inverse-inc/packetfence/go/ntlm"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/julienschmidt/httprouter"
)

type PasswordChangeEvent struct {
	RecordID          int    `json:"RecordID"`
	TargetUserName    string `json:"TargetUserName"`
	SubjectUserSid    string `json:"SubjectUserSid"`
	EventTime         string `json:"EventTime"`
	SubjectLogonId    string `json:"SubjectLogonId"`
	SubjectUserName   string `json:"SubjectUserName"`
	SubjectDomainName string `json:"SubjectDomainName"`
	EventTypeID       int    `json:"EventTypeID"`
	TargetSid         string `json:"TargetSid"`
	TargetDomainName  string `json:"TargetDomainName"`
}

func (h APIHandler) eventReport(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	type response struct {
		Status  int    `json:"status"`
		Message string `json:"message"`
	}
	type payload struct {
		Domain string                   `json:"Domain"`
		Events []map[string]interface{} `json:"Events"`
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
		w.Write(j)
		return
	}

	b := bytes.NewBuffer(nil)
	b.ReadFrom(r.Body)
	var req payload
	err = json.Unmarshal(b.Bytes(), &req)
	if err != nil {
		w.WriteHeader(http.StatusUnprocessableEntity)
		res := &response{
			Status:  http.StatusUnprocessableEntity,
			Message: "Unknown payload format, expected Domain and Events JSON",
		}
		j, _ := json.Marshal(res)
		w.Write(j)
		return
	}

	var sectionConf pfconfigdriver.Domain
	var exists bool

	hostname, _ := os.Hostname()
	sectionConf, exists = domainConfig.Element[hostname+" "+req.Domain]
	if !exists {
		sectionConf, exists = domainConfig.Element[req.Domain]
	}
	if !exists {
		w.WriteHeader(http.StatusNotFound)
		res := &response{
			Status:  http.StatusNotFound,
			Message: "Unknown domain " + req.Domain + ", record not found",
		}
		j, _ := json.Marshal(res)
		w.Write(j)
		return
	}

	ntlmAuthPort := sectionConf.NtlmAuthPort
	ntlmAuthHost := sectionConf.NtlmAuthHost
	if ntlmAuthPort == "" {
		w.WriteHeader(http.StatusInternalServerError)
		res := &response{
			Status:  http.StatusInternalServerError,
			Message: "Unable to find listening port for domain " + req.Domain,
		}
		j, _ := json.Marshal(res)
		w.Write(j)
		return
	}

	if sectionConf.UseConnector == "1" {
		AuthPort, err := strconv.Atoi(ntlmAuthPort)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			res := &response{
				Status:  http.StatusInternalServerError,
				Message: "Invalid NTLM auth port for domain " + req.Domain,
			}
			j, _ := json.Marshal(res)
			w.Write(j)
			return
		}
		// Use connector for NTLM auth
		ntlmAuthPort = strconv.Itoa(AuthPort + 100)
	}
	ntlmAuthHostPort := ntlmAuthHost + ":" + ntlmAuthPort

	err = ntlm.ReportMSEvent(ctx, ntlmAuthHostPort, req)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		res := &response{
			Status:  http.StatusInternalServerError,
			Message: err.Error(),
		}
		j, _ := json.Marshal(res)
		w.Write(j)
		return
	}

	w.WriteHeader(http.StatusOK)
	res := &response{
		Status:  http.StatusOK,
		Message: "Event reported",
	}
	j, _ := json.Marshal(res)
	w.Write(j)
}

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
		w.Write(j)
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
		w.Write(j)
		return
	}

	var sectionConf pfconfigdriver.Domain
	var exists bool
	hostname, _ := os.Hostname()

	sectionConf, exists = domainConfig.Element[hostname+" "+req.Id]
	if !exists {
		sectionConf, exists = domainConfig.Element[req.Id]
	}
	if !exists {
		w.WriteHeader(http.StatusNotFound)
		res := &response{
			Status:  http.StatusNotFound,
			Message: "Unknown domain " + req.Id + ", record not found",
		}
		j, _ := json.Marshal(res)
		w.Write(j)
		return
	}
	ntlmAuthPort := sectionConf.NtlmAuthPort
	ntlmAuthHost := sectionConf.NtlmAuthHost
	if ntlmAuthPort == "" {
		w.WriteHeader(http.StatusInternalServerError)
		res := &response{
			Status:  http.StatusInternalServerError,
			Message: "Unable to find listening port for domain " + req.Id,
		}
		j, _ := json.Marshal(res)
		w.Write(j)
		return
	}
	if sectionConf.UseConnector == "1" {
		AuthPort, err := strconv.Atoi(ntlmAuthPort)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			res := &response{
				Status:  http.StatusInternalServerError,
				Message: "Invalid NTLM auth port for domain " + req.Id,
			}
			j, _ := json.Marshal(res)
			w.Write(j)
			return
		}
		// Use connector for NTLM auth
		ntlmAuthPort = strconv.Itoa(AuthPort + 100)
	}
	ntlmAuthHostPort := ntlmAuthHost + ":" + ntlmAuthPort
	passed, err := ntlm.CheckMachineAccountWithGivenPassword(ctx, ntlmAuthHostPort, req.Password)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		res := &response{
			Status:  http.StatusInternalServerError,
			Message: err.Error(),
		}
		j, _ := json.Marshal(res)
		w.Write(j)
		return
	}

	if !passed {
		w.WriteHeader(http.StatusUnauthorized)
		res := &response{
			Status:  http.StatusUnauthorized,
			Message: "Machine account check failed",
		}
		j, _ := json.Marshal(res)
		w.Write(j)
		return
	}

	w.WriteHeader(http.StatusOK)
	res := &response{
		Status:  http.StatusOK,
		Message: "Machine account test OK",
	}
	j, _ := json.Marshal(res)
	w.Write(j)
}
