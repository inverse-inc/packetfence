package chserver

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	chshare "github.com/inverse-inc/packetfence/go/chisel/share"
	"github.com/inverse-inc/packetfence/go/chisel/share/cnet"
	"github.com/inverse-inc/packetfence/go/chisel/share/settings"
	"github.com/inverse-inc/packetfence/go/chisel/share/tunnel"
	"github.com/inverse-inc/packetfence/go/cluster"
	connector "github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/pfk8s"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
	"golang.org/x/crypto/ssh"
	"golang.org/x/sync/errgroup"
)

var credcachePathPrefix = apiPrefix + "/credcache/"

const credcacheClientTarget = "127.0.0.1:8081"

var activeTunnels = sync.Map{}
var apiPrefix = "/api/v1/pfconnector"

const (
	DYNREVERSE_BIND_ATTEMPTS = 10
	DYNREVERSE_ERR_WAIT      = 50 * time.Millisecond
)

// handleClientHandler is the main http websocket handler for the chisel server
func (s *Server) handleClientHandler(w http.ResponseWriter, r *http.Request) {
	// Transfer the logger from baseCtx to the request context to preserve log level settings
	ctx := log.TranferLogContext(s.baseCtx, r.Context())
	// Create a new request with the modified context so all handlers use proper logging
	r = r.WithContext(ctx)

	log.LoggerWContext(ctx).Info(fmt.Sprintf("Handling %s %s", r.Method, r.URL.Path))

	s.connectors.Refresh(ctx)

	//websockets upgrade AND has chisel prefix
	upgrade := strings.ToLower(r.Header.Get("Upgrade"))
	protocol := r.Header.Get("Sec-WebSocket-Protocol")
	if upgrade == "websocket" && strings.HasPrefix(protocol, "chisel-") {
		if protocol == chshare.ProtocolVersion {
			s.handleWebsocket(w, r)
			return
		}
		//print into server logs and silently fall-through
		s.Infof("ignored client connection using protocol '%s', expected '%s'",
			protocol, chshare.ProtocolVersion)
	}
	//proxy target was provided
	if s.reverseProxy != nil {
		s.reverseProxy.ServeHTTP(w, r)
		return
	}
	//no proxy defined, provide access to health/version checks
	switch r.URL.Path {
	case apiPrefix + "/ping":
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("pong"))
		return
	case apiPrefix + "/version":
		w.Write([]byte(chshare.BuildVersion))
		return
	case apiPrefix + "/dynreverse":
		s.handleDynReverse(w, r)
		return
	case apiPrefix + "/remote-binds":
		s.handleRemoteBinds(w, r)
		return
	case apiPrefix + "/all-fingerbank-collector-endpoints":
		s.handleAllFingerbankCollectorEndpoints(w, r)
		return
	case apiPrefix + "/local-fingerbank-collector-endpoints":
		s.handleLocalFingerbankCollectorEndpoints(w, r)
		return
	case apiPrefix + "/remote-fingerbank-collector-env":
		s.handleRemoteFingerbankCollectorEnv(w, r)
		return
	case apiPrefix + "/remote-fingerbank-collector-nba-conf":
		s.handleRemoteFingerbankCollectorNbaConf(w, r)
		return
	case apiPrefix + "/remote-ntlm-auth-api-env":
		s.handleRemoteNtlmAuthAPIEnv(w, r)
		return
	case apiPrefix + "/remote-ntlm-auth-api-db":
		s.handleRemoteNtlmAuthAPIDB(w, r)
		return
	case apiPrefix + "/remote-radius-conf":
		s.handleRemoteRadiusConf(w, r)
		return
	case apiPrefix + "/remote-radius-nas":
		s.handleRemoteRadiusNas(w, r)
		return
	case apiPrefix + "/local-secret":
		s.handleLocalSecret(w, r)
		return
	case apiPrefix + "/radius-secret":
		s.handleRadiusSecret(w, r)
		return
	case apiPrefix + "/multi-domain-config":
		s.handleRemoteMultiDomainConfig(w, r)
		return
	case apiPrefix + "/connector-status":
		s.handleConnectorStatus(w, r)
		return
	case apiPrefix + "/health":
		s.handleConnectorHealth(w, r)
		return
	}
	if strings.HasPrefix(r.URL.Path, credcachePathPrefix) {
		s.handleCredcacheForward(w, r)
		return
	}
	//missing :O
	w.WriteHeader(404)
	w.Write([]byte("Not found"))
}

// handleCredcacheForward routes /api/v1/pfconnector/credcache/<connector-id>/...
// through the matching active tunnel to the chisel-client's local
// /api/v1/credcache proxy on 127.0.0.1:8081. The connector-id is taken from
// the first path segment after /credcache/.
func (s *Server) handleCredcacheForward(w http.ResponseWriter, r *http.Request) {
	rest := strings.TrimPrefix(r.URL.Path, credcachePathPrefix)
	connectorId, suffix, _ := strings.Cut(rest, "/")
	if connectorId == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusBadRequest, Message: "Missing connector_id in path"})
		return
	}
	o, ok := activeTunnels.Load(connectorId)
	if !ok {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusNotFound, Message: fmt.Sprintf("Unable to find active connector tunnel: %s", connectorId)})
		return
	}
	tun := o.(*tunnel.Tunnel)
	if !tun.IsActive() {
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusServiceUnavailable, Message: fmt.Sprintf("Tunnel for %s is not active", connectorId)})
		return
	}

	// Bound the channel open so a flapping connector can't pin this request
	// goroutine for the full SSH_WAIT window while OpenChiselChannel blocks.
	openCtx, cancelOpen := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancelOpen()
	ch, err := tun.OpenChiselChannel(openCtx, credcacheClientTarget)
	if err != nil {
		log.LoggerWContext(r.Context()).Error(fmt.Sprintf("credcache forward: open channel to %s failed: %s", connectorId, err))
		w.WriteHeader(http.StatusBadGateway)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusBadGateway, Message: fmt.Sprintf("Failed to open tunnel channel: %s", err)})
		return
	}
	defer ch.Close()

	forwarded := r.Clone(r.Context())
	forwarded.RequestURI = ""
	forwarded.URL = &url.URL{
		Scheme:   "http",
		Host:     credcacheClientTarget,
		Path:     "/api/v1/credcache/" + suffix,
		RawQuery: r.URL.RawQuery,
	}
	forwarded.Host = credcacheClientTarget
	forwarded.Header = r.Header.Clone()
	forwarded.Header.Del("Connection")
	forwarded.Close = true

	if err := forwarded.Write(ch); err != nil {
		log.LoggerWContext(r.Context()).Error(fmt.Sprintf("credcache forward: write request to %s failed: %s", connectorId, err))
		w.WriteHeader(http.StatusBadGateway)
		return
	}

	resp, err := http.ReadResponse(bufio.NewReader(ch), forwarded)
	if err != nil {
		log.LoggerWContext(r.Context()).Error(fmt.Sprintf("credcache forward: read response from %s failed: %s", connectorId, err))
		w.WriteHeader(http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	for k, vs := range resp.Header {
		for _, v := range vs {
			w.Header().Add(k, v)
		}
	}
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

// handleWebsocket is responsible for handling the websocket connection
func (s *Server) handleWebsocket(w http.ResponseWriter, req *http.Request) {
	id := atomic.AddInt32(&s.sessCount, 1)
	l := s.Fork("session#%d", id)
	wsConn, err := upgrader.Upgrade(w, req, nil)
	if err != nil {
		l.Debugf("Failed to upgrade (%s)", err)
		return
	}
	conn := cnet.NewWebSocketConn(wsConn)
	// perform SSH handshake on net.Conn
	l.Debugf("Handshaking with %s...", req.RemoteAddr)
	sshConn, chans, reqs, err := ssh.NewServerConn(conn, s.sshConfig)
	if err != nil {
		s.Debugf("Failed to handshake (%s)", err)
		return
	}
	// pull the users from the session map
	var user *settings.User
	if s.users.Len() > 0 {
		sid := string(sshConn.SessionID())
		u, ok := s.sessions.Get(sid)
		if !ok {
			panic("bug in ssh auth handler")
		}
		user = u
		s.sessions.Del(sid)
	}
	// chisel server handshake (reverse of client handshake)
	// verify configuration
	l.Debugf("Verifying configuration")
	// wait for request, with timeout
	var r *ssh.Request
	select {
	case r = <-reqs:
	case <-time.After(settings.EnvDuration("CONFIG_TIMEOUT", 10*time.Second)):
		l.Debugf("Timeout waiting for configuration")
		sshConn.Close()
		return
	}
	failed := func(err error) {
		l.Debugf("Failed: %s", err)
		r.Reply(false, []byte(err.Error()))
	}
	if r.Type != "config" {
		failed(s.Errorf("expecting config request"))
		return
	}
	c, err := settings.DecodeConfig(r.Payload)
	if err != nil {
		failed(s.Errorf("invalid config"))
		return
	}
	//print if client and server  versions dont match
	if c.Version != chshare.BuildVersion {
		v := c.Version
		if v == "" {
			v = "<unknown>"
		}
		l.Infof("Client version (%s) differs from server version (%s)",
			v, chshare.BuildVersion)
	}
	//validate remotes
	for _, r := range c.Remotes {
		//if user is provided, ensure they have
		//access to the desired remotes
		if user != nil {
			addr := r.UserAddr()
			if !user.HasAccess(addr) {
				failed(s.Errorf("access to '%s' denied", addr))
				return
			}
		}
		//confirm reverse tunnels are allowed
		if r.Reverse && !s.config.Reverse {
			l.Debugf("Denied reverse port forwarding request, please enable --reverse")
			failed(s.Errorf("Reverse port forwaring not enabled on server"))
			return
		}
		//confirm reverse tunnel is available
		if r.Reverse && !r.CanListen() {
			failed(s.Errorf("Server cannot listen on %s", r.String()))
			return
		}
	}

	localSecret := pfconfigdriver.LocalSecret{}
	if err := pfconfigdriver.FetchDecodeSocket(req.Context(), &localSecret); err != nil {
		l.Infof("Failed to fetch local secret from pfconfig, continuing without it: %s", err)
	}
	pfconnectorStaticConnections := pfconfigdriver.PfconnectorStaticConnections{}
	if err := pfconfigdriver.FetchDecodeSocket(req.Context(), &pfconnectorStaticConnections); err != nil {
		l.Infof("Failed to fetch pfconnector static connections from pfconfig, continuing without them: %s", err)
	}
	additionalRemotes := chshare.Remotes{}
	if remotes, found := pfconnectorStaticConnections.Element[user.Name]; found {
		for _, remoteDef := range remotes {
			if remote, err := settings.DecodeRemote(remoteDef); err == nil {
				additionalRemotes = append(additionalRemotes, remote)
			}
		}
	}

	if client := pfk8s.NewAdminClientFromEnv(); client != nil {
		patchPortsAdd := []pfk8s.PatchPorts{}
		patchPortsDel := []pfk8s.PatchPorts{}

		services, err := client.GetService("pfconnector")
		if err != nil {
			l.Printf("Error getting pfconnector service: %v", err)
			// If we can't get the service, we can't patch it, so we just return
		}

		for _, remote := range additionalRemotes {
			port, _ := strconv.ParseUint(remote.LocalPort, 10, 16)
			for index, port := range services.Spec.Ports {
				if port.Name == "port-"+strings.ToLower(remote.LocalProto)+"-"+remote.LocalPort {
					// If the port already exists, we need to remove it first

					patchPortsDel = append(patchPortsDel, pfk8s.PatchPorts{
						Op:   "remove",
						Path: "/spec/ports/" + strconv.Itoa(index),
					})
				}
			}

			patchPortsAdd = append(patchPortsAdd, pfk8s.PatchPorts{
				Op:   "add",
				Path: "/spec/ports/-",
				Value: pfk8s.PatchPortAdd{
					Port:       int(port),
					TargetPort: int(port),
					Protocol:   strings.ToUpper(remote.LocalProto),
					Name:       "port-" + strings.ToLower(remote.LocalProto) + "-" + remote.LocalPort,
				},
			})
		}
		if err := client.PatchPorts(patchPortsDel); err != nil {
			l.Printf("Error deleting ports: %v", err)
		}
		if err := client.PatchPorts(patchPortsAdd); err != nil {
			l.Printf("Error adding ports: %v", err)
		}
	}

	//successfuly validated config!
	r.Reply(true, nil)
	//tunnel per ssh connection
	tunnel := tunnel.New(tunnel.Config{
		Logger:       l,
		Inbound:      s.config.Reverse,
		Outbound:     true, //server always accepts outbound
		Socks:        s.config.Socks5,
		KeepAlive:    s.config.KeepAlive,
		RadiusSecret: localSecret.Element,
	})
	//bind
	eg, ctx := errgroup.WithContext(req.Context())
	eg.Go(func() error {
		//connected, handover ssh connection for tunnel to use, and block
		return tunnel.BindSSH(ctx, sshConn, reqs, chans)
	})
	//connected, setup reversed-remotes?
	serverInbound := c.Remotes.Reversed(true)
	serverInbound = append(serverInbound, additionalRemotes...)
	eg.Go(func() error {
		if len(serverInbound) == 0 {
			return nil
		}
		//block
		return tunnel.BindRemotes(ctx, serverInbound)
	})
	if user != nil {
		l.Infof("Connector %s has just connected to this server", user.Name)
		settings.ClearActiveDynReverseConnector(ctx, user.Name)
		activeTunnels.Store(user.Name, tunnel)
		tunnel.ConnectorID = user.Name
		res := s.redis.Set(ctx, fmt.Sprintf("%s%s", s.redisTunnelsNamespace, user.Name), fmt.Sprintf("%s://%s", s.listenProto, req.Context().Value(http.LocalAddrContextKey).(net.Addr).String()), 0)
		if res.Err() != nil {
			l.Infof("Unable to write tunnel info to Redis: %s", res.Err())
		}
	}
	err = eg.Wait()
	if err != nil && !strings.HasSuffix(err.Error(), "EOF") {
		l.Debugf("Closed connection (%s)", err)
	} else {
		l.Debugf("Closed connection")
	}
}

func (s *Server) pfconnectorHost(req *http.Request) string {
	hostPort := strings.Split(req.Context().Value(http.LocalAddrContextKey).(net.Addr).String(), ":")
	host := sharedutils.EnvOrDefault("PFCONNECTOR_SERVER_DYN_REVERSE_HOST", strings.Join(hostPort[0:len(hostPort)-1], ":"))

	return host
}

func (s *Server) handleDynReverse(w http.ResponseWriter, req *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	payload := struct {
		ConnectorID string `json:"connector_id"`
		To          string `json:"to"`
		LocalPort   string `json:"local_port,omitempty"`
	}{}

	err := json.NewDecoder(req.Body).Decode(&payload)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusBadRequest, Message: fmt.Sprintf("Unable to decode JSON payload: %s", err)})
		return
	}

	host := s.pfconnectorHost(req)

	cacheKey := fmt.Sprintf("%s:%s", payload.ConnectorID, payload.To)
	if o, found := settings.ActiveDynReverse.Load(cacheKey); found {
		remote := o.(*settings.Remote)
		remote.Lock()
		defer remote.Unlock()
		remote.LastTouched = time.Now()
		json.NewEncoder(w).Encode(gin.H{"host": host, "port": remote.LocalPort, "message": fmt.Sprintf("Reusing existing port %s", remote.LocalPort)})
		return
	}

	connectorId := payload.ConnectorID
	if o, ok := activeTunnels.Load(connectorId); ok {
		for i := 0; i < DYNREVERSE_BIND_ATTEMPTS; i++ {
			tun := o.(*tunnel.Tunnel)
			to := payload.To
			if payload.LocalPort != "" {
				to = fmt.Sprintf("%s:%s", payload.LocalPort, to)
			} else {
				to = fmt.Sprintf("0:%s", to)
			}
			remoteStr := fmt.Sprintf("R:%s", to)
			remote, err := settings.DecodeRemote(remoteStr)
			if err != nil {
				w.WriteHeader(http.StatusBadRequest)
				json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusBadRequest, Message: fmt.Sprintf("The format for the remote (%s) is invalid: %s", to, err)})
				return
			}

			remote.LastTouched = time.Now()
			dynPort := remote.LocalPort
			settings.ActiveDynReverse.Store(cacheKey, remote)
			bindErrChan := make(chan error)
			go func() {
				ctx := context.Background()
				if err := tun.BindRemotes(ctx, []*settings.Remote{remote}); err != nil {
					log.LoggerWContext(ctx).Error(fmt.Sprintf("Error binding remote %s: %s", remote, err))
					settings.ActiveDynReverse.Delete(cacheKey)
					bindErrChan <- err
				} else {
					bindErrChan <- nil
				}
			}()

			doneChan := make(chan error)
			go func() {
				sentOnce := false
				var err error
				for {
					select {
					case <-time.After(DYNREVERSE_ERR_WAIT):
						if !sentOnce {
							doneChan <- err
							sentOnce = true
						}
					case err = <-bindErrChan:
						if !sentOnce {
							doneChan <- err
						}
						// We're all done waiting if bindErrChan has sent something
						return
					}
				}
			}()

			err = <-doneChan

			if err == nil {
				json.NewEncoder(w).Encode(gin.H{"host": host, "port": dynPort, "message": fmt.Sprintf("Setup remote %s", remoteStr)})
				return
			} else {
				log.LoggerWContext(req.Context()).Error(fmt.Sprintf("Failed to bind remote, will try again. Error: %s", err))
			}
		}
		// If we're here, then we failed multiple times at creating the remote. There must be something terribly wrong
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusInternalServerError, Message: "Unable to create dynreverse remote"})
		return
	} else {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusNotFound, Message: fmt.Sprintf("Unable to find active connector tunnel: %s", connectorId)})
		return
	}
}

var baseFingerbankPort = 23000
var maxCheckedInConnectors = 256

func (s *Server) handleRemoteBinds(w http.ResponseWriter, req *http.Request) {
	connectorId := req.URL.Query().Get("connector-id")
	if connectorId == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusNotFound, Message: "Missing connector-id query parameter"})
		return
	}

	if o, ok := activeTunnels.Load(connectorId); ok {
		tun := o.(*tunnel.Tunnel)
		index := s.computeConnectorIndex(connectorId)

		if index > maxCheckedInConnectors {
			log.LoggerWContext(req.Context()).Error(fmt.Sprintf("Too many connectors are currently connected on this server. Denying access to %s", connectorId))
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusInternalServerError, Message: "Too many connectors are currently connected on this server."})
			return
		}

		fingerbankLocalPort := baseFingerbankPort + index
		managementNetwork := pfconfigdriver.GetType[pfconfigdriver.ManagementNetwork](req.Context())

		var managementIP string
		if managementNetwork.Vip != "" {
			managementIP = managementNetwork.Vip
		} else {
			managementIP = managementNetwork.Ip
		}

		remoteStrs := []string{fmt.Sprintf("R:%d:127.0.0.1:4723", fingerbankLocalPort)}
		remotes := make([]*settings.Remote, len(remoteStrs))
		for i, remoteStr := range remoteStrs {
			remote, err := settings.DecodeRemote(remoteStr)
			sharedutils.CheckError(err)
			remotes[i] = remote
		}

		tun.IsRemoteConnector = true

		go func() {
			// TODO: handle an error
			tun.BindDynamicRemotes(remotes)
		}()

		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(gin.H{"binds": []string{
			fmt.Sprintf("80:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_80", fmt.Sprintf("%s:80", managementIP))),
			fmt.Sprintf("443:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_443", fmt.Sprintf("%s:443", managementIP))),
			fmt.Sprintf("100.64.0.1:18122:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_1812", fmt.Sprintf("%s:1812/udp|radius", managementIP))),
			fmt.Sprintf("1813:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_1813", fmt.Sprintf("%s:1813/udp|radius", managementIP))),
			fmt.Sprintf("1815:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_1815", fmt.Sprintf("%s:1815/udp|radius", managementIP))),
			fmt.Sprintf("9096:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_9096", fmt.Sprintf("%s:9096", managementIP))),
			fmt.Sprintf("containers-gateway.internal:3306:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_3306", fmt.Sprintf("%s:3306", managementIP))),
			fmt.Sprintf("containers-gateway.internal:6379:%s", sharedutils.EnvOrDefault("REDIS_CACHE_HOST_PORT", fmt.Sprintf("%s:6379", "127.0.0.1"))),
		}})
	} else {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusNotFound, Message: fmt.Sprintf("Unable to find active connector tunnel: %s", connectorId)})
		return
	}
}

type FingerbankServersReply struct {
	Servers []string `json:"servers"`
}

func (s *Server) handleAllFingerbankCollectorEndpoints(w http.ResponseWriter, req *http.Request) {
	ctx := req.Context()

	replies := map[string]*FingerbankServersReply{}
	createResponseStructPtr := func(serverId string) interface{} {
		replies[serverId] = &FingerbankServersReply{}
		return replies[serverId]
	}
	errs := map[string]error{}

	if pfk8s.IsRunningInK8S() {
		c := pfk8s.NewClientFromEnv()
		errs = c.UnifiedAPICallDeployment(
			context.Background(),
			false,
			sharedutils.EnvOrDefault("PFCONNECTOR_K8S_DEPLOYMENT_NAME", "pfconnector"),
			"GET",
			"/api/v1/pfconnector/local-fingerbank-collector-endpoints",
			createResponseStructPtr,
		)
	} else if _, clusterEnabled := cluster.EnabledServers(ctx); clusterEnabled {
		errs = cluster.UnifiedAPICallCluster(ctx, "GET", "/api/v1/pfconnector/local-fingerbank-collector-endpoints", createResponseStructPtr)
	} else {
		// Does an early return as it builds the response using the local data only
		s.handleLocalFingerbankCollectorEndpoints(w, req)
		return
	}

	for serverId, err := range errs {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error collecting fingerbank collector servers on %s: %s", serverId, err))
	}

	collectors := []string{}
	for _, resp := range replies {
		collectors = append(collectors, resp.Servers...)
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(FingerbankServersReply{Servers: collectors})
}

func (s *Server) handleLocalFingerbankCollectorEndpoints(w http.ResponseWriter, req *http.Request) {
	collectors := []string{}
	activeTunnels.Range(func(k, v interface{}) bool {
		tun := v.(*tunnel.Tunnel)
		// Only consider tunnels with an active connection
		if tun.IsActive() && tun.IsRemoteConnector {
			host := s.pfconnectorHost(req)
			fingerbankLocalPort := baseFingerbankPort + s.computeConnectorIndex(k.(string))
			collectors = append(collectors, fmt.Sprintf("http://%s:%d", host, fingerbankLocalPort))
		}
		return true
	})
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(FingerbankServersReply{Servers: collectors})
}

// fakeMachineAccountPassword masks the real AD machine-account secret for
// connectors that are not next to the domain's AD. It is a valid-length,
// obviously-fake NT-hash-shaped value: the ntlm-auth-api still starts and can
// serve cached auth, but cannot talk to AD with it.
const fakeMachineAccountPassword = "00000000000000000000000000000000"

func (s *Server) handleRemoteNtlmAuthAPIEnv(w http.ResponseWriter, req *http.Request) {
	connectorId := req.URL.Query().Get("CONNECTOR_ID")
	domains := pfconfigdriver.Domains{}
	if err := pfconfigdriver.FetchDecodeSocket(req.Context(), &domains); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusInternalServerError, Message: fmt.Sprintf("Unable to fetch domains from pfconfig: %s", err)})
		return
	}
	Connectors := connector.NewConnectorsContainer(req.Context())
	Domains := maskDomainSecretsForConnector(domains.Element, connectorId, func(ip net.IP) string {
		owner := Connectors.ForIP(req.Context(), ip)
		if owner == nil {
			return ""
		}
		return owner.PfconfigHashNS
	})
	jsonData, err := json.Marshal(Domains)
	w.Header().Set("Content-Type", "application/json")
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusInternalServerError, Message: fmt.Sprintf("Error while marshalling domains: %s", err)})
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write(jsonData)
}

// maskDomainSecretsForConnector builds the per-connector domain view served by
// handleRemoteNtlmAuthAPIEnv. It keeps only use_connector-enabled domains, and
// replaces machine_account_password with fakeMachineAccountPassword unless
// connectorId is the connector that owns the domain's AD (i.e.
// ownerForIP(ad_server) == connectorId). An empty connectorId (an unidentified
// caller) is treated as a non-owner for every domain, so its secrets are masked.
//
// ownerForIP resolves a domain's ad_server IP to the owning connector id; it is
// injected so this decision logic can be unit-tested without a live pfconfig
// socket or connectors container.
func maskDomainSecretsForConnector(domains map[string]pfconfigdriver.Domain, connectorId string, ownerForIP func(net.IP) string) map[string]pfconfigdriver.Domain {
	out := make(map[string]pfconfigdriver.Domain, len(domains))
	for domain, d := range domains {
		// Only connector-served domains are relevant to a remote; connector-less
		// domains are handled centrally.
		if !sharedutils.IsEnabled(d.UseConnector) {
			continue
		}
		// The connector next to the AD (owning the ad_server IP) gets the real
		// machine-account secret; everyone else gets the same config with the
		// secret masked so its ntlm-auth-api can still start and serve cached auth
		// without ever receiving credentials it has no use for. d is the range
		// copy, so mutating it does not touch the caller's source map.
		if connectorId == "" || ownerForIP(net.ParseIP(d.AdServer)) != connectorId {
			d.MachineAccountPassword = fakeMachineAccountPassword
		}
		out[domain] = d
	}
	return out
}

func (s *Server) handleRemoteNtlmAuthAPIDB(w http.ResponseWriter, req *http.Request) {
	type DatabaseConfig struct {
		Host       string `json:"DB_HOST"`
		Port       string `json:"DB_PORT"`
		User       string `json:"DB_USER"`
		Password   string `json:"DB_PASS"`
		Name       string `json:"DB"`
		UnixSocket string `json:"DB_UNIX_SOCKET"`
	}

	type CacheConfig struct {
		Host string `json:"CACHE_HOST"`
		Port string `json:"CACHE_PORT"`
	}

	type AppConfig struct {
		DB    DatabaseConfig `json:"DB"`
		Cache CacheConfig    `json:"CACHE"`
	}

	dbConfig := pfconfigdriver.GetType[pfconfigdriver.PfConfDatabase](req.Context())

	appConfig := AppConfig{
		DB: DatabaseConfig{
			Host:       "containers-gateway.internal",
			Port:       "3306",
			User:       dbConfig.User,
			Password:   dbConfig.Pass.String(),
			Name:       dbConfig.Db,
			UnixSocket: "",
		},
		Cache: CacheConfig{
			Host: "containers-gateway.internal",
			Port: "6379",
		},
	}
	jsonData, err := json.Marshal(appConfig)
	w.Header().Set("Content-Type", "application/json")
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusInternalServerError, Message: fmt.Sprintf("Error while marshalling appConfig: %s", err)})
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write(jsonData)

}

func (s *Server) handleRemoteFingerbankCollectorEnv(w http.ResponseWriter, req *http.Request) {
	fingerbankSettings := pfconfigdriver.FingerbankSettings{}
	if err := pfconfigdriver.FetchDecodeSocket(req.Context(), &fingerbankSettings); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusInternalServerError, Message: fmt.Sprintf("Unable to fetch fingerbank settings from pfconfig: %s", err)})
		return
	}

	webservices := pfconfigdriver.PfConfWebservices{}
	if err := pfconfigdriver.FetchDecodeSocket(req.Context(), &webservices); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusInternalServerError, Message: fmt.Sprintf("Unable to fetch webservices config from pfconfig: %s", err)})
		return
	}

	connectors := pfconfigdriver.Connectors{}
	if err := pfconfigdriver.FetchDecodeSocket(req.Context(), &connectors); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusInternalServerError, Message: fmt.Sprintf("Unable to fetch connectors config from pfconfig: %s", err)})
		return
	}

	connectorId := req.URL.Query().Get("CONNECTOR_ID")

	env := map[string]string{
		"COLLECTOR_ARP_LOOKUP":                fingerbankSettings.Collector.ArpLookup,
		"COLLECTOR_CLUSTERED":                 "true",
		"COLLECTOR_CLUSTER_RESYNC_INTERVAL":   fingerbankSettings.Collector.ClusterResyncInterval.String() + "s",
		"COLLECTOR_DB_PERSISTENCE_INTERVAL":   fingerbankSettings.Collector.DbPersistenceInterval.String() + "s",
		"COLLECTOR_DELETE_INACTIVE_ENDPOINTS": fingerbankSettings.Collector.InactiveEndpointsExpiration.String() + "h",
		"COLLECTOR_ENDPOINTS_CACHE_PATH":      "/usr/local/collector-remote/db/collector_endpoints_cache.db",
		"COLLECTOR_ENDPOINTS_DB_PATH":         "/usr/local/collector-remote/db/collector_endpoints.db",
		"COLLECTOR_QUERY_CACHE_TIME":          fingerbankSettings.Collector.QueryCacheTime.String() + "m",
		"FINGERBANK_API_KEY":                  fingerbankSettings.Upstream.ApiKey,
		"PORT":                                "4723",
	}

	if sharedutils.IsEnabled(fingerbankSettings.Collector.NetworkBehaviorAnalysis) {
		env["COLLECTOR_ENDPOINT_ANALYSIS_WEBHOOK"] = "https://localhost:9090/fingerbank/nba/webhook"
		env["COLLECTOR_ENDPOINT_ANALYSIS_WEBHOOK_PASSWORD"] = webservices.Pass.String()
		env["COLLECTOR_ENDPOINT_ANALYSIS_WEBHOOK_USERNAME"] = webservices.User
		env["COLLECTOR_NETWORK_BEHAVIOR_ANALYSIS"] = "true"
		env["COLLECTOR_NETWORK_BEHAVIOR_POLICIES"] = "/usr/local/collector-remote/conf/network_behavior_policies.conf"
	}

	if fingerbankSettings.Collector.AdditionalEnv != "" {
		for _, l := range strings.Split(fingerbankSettings.Collector.AdditionalEnv, "\n") {
			d := strings.Split(l, "=")
			env[d[0]] = strings.Join(d[1:len(d)], "=")
		}
	}

	if connectorId != "" {
		for name, connector := range connectors.Element {
			if name == connectorId {
				for _, l := range connector.FingerbankEnvironment {
					d := strings.Split(l, "=")
					if len(d) == 2 {
						env[d[0]] = d[1]
					} else if len(d) > 2 {
						env[d[0]] = strings.Join(d[1:len(d)], "=")
					}
				}
			}
		}
	}
	envFile := ""
	for k, v := range env {
		envFile += fmt.Sprintf("export %s=%s\n", k, v)
	}

	w.Write([]byte(envFile))
}

func (s *Server) handleRemoteFingerbankCollectorNbaConf(w http.ResponseWriter, req *http.Request) {
	if nbaConf, err := os.ReadFile("/usr/local/pf/conf/network_behavior_policies.conf"); err == nil {
		w.Write(nbaConf)
	} else {
		log.LoggerWContext(req.Context()).Error(fmt.Sprintf("Error while reading Fingerbank NBA config: %s", err))
		w.WriteHeader(http.StatusInternalServerError)
	}
}

func (s *Server) handleRemoteRadiusConf(w http.ResponseWriter, req *http.Request) {
	var data chshare.RadiusCerts
	apiClient := unifiedapiclient.NewFromConfig(req.Context())
	errApi := apiClient.Call(req.Context(), "GET", "/api/v1/config/certificate/radius", &data)
	if errApi != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(errApi.Error()))
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	body, err := json.Marshal(&data)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(err.Error()))
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write(body)
}

func (s *Server) handleRemoteRadiusNas(w http.ResponseWriter, req *http.Request) {
	ctx := req.Context()

	connectorId := req.URL.Query().Get("CONNECTOR_ID")
	if connectorId == "" {
		w.Header().Set("Content-Type", "application/json; charset=UTF-8")
		json.NewEncoder(w).Encode([]struct{}{})
		return
	}

	// Get connector networks for filtering
	var connectorNetworks []*net.IPNet
	Connectors := connector.NewConnectorsContainer(ctx)
	c := Connectors.Get(ctx, connectorId)
	if c != nil {
		connectorNetworks = c.NetworksObjects
	}

	// Get all switch keys from pfconfig (force a fresh fetch so newly added
	// switches show up without waiting for the pool cache to be refreshed)
	switches := pfconfigdriver.PfSwitches{}
	if err := pfconfigdriver.FetchDecodeSocket(ctx, &switches); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("Unable to fetch switches from pfconfig"))
		return
	}

	type NasEntry struct {
		Nasname string `json:"nasname"`
		Secret  string `json:"secret"`
		Type    string `json:"type"`
	}

	var entries []NasEntry
	for _, key := range switches.PfconfigKeys.Keys {
		if key == "default" || key == "100.64.0.1" || key == "127.127.127.127" {
			continue
		}

		// Filter by connector networks if a connector_id was provided
		if len(connectorNetworks) > 0 {
			switchIP := net.ParseIP(key)
			if switchIP == nil {
				continue
			}
			inNetwork := false
			for _, network := range connectorNetworks {
				if network.Contains(switchIP) {
					inNetwork = true
					break
				}
			}
			if !inNetwork {
				continue
			}
		}

		sw := pfconfigdriver.PfConfSwitch{}
		sw.PfconfigHashNS = key
		if err := pfconfigdriver.FetchDecodeSocket(ctx, &sw); err != nil {
			log.LoggerWContext(ctx).Warn(fmt.Sprintf("remote-radius-nas: failed to fetch switch %s from pfconfig, skipping: %s", key, err))
			continue
		}
		secret := sw.RadiusSecret.String()
		if secret == "" {
			continue
		}
		entries = append(entries, NasEntry{
			Nasname: key,
			Secret:  secret,
			Type:    "other",
		})
	}

	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	json.NewEncoder(w).Encode(entries)
}

func (s *Server) handleLocalSecret(w http.ResponseWriter, req *http.Request) {
	localSecret := pfconfigdriver.LocalSecret{}
	if err := pfconfigdriver.FetchDecodeSocket(req.Context(), &localSecret); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("Failed to fetch local secret"))
		return
	}
	w.Header().Set("Content-Type", "text/plain")
	w.Write([]byte(localSecret.Element))
}

func (s *Server) handleRadiusSecret(w http.ResponseWriter, req *http.Request) {
	user := pfconfigdriver.UnifiedApiSystemUser{}
	if err := pfconfigdriver.FetchDecodeSocket(req.Context(), &user); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("Failed to fetch unified API system user"))
		return
	}
	w.Header().Set("Content-Type", "text/plain")
	w.Write([]byte(user.Pass))
}

// handleRemoteMultiDomainConfig returns ConfigRealm / ConfigOrderedRealm /
// ConfigDomain in a single JSON payload so pfconnector-remote can port the
// logic of raddb/mods-config/perl/packetfence-multi-domain.pm::authorize to
// Go locally. It also includes a domain_connector map so the client can
// resolve realm→domain→connector when deciding remote vs degraded.
func (s *Server) handleRemoteMultiDomainConfig(w http.ResponseWriter, req *http.Request) {
	ctx := req.Context()

	realms := pfconfigdriver.Realms{}
	if err := pfconfigdriver.FetchDecodeSocket(ctx, &realms); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusInternalServerError, Message: fmt.Sprintf("Unable to fetch realms from pfconfig: %s", err)})
		return
	}
	ordered := pfconfigdriver.OrderedRealms{}
	if err := pfconfigdriver.FetchDecodeSocket(ctx, &ordered); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusInternalServerError, Message: fmt.Sprintf("Unable to fetch ordered realms from pfconfig: %s", err)})
		return
	}
	domains := pfconfigdriver.Domains{}
	if err := pfconfigdriver.FetchDecodeSocket(ctx, &domains); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusInternalServerError, Message: fmt.Sprintf("Unable to fetch domains from pfconfig: %s", err)})
		return
	}

	domainConnector := s.buildDomainConnectorMap(ctx, domains.Element)

	// Only expose the domain fields the pfconnector-remote actually needs for
	// the authorize/routing decision. The full Domain struct carries secrets
	// (machine_account_password, additional_machine_accounts, ...) that no
	// remote needs over this endpoint — the connector next to the AD does the
	// real NTLM auth through its own ntlm-auth-api, which gets those secrets
	// via a dedicated channel, not here.
	sanitizedDomains := make(map[string]sanitizedDomain, len(domains.Element))
	for id, d := range domains.Element {
		sanitizedDomains[id] = sanitizedDomain{
			NtlmAuthHost: d.NtlmAuthHost,
			NtlmAuthPort: d.NtlmAuthPort,
			UseConnector: d.UseConnector,
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"realms":           realms.Element,
		"ordered_realms":   ordered.Element,
		"domains":          sanitizedDomains,
		"domain_connector": domainConnector,
	})
}

// sanitizedDomain is the subset of pfconfigdriver.Domain exposed to
// pfconnector-remotes via handleRemoteMultiDomainConfig. It mirrors the
// client-side multiDomainDomain in go/chisel/clientapi/multi_domain_config.go
// and deliberately omits every secret/AD-config field.
type sanitizedDomain struct {
	NtlmAuthHost string `json:"ntlm_auth_host"`
	NtlmAuthPort string `json:"ntlm_auth_port"`
	UseConnector string `json:"use_connector"`
}

// buildDomainConnectorMap mirrors find_connector() in
// pfconfig::namespaces::resource::pfconnector_static_connections: for each
// domain with use_connector enabled, look up which connector owns the AD
// server's IP by walking connectors.conf network CIDRs. Domains whose
// AdServer doesn't parse as an IP (e.g. plain hostnames) are skipped — we
// can't pick a connector without resolving DNS, and DNS at this point would
// be racy. The Perl side has the same limitation today.
func (s *Server) buildDomainConnectorMap(ctx context.Context, domains map[string]pfconfigdriver.Domain) map[string]string {
	out := map[string]string{}
	if s.connectors == nil {
		return out
	}
	for id, d := range domains {
		if !sharedutils.IsEnabled(d.UseConnector) {
			continue
		}
		if d.AdServer == "" {
			continue
		}
		ip := net.ParseIP(d.AdServer)
		if ip == nil {
			continue
		}
		c := s.connectors.ForIP(ctx, ip)
		if c == nil {
			continue
		}
		out[id] = c.PfconfigHashNS
	}
	return out
}

// handleConnectorStatus exposes the current connector_id -> up/down map
// maintained by the prober. Refreshed on a fast cadence (default 2s); the
// pfconnector-client polls it to short-circuit FreeRADIUS authorize to
// degraded when the connector serving a realm's AD is unreachable.
func (s *Server) handleConnectorStatus(w http.ResponseWriter, req *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	status := map[string]bool{}
	if s.connectorStatus != nil {
		status = s.connectorStatus.Snapshot()
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"connector_status": status,
	})
}

// handleConnectorHealth is the no-auth probe endpoint declared in
// conf/caddy-services/api.conf.example. Returns the same per-connector map
// as /connector-status plus an "overall" rollup so external monitors and
// k8s-style liveness probes can act on a single field.
//
// Status code is 200 when overall is "ok", 503 when "degraded" — that's
// what most probes expect for unhealthy. "ok" means: every connector the
// prober has observed is currently up. Empty map (no connectors connected
// yet, or prober hasn't run) is treated as "ok" — we have nothing to flag.
func (s *Server) handleConnectorHealth(w http.ResponseWriter, req *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	status := map[string]bool{}
	if s.connectorStatus != nil {
		status = s.connectorStatus.Snapshot()
	}
	overall := "ok"
	for _, up := range status {
		if !up {
			overall = "degraded"
			break
		}
	}
	if overall == "degraded" {
		w.WriteHeader(http.StatusServiceUnavailable)
	} else {
		w.WriteHeader(http.StatusOK)
	}
	json.NewEncoder(w).Encode(map[string]interface{}{
		"overall":    overall,
		"connectors": status,
	})
}
