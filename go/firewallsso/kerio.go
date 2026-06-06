package firewallsso

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/config/pfcrypt"
)

// Kerio Control firewall SSO.
//
// Kerio Control exposes a JSON-RPC Administration API (default port 4081) at
// /admin/api/jsonrpc/. SSO is performed by binding a username to an existing
// "active host" entry:
//   - Session.login           -> obtain an X-Token (+ session cookie)
//   - ActiveHosts.get         -> resolve the device IP to its active-host id
//   - ActiveHosts.login       -> bind {hostId, userName}
//   - ActiveHosts.logout      -> clear the binding for {ids}
//   - Session.logout          -> drop the admin session
//
// The device must already be present in Kerio's Active Hosts (Kerio must be the
// gateway/in-path for the user network) for the bind to attach.
type Kerio struct {
	FirewallSSO
	Username string              `json:"username"`
	Password pfcrypt.CryptString `json:"password"`
	Port     string              `json:"port"`
}

// Firewall specific init: default the API port to 4081 if unset.
func (fw *Kerio) initChild(ctx context.Context) error {
	if fw.Port == "" {
		log.LoggerWContext(ctx).Debug("Setting default Kerio API port 4081 as it isn't defined")
		fw.Port = "4081"
	}
	return nil
}

// --- minimal JSON-RPC session client -------------------------------------

type kerioError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type kerioResponse struct {
	Result json.RawMessage `json:"result"`
	Error  *kerioError     `json:"error"`
}

type kerioHost struct {
	ID json.Number `json:"id"`
	IP string      `json:"ip"`
}

type kerioHostList struct {
	List       []kerioHost `json:"list"`
	TotalItems int         `json:"totalItems"`
}

// kerioSession holds the state for a single Start/Stop operation.
type kerioSession struct {
	client *http.Client
	url    string
	user   string
	pass   string
	token  string
	cookie string
	id     int
}

func (fw *Kerio) newSession(ctx context.Context) *kerioSession {
	dst := fw.getDst(ctx, "tcp", fw.PfconfigHashNS, fw.Port)
	return &kerioSession{
		client: fw.getHttpClient(ctx),
		url:    "https://" + dst + "/admin/api/jsonrpc/",
		user:   fw.Username,
		pass:   fw.Password.String(),
	}
}

// raw performs a single JSON-RPC POST. When auth is true the X-Token and
// session cookie are attached.
func (s *kerioSession) raw(ctx context.Context, method string, params interface{}, auth bool) (json.RawMessage, *kerioError, error) {
	s.id++
	reqBody, err := json.Marshal(map[string]interface{}{
		"jsonrpc": "2.0",
		"id":      s.id,
		"method":  method,
		"params":  params,
	})
	if err != nil {
		return nil, nil, err
	}

	req, err := http.NewRequest("POST", s.url, bytes.NewReader(reqBody))
	if err != nil {
		return nil, nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if auth {
		req.Header.Set("X-Token", s.token)
		if s.cookie != "" {
			req.Header.Set("Cookie", s.cookie)
		}
	}

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, nil, err
	}
	defer resp.Body.Close()

	if sc := resp.Header.Get("Set-Cookie"); sc != "" {
		s.cookie = strings.SplitN(sc, ";", 2)[0]
	}

	var out kerioResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, nil, err
	}
	return out.Result, out.Error, nil
}

// login authenticates and stores the session token.
func (s *kerioSession) login(ctx context.Context) error {
	s.cookie = ""
	params := map[string]interface{}{
		"userName": s.user,
		"password": s.pass,
		"application": map[string]string{
			"name":    "PacketFence",
			"vendor":  "PacketFence",
			"version": "1.0",
		},
	}
	res, apiErr, err := s.raw(ctx, "Session.login", params, false)
	if err != nil {
		return err
	}
	if apiErr != nil {
		return fmt.Errorf("Kerio Session.login failed: %s", apiErr.Message)
	}
	var r struct {
		Token string `json:"token"`
	}
	if err := json.Unmarshal(res, &r); err != nil {
		return err
	}
	if r.Token == "" {
		return fmt.Errorf("Kerio Session.login returned no token")
	}
	s.token = r.Token
	return nil
}

// call logs in lazily and retries once if the session expired (-32001).
func (s *kerioSession) call(ctx context.Context, method string, params interface{}) (json.RawMessage, error) {
	if s.token == "" {
		if err := s.login(ctx); err != nil {
			return nil, err
		}
	}
	res, apiErr, err := s.raw(ctx, method, params, true)
	if err != nil {
		return nil, err
	}
	if apiErr != nil {
		if apiErr.Code == -32001 { // session expired, relogin once
			if err := s.login(ctx); err != nil {
				return nil, err
			}
			res, apiErr, err = s.raw(ctx, method, params, true)
			if err != nil {
				return nil, err
			}
			if apiErr != nil {
				return nil, fmt.Errorf("Kerio %s failed: %s", method, apiErr.Message)
			}
			return res, nil
		}
		return nil, fmt.Errorf("Kerio %s failed: %s", method, apiErr.Message)
	}
	return res, nil
}

// logout drops the admin session (best effort).
func (s *kerioSession) logout(ctx context.Context) {
	if s.token == "" {
		return
	}
	s.raw(ctx, "Session.logout", map[string]interface{}{}, true)
}

// hostIDByIP resolves an IP to its Kerio active-host id, or "" if not present.
func (s *kerioSession) hostIDByIP(ctx context.Context, ip string) (json.Number, error) {
	query := map[string]interface{}{
		"fields":     []string{},
		"conditions": []interface{}{},
		"combining":  "Or",
		"start":      0,
		"limit":      100000,
		"orderBy":    []interface{}{},
	}
	res, err := s.call(ctx, "ActiveHosts.get", map[string]interface{}{"query": query, "refresh": true})
	if err != nil {
		return "", err
	}
	var hl kerioHostList
	if err := json.Unmarshal(res, &hl); err != nil {
		return "", err
	}
	for _, h := range hl.List {
		if h.IP == ip {
			return h.ID, nil
		}
	}
	return "", nil
}

// --- FirewallSSO interface ------------------------------------------------

// Send an SSO start: resolve the host then bind the username to it.
func (fw *Kerio) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	s := fw.newSession(ctx)
	defer s.logout(ctx)

	hostID, err := s.hostIDByIP(ctx, info["ip"])
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Couldn't query Kerio active hosts: %s", err))
		return false, err
	}
	if hostID == "" {
		err := fmt.Errorf("no Kerio active host for IP %s (is Kerio the gateway for this network?)", info["ip"])
		log.LoggerWContext(ctx).Warn(err.Error())
		return false, err
	}

	// Clear any stale binding first, then bind the user (mirrors a re-login).
	s.call(ctx, "ActiveHosts.logout", map[string]interface{}{"ids": []json.Number{hostID}})

	_, err = s.call(ctx, "ActiveHosts.login", map[string]interface{}{
		"hostId":   hostID,
		"userName": info["username"],
	})
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Couldn't SSO to Kerio: %s", err))
		return false, err
	}
	return true, nil
}

// Send an SSO stop: clear the binding for the device's active host.
func (fw *Kerio) Stop(ctx context.Context, info map[string]string) (bool, error) {
	s := fw.newSession(ctx)
	defer s.logout(ctx)

	hostID, err := s.hostIDByIP(ctx, info["ip"])
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Couldn't query Kerio active hosts: %s", err))
		return false, err
	}
	if hostID == "" {
		// Nothing bound for this IP, treat as success.
		return true, nil
	}

	_, err = s.call(ctx, "ActiveHosts.logout", map[string]interface{}{"ids": []json.Number{hostID}})
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Couldn't SSO stop to Kerio: %s", err))
		return false, err
	}
	return true, nil
}
