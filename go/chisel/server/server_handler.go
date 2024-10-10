package chserver

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
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
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/pfk8s"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
	"github.com/phayes/freeport"
	"golang.org/x/crypto/ssh"
	"golang.org/x/sync/errgroup"
)

var activeTunnels = sync.Map{}
var apiPrefix = "/api/v1/pfconnector"

const (
	DYNREVERSE_BIND_ATTEMPTS = 10
	DYNREVERSE_ERR_WAIT      = 50 * time.Millisecond
)

// handleClientHandler is the main http websocket handler for the chisel server
func (s *Server) handleClientHandler(w http.ResponseWriter, r *http.Request) {
	log.LoggerWContext(r.Context()).Info(fmt.Sprintf("Handling %s %s", r.Method, r.URL.Path))

	s.connectors.Refresh(r.Context())

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
	case apiPrefix + "/health":
		w.Write([]byte("OK\n"))
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
	}
	//missing :O
	w.WriteHeader(404)
	w.Write([]byte("Not found"))
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
	pfconfigdriver.FetchDecodeSocket(req.Context(), &localSecret)
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
	eg.Go(func() error {
		//connected, setup reversed-remotes?
		serverInbound := c.Remotes.Reversed(true)
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
			dynPort, err := freeport.GetFreePort()
			if err != nil {
				w.WriteHeader(http.StatusInternalServerError)
				json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusInternalServerError, Message: fmt.Sprintf("Unable to find available port: %s", err)})
				return
			}
			to := payload.To
			remoteStr := fmt.Sprintf("R:%d:%s", dynPort, to)
			remote, err := settings.DecodeRemote(remoteStr)
			if err != nil {
				w.WriteHeader(http.StatusBadRequest)
				json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusBadRequest, Message: fmt.Sprintf("The format for the remote (%s) is invalid: %s", to, err)})
				return
			}

			remote.Dynamic = true
			remote.LastTouched = time.Now()
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
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusInternalServerError, Message: fmt.Sprintf("Unable to create dynreverse remote")})
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
			fmt.Sprintf("1812:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_1812", fmt.Sprintf("%s:1812/udp|radius", managementIP))),
			fmt.Sprintf("1813:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_1813", fmt.Sprintf("%s:1813/udp|radius", managementIP))),
			fmt.Sprintf("1815:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_1815", fmt.Sprintf("%s:1815/udp|radius", managementIP))),
			fmt.Sprintf("127.0.0.1:9090:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_9090", fmt.Sprintf("%s:9090", managementIP))),
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

func (s *Server) handleRemoteFingerbankCollectorEnv(w http.ResponseWriter, req *http.Request) {
	fingerbankSettings := pfconfigdriver.FingerbankSettings{}
	pfconfigdriver.FetchDecodeSocket(req.Context(), &fingerbankSettings)

	webservices := pfconfigdriver.PfConfWebservices{}
	pfconfigdriver.FetchDecodeSocket(req.Context(), &webservices)

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
		env["COLLECTOR_ENDPOINT_ANALYSIS_WEBHOOK_PASSWORD"] = webservices.Pass
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

	envFile := ""
	for k, v := range env {
		envFile += fmt.Sprintf("export %s=%s\n", k, v)
	}

	w.Write([]byte(envFile))
}

func (s *Server) handleRemoteFingerbankCollectorNbaConf(w http.ResponseWriter, req *http.Request) {
	if nbaConf, err := ioutil.ReadFile("/usr/local/pf/conf/network_behavior_policies.conf"); err == nil {
		w.Write(nbaConf)
	} else {
		log.LoggerWContext(req.Context()).Error(fmt.Sprintf("Error while reading Fingerbank NBA config: %s", err))
		w.WriteHeader(http.StatusInternalServerError)
	}
}
