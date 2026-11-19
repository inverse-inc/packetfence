package settings

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

// short-hand conversions (see remote_test)
//   3000 ->
//     local  127.0.0.1:3000
//     remote 127.0.0.1:3000
//   foobar.com:3000 ->
//     local  127.0.0.1:3000
//     remote foobar.com:3000
//   3000:google.com:80 ->
//     local  127.0.0.1:3000
//     remote google.com:80
//   192.168.0.1:3000:google.com:80 ->
//     local  192.168.0.1:3000
//     remote google.com:80
//   127.0.0.1:1080:socks
//     local  127.0.0.1:1080
//     remote socks
//   stdio:example.com:22
//     local  stdio
//     remote example.com:22
//   1.1.1.1:53/udp
//     local  127.0.0.1:53/udp
//     remote 1.1.1.1:53/udp

type Remote struct {
	sync.Mutex
	LastTouched                         time.Time
	LocalHost, LocalPort, LocalProto    string
	RemoteHost, RemotePort, RemoteProto string
	Handler                             string
	ReusedTcpListener                   *net.TCPListener
	ReusedUdpConn                       *net.UDPConn
	Dynamic, Socks, Reverse, Stdio      bool
	// Companion marks the second listener of a dynamic reverse on the
	// containers gateway: the same forward, not reported on its own.
	Companion bool
}

const revPrefix = "R:"

func DecodeRemote(s string) (*Remote, error) {
	reverse := false
	if strings.HasPrefix(s, revPrefix) {
		s = strings.TrimPrefix(s, revPrefix)
		reverse = true
	}

	parts := regexp.MustCompile(`(\[[^\[\]]+\]|[^\[\]:]+):?`).FindAllStringSubmatch(s, -1)
	if len(parts) <= 0 || len(parts) >= 5 {
		return nil, errors.New("Invalid remote")
	}

	r := &Remote{Reverse: reverse, Handler: "raw"}
	//parse from back to front, to set 'remote' fields first,
	//then to set 'local' fields second (allows the 'remote' side
	//to provide the defaults)
	for i := len(parts) - 1; i >= 0; i-- {
		p := parts[i][1]
		//remote portion is socks?
		if i == len(parts)-1 && p == "socks" {
			r.Socks = true
			continue
		}
		//local portion is stdio?
		if i == 0 && p == "stdio" {
			r.Stdio = true
			continue
		}

		p, proto, handler := L4Proto(p)
		if proto != "" {
			if r.RemotePort == "" {
				r.RemoteProto = proto
			} else if r.LocalProto == "" {
				r.LocalProto = proto
			}

			r.Handler = handler
		}

		if isPort(p) {
			if !r.Socks && r.RemotePort == "" {
				if p == "0" {
					return nil, errors.New("Invalid port")
				}
				r.RemotePort = p
			}
			r.LocalPort = p
			continue
		}

		if !r.Socks && (r.RemotePort == "" && r.LocalPort == "") {
			return nil, errors.New("Missing ports")
		}

		if !isHost(p) {
			return nil, errors.New("Invalid host")
		}

		if !r.Socks && r.RemoteHost == "" {
			r.RemoteHost = p
		} else {
			r.LocalHost = p
		}
	}
	//remote string parsed, apply defaults...
	if r.Socks {
		//socks defaults
		if r.LocalHost == "" {
			r.LocalHost = "127.0.0.1"
		}
		if r.LocalPort == "" {
			r.LocalPort = "1080"
		}
	} else {
		//non-socks defaults
		if r.LocalHost == "" {
			r.LocalHost = "0.0.0.0"
		}
		if r.RemoteHost == "" {
			r.RemoteHost = "127.0.0.1"
		}
	}
	if r.RemoteProto == "" {
		r.RemoteProto = "tcp"
	}
	if r.LocalProto == "" {
		r.LocalProto = r.RemoteProto
	}
	if r.LocalProto != r.RemoteProto {
		//TODO support cross protocol
		//tcp <-> udp, is faily straight forward
		//udp <-> tcp, is trickier since udp is stateless and tcp is not
		return nil, errors.New("cross-protocol remotes are not supported yet")
	}
	if r.Socks && r.RemoteProto != "tcp" {
		return nil, errors.New("only TCP SOCKS is supported")
	}
	if r.Stdio && r.Reverse {
		return nil, errors.New("stdio cannot be reversed")
	}

	if r.Reverse && r.LocalPort == "0" {
		if err := r.setupLocalPort(); err != nil {
			return nil, fmt.Errorf("Cannot bind to a local port: %w", err)
		}
	}

	return r, nil
}

// ValidateRemappedRemoteBinds parses PFCONNECTOR_BIND_PORT_MAP entries such as
// "443=8443", "53/udp=5353" or "80=-" into a map of source to target. A source
// without a protocol applies to both tcp and udp; a port/proto source overrides it.
// Chains and cycles (a target that is also a source) and two sources landing on the
// same target port/proto are rejected.
func ValidateRemappedRemoteBinds(ports []string) (map[string]string, error) {
	portMap := map[string]string{}
	targetPorts := map[string]string{} // "port/proto" -> source mapped onto it
	sources := []string{}              // input order, so errors are stable

	for _, entry := range ports {
		entry = strings.TrimSpace(entry)
		if entry == "" {
			continue
		}
		from, to, ok := strings.Cut(entry, "=")
		if !ok {
			return nil, fmt.Errorf("invalid entry %q: expected port[/proto]=port|-", entry)
		}
		port, proto, hasProto := strings.Cut(from, "/")
		if port == "0" || !isPort(port) || (hasProto && proto != "udp" && proto != "tcp") {
			return nil, fmt.Errorf("invalid source port or protocol: %s", from)
		}
		if (to != "-" && !isPort(to)) || to == "0" {
			return nil, fmt.Errorf("invalid target port: %s", to)
		}
		target, ok := portMap[from]
		if ok {
			return nil, fmt.Errorf("cannot bind port %s which is already bound to %s", from, target)
		}
		// duplicate targets, per protocol; "-" drops the bind so it is never a target
		if to != "-" {
			for _, p := range sourceProtos(proto, hasProto) {
				other, ok := targetPorts[to+"/"+p]
				// 53=5353,53/udp=5353 is an override of the same source, not a collision
				if ok && strings.Split(other, "/")[0] != port {
					return nil, fmt.Errorf("cannot bind %s and %s to the same target %s/%s", other, from, to, p)
				}
				targetPorts[to+"/"+p] = from
			}
		}
		portMap[from] = to
		sources = append(sources, from)
	}
	// detect chains and cycles: a target that is also a source on the same protocol
	for _, from := range sources {
		to := portMap[from]
		if to == "-" {
			continue
		}
		port, proto, hasProto := strings.Cut(from, "/")
		for _, p := range sourceProtos(proto, hasProto) {
			// i.e. 80=443,443/tcp=8443: a port/proto rule overrides a plain port rule
			cycledFrom, ok := portMap[to+"/"+p]
			if !ok {
				// i.e. 80=443,443=80
				cycledFrom, ok = portMap[to]
			}
			if !ok {
				continue
			}
			if cycledFrom == port {
				return nil, fmt.Errorf("port map has a cycle: %s=%s and %s/%s=%s", from, to, to, p, cycledFrom)
			}
			return nil, fmt.Errorf("port map has a chain: %s=%s but %s/%s is also remapped", from, to, to, p)
		}
	}
	return portMap, nil
}

// sourceProtos returns the protocols a source applies to: a source without a
// protocol applies to both tcp and udp.
func sourceProtos(proto string, hasProto bool) []string {
	if hasProto {
		return []string{proto}
	}
	return []string{"tcp", "udp"}
}

// RemapRemoteBinds rewrites the local port of remotes fetched from the pfconnector
// server so they don't collide with host services. Remotes mapped to "-" are dropped.
// A remote remapped onto a port/proto that is already in remotes is skipped and
// described in conflicts, so the remaining remotes can still bind.
func RemapRemoteBinds(bindPortMap map[string]string, remotes []*Remote) (remapped []*Remote, conflicts []string) {
	// Snapshot the original binds before any LocalPort is rewritten below.
	existing := map[string]bool{}
	for _, remote := range remotes {
		existing[remote.LocalPort+"/"+remote.LocalProto] = true
	}

	remapped = make([]*Remote, 0, len(remotes))
	for _, remote := range remotes {
		to, ok := bindPortMap[remote.LocalPort+"/"+remote.LocalProto]
		if !ok {
			to, ok = bindPortMap[remote.LocalPort]
		}
		switch {
		case !ok:
			remapped = append(remapped, remote)
		case to == "-":
			// dropped; rules are logged at startup
		case existing[to+"/"+remote.LocalProto]:
			conflicts = append(conflicts, fmt.Sprintf("%s/%s -> %s: %s/%s is already bound", remote.LocalPort, remote.LocalProto, to, to, remote.LocalProto))
		default:
			remote.LocalPort = to
			remapped = append(remapped, remote)
		}
	}
	return remapped, conflicts
}

func (r *Remote) setupLocalPort() error {
	if r.LocalProto == "tcp" {
		addr, err := net.ResolveTCPAddr("tcp", r.Local())
		if err != nil {
			return fmt.Errorf("resolve: %w", err)
		}

		tl, err := net.ListenTCP("tcp", addr)
		if err != nil {
			return fmt.Errorf("net.ListenTCP: %w", err)
		}

		r.LocalPort = strconv.Itoa(tl.Addr().(*net.TCPAddr).Port)
		r.ReusedTcpListener = tl
		r.Dynamic = true
		return nil
	}

	if r.LocalProto == "udp" {
		addr, err := net.ResolveUDPAddr("udp", r.Local())
		if err != nil {
			return fmt.Errorf("resolve: %w", err)
		}

		conn, err := net.ListenUDP("udp", addr)
		if err != nil {
			return fmt.Errorf("net.ListenUDP: %w", err)
		}

		r.LocalPort = strconv.Itoa(conn.LocalAddr().(*net.UDPAddr).Port)
		r.ReusedUdpConn = conn
		r.Dynamic = true
		return nil
	}

	return errors.New("Proto not supported")
}

func isPort(s string) bool {
	n, err := strconv.Atoi(s)
	if err != nil {
		return false
	}
	if n < 0 || n > 65535 {
		return false
	}
	return true
}

func isHost(s string) bool {
	_, err := url.Parse("//" + s)
	if err != nil {
		return false
	}
	return true
}

var l4Proto = regexp.MustCompile(`(?i)\/(tcp|udp)(|.*)?$`)

// L4Proto extacts the layer-4 protocol from the given string
func L4Proto(s string) (string, string, string) {
	handler := "raw"
	if l4Proto.MatchString(s) {
		split := strings.SplitN(s, "|", 2)
		if len(split) > 1 {
			s = split[0]
			handler = split[1]
		}

		l := len(s)
		return strings.ToLower(s[:l-4]), s[l-3:], handler
	}

	return s, "", handler
}

// implement Stringer
func (r *Remote) String() string {
	sb := strings.Builder{}
	if r.Reverse {
		sb.WriteString(revPrefix)
	}
	sb.WriteString(strings.TrimPrefix(r.Local(), "0.0.0.0:"))
	sb.WriteString("=>")
	sb.WriteString(strings.TrimPrefix(r.Remote(), "127.0.0.1:"))
	if r.RemoteProto == "udp" {
		sb.WriteString("/udp")
	}
	return sb.String()
}

// Encode remote to a string
func (r *Remote) Encode() string {
	if r.LocalPort == "" {
		r.LocalPort = r.RemotePort
	}
	local := r.Local()
	remote := r.Remote()
	if r.RemoteProto == "udp" {
		remote += "/udp"
	}
	if r.Reverse {
		return "R:" + local + ":" + remote
	}
	return local + ":" + remote
}

// Local is the decodable local portion
func (r *Remote) Local() string {
	if r.Stdio {
		return "stdio"
	}
	if r.LocalHost == "" {
		r.LocalHost = "0.0.0.0"
	}
	return r.LocalHost + ":" + r.LocalPort
}

// Remote is the decodable remote portion
func (r *Remote) Remote() string {
	if r.Socks {
		return "socks"
	}
	if r.RemoteHost == "" {
		r.RemoteHost = "127.0.0.1"
	}
	return r.RemoteHost + ":" + r.RemotePort
}

// UserAddr is checked when checking if a
// user has access to a given remote
func (r *Remote) UserAddr() string {
	if r.Reverse {
		return "R:" + r.LocalHost + ":" + r.LocalPort
	}
	return r.RemoteHost + ":" + r.RemotePort
}

// CanListen checks if the port can be listened on
func (r *Remote) CanListen() bool {
	//valid protocols
	switch r.LocalProto {
	case "tcp":
		conn, err := net.Listen("tcp", r.Local())
		if err == nil {
			conn.Close()
			return true
		}
		return false
	case "udp":
		addr, err := net.ResolveUDPAddr("udp", r.Local())
		if err != nil {
			return false
		}
		conn, err := net.ListenUDP(r.LocalProto, addr)
		if err == nil {
			conn.Close()
			return true
		}
		return false
	}
	//invalid
	return false
}

type Remotes []*Remote

// Filter out forward reversed/non-reversed remotes
func (rs Remotes) Reversed(reverse bool) Remotes {
	subset := Remotes{}
	for _, r := range rs {
		match := r.Reverse == reverse
		if match {
			subset = append(subset, r)
		}
	}
	return subset
}

// Encode back into strings
func (rs Remotes) Encode() []string {
	s := make([]string, len(rs))
	for i, r := range rs {
		s[i] = r.Encode()
	}
	return s
}
