package api

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"
	"fmt"
	"io"
	"net"
	"testing"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// fakeCollector stands in for a fingerbank collector client: the tests only need
// to tell two clients apart, never to call one.
type fakeCollector struct{ name string }

func (c *fakeCollector) Call(ctx context.Context, method, path string, payload, decodeResponseIn interface{}) error {
	return fmt.Errorf("fakeCollector %s was called", c.name)
}

// locationlogDriver answers the locationlog query switchIPsForMacs makes:
// switchIPs maps a MAC to its open session's switch_ip, a MAC absent from it has
// no open session, and queryErr is a failed read. The MACs queried are recorded.
type locationlogDriver struct {
	switchIPs map[string]string
	queryErr  error
	queries   int
	queried   []string
}

func (d *locationlogDriver) Open(string) (driver.Conn, error) { return &locationlogConn{d: d}, nil }

type locationlogConn struct{ d *locationlogDriver }

func (c *locationlogConn) Prepare(string) (driver.Stmt, error) { return &locationlogStmt{d: c.d}, nil }
func (c *locationlogConn) Close() error                        { return nil }
func (c *locationlogConn) Begin() (driver.Tx, error)           { return nil, errors.New("not implemented") }

type locationlogStmt struct{ d *locationlogDriver }

func (s *locationlogStmt) Close() error  { return nil }
func (s *locationlogStmt) NumInput() int { return -1 }

func (s *locationlogStmt) Exec([]driver.Value) (driver.Result, error) {
	return nil, errors.New("not implemented")
}

func (s *locationlogStmt) Query(args []driver.Value) (driver.Rows, error) {
	s.d.queries++
	if s.d.queryErr != nil {
		return nil, s.d.queryErr
	}

	rows := &locationlogRows{}
	for _, arg := range args {
		mac := arg.(string)
		s.d.queried = append(s.d.queried, mac)
		if switchIP, ok := s.d.switchIPs[mac]; ok {
			rows.rows = append(rows.rows, [2]string{mac, switchIP})
		}
	}
	return rows, nil
}

// locationlogRows returns one (mac, switch_ip) row per open session.
type locationlogRows struct {
	rows [][2]string
	next int
}

func (r *locationlogRows) Columns() []string { return []string{"mac", "switch_ip"} }
func (r *locationlogRows) Close() error      { return nil }

func (r *locationlogRows) Next(dest []driver.Value) error {
	if r.next >= len(r.rows) {
		return io.EOF
	}

	dest[0] = r.rows[r.next][0]
	dest[1] = r.rows[r.next][1]
	r.next++
	return nil
}

func locationlogHandler(t *testing.T, d *locationlogDriver) *APIHandler {
	t.Helper()
	name := fmt.Sprintf("pf-locationlog-test-%d", time.Now().UnixNano())
	sql.Register(name, d)
	db, err := sql.Open(name, "")
	if err != nil {
		t.Fatalf("sql.Open: %v", err)
	}

	t.Cleanup(func() { db.Close() })
	return &APIHandler{db: db}
}

// connectorsFor builds a container holding the given connectors without going
// through pfconfig: id "local_connector" with no networks stands in for the
// catch-all ForIP falls back to.
func connectorsFor(t *testing.T, networksByID map[string][]string) *connector.ConnectorsContainer {
	t.Helper()
	structs := map[string]pfconfigdriver.PfconfigObject{}
	for id, networks := range networksByID {
		c := &connector.Connector{Networks: networks}
		c.PfconfigHashNS = id
		for _, network := range networks {
			_, ipnet, err := net.ParseCIDR(network)
			if err != nil {
				t.Fatalf("ParseCIDR(%s): %v", network, err)
			}

			c.NetworksObjects = append(c.NetworksObjects, ipnet)
		}

		structs[id] = c
	}

	cc := &connector.ConnectorsContainer{}
	cc.Structs = structs
	return cc
}

func TestSwitchIPsForMacs(t *testing.T) {
	ctx := log.LoggerDummyContext()

	t.Run("no database handle", func(t *testing.T) {
		if got := (&APIHandler{}).switchIPsForMacs(ctx, []string{"00:11:22:33:44:55"}); len(got) != 0 {
			t.Errorf("switchIPsForMacs without a handle = %v, want none", got)
		}
	})

	t.Run("open sessions in one query", func(t *testing.T) {
		d := &locationlogDriver{switchIPs: map[string]string{"00:11:22:33:44:55": "10.1.2.3"}}
		got := locationlogHandler(t, d).switchIPsForMacs(ctx, []string{"00:11:22:33:44:55", "00:11:22:33:44:56"})
		if len(got) != 1 || got["00:11:22:33:44:55"] != "10.1.2.3" {
			t.Errorf("switchIPsForMacs = %v, want only 00:11:22:33:44:55 => 10.1.2.3", got)
		}
		if d.queries != 1 {
			t.Errorf("switchIPsForMacs ran %d queries, want 1", d.queries)
		}
	})

	t.Run("MACs are normalized to the locationlog form", func(t *testing.T) {
		d := &locationlogDriver{switchIPs: map[string]string{"aa:bb:cc:dd:ee:ff": "10.1.2.3"}}
		got := locationlogHandler(t, d).switchIPsForMacs(ctx, []string{"AA-BB-CC-DD-EE-FF", "not-a-mac"})
		if got[normalizeMac("AA-BB-CC-DD-EE-FF")] != "10.1.2.3" {
			t.Errorf("switchIPsForMacs = %v, want aa:bb:cc:dd:ee:ff => 10.1.2.3", got)
		}
		if len(d.queried) != 1 || d.queried[0] != "aa:bb:cc:dd:ee:ff" {
			t.Errorf("switchIPsForMacs queried %v, want only aa:bb:cc:dd:ee:ff", d.queried)
		}
	})

	t.Run("no valid MAC, no query", func(t *testing.T) {
		d := &locationlogDriver{}
		locationlogHandler(t, d).switchIPsForMacs(ctx, []string{"not-a-mac"})
		if d.queries != 0 {
			t.Errorf("switchIPsForMacs ran %d queries for no valid MAC, want 0", d.queries)
		}
	})

	t.Run("failed read", func(t *testing.T) {
		h := locationlogHandler(t, &locationlogDriver{queryErr: errors.New("lost connection during query")})
		if got := h.switchIPsForMacs(ctx, []string{"00:11:22:33:44:55"}); len(got) != 0 {
			t.Errorf("switchIPsForMacs on a failed read = %v, want none", got)
		}
	})
}

// Every way the device's connector can fail to resolve must fall back to the
// configured collector, which is what the deployment used before this targeting
// existed.
func TestCollectorClientForSwitchIPFallsBackToTheConfiguredCollector(t *testing.T) {
	ctx := log.LoggerDummyContext()
	fallback := &fakeCollector{name: "configured"}

	cases := []struct {
		name       string
		switchIP   string
		connectors map[string][]string
	}{
		{name: "no open locationlog session", connectors: map[string][]string{"connA": {"10.1.0.0/16"}}},
		{name: "unparseable switch IP", switchIP: "not-an-ip", connectors: map[string][]string{"connA": {"10.1.0.0/16"}}},
		{name: "switch IP behind no connector", switchIP: "192.168.1.1", connectors: map[string][]string{"connA": {"10.1.0.0/16"}}},
		{name: "device on the local connector", switchIP: "192.168.1.1", connectors: map[string][]string{"local_connector": {}}},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			cache := map[string]collectorCaller{}
			got := collectorClientForSwitchIP(ctx, c.switchIP, fallback, connectorsFor(t, c.connectors), cache)
			if got != collectorCaller(fallback) {
				t.Errorf("collectorClientForSwitchIP = %#v, want the configured collector", got)
			}

			if len(cache) != 0 {
				t.Errorf("a device with no resolvable connector must not populate the per-connector cache, got %v", cache)
			}
		})
	}
}

func TestHasRemoteConnectors(t *testing.T) {
	ctx := log.LoggerDummyContext()
	cases := []struct {
		name       string
		connectors map[string][]string
		want       bool
	}{
		{name: "local connector only", connectors: map[string][]string{"local_connector": {}}, want: false},
		{name: "remote connector without networks", connectors: map[string][]string{"local_connector": {}, "connA": {}}, want: false},
		{name: "remote connector with networks", connectors: map[string][]string{"local_connector": {}, "connA": {"10.1.0.0/16"}}, want: true},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := connectorsFor(t, c.connectors).HasRemoteConnectors(ctx); got != c.want {
				t.Errorf("HasRemoteConnectors = %v, want %v", got, c.want)
			}
		})
	}
}

// The batch handler resolves one client per connector, not one per MAC: a
// connector already in the cache must be answered from it, without another
// endpoint lookup over the tunnel.
func TestCollectorClientForSwitchIPUsesTheCachedClient(t *testing.T) {
	ctx := log.LoggerDummyContext()
	fallback := &fakeCollector{name: "configured"}
	dedicated := &fakeCollector{name: "connA"}

	connectors := connectorsFor(t, map[string][]string{"connA": {"10.1.0.0/16"}})
	cache := map[string]collectorCaller{"connA": dedicated}

	for _, switchIP := range []string{"10.1.2.3", "10.1.2.4"} {
		got := collectorClientForSwitchIP(ctx, switchIP, fallback, connectors, cache)
		if got != collectorCaller(dedicated) {
			t.Fatalf("%s: collectorClientForSwitchIP = %#v, want the cached connA collector", switchIP, got)
		}
	}
}

// A malformed endpoint must not produce a client the caller would then call
// with a broken host.
func TestBuildCollectorClientFromEndpointRejectsAMalformedURL(t *testing.T) {
	if client := buildCollectorClientFromEndpoint(log.LoggerDummyContext(), "://no-scheme"); client != nil {
		t.Errorf("buildCollectorClientFromEndpoint on a malformed URL = %#v, want nil", client)
	}
}

// buildHandler registers the routes (binding the handler methods) before it opens
// the database handle, so the bound methods must still see that handle.
func TestHandlerMethodsSeeTheDatabaseSetAfterRegistration(t *testing.T) {
	ctx := log.LoggerDummyContext()
	m := &APIHandler{}
	bound := m.switchIPsForMacs
	m.db = locationlogHandler(t, &locationlogDriver{switchIPs: map[string]string{"00:11:22:33:44:55": "10.1.2.3"}}).db

	if got := bound(ctx, []string{"00:11:22:33:44:55"}); got["00:11:22:33:44:55"] != "10.1.2.3" {
		t.Errorf("switchIPsForMacs bound before the handle was set = %v, want 00:11:22:33:44:55 => 10.1.2.3", got)
	}
}

// answeringCollector records its calls and answers them with err.
type answeringCollector struct {
	err   error
	calls int
}

func (c *answeringCollector) Call(ctx context.Context, method, path string, payload, decodeResponseIn interface{}) error {
	c.calls++
	return c.err
}

func TestFetchEndpointDataFallsBackWhenTheDedicatedCollectorFails(t *testing.T) {
	ctx := log.LoggerDummyContext()
	const mac = "00:11:22:33:44:55"

	cases := []struct {
		name                            string
		dedicatedErr, defaultErr        error
		sameClient                      bool
		wantErr                         bool
		wantDedicatedCalls, wantDefault int
	}{
		{name: "dedicated collector answers", wantDedicatedCalls: 1},
		{name: "dedicated collector fails", dedicatedErr: errors.New("tunnel down"), wantDedicatedCalls: 1, wantDefault: 1},
		{name: "both collectors fail", dedicatedErr: errors.New("tunnel down"), defaultErr: errors.New("down"), wantErr: true, wantDedicatedCalls: 1, wantDefault: 1},
		{name: "configured collector fails, no retry", sameClient: true, defaultErr: errors.New("down"), wantErr: true, wantDefault: 1},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			def := &answeringCollector{err: c.defaultErr}
			var client collectorCaller = &answeringCollector{err: c.dedicatedErr}
			if c.sameClient {
				client = def
			}

			_, err := fetchEndpointData(ctx, mac, client, def)
			if (err != nil) != c.wantErr {
				t.Errorf("fetchEndpointData error = %v, want error: %v", err, c.wantErr)
			}
			if !c.sameClient && client.(*answeringCollector).calls != c.wantDedicatedCalls {
				t.Errorf("dedicated collector called %d times, want %d", client.(*answeringCollector).calls, c.wantDedicatedCalls)
			}
			if def.calls != c.wantDefault {
				t.Errorf("configured collector called %d times, want %d", def.calls, c.wantDefault)
			}
		})
	}
}
