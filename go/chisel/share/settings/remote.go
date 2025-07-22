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
//   1.1.1.1:53/dual
//     local  127.0.0.1:53/dual (both TCP and UDP)
//     remote 1.1.1.1:53/dual (both TCP and UDP)

type Remote struct {
	sync.Mutex
	LastTouched                     time.Time
	LocalHost, LocalPort            string
	RemoteHost, RemotePort          string
	LocalProtocols, RemoteProtocols []string // Support multiple protocols
	Handler                         string
	ReusedTcpListener               *net.TCPListener
	ReusedUdpConn                   *net.UDPConn
	Dynamic, Socks, Reverse, Stdio  bool
	DualStack                       bool // New field to indicate dual stack mode
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

	r := &Remote{
		Reverse:         reverse,
		Handler:         "raw",
		LocalProtocols:  []string{},
		RemoteProtocols: []string{},
	}

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

		p, protocols, handler := L4Proto(p)
		if len(protocols) > 0 {
			if len(r.RemoteProtocols) == 0 {
				r.RemoteProtocols = protocols
			} else if len(r.LocalProtocols) == 0 {
				r.LocalProtocols = protocols
			}
			r.Handler = handler

			// Check if dual stack is requested
			if len(protocols) > 1 || (len(protocols) == 1 && protocols[0] == "dual") {
				r.DualStack = true
			}
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

	// Set default protocols
	if len(r.RemoteProtocols) == 0 {
		if r.DualStack {
			r.RemoteProtocols = []string{"tcp", "udp"}
		} else {
			r.RemoteProtocols = []string{"tcp"}
		}
	}
	if len(r.LocalProtocols) == 0 {
		r.LocalProtocols = r.RemoteProtocols
	}

	// Handle dual stack protocol expansion
	for i, proto := range r.RemoteProtocols {
		if proto == "dual" {
			r.RemoteProtocols = append(r.RemoteProtocols[:i], append([]string{"tcp", "udp"}, r.RemoteProtocols[i+1:]...)...)
			r.DualStack = true
			break
		}
	}
	for i, proto := range r.LocalProtocols {
		if proto == "dual" {
			r.LocalProtocols = append(r.LocalProtocols[:i], append([]string{"tcp", "udp"}, r.LocalProtocols[i+1:]...)...)
			r.DualStack = true
			break
		}
	}

	// Validate protocol compatibility
	if r.Socks && !contains(r.RemoteProtocols, "tcp") {
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

func (r *Remote) setupLocalPort() error {
	if contains(r.LocalProtocols, "tcp") {
		addr, err := net.ResolveTCPAddr("tcp", r.Local())
		if err != nil {
			return fmt.Errorf("resolve TCP: %w", err)
		}

		tl, err := net.ListenTCP("tcp", addr)
		if err != nil {
			return fmt.Errorf("net.ListenTCP: %w", err)
		}

		r.LocalPort = strconv.Itoa(tl.Addr().(*net.TCPAddr).Port)
		r.ReusedTcpListener = tl
		r.Dynamic = true
	}

	if contains(r.LocalProtocols, "udp") {
		addr, err := net.ResolveUDPAddr("udp", r.Local())
		if err != nil {
			return fmt.Errorf("resolve UDP: %w", err)
		}

		conn, err := net.ListenUDP("udp", addr)
		if err != nil {
			return fmt.Errorf("net.ListenUDP: %w", err)
		}

		// Only set LocalPort if not already set by TCP
		if r.LocalPort == "" || r.LocalPort == "0" {
			r.LocalPort = strconv.Itoa(conn.LocalAddr().(*net.UDPAddr).Port)
		}
		r.ReusedUdpConn = conn
		r.Dynamic = true
	}

	if len(r.LocalProtocols) == 0 {
		return errors.New("No protocols specified")
	}

	return nil
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

var l4Proto = regexp.MustCompile(`(?i)\/(tcp|udp|dual)(|.*)?$`)

// L4Proto extracts the layer-4 protocol(s) from the given string
func L4Proto(s string) (string, []string, string) {
	handler := "raw"
	if l4Proto.MatchString(s) {
		split := strings.SplitN(s, "|", 2)
		if len(split) > 1 {
			s = split[0]
			handler = split[1]
		}

		l := len(s)
		protoStr := strings.ToLower(s[len(s)-3:])
		if strings.HasSuffix(s, "/dual") {
			protoStr = "dual"
			l = len(s) - 5 // "/dual" is 5 characters
		} else {
			l = l - 4 // "/tcp" or "/udp" is 4 characters
		}

		var protocols []string
		if protoStr == "dual" {
			protocols = []string{"tcp", "udp"}
		} else {
			protocols = []string{protoStr}
		}

		return s[:l], protocols, handler
	}

	return s, []string{}, handler
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

	if r.DualStack {
		sb.WriteString("/dual")
	} else if len(r.RemoteProtocols) == 1 && r.RemoteProtocols[0] == "udp" {
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

	if r.DualStack {
		remote += "/dual"
	} else if len(r.RemoteProtocols) == 1 && r.RemoteProtocols[0] == "udp" {
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
	canListenTCP := false
	canListenUDP := false

	// Check TCP if it's one of the protocols
	if contains(r.LocalProtocols, "tcp") {
		conn, err := net.Listen("tcp", r.Local())
		if err == nil {
			conn.Close()
			canListenTCP = true
		}
	} else {
		canListenTCP = true // Not required, so consider it "OK"
	}

	// Check UDP if it's one of the protocols
	if contains(r.LocalProtocols, "udp") {
		addr, err := net.ResolveUDPAddr("udp", r.Local())
		if err == nil {
			conn, err := net.ListenUDP("udp", addr)
			if err == nil {
				conn.Close()
				canListenUDP = true
			}
		}
	} else {
		canListenUDP = true // Not required, so consider it "OK"
	}

	// For dual stack, both must be available
	if r.DualStack {
		return canListenTCP && canListenUDP
	}

	// For single protocol, just that one needs to work
	return canListenTCP && canListenUDP
}

// Helper function to check if a slice contains a string
func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}

// GetProtocols returns the protocols for local and remote
func (r *Remote) GetLocalProtocols() []string {
	return r.LocalProtocols
}

func (r *Remote) GetRemoteProtocols() []string {
	return r.RemoteProtocols
}

// IsDualStack returns whether this remote uses dual stack
func (r *Remote) IsDualStack() bool {
	return r.DualStack
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
