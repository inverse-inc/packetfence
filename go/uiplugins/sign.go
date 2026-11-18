package uiplugins

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"strconv"
	"strings"
	"time"
)

// A plugin service authenticates the requests of the proxy with a signature:
// it is reachable by other services than PacketFence (eg the containers of
// the docker bridge), which could otherwise send the identity headers
// themselves.
//
//	X-PacketFence-Plugin-Timestamp  unix time of the request, in seconds
//	X-PacketFence-Plugin-Signature  hex HMAC-SHA256 with the key of the plugin of
//	                                timestamp, method, path (URL encoded, as the
//	                                plugin receives it), query, X-PacketFence-Username,
//	                                X-PacketFence-Admin-Actions, joined by "\n"
//
// The key of a plugin is ProxyKey(name): the HMAC-SHA256 of
// "packetfence ui plugin proxy <name>" with the system init key of
// PacketFence, the same on every node of a cluster. The package of a plugin
// gets it from pf::ui_plugins::proxy_key. A plugin refuses a request without
// a valid signature, or older than SignatureMaxAge.
const (
	TimestampHeader = "X-PacketFence-Plugin-Timestamp"
	SignatureHeader = "X-PacketFence-Plugin-Signature"
	// the admin token, passed to the bundle plugins only (their own API
	// calls to PacketFence then run with the rights of the admin)
	AdminTokenHeader = "X-PacketFence-Admin-Token"
)

// SignatureMaxAge is how old a signed request a plugin accepts
const SignatureMaxAge = 2 * time.Minute

// SystemInitKey gives the system init key of PacketFence, set by the API
// handler (go/config/pfcrypt), a variable for the tests
var SystemInitKey func() []byte

// ProxyKey is the key a plugin checks the signature of the proxy with
func ProxyKey(name string) []byte {
	if SystemInitKey == nil {
		return nil
	}
	mac := hmac.New(sha256.New, SystemInitKey())
	mac.Write([]byte("packetfence ui plugin proxy " + name))
	return mac.Sum(nil)
}

// Signature is the hex signature of a request to a plugin
func Signature(key []byte, timestamp, method, path, query, username, actions string) string {
	mac := hmac.New(sha256.New, key)
	mac.Write([]byte(strings.Join([]string{timestamp, method, path, query, username, actions}, "\n")))
	return hex.EncodeToString(mac.Sum(nil))
}

// signHeaders are the signature headers of a request to the plugin name
func signHeaders(name, method, path, query, username, actions string, now time.Time) (timestamp, signature string) {
	key := ProxyKey(name)
	if key == nil {
		return "", ""
	}
	timestamp = strconv.FormatInt(now.Unix(), 10)
	return timestamp, Signature(key, timestamp, method, path, query, username, actions)
}
