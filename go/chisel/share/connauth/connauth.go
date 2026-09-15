// Package connauth authenticates a connector-remote's requests to the
// pfconnector server's tunnel-local API (port 22226).
//
// That API is reached through the tunnel and every connector's requests
// arrive from the same place, so the server cannot tell from the connection
// which connector is calling; the handlers take the connector id from the
// request. Any process able to reach a tunnel could therefore act as another
// connector (read its site network, relay DHCP into its scopes, rewrite its
// reported addresses). Requests to those endpoints carry Header: a timestamp
// and an HMAC-SHA256 of the connector id and the timestamp under the
// connector's own secret, which only that connector and the server know.
package connauth

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"strconv"
	"strings"
	"time"
)

// Header carries "<unix timestamp>:<hex hmac>".
const Header = "X-PF-Connector-Auth"

// MaxSkew bounds the age of a signature (replay window; connector clocks
// are NTP-synced but not necessarily tight).
const MaxSkew = 5 * time.Minute

var (
	ErrMissing = errors.New("missing connector signature")
	ErrInvalid = errors.New("invalid connector signature")
	ErrStale   = errors.New("stale connector signature")
)

func mac(connectorID, secret, ts string) string {
	h := hmac.New(sha256.New, []byte(secret))
	h.Write([]byte("pfconnector-api:" + connectorID + ":" + ts))
	return hex.EncodeToString(h.Sum(nil))
}

// Sign returns the header value for connectorID at time now.
func Sign(connectorID, secret string, now time.Time) string {
	ts := strconv.FormatInt(now.Unix(), 10)
	return ts + ":" + mac(connectorID, secret, ts)
}

// Verify checks a header value against the connector's secret.
func Verify(connectorID, secret, header string, now time.Time) error {
	if header == "" {
		return ErrMissing
	}
	ts, sig, ok := strings.Cut(header, ":")
	if !ok || secret == "" {
		return ErrInvalid
	}
	unix, err := strconv.ParseInt(ts, 10, 64)
	if err != nil {
		return ErrInvalid
	}
	want := mac(connectorID, secret, ts)
	if len(sig) != len(want) || !hmac.Equal([]byte(sig), []byte(want)) {
		return ErrInvalid
	}
	if skew := now.Sub(time.Unix(unix, 0)); skew > MaxSkew || skew < -MaxSkew {
		return ErrStale
	}
	return nil
}
