package firewallsso

import (
	"bytes"
	"context"
	"fmt"
	"github.com/gorilla/rpc/v2/json2"
	"github.com/inverse-inc/packetfence/go/log"
	"net/http"
)

type JSONRPC struct {
	FirewallSSO
	Username string `json:"username"`
	Password string `json:"password"`
	Port     string `json:"port"`
}

type JSONRPC_Args struct {
	User    string `json:"user"`
	MAC     string `json:"mac"`
	IP      string `json:"ip"`
	Role    string `json:"role"`
	Timeout int    `json:"timeout"`
}

// Create JSON-RPC request body
func (fw *JSONRPC) getRequestBody(action string, info map[string]string, timeout int) ([]byte, error) {
	args := &JSONRPC_Args{
		User:    info["username"],
		MAC:     info["mac"],
		IP:      info["ip"],
		Role:    info["role"],
		Timeout: timeout,
	}
	body, err := json2.EncodeClientRequest(action, args)
	return body, err
}

// Make a JSON-RPC request
// Returns an error unless the server acknowledges success
func (fw *JSONRPC) makeRpcRequest(ctx context.Context, action string, info map[string]string, timeout int) error {
	body, err := fw.getRequestBody(action, info, timeout)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Cannot encode JSON-RPC call: %s", err))
		return err
	}

	req, err := http.NewRequest("POST", "https://"+fw.PfconfigHashNS+":"+fw.Port, bytes.NewBuffer(body))
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Cannot create HTTP request for JSON-RPC call: %s", err))
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.SetBasicAuth(fw.Username, fw.Password)

	resp, err := fw.getHttpClient(ctx).Do(req)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Cannot make HTTP request for JSON-RPC call: %s", err))
		return err
	}
	defer resp.Body.Close()

	var result [1]string
	err = json2.DecodeClientResponse(resp.Body, &result)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Cannot decode JSON-RPC response: %s", err))
		return err
	}

	if result[0] == "OK" {
		return nil
	} else {
		return fmt.Errorf("JSON-RPC call returned an error: %s", result[0])
	}
}

// Send an SSO start to the JSON-RPC server
func (fw *JSONRPC) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	err := fw.makeRpcRequest(ctx, "Start", info, timeout)
	return err == nil, err
}

// Send an SSO stop to the JSON-RPC server
func (fw *JSONRPC) Stop(ctx context.Context, info map[string]string) (bool, error) {
	err := fw.makeRpcRequest(ctx, "Stop", info, 0)
	return err == nil, err
}
