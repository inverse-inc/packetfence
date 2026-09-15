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

// locationlogDriver answers the single locationlog query switchIPForMac makes:
// switchIP is returned as the open session's switch_ip, an empty string as no
// row at all, and queryErr as a failed read.
type locationlogDriver struct {
	switchIP string
	queryErr error
	queries  int
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

func (s *locationlogStmt) Query([]driver.Value) (driver.Rows, error) {
	s.d.queries++
	if s.d.queryErr != nil {
		return nil, s.d.queryErr
	}

	return &locationlogRows{value: s.d.switchIP}, nil
}

// locationlogRows returns one switch_ip, or no row when value is empty, which
// database/sql turns into sql.ErrNoRows.
type locationlogRows struct {
	value string
	done  bool
}

func (r *locationlogRows) Columns() []string { return []string{"switch_ip"} }
func (r *locationlogRows) Close() error      { return nil }

func (r *locationlogRows) Next(dest []driver.Value) error {
	if r.done || r.value == "" {
		return io.EOF
	}

	r.done = true
	dest[0] = r.value
	return nil
}

func locationlogHandler(t *testing.T, d *locationlogDriver) APIHandler {
	t.Helper()
	name := fmt.Sprintf("pf-locationlog-test-%d", time.Now().UnixNano())
	sql.Register(name, d)
	db, err := sql.Open(name, "")
	if err != nil {
		t.Fatalf("sql.Open: %v", err)
	}

	t.Cleanup(func() { db.Close() })
	return APIHandler{db: db}
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

func TestSwitchIPForMac(t *testing.T) {
	ctx := log.LoggerDummyContext()
	const mac = "00:11:22:33:44:55"

	t.Run("no database handle", func(t *testing.T) {
		if got := (APIHandler{}).switchIPForMac(ctx, mac); got != "" {
			t.Errorf("switchIPForMac without a handle = %q, want an empty string", got)
		}
	})

	t.Run("open session", func(t *testing.T) {
		h := locationlogHandler(t, &locationlogDriver{switchIP: "10.1.2.3"})
		if got := h.switchIPForMac(ctx, mac); got != "10.1.2.3" {
			t.Errorf("switchIPForMac = %q, want 10.1.2.3", got)
		}
	})

	t.Run("no open session", func(t *testing.T) {
		h := locationlogHandler(t, &locationlogDriver{})
		if got := h.switchIPForMac(ctx, mac); got != "" {
			t.Errorf("switchIPForMac with no open session = %q, want an empty string", got)
		}
	})

	t.Run("failed read", func(t *testing.T) {
		h := locationlogHandler(t, &locationlogDriver{queryErr: errors.New("lost connection during query")})
		if got := h.switchIPForMac(ctx, mac); got != "" {
			t.Errorf("switchIPForMac on a failed read = %q, want an empty string", got)
		}
	})
}

// Every way the device's connector can fail to resolve must fall back to the
// configured collector, which is what the deployment used before this targeting
// existed.
func TestCollectorClientForMacFallsBackToTheConfiguredCollector(t *testing.T) {
	ctx := log.LoggerDummyContext()
	const mac = "00:11:22:33:44:55"
	fallback := &fakeCollector{name: "configured"}

	cases := []struct {
		name       string
		handler    func(t *testing.T) APIHandler
		connectors map[string][]string
	}{
		{
			name:       "no database handle",
			handler:    func(t *testing.T) APIHandler { return APIHandler{} },
			connectors: map[string][]string{"connA": {"10.1.0.0/16"}},
		},
		{
			name: "no open locationlog session",
			handler: func(t *testing.T) APIHandler {
				return locationlogHandler(t, &locationlogDriver{})
			},
			connectors: map[string][]string{"connA": {"10.1.0.0/16"}},
		},
		{
			name: "unparseable switch IP",
			handler: func(t *testing.T) APIHandler {
				return locationlogHandler(t, &locationlogDriver{switchIP: "not-an-ip"})
			},
			connectors: map[string][]string{"connA": {"10.1.0.0/16"}},
		},
		{
			name: "switch IP behind no connector",
			handler: func(t *testing.T) APIHandler {
				return locationlogHandler(t, &locationlogDriver{switchIP: "192.168.1.1"})
			},
			connectors: map[string][]string{"connA": {"10.1.0.0/16"}},
		},
		{
			name: "device on the local connector",
			handler: func(t *testing.T) APIHandler {
				return locationlogHandler(t, &locationlogDriver{switchIP: "192.168.1.1"})
			},
			connectors: map[string][]string{"local_connector": {}},
		},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			h := c.handler(t)
			cache := map[string]collectorCaller{}
			got := h.collectorClientForMac(ctx, mac, fallback, connectorsFor(t, c.connectors), cache)
			if got != collectorCaller(fallback) {
				t.Errorf("collectorClientForMac = %#v, want the configured collector", got)
			}

			if len(cache) != 0 {
				t.Errorf("a device with no resolvable connector must not populate the per-connector cache, got %v", cache)
			}
		})
	}
}

// The batch handler resolves one client per connector, not one per MAC: a
// connector already in the cache must be answered from it, without another
// endpoint lookup over the tunnel.
func TestCollectorClientForMacUsesTheCachedClient(t *testing.T) {
	ctx := log.LoggerDummyContext()
	fallback := &fakeCollector{name: "configured"}
	dedicated := &fakeCollector{name: "connA"}

	h := locationlogHandler(t, &locationlogDriver{switchIP: "10.1.2.3"})
	connectors := connectorsFor(t, map[string][]string{"connA": {"10.1.0.0/16"}})
	cache := map[string]collectorCaller{"connA": dedicated}

	for _, mac := range []string{"00:11:22:33:44:55", "00:11:22:33:44:56"} {
		got := h.collectorClientForMac(ctx, mac, fallback, connectors, cache)
		if got != collectorCaller(dedicated) {
			t.Fatalf("%s: collectorClientForMac = %#v, want the cached connA collector", mac, got)
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
