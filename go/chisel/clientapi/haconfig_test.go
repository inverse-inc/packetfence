package clientapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strconv"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/chisel/share/connauth"
)

// The master relays a whitelisted tunnel API call for a backup: the request
// must be signed for that name and recent, the master adds its own connector
// id and signs the upstream call, and the answer is sealed with the group key.
func TestHAConfigRelay(t *testing.T) {
	var gotQuery url.Values
	var gotAuth string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotQuery = r.URL.Query()
		gotAuth = r.Header.Get(connauth.Header)
		if r.URL.Path != "/api/v1/pfconnector/remote-radius-nas" {
			http.NotFound(w, r)
			return
		}
		w.Write([]byte(`[{"nasname":"192.0.2.1","secret":"s"}]`))
	}))
	defer upstream.Close()
	defer func(base string) { haTunnelAPIBase = base }(haTunnelAPIBase)
	haTunnelAPIBase = upstream.URL

	const secret = "connector-secret"
	SetHASecret(secret)
	defer ClearHAState()
	api := &API{ConnectorId: "connector-a", ctx: context.Background()}
	handler := haConfigRelay(api)

	request := func(name, ts, signature string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/ha/config-relay?"+url.Values{"name": {name}, "ts": {ts}}.Encode(), nil)
		req.RemoteAddr = "192.0.2.10:40000"
		req.Header.Set(haSignatureHeader, signature)
		rec := httptest.NewRecorder()
		handler(rec, req)
		return rec
	}
	now := strconv.FormatInt(time.Now().Unix(), 10)
	good := configRelaySignature(HAKey(secret), "remote-radius-nas", now)

	SetHAState("192.0.2.100", "backup")
	if rec := request("remote-radius-nas", now, good); rec.Code != http.StatusNotFound {
		t.Fatalf("a backup must not relay: HTTP %d", rec.Code)
	}

	SetHAState("192.0.2.100", "master")
	rec := request("remote-radius-nas", now, good)
	if rec.Code != http.StatusOK {
		t.Fatalf("relay: HTTP %d %s", rec.Code, rec.Body.String())
	}
	opened, err := decryptSnapshot(HACacheKey(secret), rec.Body.Bytes())
	if err != nil || string(opened) != `[{"nasname":"192.0.2.1","secret":"s"}]` {
		t.Fatalf("relayed body: %q %v", opened, err)
	}
	if gotQuery.Get("CONNECTOR_ID") != "connector-a" {
		t.Errorf("upstream query: %v", gotQuery)
	}
	if err := connauth.Verify("connector-a", secret, gotAuth, time.Now()); err != nil {
		t.Errorf("upstream connector auth %q: %v", gotAuth, err)
	}

	// Signature bound to the name: reusing it for another call is refused.
	if rec := request("radius-secret", now, good); rec.Code != http.StatusForbidden {
		t.Errorf("signature of another name: HTTP %d", rec.Code)
	}
	old := strconv.FormatInt(time.Now().Add(-time.Hour).Unix(), 10)
	if rec := request("remote-radius-nas", old, configRelaySignature(HAKey(secret), "remote-radius-nas", old)); rec.Code != http.StatusForbidden {
		t.Errorf("stale request: HTTP %d", rec.Code)
	}
	if rec := request("../../admin", now, configRelaySignature(HAKey(secret), "../../admin", now)); rec.Code != http.StatusNotFound {
		t.Errorf("call outside the whitelist: HTTP %d", rec.Code)
	}
	if rec := request("radius-secret", now, configRelaySignature(HAKey(secret), "radius-secret", now)); rec.Code != http.StatusBadGateway {
		t.Errorf("upstream error must surface as 502: HTTP %d", rec.Code)
	}
}

// The backup side only ever listens on loopback.
func TestServeConfigRelayLoopbackOnly(t *testing.T) {
	if err := ServeConfigRelay(context.Background(), "0.0.0.0:22227", "192.0.2.100", "s"); err == nil {
		t.Fatalf("a non-loopback relay address must be refused")
	}
}
