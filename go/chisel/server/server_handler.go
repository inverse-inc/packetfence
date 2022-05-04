package chserver

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
	chshare "github.com/jpillora/chisel/share"
	"github.com/jpillora/chisel/share/cnet"
	"github.com/jpillora/chisel/share/settings"
	"github.com/jpillora/chisel/share/tunnel"
	"github.com/phayes/freeport"
	"golang.org/x/crypto/ssh"
	"golang.org/x/sync/errgroup"
)

var activeTunnels = sync.Map{}
var activeDynReverse = sync.Map{}
var apiPrefix = "/api/v1/pfconnector"

// handleClientHandler is the main http websocket handler for the chisel server
func (s *Server) handleClientHandler(w http.ResponseWriter, r *http.Request) {
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
	//successfuly validated config!
	r.Reply(true, nil)
	//tunnel per ssh connection
	tunnel := tunnel.New(tunnel.Config{
		Logger:    l,
		Inbound:   s.config.Reverse,
		Outbound:  true, //server always accepts outbound
		Socks:     s.config.Socks5,
		KeepAlive: s.config.KeepAlive,
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
		activeTunnels.Store(user.Name, tunnel)
		res := s.redis.Set(fmt.Sprintf("%s%s", s.redisTunnelsNamespace, user.Name), fmt.Sprintf("%s://%s", s.listenProto, req.Context().Value(http.LocalAddrContextKey).(net.Addr).String()), 0)
		if res.Err() != nil {
			l.Errorf("Unable to write tunnel info to Redis: %s", res.Err())
		}
	}
	err = eg.Wait()
	if err != nil && !strings.HasSuffix(err.Error(), "EOF") {
		l.Debugf("Closed connection (%s)", err)
	} else {
		l.Debugf("Closed connection")
	}
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

	hostPort := strings.Split(req.Context().Value(http.LocalAddrContextKey).(net.Addr).String(), ":")
	host := sharedutils.EnvOrDefault("PFCONNECTOR_SERVER_HOST", strings.Join(hostPort[0:len(hostPort)-1], ":"))

	cacheKey := fmt.Sprintf("%s:%s", payload.ConnectorID, payload.To)
	if o, found := activeDynReverse.Load(cacheKey); found {
		remote := o.(*settings.Remote)
		var err error
		func() {
			remote.Lock()
			defer remote.Unlock()
			remote.LastTouched = time.Now()

			switch remote.LocalProto {
			case "tcp":
				var c net.Listener
				c, err = net.Listen(remote.LocalProto, fmt.Sprintf(":%s", remote.LocalPort))
				if c != nil {
					c.Close()
				}
			case "udp":
				var c net.PacketConn
				c, err = net.ListenPacket(remote.LocalProto, fmt.Sprintf(":%s", remote.LocalPort))
				if c != nil {
					c.Close()
				}
			}
		}()
		if err != nil {
			json.NewEncoder(w).Encode(gin.H{"host": host, "port": remote.LocalPort, "message": fmt.Sprintf("Reusing existing port %s", remote.LocalPort)})
			return
		} else {
			activeDynReverse.Delete(cacheKey)
		}
	}

	connectorId := payload.ConnectorID
	if o, ok := activeTunnels.Load(connectorId); ok {
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
		go func() {
			// TODO: handle an error
			tun.BindRemotes(context.Background(), []*settings.Remote{remote})
		}()

		activeDynReverse.Store(cacheKey, remote)
		json.NewEncoder(w).Encode(gin.H{"host": host, "port": dynPort, "message": fmt.Sprintf("Setup remote %s", remoteStr)})
	} else {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusNotFound, Message: fmt.Sprintf("Unable to find active connector tunnel: %s", connectorId)})
		return
	}
}

func (s *Server) handleRemoteBinds(w http.ResponseWriter, req *http.Request) {
	managementNetwork := pfconfigdriver.Config.Interfaces.ManagementNetwork
	pfconfigdriver.FetchDecodeSocket(req.Context(), &managementNetwork)

	var managementIP string
	if managementNetwork.Vip != "" {
		managementIP = managementNetwork.Vip
	} else {
		managementIP = managementNetwork.Ip
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(gin.H{"binds": []string{
		fmt.Sprintf("80:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_80", fmt.Sprintf("%s:80", managementIP))),
		fmt.Sprintf("443:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_443", fmt.Sprintf("%s:443", managementIP))),
		fmt.Sprintf("1812:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_1812", fmt.Sprintf("%s:1812/udp", managementIP))),
		fmt.Sprintf("1813:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_1813", fmt.Sprintf("%s:1813/udp", managementIP))),
		fmt.Sprintf("1815:%s", sharedutils.EnvOrDefault("PFCONNECTOR_BINDS_HOST_PORT_1815", fmt.Sprintf("%s:1815/udp", managementIP))),
	}})
}
