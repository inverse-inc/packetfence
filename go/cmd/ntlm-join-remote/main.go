package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/coreos/go-systemd/daemon"
	"github.com/gorilla/mux"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
)

var ctx = context.Background()

const (
	defaultListenAddr     = ":23000"
	impacketAddComputer   = "/usr/local/pf/bin/impacket-addcomputer"
	defaultCommandTimeout = 120 * time.Second
)

// AddComputerRequest represents the request body for adding/managing a computer account
type AddComputerRequest struct {
	// Account credentials in format [domain/]username[:password]
	Account string `json:"account"`
	// Password for the account (alternative to including in Account)
	Password string `json:"password,omitempty"`
	// Domain NetBIOS name (required if DC has multiple domains)
	DomainNetbios string `json:"domain_netbios,omitempty"`
	// Name of computer to add (with or without trailing $)
	ComputerName string `json:"computer_name,omitempty"`
	// Password to set for the computer account
	ComputerPass string `json:"computer_pass,omitempty"`
	// Don't add a computer, only set password on existing one
	NoAdd bool `json:"no_add,omitempty"`
	// Delete an existing computer
	Delete bool `json:"delete,omitempty"`
	// Method of adding the computer: SAMR or LDAPS
	Method string `json:"method,omitempty"`
	// Port to use: 139, 445, or 636
	Port int `json:"port,omitempty"`
	// Hostname of the domain controller
	DCHost string `json:"dc_host,omitempty"`
	// IP of the domain controller
	DCIP string `json:"dc_ip,omitempty"`
	// NTLM hashes in format LMHASH:NTHASH
	Hashes string `json:"hashes,omitempty"`
	// Use Kerberos authentication
	Kerberos bool `json:"kerberos,omitempty"`
	// AES key for Kerberos authentication
	AESKey string `json:"aes_key,omitempty"`
	// Base DN for LDAP
	BaseDN string `json:"base_dn,omitempty"`
	// Group to which the account will be added
	ComputerGroup string `json:"computer_group,omitempty"`
	// Enable debug output
	Debug bool `json:"debug,omitempty"`
	// Use StartTLS
	StartTLS bool `json:"start_tls,omitempty"`
	// Client certificate path
	ClientCert string `json:"client_cert,omitempty"`
	// Client key path
	ClientKey string `json:"client_key,omitempty"`
	// CA certificate path
	CACert string `json:"ca_cert,omitempty"`
	// Enable TLS Channel Binding
	ChannelBinding bool `json:"channel_binding,omitempty"`
}

// Response represents the API response
type Response struct {
	Success bool   `json:"success"`
	Message string `json:"message,omitempty"`
	Output  string `json:"output,omitempty"`
	Error   string `json:"error,omitempty"`
}

func main() {
	log.SetProcessName("ntlm-join-remote")
	ctx = log.LoggerNewContext(ctx)

	effectiveLogLevel := sharedutils.EnvOrDefault("LOG_LEVEL", "INFO")
	ctx = log.LoggerSetLevel(ctx, effectiveLogLevel)

	listenAddr := sharedutils.EnvOrDefault("NTLM_JOIN_REMOTE_LISTEN", defaultListenAddr)

	router := mux.NewRouter()
	router.HandleFunc("/api/v1/computer/add", handleAddComputer).Methods("POST")
	router.HandleFunc("/api/v1/computer/delete", handleDeleteComputer).Methods("POST")
	router.HandleFunc("/api/v1/computer/set-password", handleSetPassword).Methods("POST")
	router.HandleFunc("/api/v1/computer/run", handleRun).Methods("POST")
	router.HandleFunc("/api/v1/health", handleHealth).Methods("GET")

	srv := &http.Server{
		Addr:         listenAddr,
		IdleTimeout:  5 * time.Second,
		ReadTimeout:  defaultCommandTimeout + 10*time.Second,
		WriteTimeout: defaultCommandTimeout + 10*time.Second,
		Handler:      router,
	}

	log.LoggerWContext(ctx).Info(fmt.Sprintf("Starting ntlm-join-remote on %s", listenAddr))

	// Systemd notification
	daemon.SdNotify(false, "READY=1")

	// Watchdog goroutine
	go func() {
		interval, err := daemon.SdWatchdogEnabled(false)
		if err != nil || interval == 0 {
			return
		}
		for {
			daemon.SdNotify(false, "WATCHDOG=1")
			time.Sleep(interval / 3)
		}
	}()

	if err := srv.ListenAndServe(); err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Server error: %s", err.Error()))
		os.Exit(1)
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(Response{Success: true, Message: "OK"})
}

func handleAddComputer(w http.ResponseWriter, r *http.Request) {
	var req AddComputerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}

	// Ensure we're not deleting or just setting password
	req.Delete = false
	req.NoAdd = false

	executeImpacket(w, r, &req)
}

func handleDeleteComputer(w http.ResponseWriter, r *http.Request) {
	var req AddComputerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}

	if req.ComputerName == "" {
		sendError(w, http.StatusBadRequest, "computer_name is required for delete operation", "")
		return
	}

	req.Delete = true
	req.NoAdd = false

	executeImpacket(w, r, &req)
}

func handleSetPassword(w http.ResponseWriter, r *http.Request) {
	var req AddComputerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}

	if req.ComputerName == "" {
		sendError(w, http.StatusBadRequest, "computer_name is required for set-password operation", "")
		return
	}

	req.NoAdd = true
	req.Delete = false

	executeImpacket(w, r, &req)
}

func handleRun(w http.ResponseWriter, r *http.Request) {
	var req AddComputerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body", err.Error())
		return
	}

	executeImpacket(w, r, &req)
}

func executeImpacket(w http.ResponseWriter, r *http.Request, req *AddComputerRequest) {
	if req.Account == "" {
		sendError(w, http.StatusBadRequest, "account is required", "")
		return
	}

	args := buildArgs(req)

	log.LoggerWContext(r.Context()).Info(fmt.Sprintf("Executing impacket-addcomputer with args: %v", sanitizeArgs(args)))

	ctx, cancel := context.WithTimeout(r.Context(), defaultCommandTimeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, impacketAddComputer, args...)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()

	w.Header().Set("Content-Type", "application/json")

	if ctx.Err() == context.DeadlineExceeded {
		sendError(w, http.StatusGatewayTimeout, "Command timed out", "")
		return
	}

	if err != nil {
		log.LoggerWContext(r.Context()).Error(fmt.Sprintf("impacket-addcomputer failed: %s, stderr: %s", err.Error(), stderr.String()))
		sendError(w, http.StatusInternalServerError, "Command failed", fmt.Sprintf("%s\n%s", err.Error(), stderr.String()))
		return
	}

	output := stdout.String()
	if output == "" {
		output = stderr.String()
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(Response{
		Success: true,
		Message: "Command executed successfully",
		Output:  output,
	})
}

func buildArgs(req *AddComputerRequest) []string {
	var args []string

	// Account is the positional argument
	account := req.Account
	if req.Password != "" && !strings.Contains(account, ":") {
		account = fmt.Sprintf("%s:%s", account, req.Password)
	}
	args = append(args, account)

	if req.DomainNetbios != "" {
		args = append(args, "-domain-netbios", req.DomainNetbios)
	}

	if req.ComputerName != "" {
		args = append(args, "-computer-name", req.ComputerName)
	}

	if req.ComputerPass != "" {
		args = append(args, "-computer-pass", req.ComputerPass)
	}

	if req.NoAdd {
		args = append(args, "-no-add")
	}

	if req.Delete {
		args = append(args, "-delete")
	}

	if req.Method != "" {
		args = append(args, "-method", req.Method)
	}

	if req.Port != 0 {
		args = append(args, "-port", fmt.Sprintf("%d", req.Port))
	}

	if req.DCHost != "" {
		args = append(args, "-dc-host", req.DCHost)
	}

	if req.DCIP != "" {
		args = append(args, "-dc-ip", req.DCIP)
	}

	if req.Hashes != "" {
		args = append(args, "-hashes", req.Hashes)
	}

	if req.Kerberos {
		args = append(args, "-k")
	}

	if req.AESKey != "" {
		args = append(args, "-aesKey", req.AESKey)
	}

	if req.BaseDN != "" {
		args = append(args, "-baseDN", req.BaseDN)
	}

	if req.ComputerGroup != "" {
		args = append(args, "-computer-group", req.ComputerGroup)
	}

	if req.Debug {
		args = append(args, "-debug")
	}

	if req.StartTLS {
		args = append(args, "-start-tls")
	}

	if req.ClientCert != "" {
		args = append(args, "-client-cert", req.ClientCert)
	}

	if req.ClientKey != "" {
		args = append(args, "-client-key", req.ClientKey)
	}

	if req.CACert != "" {
		args = append(args, "-ca-cert", req.CACert)
	}

	if req.ChannelBinding {
		args = append(args, "-channel-binding")
	}

	return args
}

// sanitizeArgs removes sensitive information from args for logging
func sanitizeArgs(args []string) []string {
	sanitized := make([]string, len(args))
	copy(sanitized, args)

	sensitiveFlags := map[string]bool{
		"-computer-pass": true,
		"-hashes":        true,
		"-aesKey":        true,
	}

	for i := 0; i < len(sanitized); i++ {
		if sensitiveFlags[sanitized[i]] && i+1 < len(sanitized) {
			sanitized[i+1] = "****"
		}
		// Also sanitize password in account string
		if i == 0 && strings.Contains(sanitized[i], ":") {
			parts := strings.SplitN(sanitized[i], ":", 2)
			if len(parts) == 2 {
				sanitized[i] = parts[0] + ":****"
			}
		}
	}

	return sanitized
}

func sendError(w http.ResponseWriter, statusCode int, message, errDetail string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(Response{
		Success: false,
		Message: message,
		Error:   errDetail,
	})
}
